const assert=require('node:assert/strict');
const core=require('./ai-analysis-core.js');

assert.equal(core.categoryFromLabels([{label:'running shoe',score:.9}]),'靴');
assert.equal(core.categoryFromLabels([{label:'backpack, knapsack',score:.8}]),'バッグ');
assert.equal(core.colorName({r:245,g:245,b:242}),'白');
assert.equal(core.colorName({r:30,g:35,b:40}),'黒');
assert.equal(core.colorName({r:32,g:90,b:210}),'青');

const labels=core.aggregate([
  [{label:'running shoe',score:.82},{label:'sandal',score:.1}],
  [{label:'running shoe',score:.72},{label:'loafer',score:.14}]
]);
assert.equal(labels[0].label,'running shoe');
assert.equal(labels[0].imageCount,2);

const fields=core.buildFields({
  labels,
  dominantColor:{r:32,g:90,b:210},
  photoCount:3,
  existing:{}
});
assert.equal(fields.title,'スニーカー');
assert.equal(fields.category,'靴');
assert.equal(fields.color,'青');
assert.equal(fields.condition,'要確認');
assert.match(fields.features,/スニーカー/);
assert.match(fields.description,/写真は3枚/);

console.log('QR-007 ai-analysis-core tests PASS');
