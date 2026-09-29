'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const api = require('./api-client.js');

function jsonResponse(body, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    async json() { return body; },
  };
}

test('unconfigured client never performs network I/O', async () => {
  let called = false;
  const client = api.createClient({ fetchImpl: async () => { called = true; } });
  assert.equal(client.configured, false);
  await assert.rejects(
    client.query('usedcar.vehicle.get', { vehicle_id: 'vehicle_12345678' }),
    (error) => error.code === 'API_NOT_CONFIGURED',
  );
  assert.equal(called, false);
});

test('query builds the common Worker API request shape', async () => {
  let request;
  const client = api.createClient({
    baseUrl: 'https://api.example.test/',
    fetchImpl: async (url, init) => {
      request = { url, init };
      return jsonResponse({ ok: true, request_id: 'req-server', data: { vehicle_id: 'v1' }, meta: {} });
    },
  });
  const result = await client.query('usedcar.vehicle.get', { vehicle_id: 'vehicle_12345678' }, { requestId: 'req-client' });
  assert.equal(request.url, 'https://api.example.test/v1/queries/usedcar.vehicle.get');
  assert.equal(request.init.method, 'POST');
  assert.equal(request.init.credentials, 'include');
  assert.equal(request.init.cache, 'no-store');
  assert.equal(request.init.headers['X-AutoAI-Request'], '1');
  assert.equal(request.init.headers['X-Request-Id'], 'req-client');
  assert.equal(request.init.headers['Idempotency-Key'], undefined);
  assert.deepEqual(JSON.parse(request.init.body), { input: { vehicle_id: 'vehicle_12345678' } });
  assert.equal(result.requestId, 'req-server');
  assert.equal(result.idempotencyKey, null);
});

test('command preserves caller supplied idempotency key for retries', async () => {
  let request;
  const client = api.createClient({
    baseUrl: 'https://api.example.test',
    fetchImpl: async (url, init) => {
      request = { url, init };
      return jsonResponse({ ok: true, request_id: 'req-1', data: { vehicle_id: 'v1' }, meta: {} });
    },
  });
  const result = await client.command(
    'usedcar.vehicle.update',
    { vehicle_id: 'vehicle_12345678', expected_state_version: 3 },
    { idempotencyKey: 'idem-fixed-12345678' },
  );
  assert.equal(request.url, 'https://api.example.test/v1/commands/usedcar.vehicle.update');
  assert.equal(request.init.headers['Idempotency-Key'], 'idem-fixed-12345678');
  assert.equal(result.idempotencyKey, 'idem-fixed-12345678');
});

test('command auto-generates an idempotency key when absent', async () => {
  let key;
  const client = api.createClient({
    baseUrl: 'https://api.example.test',
    fetchImpl: async (url, init) => {
      key = init.headers['Idempotency-Key'];
      return jsonResponse({ ok: true, request_id: 'req-2', data: {}, meta: {} });
    },
  });
  const result = await client.command('usedcar.customer.create', { display_name: 'Test' });
  assert.match(key, /^p014-/);
  assert.equal(result.idempotencyKey, key);
});

test('non-allowlisted operations are rejected before fetch', async () => {
  let called = false;
  const client = api.createClient({
    baseUrl: 'https://api.example.test',
    fetchImpl: async () => { called = true; },
  });
  await assert.rejects(
    client.invoke('system.db.ping', {}),
    (error) => error.code === 'OPERATION_NOT_ALLOWED',
  );
  assert.equal(called, false);
});

test('kind mismatch is rejected before fetch', async () => {
  const client = api.createClient({ baseUrl: 'https://api.example.test', fetchImpl: async () => jsonResponse({}) });
  await assert.rejects(
    Promise.resolve().then(() => client.query('usedcar.customer.create', {})),
    (error) => error.code === 'OPERATION_KIND_MISMATCH',
  );
});

test('Worker error payload is normalized', async () => {
  const client = api.createClient({
    baseUrl: 'https://api.example.test',
    fetchImpl: async () => jsonResponse({
      ok: false,
      request_id: 'req-error',
      error: { code: 'FORBIDDEN', message: 'Operation is not permitted', retry_after_seconds: null },
    }, 403),
  });
  await assert.rejects(
    client.query('usedcar.customer.get', { customer_id: 'customer_12345678' }),
    (error) => error.code === 'FORBIDDEN' && error.status === 403 && error.requestId === 'req-error',
  );
});

test('all P014 project operations are represented with the expected kind', () => {
  assert.deepEqual(api.OPERATIONS, {
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
});
