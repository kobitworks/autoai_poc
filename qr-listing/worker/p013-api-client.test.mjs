import assert from "node:assert/strict";
import {
  P013ApiError,
  createP013ApiClient,
  p013ApiClientContract,
} from "./p013-api-client.mjs";

function okPayload(data = {}) {
  return new Response(JSON.stringify({
    ok: true,
    request_id: "req_test",
    data,
    meta: { schema_version: 1 },
  }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

async function run() {
  const seen = [];
  const fetchImpl = async (url, init) => {
    seen.push({ url, init });
    return okPayload({ found: true });
  };

  const api = createP013ApiClient({
    baseUrl: "https://p013-api.example.test/",
    fetchImpl,
  });

  await api.getProduct(
    { product_id: "prod:001" },
    { requestId: "req_client_1" },
  );

  assert.equal(seen[0].url, "https://p013-api.example.test/v1/queries/p013.product.get");
  assert.equal(seen[0].init.method, "POST");
  assert.equal(seen[0].init.credentials, "include");
  assert.equal(seen[0].init.cache, "no-store");
  assert.equal(seen[0].init.headers["X-AutoAI-Request"], "1");
  assert.equal(seen[0].init.headers["X-Request-Id"], "req_client_1");
  assert.equal(seen[0].init.headers["Idempotency-Key"], undefined);
  assert.deepEqual(JSON.parse(seen[0].init.body), {
    input: { product_id: "prod:001" },
  });

  const idem = "qr019:create:000001";
  await api.createProduct(
    {
      product_id: "prod:002",
      primary_qr_code: "QPMS2609300043120001",
      data_scope: "staging",
    },
    { idempotencyKey: idem },
  );
  await api.createProduct(
    {
      product_id: "prod:002",
      primary_qr_code: "QPMS2609300043120001",
      data_scope: "staging",
    },
    { idempotencyKey: idem },
  );

  assert.equal(seen[1].url, "https://p013-api.example.test/v1/commands/p013.product.create");
  assert.equal(seen[1].init.headers["Idempotency-Key"], idem);
  assert.equal(seen[2].init.headers["Idempotency-Key"], idem);

  await assert.rejects(
    () => api.createProduct({}, { idempotencyKey: "short" }),
    /valid Idempotency-Key/,
  );

  await assert.rejects(
    () => api.getProduct({}, { idempotencyKey: idem }),
    /not accepted for queries/,
  );

  assert.throws(
    () => createP013ApiClient({
      baseUrl: "http://remote.example.test",
      fetchImpl,
    }),
    /must use https/,
  );

  assert.doesNotThrow(() => createP013ApiClient({
    baseUrl: "http://127.0.0.1:8787/",
    fetchImpl,
  }));

  const failApi = createP013ApiClient({
    baseUrl: "https://p013-api.example.test",
    fetchImpl: async () => new Response(JSON.stringify({
      ok: false,
      request_id: "req_denied",
      error: {
        code: "FORBIDDEN",
        message: "Operation is not permitted",
        retry_after_seconds: null,
      },
    }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    }),
  });

  await assert.rejects(
    () => failApi.listProducts({}),
    (error) => {
      assert.ok(error instanceof P013ApiError);
      assert.equal(error.status, 403);
      assert.equal(error.code, "FORBIDDEN");
      assert.equal(error.requestId, "req_denied");
      return true;
    },
  );

  const retryApi = createP013ApiClient({
    baseUrl: "https://p013-api.example.test",
    fetchImpl: async () => new Response("busy", {
      status: 429,
      headers: { "Retry-After": "60" },
    }),
  });

  await assert.rejects(
    () => retryApi.listProducts({}),
    (error) => {
      assert.equal(error.code, "HTTP_ERROR");
      assert.equal(error.status, 429);
      assert.equal(error.retryAfterSeconds, 60);
      return true;
    },
  );

  assert.equal(
    p013ApiClientContract.idempotencyKeyPattern,
    "^[A-Za-z0-9._~:+\\/-]{16,128}$",
  );
  assert.deepEqual(
    Object.keys(p013ApiClientContract.operations),
    ["getProduct", "listProducts", "createProduct", "updateProductStatus"],
  );

  console.log(JSON.stringify({
    ok: true,
    assertions: 20,
    requests: seen.length,
    queryPath: seen[0].url,
    commandPath: seen[1].url,
    reusedIdempotencyKey: seen[1].init.headers["Idempotency-Key"] === seen[2].init.headers["Idempotency-Key"],
  }, null, 2));
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
