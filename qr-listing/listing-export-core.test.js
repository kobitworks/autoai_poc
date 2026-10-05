'use strict';
const assert=require('assert');
const Core=require('./listing-export-core.js');

const base={
  code:'QPMS2610052024000001',
  files:['QPMS2610052024000001_01.jpg','QPMS2610052024000001_02.jpg'],
  imageCount:2,
  confirmedProduct:{
    confirmedAt:'2026-10-05T11:20:00.000Z',
    fields:{
      title:'テスト商品',
      brand:'AutoAI',
      category:'その他',
      color:'青',
      condition:'良好',
      features:'軽量',
      description:'確認済み説明'
    }
  }
};

const row=Core.buildListingRecord(base);
assert(row);
assert.strictEqual(row.product_code,base.code);
assert.strictEqual(row.title,'テスト商品');
assert.strictEqual(row.price,'');
assert.strictEqual(row.currency,'JPY');
assert.strictEqual(row.quantity,1);
assert.strictEqual(row.listing_status,'draft');
assert.strictEqual(row.image_files,base.files.join(' | '));

assert.strictEqual(Core.buildListingRecord({code:'X'}),null);
assert.strictEqual(Core.buildListingRecord({code:'X',confirmedProduct:{fields:{title:'  '}}}),null);

const rows=Core.buildListingRecords([
  base,
  Object.assign({},base,{code:'QPMS2610052024000000',confirmedProduct:{confirmedAt:'2026-10-05T11:10:00Z',fields:Object.assign({},base.confirmedProduct.fields,{title:'先頭'})}}),
  {code:'NO-CONFIRM'}
]);
assert.strictEqual(rows.length,2);
assert.strictEqual(rows[0].title,'先頭');

const csv=Core.toCsv([row]);
assert(csv.includes('"商品ID","商品名"'));
assert(csv.includes('"テスト商品"'));
assert(csv.includes('"QPMS2610052024000001_01.jpg | QPMS2610052024000001_02.jpg"'));

const dangerous=Object.assign({},base,{
  code:'SAFE',
  confirmedProduct:{confirmedAt:'2026-10-05T11:20:00Z',fields:Object.assign({},base.confirmedProduct.fields,{title:'=1+1',description:'"quoted", value'})}
});
const dangerousCsv=Core.toCsv([Core.buildListingRecord(dangerous)]);
assert(dangerousCsv.includes('"\'=1+1"'));
assert(dangerousCsv.includes('"""quoted"", value"'));

const copy=Core.toCopyText(row);
assert.deepStrictEqual(JSON.parse(copy),row);
console.log('QR-009 listing export core tests: PASS');
