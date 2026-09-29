'use strict';

(function (root, factory) {
  const dependency = typeof module !== 'undefined' && module.exports
    ? require('./api-client.js')
    : root.UsedCarApi;
  const api = factory(dependency);
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  root.UsedCarData = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function (UsedCarApi) {
  const MOCK_DATA = Object.freeze({
    customers: Object.freeze([
      Object.freeze({name:'山田 太郎',phone:'090-1234-5678',area:'埼玉県さいたま市',cars:2,vehicle:'プリウス / アクア'}),
      Object.freeze({name:'佐藤 美咲',phone:'080-2233-4455',area:'埼玉県川越市',cars:1,vehicle:'N-BOX'}),
      Object.freeze({name:'鈴木 一郎',phone:'090-7777-1212',area:'埼玉県熊谷市',cars:1,vehicle:'エブリイ'})
    ]),
    vehicles: Object.freeze({
      v1:Object.freeze({title:'トヨタ プリウス',sub:'山田 太郎 / 大宮 330 あ 12-34',badge:'車検まで22日',owner:'山田 太郎',phone:'090-1234-5678',address:'埼玉県さいたま市',info:[['メーカー','トヨタ'],['車名','プリウス'],['年式','2020年'],['車台番号','ZVW51-1234567'],['走行距離','42,300 km'],['販売日','2025/10/15'],['販売価格','1,680,000円'],['車検満了','2026/10/18'],['担当','田中']],events:[['2026/09/10','エンジンオイル交換','42,300km / 8,800円'],['2026/07/03','右ドア板金修理','40,980km / 52,800円'],['2026/03/10','タイヤ4本交換','38,420km / 64,000円']],docs:[['📄','車検証','車検証_プリウス.jpg'],['🚗','車両写真','外観写真 6枚'],['🧾','修理記録','手書き修理メモ 2枚']]}),
      v2:Object.freeze({title:'ホンダ N-BOX',sub:'佐藤 美咲 / 川越 580 う 56-78',badge:'車検まで57日',owner:'佐藤 美咲',phone:'080-2233-4455',address:'埼玉県川越市',info:[['メーカー','ホンダ'],['車名','N-BOX'],['年式','2021年'],['車台番号','JF3-9876543'],['走行距離','31,850 km'],['販売日','2025/06/08'],['販売価格','1,390,000円'],['車検満了','2026/11/22'],['担当','田中']],events:[['2026/08/22','12か月点検','31,500km / 16,500円'],['2026/05/11','エアコンフィルター交換','29,100km / 5,500円']],docs:[['📄','車検証','車検証_NBOX.jpg'],['🚗','車両写真','外観写真 4枚']]}),
      v3:Object.freeze({title:'スズキ エブリイ',sub:'鈴木 一郎 / 熊谷 480 か 90-12',badge:'車検まで73日',owner:'鈴木 一郎',phone:'090-7777-1212',address:'埼玉県熊谷市',info:[['メーカー','スズキ'],['車名','エブリイ'],['年式','2019年'],['車台番号','DA17V-456789'],['走行距離','68,210 km'],['販売日','2024/11/02'],['販売価格','980,000円'],['車検満了','2026/12/08'],['担当','佐々木']],events:[['2026/06/14','ブレーキパッド交換','64,900km / 28,600円'],['2026/02/18','オイル・エレメント交換','61,200km / 9,900円']],docs:[['📄','車検証','車検証_エブリイ.jpg'],['🚗','車両写真','外観写真 5枚'],['🧾','整備記録','整備記録写真 3枚']]})
    })
  });

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function normalizeMode(mode) {
    const value = String(mode || 'mock').trim().toLowerCase();
    if (!['mock', 'api'].includes(value)) {
      throw new Error('Used-car data mode must be mock or api');
    }
    return value;
  }

  function mockResult(data) {
    return Promise.resolve({
      mode: 'mock',
      persisted: false,
      data: clone(data),
      requestId: null,
      idempotencyKey: null,
    });
  }

  function createAdapter(options = {}) {
    const mode = normalizeMode(options.mode);
    const apiClient = options.apiClient || (
      mode === 'api' && UsedCarApi
        ? UsedCarApi.createClient({
            baseUrl: options.baseUrl,
            fetchImpl: options.fetchImpl,
          })
        : null
    );

    function requireApi() {
      if (mode !== 'api') return null;
      if (!apiClient || apiClient.configured === false) {
        const ErrorType = UsedCarApi && UsedCarApi.UsedCarApiError ? UsedCarApi.UsedCarApiError : Error;
        const error = new ErrorType('P014 Worker API is not configured', { code: 'API_NOT_CONFIGURED' });
        if (!error.code) error.code = 'API_NOT_CONFIGURED';
        throw error;
      }
      return apiClient;
    }

    function mockSnapshot() {
      return clone(MOCK_DATA);
    }

    async function query(operationId, input = {}, invokeOptions = {}) {
      if (mode === 'mock') {
        if (operationId === 'usedcar.vehicle.get') {
          const v = MOCK_DATA.vehicles[input.vehicle_id];
          return mockResult(v || null);
        }
        return mockResult(null);
      }
      return requireApi().query(operationId, input, invokeOptions);
    }

    async function command(operationId, input = {}, invokeOptions = {}) {
      if (mode === 'mock') {
        return mockResult({ operation_id: operationId, input });
      }
      return requireApi().command(operationId, input, invokeOptions);
    }

    return Object.freeze({
      mode,
      configured: mode === 'mock' || Boolean(apiClient && apiClient.configured),
      mockSnapshot,
      query,
      command,
      getVehicle(vehicleId, options) {
        return query('usedcar.vehicle.get', { vehicle_id: vehicleId }, options);
      },
      getCustomer(customerId, options) {
        return query('usedcar.customer.get', { customer_id: customerId }, options);
      },
      listInspections(vehicleId, options) {
        return query('usedcar.inspection.list.by_vehicle', { vehicle_id: vehicleId }, options);
      },
      listMaintenance(vehicleId, options) {
        return query('usedcar.maintenance.list.by_vehicle', { vehicle_id: vehicleId }, options);
      },
      listDocuments(vehicleId, options) {
        return query('usedcar.document.list.by_vehicle', { vehicle_id: vehicleId }, options);
      },
      createCustomer(input, options) {
        return command('usedcar.customer.create', input, options);
      },
      createVehicle(input, options) {
        return command('usedcar.vehicle.create', input, options);
      },
      updateVehicle(input, options) {
        return command('usedcar.vehicle.update', input, options);
      },
      createInspection(input, options) {
        return command('usedcar.inspection.create', input, options);
      },
      createMaintenance(input, options) {
        return command('usedcar.maintenance.create', input, options);
      },
      linkDocument(input, options) {
        return command('usedcar.document.link.create', input, options);
      },
      archiveDocument(input, options) {
        return command('usedcar.document.archive', input, options);
      },
    });
  }

  return Object.freeze({
    MOCK_DATA,
    normalizeMode,
    createAdapter,
  });
});
