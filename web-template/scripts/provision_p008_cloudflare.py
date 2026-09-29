#!/usr/bin/env python3
import json, os, urllib.parse, urllib.request, urllib.error
from datetime import datetime, timezone

API="https://api.cloudflare.com/client/v4"
ACCOUNT=os.environ["CLOUDFLARE_ACCOUNT_ID"]
TOKEN=os.environ["CLOUDFLARE_API_TOKEN"]
PROJECT_ID="P008"
PROJECT_NAME="Webシステム自動構築"
D1_NAME="p008-web-template-production"
CONTROL_NAME="p016-db-management-production"
R2_NAMES={
  "staging":"p008-web-template-files-staging",
  "production":"p008-web-template-files-production",
}
ORIGINS={
  "staging":["https://kobitworks.github.io"],
  "production":["https://kobitworks.github.io"],
}

def req(method,url,payload=None):
    data=None if payload is None else json.dumps(payload).encode()
    r=urllib.request.Request(url,data=data,method=method,headers={
      "Authorization":f"Bearer {TOKEN}",
      "Content-Type":"application/json",
    })
    try:
      with urllib.request.urlopen(r,timeout=60) as x:
        out=json.loads(x.read().decode())
    except urllib.error.HTTPError as e:
      body=e.read().decode(errors="replace")
      raise RuntimeError(f"Cloudflare HTTP {e.code}: {body[:600]}")
    if not out.get("success",False):
      raise RuntimeError("Cloudflare API error: "+json.dumps(out.get("errors",[])))
    return out.get("result")

def sqlq(v):
    return "'" + str(v).replace("'","''") + "'"

def d1_find(name):
    q=urllib.parse.urlencode({"name":name,"page":1,"per_page":10})
    rows=req("GET",f"{API}/accounts/{ACCOUNT}/d1/database?{q}") or []
    hits=[x for x in rows if x.get("name")==name]
    if len(hits)>1: raise RuntimeError(f"multiple D1 matches: {name}")
    return hits[0] if hits else None

def d1_query(uuid,sql):
    out=req("POST",f"{API}/accounts/{ACCOUNT}/d1/database/{uuid}/query",{"sql":sql}) or []
    rows=[]
    for block in out:
      rows.extend(block.get("results") or [])
      if block.get("success") is False: raise RuntimeError("D1 query failed")
    return rows

def provision_d1():
    control=d1_find(CONTROL_NAME)
    if not control: raise RuntimeError(f"missing P016 control D1: {CONTROL_NAME}")
    catalog=d1_query(control["uuid"],
      "SELECT d.environment,d.database_name,d.database_uuid,sv.version AS schema_version "
      "FROM databases d LEFT JOIN schema_versions sv ON sv.database_id=d.id "
      f"WHERE d.project_id={sqlq(PROJECT_ID)} AND d.environment='production';")
    if len(catalog)>1: raise RuntimeError("multiple P008 production catalog rows")
    target=d1_find(D1_NAME)
    if catalog:
      row=catalog[0]
      if not target: raise RuntimeError("P016 catalog references missing P008 D1")
      if row["database_name"]!=D1_NAME or row["database_uuid"]!=target["uuid"]:
        raise RuntimeError("P008 D1 catalog drift")
    elif target:
      tc=d1_query(target["uuid"],"SELECT COUNT(*) AS n FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
      if int(tc[0]["n"])>0:
        raise RuntimeError("unregistered existing P008 D1 has tables; refusing adoption")
    created=False
    if not target:
      target=req("POST",f"{API}/accounts/{ACCOUNT}/d1/database",{
        "name":D1_NAME,"primary_location_hint":"apac"
      })
      created=True
    ok=d1_query(target["uuid"],"SELECT 1 AS ok;")
    if not ok or int(ok[0]["ok"])!=1: raise RuntimeError("P008 D1 read check failed")
    now=datetime.now(timezone.utc).isoformat().replace("+00:00","Z")
    sql="\n".join([
      "INSERT INTO projects (project_id,project_name,status,created_at,updated_at) "
      f"VALUES ({sqlq(PROJECT_ID)},{sqlq(PROJECT_NAME)},'active',{sqlq(now)},{sqlq(now)}) "
      "ON CONFLICT(project_id) DO UPDATE SET project_name=excluded.project_name,status='active',updated_at=excluded.updated_at;",
      "INSERT INTO databases (project_id,environment,database_name,database_uuid,provider,status,created_at,updated_at) "
      f"VALUES ({sqlq(PROJECT_ID)},'production',{sqlq(D1_NAME)},{sqlq(target['uuid'])},'cloudflare-d1','active',{sqlq(now)},{sqlq(now)}) "
      "ON CONFLICT(project_id,environment) DO UPDATE SET database_name=excluded.database_name,database_uuid=excluded.database_uuid,provider=excluded.provider,status=excluded.status,updated_at=excluded.updated_at;",
      "INSERT INTO schema_versions (database_id,version,migration_name,applied_at) "
      f"SELECT id,0,NULL,{sqlq(now)} FROM databases WHERE project_id={sqlq(PROJECT_ID)} AND environment='production' "
      "ON CONFLICT(database_id) DO NOTHING;",
    ])
    d1_query(control["uuid"],sql)
    verify=d1_query(control["uuid"],
      "SELECT d.database_name,d.database_uuid,sv.version AS schema_version "
      "FROM databases d LEFT JOIN schema_versions sv ON sv.database_id=d.id "
      f"WHERE d.project_id={sqlq(PROJECT_ID)} AND d.environment='production';")
    if len(verify)!=1 or verify[0]["database_uuid"]!=target["uuid"]:
      raise RuntimeError("P008 D1 catalog verification failed")
    return {"database_name":D1_NAME,"database_uuid":target["uuid"],"created":created,
            "catalog_registered":True,"schema_version":int(verify[0]["schema_version"])}

def r2_find(name):
    q=urllib.parse.urlencode({"name_contains":name,"order":"name","direction":"asc","per_page":1000})
    result=req("GET",f"{API}/accounts/{ACCOUNT}/r2/buckets?{q}") or {}
    hits=[x for x in (result.get("buckets") or []) if x.get("name")==name]
    if len(hits)>1: raise RuntimeError(f"multiple R2 matches: {name}")
    return hits[0] if hits else None

def verify_private(name):
    safe=urllib.parse.quote(name,safe="")
    managed=req("GET",f"{API}/accounts/{ACCOUNT}/r2/buckets/{safe}/domains/managed") or {}
    if managed.get("enabled"): raise RuntimeError(f"r2.dev public access enabled: {name}")
    custom=req("GET",f"{API}/accounts/{ACCOUNT}/r2/buckets/{safe}/domains/custom") or {}
    enabled=[x.get("domain") for x in (custom.get("domains") or []) if x.get("enabled")]
    if enabled: raise RuntimeError(f"custom public domain enabled for {name}: {enabled}")

def ownership_rule_id(environment):
    return f"autoai-{PROJECT_ID.lower()}-{environment}-owned-v1"

def cors_rules(environment,origins):
    return [{"id":ownership_rule_id(environment),"allowed":{
      "origins":origins,
      "methods":["GET","HEAD","PUT"],
      "headers":["Content-Type","If-Match","If-None-Match","x-amz-content-sha256","x-amz-checksum-sha256"]
    },"exposeHeaders":["ETag"],"maxAgeSeconds":3600}]

def get_cors(name):
    safe=urllib.parse.quote(name,safe="")
    return req("GET",f"{API}/accounts/{ACCOUNT}/r2/buckets/{safe}/cors") or {}

def has_ownership_marker(name,environment):
    expected=ownership_rule_id(environment)
    rules=get_cors(name).get("rules") or []
    matches=[x for x in rules if x.get("id")==expected]
    if len(matches)>1:
      raise RuntimeError(f"duplicate P008 R2 ownership marker: {name}")
    return len(matches)==1

def put_managed_cors(name,environment):
    safe=urllib.parse.quote(name,safe="")
    rules=cors_rules(environment,ORIGINS[environment])
    req("PUT",f"{API}/accounts/{ACCOUNT}/r2/buckets/{safe}/cors",{"rules":rules})
    if not has_ownership_marker(name,environment):
      raise RuntimeError(f"R2 ownership marker verification failed: {name}")

def rollback_new_bucket(name):
    safe=urllib.parse.quote(name,safe="")
    req("DELETE",f"{API}/accounts/{ACCOUNT}/r2/buckets/{safe}")

def create_owned_bucket(name,environment):
    created=req("POST",f"{API}/accounts/{ACCOUNT}/r2/buckets",{
      "name":name,"locationHint":"apac","storageClass":"Standard"
    })
    if not created or created.get("name")!=name:
      raise RuntimeError(f"R2 create response mismatch: {name}")
    try:
      put_managed_cors(name,environment)
    except Exception as marker_error:
      try:
        rollback_new_bucket(name)
      except Exception as rollback_error:
        raise RuntimeError(
          f"R2 bucket created but ownership marker failed and rollback also failed: {name}; "
          f"marker={marker_error}; rollback={rollback_error}"
        ) from marker_error
      raise RuntimeError(
        f"R2 bucket ownership marker failed; newly created empty bucket rolled back: {name}; "
        f"marker={marker_error}"
      ) from marker_error
    return created

def provision_r2():
    out={}
    for env,name in R2_NAMES.items():
      existing=r2_find(name)
      created=False
      if existing:
        if not has_ownership_marker(name,env):
          raise RuntimeError(f"R2 bucket exists without P008 ownership marker: {name}")
      else:
        existing=create_owned_bucket(name,env)
        created=True

      verify_private(name)
      put_managed_cors(name,env)
      out[env]={"bucket_name":name,"created":created,"private_verified":True,
                "cors_verified":True,"allowed_origins":ORIGINS[env],
                "ownership_marker":ownership_rule_id(env)}
    return out

def main():
    d1=provision_d1()
    summary={
      "project_id":PROJECT_ID,
      "system_name":PROJECT_NAME,
      "d1":d1,
      "r2":provision_r2(),
      "destructive_operations":False,
      "production_worker_deployed":False,
    }
    print(json.dumps(summary,ensure_ascii=False,indent=2,sort_keys=True))

if __name__=="__main__":
    main()
