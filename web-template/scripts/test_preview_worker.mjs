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
    DB: {
      prepare(sql) {
        assert.equal(sql, "SELECT 1 AS ok");
        return { first: async () => ({ ok: 1 }) };
      },
    },
    FILES: {
      list: async ({ limit }) => {
        assert.equal(limit, 1);
        return { objects: [] };
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
    r2_read: true,
    r2_sample_count: 0,
  });
  assert.equal(response.headers.get("cache-control"), "no-store");
}

{
  const response = await worker.fetch(
    new Request("https://preview.test/", { method: "GET" }),
    goodEnv(),
  );
  assert.equal(response.status, 200);
  assert.match(await response.text(), /P008 Cloudflare Preview/);
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
  env.FILES.list = async () => {
    throw new Error("mock-r2-failure");
  };
  const response = await worker.fetch(new Request("https://preview.test/health"), env);
  assert.equal(response.status, 500);
  const body = await response.json();
  assert.equal(body.ok, false);
  assert.equal(body.environment, "preview");
  assert.match(body.error, /mock-r2-failure/);
}

console.log(JSON.stringify({
  ok: true,
  tests: 5,
  health_binding_mock: "pass",
  preview_read_only: true,
}, null, 2));
