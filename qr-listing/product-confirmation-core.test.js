'use strict';
const assert=require('node:assert/strict');
const Core=require('./product-confirmation-core.js');

const normalized=Core.normalizeFields({
  title:'  テスト商品  ',
  brand:null,
  category:' バッグ ',
  color:'黒',
  condition:' 要確認 ',
  features:' 特徴 ',
  description:' 説明 '
});
assert.equal(normalized.title,'テスト商品');
assert.equal(normalized.brand,'');
assert.equal(normalized.category,'バッグ');
assert.equal(normalized.condition,'要確認');

const invalid=Core.validateFields({title:'   '});
assert.equal(invalid.ok,false);
assert.equal(invalid.errors[0].code,'TITLE_REQUIRED');

const valid=Core.validateFields({title:'商品A',brand:'Brand'});
assert.equal(valid.ok,true);
assert.equal(valid.fields.title,'商品A');

const confirmed=Core.buildConfirmedProduct({
  fields:{title:' 商品A ',brand:' Brand ',category:'バッグ'},
  confirmedAt:'2026-10-05T09:21:00.000Z',
  sourceAnalysisExecutedAt:'2026-10-05T09:20:00.000Z',
  sourceCandidateSavedAt:'2026-10-05T09:20:30.000Z'
});
assert.equal(confirmed.fields.title,'商品A');
assert.equal(confirmed.fields.brand,'Brand');
assert.equal(confirmed.source,'human-reviewed-ai-candidate');
assert.equal(confirmed.confirmedAt,'2026-10-05T09:21:00.000Z');

assert.throws(
  ()=>Core.buildConfirmedProduct({fields:{title:''},confirmedAt:'2026-10-05T09:21:00.000Z'}),
  err=>err&&err.code==='TITLE_REQUIRED'
);
assert.throws(
  ()=>Core.buildConfirmedProduct({fields:{title:'商品A'},confirmedAt:''}),
  err=>err&&err.code==='CONFIRMED_AT_REQUIRED'
);

console.log('product-confirmation-core: PASS');
