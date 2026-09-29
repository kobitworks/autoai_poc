'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const data = require('./data-adapter.js');

test('default adapter is mock and returns an isolated fixture snapshot', () => {
  const adapter = data.createAdapter();
  assert.equal(adapter.mode, 'mock');
  assert.equal(adapter.configured, true);
  const a = adapter.mockSnapshot();
  const b = adapter.mockSnapshot();
  assert.equal(a.customers.length, 3);
  assert.equal(Object.keys(a.vehicles).length, 3);
  a.customers[0].name = 'changed';
  assert.equal(b.customers[0].name, '山田 太郎');
});

test('mock mode never needs an API client and never persists commands', async () => {
  const adapter = data.createAdapter({ mode: 'mock' });
  const result = await adapter.createCustomer({ display_name: 'テスト顧客' }, { idempotencyKey: 'idem-1' });
  assert.equal(result.mode, 'mock');
  assert.equal(result.persisted, false);
  assert.equal(result.idempotencyKey, null);
  assert.equal(result.data.operation_id, 'usedcar.customer.create');
});

test('api mode without configured base is rejected before network I/O', async () => {
  let called = false;
  const adapter = data.createAdapter({
    mode: 'api',
    fetchImpl: async () => { called = true; },
  });
  assert.equal(adapter.configured, false);
  await assert.rejects(
    adapter.getVehicle('vehicle_12345678'),
    (error) => error.code === 'API_NOT_CONFIGURED',
  );
  assert.equal(called, false);
});

test('api query delegates to the P014 API client boundary', async () => {
  const calls = [];
  const apiClient = {
    configured: true,
    async query(operationId, input, options) {
      calls.push({ kind: 'query', operationId, input, options });
      return { payload: { ok: true }, requestId: 'req-q', idempotencyKey: null };
    },
    async command() {
      throw new Error('not expected');
    },
  };
  const adapter = data.createAdapter({ mode: 'api', apiClient });
  const result = await adapter.listMaintenance('vehicle_12345678', { requestId: 'req-client' });
  assert.equal(result.requestId, 'req-q');
  assert.deepEqual(calls, [{
    kind: 'query',
    operationId: 'usedcar.maintenance.list.by_vehicle',
    input: { vehicle_id: 'vehicle_12345678' },
    options: { requestId: 'req-client' },
  }]);
});

test('api command preserves caller supplied Idempotency-Key', async () => {
  const calls = [];
  const apiClient = {
    configured: true,
    async query() {
      throw new Error('not expected');
    },
    async command(operationId, input, options) {
      calls.push({ operationId, input, options });
      return { payload: { ok: true }, requestId: 'req-c', idempotencyKey: options.idempotencyKey };
    },
  };
  const adapter = data.createAdapter({ mode: 'api', apiClient });
  const result = await adapter.updateVehicle(
    { vehicle_id: 'vehicle_12345678', expected_state_version: 4 },
    { idempotencyKey: 'idem-fixed-12345678' },
  );
  assert.equal(result.idempotencyKey, 'idem-fixed-12345678');
  assert.deepEqual(calls[0], {
    operationId: 'usedcar.vehicle.update',
    input: { vehicle_id: 'vehicle_12345678', expected_state_version: 4 },
    options: { idempotencyKey: 'idem-fixed-12345678' },
  });
});

test('unsupported data mode is rejected immediately', () => {
  assert.throws(() => data.createAdapter({ mode: 'direct-d1' }), /mock or api/);
});
