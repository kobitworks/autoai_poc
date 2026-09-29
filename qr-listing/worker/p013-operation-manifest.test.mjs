import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { p013Operations } from "./p013-operations.mjs";
import { p013ApiClientContract } from "./p013-api-client.mjs";

const manifestUrl = new URL("./p013-operation-manifest.json", import.meta.url);
const manifest = JSON.parse(await readFile(manifestUrl, "utf8"));

assert.equal(manifest.manifest_version, 1);
assert.equal(manifest.project_id, "P013");
assert.equal(manifest.worker_api_version, "v1");
assert.equal(manifest.default_deny, true);
assert.equal(manifest.environment_bound_at_deploy, true);

function normOperation(x) {
  return {
    operation_id: x.operation_id ?? x.operationId,
    kind: x.kind,
    resource: x.resource,
    action: x.action,
  };
}

const registryOps = Object.values(p013Operations)
  .map(normOperation)
  .sort((a,b)=>a.operation_id.localeCompare(b.operation_id));

const manifestOps = manifest.operations
  .map(normOperation)
  .sort((a,b)=>a.operation_id.localeCompare(b.operation_id));

assert.deepEqual(manifestOps, registryOps);

const clientOps = Object.values(p013ApiClientContract.operations)
  .map((x)=>({ operation_id:x.operationId, kind:x.kind }))
  .sort((a,b)=>a.operation_id.localeCompare(b.operation_id));

assert.deepEqual(
  clientOps,
  manifestOps.map((x)=>({operation_id:x.operation_id,kind:x.kind}))
);

const derivedPermissions = [...new Map(
  registryOps.map((x)=>[x.resource+"\u0000"+x.action,{resource:x.resource,action:x.action}])
).values()].sort((a,b)=>(a.resource+":"+a.action).localeCompare(b.resource+":"+b.action));

const manifestPermissions = [...manifest.permissions]
  .sort((a,b)=>(a.resource+":"+a.action).localeCompare(b.resource+":"+b.action));

assert.deepEqual(manifestPermissions, derivedPermissions);

const operationIds = manifestOps.map((x)=>x.operation_id);
assert.equal(new Set(operationIds).size, operationIds.length);

const permissionKeys = manifestPermissions.map((x)=>x.resource+":"+x.action);
assert.equal(new Set(permissionKeys).size, permissionKeys.length);

for (const op of manifestOps) {
  assert.match(op.operation_id, /^p013\.[a-z0-9_.-]+$/);
  assert.ok(["query","command"].includes(op.kind));
  assert.ok(op.resource && op.action);
  assert.ok(!op.resource.includes("*"));
  assert.ok(!op.action.includes("*"));
}

for (const p of manifestPermissions) {
  assert.ok(p.resource.startsWith("p013."));
  assert.ok(!p.resource.includes("*"));
  assert.ok(!p.action.includes("*"));
}

console.log(JSON.stringify({
  ok:true,
  operation_count:manifestOps.length,
  permission_count:manifestPermissions.length,
  operations:operationIds,
  permissions:permissionKeys
},null,2));
