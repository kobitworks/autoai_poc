#!/usr/bin/env python3
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "wrangler.p008.template.jsonc"
WORKER = ROOT / "src" / "worker.js"
WORKFLOW = ROOT.parent / ".github" / "workflows" / "p008-cloudflare-provision-preview.yml"
PREFLIGHT = ROOT.parent / ".github" / "workflows" / "p008-cloudflare-preflight.yml"
PROVISION = ROOT / "scripts" / "provision_p008_cloudflare.py"


def load_jsonc(path: Path):
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"(?m)^\s*//.*$", "", text)
    return json.loads(text)


def require(condition, message):
    if not condition:
        raise SystemExit(message)


cfg = load_jsonc(CONFIG)
require(cfg.get("name") == "p008-web-template", "worker name mismatch")
require(cfg.get("main") == "src/worker.js", "worker entry mismatch")
require(cfg.get("workers_dev") is True, "workers_dev must be true for preview")
require(cfg.get("preview_urls") is True, "preview_urls must be true")
require(cfg.get("vars", {}).get("ENVIRONMENT") == "production", "base ENVIRONMENT must be production")
require(cfg.get("vars", {}).get("DB_WRITE_ENABLED") == "false", "base DB_WRITE_ENABLED must be false")
require(cfg.get("vars", {}).get("FILE_STORAGE_MODE") == "none", "base file storage mode must be none")
require("r2_buckets" not in cfg, "R2 binding must not exist in base config")

base_d1 = cfg.get("d1_databases") or []
require(len(base_d1) == 1, "base D1 binding count must be 1")
require(base_d1[0].get("binding") == "DB", "base D1 binding must be DB")
require(base_d1[0].get("database_name") == "p008-web-template-production", "base D1 name mismatch")
require(base_d1[0].get("database_id") == "__D1_DATABASE_ID__", "base D1 placeholder mismatch")

preview = cfg.get("previews") or {}
require(preview.get("vars", {}).get("ENVIRONMENT") == "preview", "preview ENVIRONMENT mismatch")
require(preview.get("vars", {}).get("DB_WRITE_ENABLED") == "false", "preview DB_WRITE_ENABLED must be false")
require(preview.get("vars", {}).get("FILE_STORAGE_MODE") == "local-only", "preview file storage mode mismatch")
require("r2_buckets" not in preview, "R2 binding must not exist in preview config")
preview_d1 = preview.get("d1_databases") or []
require(len(preview_d1) == 1 and preview_d1[0].get("binding") == "DB", "preview D1 binding mismatch")
require(preview_d1[0].get("database_name") == "p008-web-template-production", "preview D1 name mismatch")
require(preview_d1[0].get("database_id") == "__D1_DATABASE_ID__", "preview D1 placeholder mismatch")

worker = WORKER.read_text(encoding="utf-8")
require("env.FILES" not in worker, "Worker must not reference an R2 FILES binding")
require("r2_enabled: false" in worker, "Worker health must explicitly report R2 disabled")
require("zero_cost_guard: true" in worker, "Worker health must report zero-cost guard")

workflow = WORKFLOW.read_text(encoding="utf-8")
for snippet in [
    "python3 scripts/provision_p008_cloudflare.py",
    "npx wrangler preview",
    "--name develop",
    "wrangler.p008.generated.jsonc",
    ".preview.urls[0]",
    ".environment == \"preview\"",
    ".db_write_enabled == false",
    ".d1_read == true",
    ".r2_enabled == false",
]:
    require(snippet in workflow, f"provision workflow contract missing: {snippet}")
require("/r2/" not in workflow, "Provision workflow must not call R2 API")
require("r2/buckets" not in workflow, "Provision workflow must not call R2 bucket API")

preflight = PREFLIGHT.read_text(encoding="utf-8")
require("/subscriptions" in preflight, "Preflight must verify account subscriptions")
require("Billing Read" in preflight, "Preflight must explain Billing Read requirement")
require("/r2/" not in preflight and "r2/buckets" not in preflight, "Preflight must not call R2 API")

provision = PROVISION.read_text(encoding="utf-8")
require("/subscriptions" in provision, "Provision script must verify account subscriptions")
require("Paid or billable Workers subscription detected" in provision, "Paid Workers fail-closed guard missing")
require("/r2/" not in provision and "r2/buckets" not in provision, "Provision script must not call R2 API")
require("provision_r2" not in provision, "R2 provisioning code must not remain active")

print(json.dumps({
    "ok": True,
    "worker_name": cfg["name"],
    "preview_environment": preview["vars"]["ENVIRONMENT"],
    "preview_d1": preview_d1[0]["database_name"],
    "r2_binding_present": False,
    "zero_cost_guard": "ok",
    "provision_workflow_contract": "ok",
}, ensure_ascii=False, indent=2))
