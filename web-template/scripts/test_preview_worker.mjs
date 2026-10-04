import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/worker.js", import.meta.url), "utf8");
const workerModule = await import(
  "data:text/javascript;base64," + Buffer.from(source, "utf8").toString("base64")
);
const worker = workerModule.default;

function goodEnv() {
  return {
    ENVIRONMENT: "preview",
    DB_WRITE_ENABLED: "false",
    FILE_STORAGE_MODE: "local-only",
    DB: {
      prepare(sql) {
        assert.equal(sql, "SELECT 1 AS ok");
        return { first: async () => ({ ok: 1 }) };
      },
    },
  };
}

{
  const response = await worker.fetch(new Request("https://preview.test/health"), goodEnv());
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.deepEqual(body, {
    ok: true,
    environment: "preview",
    db_write_enabled: false,
    d1_read: true,
    file_storage_mode: "local-only",
    r2_enabled: false,
    zero_cost_guard: true,
  });
  assert.equal(response.headers.get("cache-control"), "no-store");
}

{
  const response = await worker.fetch(
    new Request("https://preview.test/", { method: "GET" }),
    goodEnv(),
  );
  assert.equal(response.status, 200);
  assert.match(await response.text(), /P008 Free Preview/);
  assert.match(await response.text(), /R2は使用しません/);
}

{
  const response = await worker.fetch(
    new Request("https://preview.test/", { method: "HEAD" }),
    goodEnv(),
  );
  assert.equal(response.status, 200);
  assert.equal(await response.text(), "");
}

{
  const response = await worker.fetch(
    new Request("https://preview.test/", { method: "POST" }),
    goodEnv(),
  );
  assert.equal(response.status, 405);
  const body = await response.json();
  assert.equal(body.ok, false);
  assert.equal(body.error, "method_not_allowed");
}

{
  const env = goodEnv();
  env.DB.prepare = () => ({ first: async () => { throw new Error("mock-d1-failure"); } });
  const response = await worker.fetch(new Request("https://preview.test/health"), env);
  assert.equal(response.status, 500);
  const body = await response.json();
  assert.equal(body.ok, false);
  assert.equal(body.environment, "preview");
  assert.equal(body.r2_enabled, false);
  assert.match(body.error, /mock-d1-failure/);
}

console.log(JSON.stringify({
  ok: true,
  tests: 5,
  health_binding_mock: "d1-only-pass",
  preview_read_only: true,
  r2_binding_present: false,
}, null, 2));
