// P013 QR商品出品支援 - browser-safe client for the P016 common Worker API.
// QR-019 adds only request construction/error normalization.
// No Worker URL, Access AUD, token, secret, or permission is embedded here.

const IDEMPOTENCY_KEY_RE = /^[A-Za-z0-9._~:+\/-]{16,128}$/;

const OPERATIONS = Object.freeze({
  getProduct: Object.freeze({ kind: "query", operationId: "p013.product.get" }),
  listProducts: Object.freeze({ kind: "query", operationId: "p013.product.list" }),
  createProduct: Object.freeze({ kind: "command", operationId: "p013.product.create" }),
  updateProductStatus: Object.freeze({ kind: "command", operationId: "p013.product.update_status" }),
});

function normalizeBaseUrl(value) {
  const raw = String(value || "").trim();
  if (!raw) throw new TypeError("baseUrl is required");

  let url;
  try {
    url = new URL(raw);
  } catch {
    throw new TypeError("baseUrl must be an absolute URL");
  }

  const localHttp =
    url.protocol === "http:" &&
    ["localhost", "127.0.0.1", "::1"].includes(url.hostname);

  if (url.protocol !== "https:" && !localHttp) {
    throw new TypeError("baseUrl must use https (http is allowed only for localhost)");
  }
  if (url.username || url.password) {
    throw new TypeError("baseUrl must not contain credentials");
  }
  if (url.search || url.hash) {
    throw new TypeError("baseUrl must not contain query or fragment");
  }

  url.pathname = url.pathname.replace(/\/+$/, "");
  return url.toString().replace(/\/$/, "");
}

function operationPath(baseUrl, operation) {
  const segment = operation.kind === "command" ? "commands" : "queries";
  return `${baseUrl}/v1/${segment}/${encodeURIComponent(operation.operationId)}`;
}

export class P013ApiError extends Error {
  constructor(message, {
    status = 0,
    code = "NETWORK_ERROR",
    requestId = null,
    retryAfterSeconds = null,
    cause = null,
  } = {}) {
    super(message, cause ? { cause } : undefined);
    this.name = "P013ApiError";
    this.status = status;
    this.code = code;
    this.requestId = requestId;
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

export function createP013ApiClient({
  baseUrl,
  fetchImpl = globalThis.fetch,
  credentials = "include",
} = {}) {
  const normalizedBaseUrl = normalizeBaseUrl(baseUrl);
  if (typeof fetchImpl !== "function") {
    throw new TypeError("fetchImpl must be a function");
  }

  async function invoke(operationName, input = {}, {
    idempotencyKey = null,
    requestId = null,
  } = {}) {
    const operation = OPERATIONS[operationName];
    if (!operation) throw new TypeError("Unsupported P013 operation");

    if (operation.kind === "command") {
      if (!IDEMPOTENCY_KEY_RE.test(String(idempotencyKey || ""))) {
        throw new TypeError("A valid Idempotency-Key is required for commands");
      }
    } else if (idempotencyKey != null) {
      throw new TypeError("Idempotency-Key is not accepted for queries");
    }

    const headers = {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "X-AutoAI-Request": "1",
    };
    if (requestId) headers["X-Request-Id"] = String(requestId);
    if (operation.kind === "command") headers["Idempotency-Key"] = String(idempotencyKey);

    let response;
    try {
      response = await fetchImpl(operationPath(normalizedBaseUrl, operation), {
        method: "POST",
        credentials,
        cache: "no-store",
        headers,
        body: JSON.stringify({ input: input ?? {} }),
      });
    } catch (error) {
      throw new P013ApiError("Worker API request failed", {
        code: "NETWORK_ERROR",
        cause: error,
      });
    }

    let payload = null;
    try {
      payload = await response.json();
    } catch {
      // Non-JSON error responses are normalized below.
    }

    if (!response.ok || payload?.ok !== true) {
      const retryHeader = response.headers?.get?.("Retry-After");
      const retryFromBody = payload?.error?.retry_after_seconds;
      const retry = retryFromBody ?? (retryHeader != null && retryHeader !== "" ? Number(retryHeader) : null);
      throw new P013ApiError(
        payload?.error?.message || `Worker API returned HTTP ${response.status}`,
        {
          status: Number(response.status || 0),
          code: payload?.error?.code || "HTTP_ERROR",
          requestId: payload?.request_id || null,
          retryAfterSeconds: Number.isFinite(Number(retry)) ? Number(retry) : null,
        },
      );
    }

    return payload;
  }

  return Object.freeze({
    getProduct(input, options) {
      return invoke("getProduct", input, options);
    },
    listProducts(input = {}, options) {
      return invoke("listProducts", input, options);
    },
    createProduct(input, options) {
      return invoke("createProduct", input, options);
    },
    updateProductStatus(input, options) {
      return invoke("updateProductStatus", input, options);
    },
  });
}

export const p013ApiClientContract = Object.freeze({
  idempotencyKeyPattern: IDEMPOTENCY_KEY_RE.source,
  operations: OPERATIONS,
});
