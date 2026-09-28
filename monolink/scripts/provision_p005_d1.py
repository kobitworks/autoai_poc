#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import re
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from typing import Any

API_BASE = "https://api.cloudflare.com/client/v4"
CONTROL_DATABASE_NAME = "p016-db-management-production"
PROJECT_ID = "P005"
SYSTEM_NAME = "モノリンク"
LOCATION_HINT = "apac"
MAX_DATABASE_NAME_LENGTH = 31

# Cloudflare D1 docs currently publish 10 databases/account on Workers Free
# and 50,000 on Workers Paid. To avoid requiring Billing Read permission,
# this task uses the smaller published limit as a conservative lower bound.
CONSERVATIVE_DATABASE_LIMIT = 10


class ProvisioningError(RuntimeError):
    pass


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sql_quote(value: Any) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def request_json(method: str, url: str, token: str, payload: Any | None = None) -> dict[str, Any]:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise ProvisioningError(f"Cloudflare HTTP {exc.code}: {detail[:800]}") from exc

    if not data.get("success", False):
        raise ProvisioningError("Cloudflare API error: " + json.dumps(data.get("errors", [])))
    return data


def query_rows(data: dict[str, Any]) -> list[dict[str, Any]]:
    result = data.get("result") or []
    rows: list[dict[str, Any]] = []
    if isinstance(result, list):
        for block in result:
            if not isinstance(block, dict):
                continue
            if block.get("success") is False:
                raise ProvisioningError("D1 query failed")
            block_rows = block.get("results") or []
            if isinstance(block_rows, list):
                rows.extend(x for x in block_rows if isinstance(x, dict))
    return rows


def ascii_slug(system_name: str, max_length: int) -> str:
    normalized = unicodedata.normalize("NFKD", system_name.strip())
    ascii_text = normalized.encode("ascii", "ignore").decode("ascii").lower()
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_text).strip("-")
    digest = hashlib.sha256(system_name.encode("utf-8")).hexdigest()
    if not slug:
        slug = f"sys-{digest[:8]}"
    if len(slug) > max_length:
        prefix_length = max_length - 7
        prefix = slug[:prefix_length].rstrip("-") or "sys"
        slug = f"{prefix}-{digest[:6]}"[:max_length].strip("-")
    return slug


def target_database_name() -> str:
    project_key = PROJECT_ID.lower()
    suffix = "-production"
    max_slug_length = MAX_DATABASE_NAME_LENGTH - len(project_key) - 1 - len(suffix)
    slug = ascii_slug(SYSTEM_NAME, max_slug_length)
    name = f"{project_key}-{slug}-production"
    if len(name) > MAX_DATABASE_NAME_LENGTH or not re.fullmatch(r"[a-z0-9-]+", name):
        raise ProvisioningError(f"Unsafe derived database name: {name}")
    return name


class D1Client:
    def __init__(self, account_id: str, token: str) -> None:
        self.account_id = account_id
        self.token = token
        self.base = f"{API_BASE}/accounts/{account_id}/d1/database"

    def list_all(self) -> tuple[list[dict[str, Any]], int]:
        url = f"{self.base}?page=1&per_page=10000"
        data = request_json("GET", url, self.token)
        result = data.get("result") or []
        if not isinstance(result, list):
            raise ProvisioningError("Unexpected D1 list response")
        items = [x for x in result if isinstance(x, dict)]
        info = data.get("result_info") or {}
        total_count = int(info.get("total_count", len(items)))
        if total_count != len(items):
            # We only create under the conservative limit of 10, so a larger
            # paginated account is not safe to auto-provision in this workflow.
            if total_count >= CONSERVATIVE_DATABASE_LIMIT:
                return items, total_count
            raise ProvisioningError("D1 list pagination mismatch below conservative limit")
        return items, total_count

    def find_exact(self, name: str) -> dict[str, str] | None:
        query = urllib.parse.urlencode({"name": name, "page": 1, "per_page": 10})
        data = request_json("GET", f"{self.base}?{query}", self.token)
        result = data.get("result") or []
        hits = [x for x in result if isinstance(x, dict) and x.get("name") == name]
        if len(hits) > 1:
            raise ProvisioningError(f"Multiple D1 databases found with exact name: {name}")
        if not hits:
            return None
        uuid = hits[0].get("uuid")
        if not uuid:
            raise ProvisioningError(f"D1 database has no uuid: {name}")
        return {"name": name, "uuid": str(uuid)}

    def create(self, name: str) -> dict[str, str]:
        data = request_json(
            "POST",
            self.base,
            self.token,
            {"name": name, "primary_location_hint": LOCATION_HINT},
        )
        result = data.get("result") or {}
        uuid = result.get("uuid") if isinstance(result, dict) else None
        if not uuid:
            raise ProvisioningError(f"D1 create response missing uuid for {name}")
        return {"name": name, "uuid": str(uuid)}

    def query(self, uuid: str, sql: str) -> list[dict[str, Any]]:
        data = request_json(
            "POST",
            f"{self.base}/{uuid}/query",
            self.token,
            {"sql": sql},
        )
        return query_rows(data)


def catalog_rows(client: D1Client, control_uuid: str) -> list[dict[str, Any]]:
    return client.query(
        control_uuid,
        "SELECT d.environment,d.database_name,d.database_uuid,"
        "sv.version AS schema_version "
        "FROM databases d "
        "LEFT JOIN schema_versions sv ON sv.database_id=d.id "
        f"WHERE d.project_id={sql_quote(PROJECT_ID)} "
        "AND d.environment='production';",
    )


def table_count(client: D1Client, uuid: str) -> int:
    rows = client.query(
        uuid,
        "SELECT COUNT(*) AS table_count FROM sqlite_master "
        "WHERE type='table' AND name NOT LIKE 'sqlite_%';",
    )
    if not rows:
        raise ProvisioningError("Could not verify target D1 table count")
    return int(rows[0].get("table_count", 0))


def main() -> int:
    account_id = os.environ.get("CLOUDFLARE_ACCOUNT_ID", "")
    token = os.environ.get("CLOUDFLARE_API_TOKEN", "")
    if not account_id or not token:
        raise ProvisioningError("Cloudflare GitHub Secrets are missing")

    client = D1Client(account_id, token)
    desired_name = target_database_name()

    control = client.find_exact(CONTROL_DATABASE_NAME)
    if control is None:
        raise ProvisioningError(f"Required P016 control D1 is missing: {CONTROL_DATABASE_NAME}")

    existing = client.find_exact(desired_name)
    rows = catalog_rows(client, control["uuid"])

    if len(rows) > 1:
        raise ProvisioningError("Multiple P005 production rows found in P016 catalog")
    if rows:
        row = rows[0]
        if row.get("database_name") != desired_name:
            raise ProvisioningError("P005 catalog database_name drift")
        if existing is None:
            raise ProvisioningError("P005 catalog references missing Cloudflare D1")
        if row.get("database_uuid") != existing["uuid"]:
            raise ProvisioningError("P005 catalog database_uuid drift")
    elif existing is not None:
        if table_count(client, existing["uuid"]) > 0:
            raise ProvisioningError(
                "Unregistered existing P005 D1 contains tables; explicit adoption is required"
            )

    before_items, before_count = client.list_all()
    created = False

    if existing is None:
        if before_count >= CONSERVATIVE_DATABASE_LIMIT:
            raise ProvisioningError(
                f"DB_CAPACITY_CHECK failed: current_count={before_count}, "
                f"conservative_limit={CONSERVATIVE_DATABASE_LIMIT}. "
                "Current token does not need Billing Read because auto-create "
                "is allowed only below the published Free-tier minimum limit."
            )
        production = client.create(desired_name)
        created = True
    else:
        production = existing

    read_check = client.query(production["uuid"], "SELECT 1 AS ok;")
    if not read_check or int(read_check[0].get("ok", 0)) != 1:
        raise ProvisioningError("P005 production D1 read verification failed")

    now = utc_now()
    registration_sql = "\n".join([
        "INSERT INTO projects (project_id,project_name,status,created_at,updated_at) "
        f"VALUES ({sql_quote(PROJECT_ID)},{sql_quote(SYSTEM_NAME)},'active',{sql_quote(now)},{sql_quote(now)}) "
        "ON CONFLICT(project_id) DO UPDATE SET "
        "project_name=excluded.project_name,status='active',updated_at=excluded.updated_at;",
        "INSERT INTO databases "
        "(project_id,environment,database_name,database_uuid,provider,status,created_at,updated_at) "
        f"VALUES ({sql_quote(PROJECT_ID)},'production',{sql_quote(desired_name)},"
        f"{sql_quote(production['uuid'])},'cloudflare-d1','active',{sql_quote(now)},{sql_quote(now)}) "
        "ON CONFLICT(project_id,environment) DO UPDATE SET "
        "database_name=excluded.database_name,database_uuid=excluded.database_uuid,"
        "provider=excluded.provider,status=excluded.status,updated_at=excluded.updated_at;",
        "INSERT INTO schema_versions (database_id,version,migration_name,applied_at) "
        f"SELECT id,0,NULL,{sql_quote(now)} FROM databases "
        f"WHERE project_id={sql_quote(PROJECT_ID)} AND environment='production' "
        "ON CONFLICT(database_id) DO NOTHING;",
    ])
    client.query(control["uuid"], registration_sql)

    verify = catalog_rows(client, control["uuid"])
    if len(verify) != 1:
        raise ProvisioningError("P005 catalog verification failed")
    v = verify[0]
    if v.get("database_name") != desired_name or v.get("database_uuid") != production["uuid"]:
        raise ProvisioningError("P005 catalog verification mismatch")
    if v.get("schema_version") is None:
        raise ProvisioningError("P005 schema version missing after registration")

    _, after_count = client.list_all()
    expected_after = before_count + (1 if created else 0)
    if after_count != expected_after:
        raise ProvisioningError(
            f"Unexpected D1 count after provisioning: before={before_count}, after={after_count}"
        )

    summary = {
        "project_id": PROJECT_ID,
        "system_name": SYSTEM_NAME,
        "capacity": {
            "current_count_before": before_count,
            "conservative_limit": CONSERVATIVE_DATABASE_LIMIT,
            "minimum_available_slots_before": max(0, CONSERVATIVE_DATABASE_LIMIT - before_count),
            "basis": "Cloudflare published Workers Free D1 database/account limit",
            "check_passed": (not created) or before_count < CONSERVATIVE_DATABASE_LIMIT,
        },
        "production": {
            "database_name": desired_name,
            "database_uuid": production["uuid"],
            "created": created,
            "read_verified": True,
            "catalog_registered": True,
            "schema_version": int(v["schema_version"]),
        },
        "d1_count_after": after_count,
        "legacy_staging": {
            "created": False,
            "modified": False,
            "deleted": False,
        },
        "migration_applied": False,
        "destructive_operation": False,
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
