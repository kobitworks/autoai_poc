#!/usr/bin/env python3
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "wrangler.p008.template.jsonc"
WORKFLOW = ROOT.parent / ".github" / "workflows" / "p008-cloudflare-provision-preview.yml"

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

base_d1 = cfg.get("d1_databases") or []
require(len(base_d1) == 1, "base D1 binding count must be 1")
require(base_d1[0].get("binding") == "DB", "base D1 binding must be DB")
require(base_d1[0].get("database_name") == "p008-web-template-production", "base D1 name mismatch")
require(base_d1[0].get("database_id") == "__D1_DATABASE_ID__", "base D1 placeholder mismatch")

base_r2 = cfg.get("r2_buckets") or []
require(len(base_r2) == 1, "base R2 binding count must be 1")
require(base_r2[0].get("binding") == "FILES", "base R2 binding must be FILES")
require(base_r2[0].get("bucket_name") == "p008-web-template-files-production", "base R2 bucket mismatch")

preview = cfg.get("previews") or {}
require(preview.get("vars", {}).get("ENVIRONMENT") == "preview", "preview ENVIRONMENT mismatch")
require(preview.get("vars", {}).get("DB_WRITE_ENABLED") == "false", "preview DB_WRITE_ENABLED must be false")
preview_d1 = preview.get("d1_databases") or []
require(len(preview_d1) == 1 and preview_d1[0].get("binding") == "DB", "preview D1 binding mismatch")
require(preview_d1[0].get("database_name") == "p008-web-template-production", "preview D1 name mismatch")
require(preview_d1[0].get("database_id") == "__D1_DATABASE_ID__", "preview D1 placeholder mismatch")
preview_r2 = preview.get("r2_buckets") or []
require(len(preview_r2) == 1 and preview_r2[0].get("binding") == "FILES", "preview R2 binding mismatch")
require(preview_r2[0].get("bucket_name") == "p008-web-template-files-staging", "preview must use staging R2")

workflow = WORKFLOW.read_text(encoding="utf-8")
required_snippets = [
    "python3 scripts/provision_p008_cloudflare.py",
    "npx wrangler preview",
    "--name develop",
    "wrangler.p008.generated.jsonc",
    ".preview.urls[0]",
    ".environment == \"preview\"",
    ".db_write_enabled == false",
    ".d1_read == true",
    ".r2_read == true",
]
for snippet in required_snippets:
    require(snippet in workflow, f"provision workflow contract missing: {snippet}")

print(json.dumps({
    "ok": True,
    "worker_name": cfg["name"],
    "preview_environment": preview["vars"]["ENVIRONMENT"],
    "preview_d1": preview_d1[0]["database_name"],
    "preview_r2": preview_r2[0]["bucket_name"],
    "provision_workflow_contract": "ok",
}, ensure_ascii=False, indent=2))
