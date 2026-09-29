'use strict';

(function (root, factory) {
  const api = factory();
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  root.UsedCarApi = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  const OPERATIONS = Object.freeze({
    'usedcar.customer.create': 'command',
    'usedcar.customer.get': 'query',
    'usedcar.vehicle.create': 'command',
    'usedcar.vehicle.get': 'query',
    'usedcar.vehicle.update': 'command',
    'usedcar.inspection.create': 'command',
    'usedcar.inspection.list.by_vehicle': 'query',
    'usedcar.maintenance.create': 'command',
    'usedcar.maintenance.list.by_vehicle': 'query',
    'usedcar.document.link.create': 'command',
    'usedcar.document.list.by_vehicle': 'query',
    'usedcar.document.archive': 'command',
  });

  class UsedCarApiError extends Error {
    constructor(message, options = {}) {
      super(message);
      this.name = 'UsedCarApiError';
      this.code = options.code || 'API_ERROR';
      this.status = options.status || 0;
      this.requestId = options.requestId || null;
      this.retryAfterSeconds = options.retryAfterSeconds ?? null;
      this.payload = options.payload ?? null;
    }
  }

  function normalizeBaseUrl(value) {
    const raw = String(value || '').trim();
    if (!raw) return '';
    let parsed;
    try {
      parsed = new URL(raw);
    } catch {
      throw new UsedCarApiError('API base URL is invalid', { code: 'INVALID_API_BASE_URL' });
    }
    if (!['https:', 'http:'].includes(parsed.protocol)) {
      throw new UsedCarApiError('API base URL must use http or https', { code: 'INVALID_API_BASE_URL' });
    }
    return parsed.toString().replace(/\/+$/, '');
  }

  function randomToken(prefix) {
    const uuid = globalThis.crypto && typeof globalThis.crypto.randomUUID === 'function'
      ? globalThis.crypto.randomUUID()
      : `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    return `${prefix}-${uuid}`;
  }

  function newIdempotencyKey() {
    return randomToken('p014');
  }

  function operationKind(operationId) {
    return OPERATIONS[operationId] || null;
  }

  function createClient(options = {}) {
    const baseUrl = normalizeBaseUrl(options.baseUrl);
    const fetchImpl = options.fetchImpl || globalThis.fetch;

    async function invoke(operationId, input = {}, invokeOptions = {}) {
      const kind = operationKind(operationId);
      if (!kind) {
        throw new UsedCarApiError('Operation is not allowlisted for P014', { code: 'OPERATION_NOT_ALLOWED' });
      }
      if (!baseUrl) {
        throw new UsedCarApiError('P014 Worker API is not configured', { code: 'API_NOT_CONFIGURED' });
      }
      if (typeof fetchImpl !== 'function') {
        throw new UsedCarApiError('Fetch API is unavailable', { code: 'FETCH_UNAVAILABLE' });
      }

      const requestId = invokeOptions.requestId || randomToken('req');
      const headers = {
        'Content-Type': 'application/json',
        'X-AutoAI-Request': '1',
        'X-Request-Id': requestId,
      };
      let idempotencyKey = null;
      if (kind === 'command') {
        idempotencyKey = invokeOptions.idempotencyKey || newIdempotencyKey();
        headers['Idempotency-Key'] = idempotencyKey;
      }

      const url = `${baseUrl}/v1/${kind === 'query' ? 'queries' : 'commands'}/${encodeURIComponent(operationId)}`;
      let response;
      try {
        response = await fetchImpl(url, {
          method: 'POST',
          credentials: 'include',
          mode: 'cors',
          cache: 'no-store',
          headers,
          body: JSON.stringify({ input }),
        });
      } catch (error) {
        throw new UsedCarApiError('Worker API request failed', {
          code: 'NETWORK_ERROR',
          requestId,
          payload: { cause: String(error && error.message ? error.message : error) },
        });
      }

      let payload = null;
      try {
        payload = await response.json();
      } catch {
        throw new UsedCarApiError('Worker API returned invalid JSON', {
          code: 'INVALID_RESPONSE',
          status: response.status,
          requestId,
        });
      }

      const responseRequestId = payload && payload.request_id ? payload.request_id : requestId;
      if (!response.ok || !payload || payload.ok !== true) {
        const error = payload && payload.error ? payload.error : {};
        throw new UsedCarApiError(error.message || 'Worker API returned an error', {
          code: error.code || 'API_ERROR',
          status: response.status,
          requestId: responseRequestId,
          retryAfterSeconds: error.retry_after_seconds ?? null,
          payload,
        });
      }

      return {
        payload,
        requestId: responseRequestId,
        idempotencyKey,
      };
    }

    return Object.freeze({
      configured: Boolean(baseUrl),
      baseUrl,
      invoke,
      query(operationId, input, options) {
        if (operationKind(operationId) !== 'query') {
          throw new UsedCarApiError('Operation is not a query', { code: 'OPERATION_KIND_MISMATCH' });
        }
        return invoke(operationId, input, options);
      },
      command(operationId, input, options) {
        if (operationKind(operationId) !== 'command') {
          throw new UsedCarApiError('Operation is not a command', { code: 'OPERATION_KIND_MISMATCH' });
        }
        return invoke(operationId, input, options);
      },
    });
  }

  return Object.freeze({
    OPERATIONS,
    UsedCarApiError,
    normalizeBaseUrl,
    operationKind,
    newIdempotencyKey,
    createClient,
  });
});
