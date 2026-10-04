#!/usr/bin/env python3
import json
import os
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

API = "https://api.cloudflare.com/client/v4"
ACCOUNT = os.environ["CLOUDFLARE_ACCOUNT_ID"]
TOKEN = os.environ["CLOUDFLARE_API_TOKEN"]
PROJECT_ID = "P008"
PROJECT_NAME = "Webシステム自動構築"
D1_NAME = "p008-web-template-production"
CONTROL_NAME = "p016-db-management-production"
ACTIVE_SUBSCRIPTION_STATES = {"trial", "provisioned", "paid", "awaitingpayment"}


def req(method, url, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    r = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(r, timeout=60) as x:
            out = json.loads(x.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        raise RuntimeError(f"Cloudflare HTTP {e.code}: {body[:600]}") from e
    if not out.get("success", False):
        raise RuntimeError("Cloudflare API error: " + json.dumps(out.get("errors", [])))
    return out.get("result")


def sqlq(value):
    return "'" + str(value).replace("'", "''") + "'"


def verify_zero_cost_workers_plan():
    subscriptions = req("GET", f"{API}/accounts/{ACCOUNT}/subscriptions") or []
    if not isinstance(subscriptions, list):
        raise RuntimeError("Unexpected Cloudflare subscriptions response")

    disallowed = []
    for subscription in subscriptions:
        rate_plan = str((subscription.get("rate_plan") or {}).get("id") or "").upper()
        state = str(subscription.get("state") or "").lower()
        if (
            "WORKERS" in rate_plan
            and "FREE" not in rate_plan
            and state in ACTIVE_SUBSCRIPTION_STATES
        ):
            disallowed.append({"rate_plan": rate_plan, "state": subscription.get("state")})

    if disallowed:
        raise RuntimeError(
            "Paid or billable Workers subscription detected; refusing P008 PoC deployment: "
            + json.dumps(disallowed, ensure_ascii=False)
        )

    return {
        "checked": True,
        "paid_workers_subscription": False,
        "billing_changes": False,
    }


def d1_find(name):
    q = urllib.parse.urlencode({"name": name, "page": 1, "per_page": 10})
    rows = req("GET", f"{API}/accounts/{ACCOUNT}/d1/database?{q}") or []
    hits = [x for x in rows if x.get("name") == name]
    if len(hits) > 1:
        raise RuntimeError(f"multiple D1 matches: {name}")
    return hits[0] if hits else None


def d1_query(uuid, sql):
    out = req(
        "POST",
        f"{API}/accounts/{ACCOUNT}/d1/database/{uuid}/query",
        {"sql": sql},
    ) or []
    rows = []
    for block in out:
        rows.extend(block.get("results") or [])
        if block.get("success") is False:
            raise RuntimeError("D1 query failed")
    return rows


def provision_d1():
    control = d1_find(CONTROL_NAME)
    if not control:
        raise RuntimeError(f"missing P016 control D1: {CONTROL_NAME}")

    catalog = d1_query(
        control["uuid"],
        "SELECT d.environment,d.database_name,d.database_uuid,sv.version AS schema_version "
        "FROM databases d LEFT JOIN schema_versions sv ON sv.database_id=d.id "
        f"WHERE d.project_id={sqlq(PROJECT_ID)} AND d.environment='production';",
    )
    if len(catalog) > 1:
        raise RuntimeError("multiple P008 production catalog rows")

    target = d1_find(D1_NAME)
    if catalog:
        row = catalog[0]
        if not target:
            raise RuntimeError("P016 catalog references missing P008 D1")
        if row["database_name"] != D1_NAME or row["database_uuid"] != target["uuid"]:
            raise RuntimeError("P008 D1 catalog drift")
    elif target:
        table_count = d1_query(
            target["uuid"],
            "SELECT COUNT(*) AS n FROM sqlite_master "
            "WHERE type='table' AND name NOT LIKE 'sqlite_%';",
        )
        if int(table_count[0]["n"]) > 0:
            raise RuntimeError("unregistered existing P008 D1 has tables; refusing adoption")

    created = False
    if not target:
        target = req(
            "POST",
            f"{API}/accounts/{ACCOUNT}/d1/database",
            {"name": D1_NAME, "primary_location_hint": "apac"},
        )
        created = True

    ok = d1_query(target["uuid"], "SELECT 1 AS ok;")
    if not ok or int(ok[0]["ok"]) != 1:
        raise RuntimeError("P008 D1 read check failed")

    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    sql = "\n".join(
        [
            "INSERT INTO projects (project_id,project_name,status,created_at,updated_at) "
            f"VALUES ({sqlq(PROJECT_ID)},{sqlq(PROJECT_NAME)},'active',{sqlq(now)},{sqlq(now)}) "
            "ON CONFLICT(project_id) DO UPDATE SET "
            "project_name=excluded.project_name,status='active',updated_at=excluded.updated_at;",
            "INSERT INTO databases "
            "(project_id,environment,database_name,database_uuid,provider,status,created_at,updated_at) "
            f"VALUES ({sqlq(PROJECT_ID)},'production',{sqlq(D1_NAME)},{sqlq(target['uuid'])},"
            f"'cloudflare-d1','active',{sqlq(now)},{sqlq(now)}) "
            "ON CONFLICT(project_id,environment) DO UPDATE SET "
            "database_name=excluded.database_name,database_uuid=excluded.database_uuid,"
            "provider=excluded.provider,status=excluded.status,updated_at=excluded.updated_at;",
            "INSERT INTO schema_versions (database_id,version,migration_name,applied_at) "
            f"SELECT id,0,NULL,{sqlq(now)} FROM databases "
            f"WHERE project_id={sqlq(PROJECT_ID)} AND environment='production' "
            "ON CONFLICT(database_id) DO NOTHING;",
        ]
    )
    d1_query(control["uuid"], sql)

    verify = d1_query(
        control["uuid"],
        "SELECT d.database_name,d.database_uuid,sv.version AS schema_version "
        "FROM databases d LEFT JOIN schema_versions sv ON sv.database_id=d.id "
        f"WHERE d.project_id={sqlq(PROJECT_ID)} AND d.environment='production';",
    )
    if len(verify) != 1 or verify[0]["database_uuid"] != target["uuid"]:
        raise RuntimeError("P008 D1 catalog verification failed")

    return {
        "database_name": D1_NAME,
        "database_uuid": target["uuid"],
        "created": created,
        "catalog_registered": True,
        "schema_version": int(verify[0]["schema_version"]),
    }


def main():
    workers_free_guard = verify_zero_cost_workers_plan()
    d1 = provision_d1()
    summary = {
        "project_id": PROJECT_ID,
        "system_name": PROJECT_NAME,
        "workers_free_guard": workers_free_guard,
        "d1": d1,
        "r2_enabled": False,
        "file_storage_mode": "mock/static/local-only",
        "destructive_operations": False,
        "billing_changes": False,
        "production_worker_deployed": False,
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
