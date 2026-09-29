// P013 QR商品出品支援 - project-scoped Worker operations
// Intended to be wired into the P016 common Worker runtime by QR-014.
// No Worker deploy / permission registration is performed by this file alone.

const PRODUCT_ID_PATTERN = "^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$";
const QR_PATTERN = "^QPMS[0-9]{16}$";
const PRODUCT_STATUSES = [
  "PHOTO_GROUPED",
  "AI_PENDING",
  "AI_RUNNING",
  "AI_REVIEW",
  "CONFIRMED",
  "LISTING_READY",
  "EXPORTED",
  "ARCHIVED",
];
const DATA_SCOPES = ["staging", "production"];

const productIdSchema = { type: "string", pattern: PRODUCT_ID_PATTERN, maxLength: 64 };
const qrCodeSchema = { type: "string", pattern: QR_PATTERN, minLength: 20, maxLength: 20 };
const statusSchema = { type: "string", enum: PRODUCT_STATUSES };
const scopeSchema = { type: "string", enum: DATA_SCOPES };

function strictObject(properties, required = []) {
  return Object.freeze({
    type: "object",
    additionalProperties: false,
    properties,
    ...(required.length ? { required } : {}),
  });
}

function actorSubject(principal) {
  return String(principal?.actorId || principal?.clientKey || "unknown").slice(0, 255);
}

function nowIso() {
  return new Date().toISOString();
}

function changeCount(result) {
  return Number(result?.meta?.changes || 0);
}

function eventId(requestId, suffix) {
  const base = String(requestId || "request").replace(/[^A-Za-z0-9._:-]/g, "_").slice(0, 96);
  return `evt:${base}:${suffix}`;
}

export const p013Operations = Object.freeze({
  "p013.product.get": Object.freeze({
    operationId: "p013.product.get",
    kind: "query",
    resource: "p013.product",
    action: "read",
    inputSchema: strictObject({ product_id: productIdSchema }, ["product_id"]),
    async handler({ db, input }) {
      const row = await db.prepare(
        "SELECT product_id,primary_qr_code,data_scope,status,state_version,created_by,created_at,updated_at,archived_at " +
        "FROM products WHERE product_id=? LIMIT 1"
      ).bind(input.product_id).first();
      return { found: Boolean(row), product: row || null };
    },
  }),

  "p013.product.list": Object.freeze({
    operationId: "p013.product.list",
    kind: "query",
    resource: "p013.product",
    action: "read",
    inputSchema: strictObject({
      data_scope: scopeSchema,
      status: statusSchema,
      limit: { type: "integer", minimum: 1, maximum: 100 },
    }),
    async handler({ db, input }) {
      const scope = input.data_scope || "staging";
      const limit = Number(input.limit || 50);
      if (input.status) {
        const result = await db.prepare(
          "SELECT product_id,primary_qr_code,data_scope,status,state_version,created_at,updated_at " +
          "FROM products WHERE data_scope=? AND status=? ORDER BY updated_at DESC,product_id ASC LIMIT ?"
        ).bind(scope, input.status, limit).all();
        return { products: result?.results || [] };
      }
      const result = await db.prepare(
        "SELECT product_id,primary_qr_code,data_scope,status,state_version,created_at,updated_at " +
        "FROM products WHERE data_scope=? ORDER BY updated_at DESC,product_id ASC LIMIT ?"
      ).bind(scope, limit).all();
      return { products: result?.results || [] };
    },
  }),

  "p013.product.create": Object.freeze({
    operationId: "p013.product.create",
    kind: "command",
    resource: "p013.product",
    action: "create",
    inputSchema: strictObject({
      product_id: productIdSchema,
      primary_qr_code: qrCodeSchema,
      data_scope: scopeSchema,
    }, ["product_id", "primary_qr_code"]),
    async handler({ db, input, principal, requestId }) {
      const scope = input.data_scope || "staging";
      const actor = actorSubject(principal);
      const now = nowIso();

      const existing = await db.prepare(
        "SELECT product_id,primary_qr_code,state_version,status FROM products " +
        "WHERE product_id=? OR primary_qr_code=? LIMIT 1"
      ).bind(input.product_id, input.primary_qr_code).first();
      if (existing) {
        return { created: false, reason: "PRODUCT_OR_QR_ALREADY_ASSIGNED", product: existing };
      }

      const qr = await db.prepare(
        "SELECT qr_code,status FROM management_qr_codes WHERE qr_code=? LIMIT 1"
      ).bind(input.primary_qr_code).first();
      if (!qr || qr.status !== "AVAILABLE") {
        return { created: false, reason: "QR_NOT_AVAILABLE", product: null };
      }

      const productStmt = db.prepare(
        "INSERT INTO products " +
        "(product_id,primary_qr_code,data_scope,status,state_version,created_by,created_at,updated_at) " +
        "SELECT ?,?,?, 'PHOTO_GROUPED',1,?,?,? " +
        "FROM management_qr_codes WHERE qr_code=? AND status='AVAILABLE' " +
        "AND NOT EXISTS (SELECT 1 FROM products WHERE product_id=? OR primary_qr_code=?)"
      ).bind(
        input.product_id,
        input.primary_qr_code,
        scope,
        actor,
        now,
        now,
        input.primary_qr_code,
        input.product_id,
        input.primary_qr_code,
      );

      const qrStmt = db.prepare(
        "UPDATE management_qr_codes SET status='DISCOVERED',updated_at=? " +
        "WHERE qr_code=? AND status='AVAILABLE' " +
        "AND EXISTS (SELECT 1 FROM products WHERE product_id=? AND primary_qr_code=? AND created_at=?)"
      ).bind(now, input.primary_qr_code, input.product_id, input.primary_qr_code, now);

      const eventStmt = db.prepare(
        "INSERT INTO product_state_events " +
        "(event_id,product_id,from_status,to_status,reason,actor_subject,occurred_at) " +
        "SELECT ?,product_id,NULL,status,'product_create',?,? FROM products " +
        "WHERE product_id=? AND primary_qr_code=? AND created_at=?"
      ).bind(
        eventId(requestId, "create"),
        actor,
        now,
        input.product_id,
        input.primary_qr_code,
        now,
      );

      const results = await db.batch([productStmt, qrStmt, eventStmt]);
      if (changeCount(results?.[0]) !== 1) {
        return { created: false, reason: "CREATE_PRECONDITION_CONFLICT", product: null };
      }

      return {
        created: true,
        product: {
          product_id: input.product_id,
          primary_qr_code: input.primary_qr_code,
          data_scope: scope,
          status: "PHOTO_GROUPED",
          state_version: 1,
        },
      };
    },
  }),

  "p013.product.update_status": Object.freeze({
    operationId: "p013.product.update_status",
    kind: "command",
    resource: "p013.product",
    action: "update",
    inputSchema: strictObject({
      product_id: productIdSchema,
      expected_state_version: { type: "integer", minimum: 1 },
      status: statusSchema,
      reason: { type: "string", maxLength: 500 },
    }, ["product_id", "expected_state_version", "status"]),
    async handler({ db, input, principal, requestId }) {
      const actor = actorSubject(principal);
      const now = nowIso();
      const current = await db.prepare(
        "SELECT product_id,status,state_version FROM products WHERE product_id=? LIMIT 1"
      ).bind(input.product_id).first();

      if (!current) {
        return { updated: false, reason: "PRODUCT_NOT_FOUND", product: null };
      }
      if (Number(current.state_version) !== Number(input.expected_state_version)) {
        return { updated: false, reason: "STATE_VERSION_CONFLICT", product: current };
      }
      if (current.status === input.status) {
        return { updated: false, reason: "NO_STATE_CHANGE", product: current };
      }

      const nextVersion = Number(input.expected_state_version) + 1;
      const updateStmt = db.prepare(
        "UPDATE products SET status=?,state_version=state_version+1,updated_at=?, " +
        "archived_at=CASE WHEN ?='ARCHIVED' THEN COALESCE(archived_at,?) ELSE archived_at END " +
        "WHERE product_id=? AND state_version=?"
      ).bind(
        input.status,
        now,
        input.status,
        now,
        input.product_id,
        input.expected_state_version,
      );

      const eventStmt = db.prepare(
        "INSERT INTO product_state_events " +
        "(event_id,product_id,from_status,to_status,reason,actor_subject,occurred_at) " +
        "SELECT ?,product_id,?,?,?, ?,? FROM products " +
        "WHERE product_id=? AND state_version=? AND status=? AND updated_at=?"
      ).bind(
        eventId(requestId, "status"),
        current.status,
        input.status,
        input.reason || "status_update",
        actor,
        now,
        input.product_id,
        nextVersion,
        input.status,
        now,
      );

      const results = await db.batch([updateStmt, eventStmt]);
      if (changeCount(results?.[0]) !== 1) {
        const latest = await db.prepare(
          "SELECT product_id,status,state_version FROM products WHERE product_id=? LIMIT 1"
        ).bind(input.product_id).first();
        return { updated: false, reason: "STATE_VERSION_CONFLICT", product: latest || null };
      }

      return {
        updated: true,
        product: {
          product_id: input.product_id,
          status: input.status,
          state_version: nextVersion,
        },
      };
    },
  }),
});

export function getP013Operation(operationId) {
  return p013Operations[operationId] || null;
}
