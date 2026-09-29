import assert from "node:assert/strict";
import { p013Operations, getP013Operation } from "./p013-operations.mjs";

class Statement {
  constructor(db, sql) {
    this.db = db;
    this.sql = sql;
    this.binds = [];
  }
  bind(...args) {
    this.binds = args;
    this.db.seen.push({ type: "bind", sql: this.sql, args });
    return this;
  }
  async first() {
    this.db.seen.push({ type: "first", sql: this.sql, args: this.binds });
    return this.db.firstQueue.length ? this.db.firstQueue.shift() : null;
  }
  async all() {
    this.db.seen.push({ type: "all", sql: this.sql, args: this.binds });
    return this.db.allQueue.length ? this.db.allQueue.shift() : { results: [] };
  }
}

class FakeDb {
  constructor({ first = [], all = [], batch = [] } = {}) {
    this.firstQueue = [...first];
    this.allQueue = [...all];
    this.batchQueue = [...batch];
    this.seen = [];
  }
  prepare(sql) {
    this.seen.push({ type: "prepare", sql });
    return new Statement(this, sql);
  }
  async batch(statements) {
    this.seen.push({
      type: "batch",
      statements: statements.map((s) => ({ sql: s.sql, args: s.binds })),
    });
    if (this.batchQueue.length) return this.batchQueue.shift();
    return statements.map(() => ({ meta: { changes: 1 } }));
  }
}

const principal = { actorId: "user-001", clientKey: "cf-access-app:test" };

assert.equal(Object.keys(p013Operations).length, 4);
assert.equal(getP013Operation("p013.product.get").resource, "p013.product");
assert.equal(getP013Operation("p013.product.update_status").action, "update");
assert.equal(getP013Operation("missing"), null);

for (const op of Object.values(p013Operations)) {
  assert.equal(op.inputSchema.type, "object");
  assert.equal(op.inputSchema.additionalProperties, false);
  assert.ok(["query", "command"].includes(op.kind));
  assert.equal(op.resource, "p013.product");
}

{
  const db = new FakeDb({ first: [{ product_id: "prd-1", state_version: 3, status: "AI_REVIEW" }] });
  const out = await p013Operations["p013.product.get"].handler({
    db, input: { product_id: "prd-1" }, principal, requestId: "r1"
  });
  assert.equal(out.found, true);
  assert.equal(out.product.product_id, "prd-1");
  const call = db.seen.find((x) => x.type === "first");
  assert.match(call.sql, /WHERE product_id=\? LIMIT 1/);
  assert.deepEqual(call.args, ["prd-1"]);
}

{
  const rows = [{ product_id: "prd-2", status: "CONFIRMED", state_version: 2 }];
  const db = new FakeDb({ all: [{ results: rows }] });
  const out = await p013Operations["p013.product.list"].handler({
    db, input: { data_scope: "staging", status: "CONFIRMED", limit: 10 }, principal, requestId: "r2"
  });
  assert.deepEqual(out.products, rows);
  const call = db.seen.find((x) => x.type === "all");
  assert.match(call.sql, /data_scope=\? AND status=\?/);
  assert.deepEqual(call.args, ["staging", "CONFIRMED", 10]);
}

{
  const db = new FakeDb({
    first: [null, { qr_code: "QPMS2609291234560001", status: "AVAILABLE" }],
    batch: [[{ meta: { changes: 1 } }, { meta: { changes: 1 } }, { meta: { changes: 1 } }]],
  });
  const out = await p013Operations["p013.product.create"].handler({
    db,
    input: {
      product_id: "prd-create-1",
      primary_qr_code: "QPMS2609291234560001",
      data_scope: "staging",
    },
    principal,
    requestId: "req-create",
  });
  assert.equal(out.created, true);
  assert.equal(out.product.state_version, 1);
  const batch = db.seen.find((x) => x.type === "batch");
  assert.equal(batch.statements.length, 3);
  assert.match(batch.statements[0].sql, /^INSERT INTO products/);
  assert.match(batch.statements[0].sql, /status='AVAILABLE'/);
  assert.match(batch.statements[1].sql, /^UPDATE management_qr_codes/);
  assert.match(batch.statements[2].sql, /^INSERT INTO product_state_events/);
  assert.ok(batch.statements[2].args[0].startsWith("evt:req-create:create"));
}

{
  const db = new FakeDb({
    first: [{ product_id: "prd-existing", primary_qr_code: "QPMS2609291234560002", state_version: 1, status: "PHOTO_GROUPED" }],
  });
  const out = await p013Operations["p013.product.create"].handler({
    db,
    input: {
      product_id: "prd-existing",
      primary_qr_code: "QPMS2609291234560002",
    },
    principal,
    requestId: "req-conflict",
  });
  assert.equal(out.created, false);
  assert.equal(out.reason, "PRODUCT_OR_QR_ALREADY_ASSIGNED");
  assert.equal(db.seen.some((x) => x.type === "batch"), false);
}

{
  const db = new FakeDb({
    first: [{ product_id: "prd-u1", status: "AI_REVIEW", state_version: 4 }],
    batch: [[{ meta: { changes: 1 } }, { meta: { changes: 1 } }]],
  });
  const out = await p013Operations["p013.product.update_status"].handler({
    db,
    input: {
      product_id: "prd-u1",
      expected_state_version: 4,
      status: "CONFIRMED",
      reason: "human_review_complete",
    },
    principal,
    requestId: "req-update",
  });
  assert.equal(out.updated, true);
  assert.equal(out.product.state_version, 5);
  const batch = db.seen.find((x) => x.type === "batch");
  assert.match(batch.statements[0].sql, /WHERE product_id=\? AND state_version=\?/);
  assert.deepEqual(batch.statements[0].args.slice(-2), ["prd-u1", 4]);
  assert.match(batch.statements[1].sql, /state_version=\? AND status=\? AND updated_at=\?/);
}

{
  const db = new FakeDb({
    first: [{ product_id: "prd-u2", status: "AI_REVIEW", state_version: 7 }],
  });
  const out = await p013Operations["p013.product.update_status"].handler({
    db,
    input: { product_id: "prd-u2", expected_state_version: 6, status: "CONFIRMED" },
    principal,
    requestId: "req-stale",
  });
  assert.equal(out.updated, false);
  assert.equal(out.reason, "STATE_VERSION_CONFLICT");
  assert.equal(db.seen.some((x) => x.type === "batch"), false);
}

{
  const db = new FakeDb({
    first: [
      { product_id: "prd-race", status: "AI_REVIEW", state_version: 4 },
      { product_id: "prd-race", status: "LISTING_READY", state_version: 5 },
    ],
    batch: [[{ meta: { changes: 0 } }, { meta: { changes: 0 } }]],
  });
  const out = await p013Operations["p013.product.update_status"].handler({
    db,
    input: { product_id: "prd-race", expected_state_version: 4, status: "CONFIRMED" },
    principal,
    requestId: "req-race",
  });
  assert.equal(out.updated, false);
  assert.equal(out.reason, "STATE_VERSION_CONFLICT");
  assert.equal(out.product.state_version, 5);
}

console.log(JSON.stringify({
  ok: true,
  operation_count: Object.keys(p013Operations).length,
  tested: [
    "registry metadata",
    "strict schemas",
    "prepared/bound product get",
    "filtered product list",
    "conditional create + QR discovery + event",
    "duplicate create rejection",
    "state_version update + event",
    "stale expected_state_version rejection",
    "race conflict after conditional update"
  ]
}, null, 2));
