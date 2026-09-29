'use strict';
const assert = require('assert');
const core = require('./qr-grouping-core');

const A = 'QPMS2609281234560001';
const B = 'QPMS2609281234560002';

assert.strictEqual(core.validCode(A), true);
assert.strictEqual(core.validCode(A.toLowerCase()), true);
assert.strictEqual(core.validCode('QPMS260928123456001'), false);
assert.strictEqual(core.validCode('OTHER2609281234560001'), false);

assert.strictEqual(core.norm(A), A);
assert.strictEqual(core.norm('https://example.test/item?code=' + A), A);
assert.strictEqual(core.norm('https%3A%2F%2Fexample.test%2Fitem%3Fcode%3D' + A), A);
assert.strictEqual(core.norm('prefix-' + B + '-suffix'), B);
assert.strictEqual(core.norm('https://example.test/no-code'), '');
assert.strictEqual(core.norm('%E0%A4%A'), '');

assert.deepStrictEqual(core.uniq(['x','x','y','',null,'y']), ['x','y']);

const images = [
  { id:'2', originalName:'b.jpg', mimeType:'image/jpeg', qrCode:A, status:'grouped' },
  { id:'1', originalName:'a.png', mimeType:'image/png', qrCode:A, status:'grouped' },
  { id:'3', originalName:'c.webp', mimeType:'image/webp', qrCode:B, status:'manual' },
  { id:'4', originalName:'multi.jpg', mimeType:'image/jpeg', qrCode:'', status:'multi', qrCandidates:[A,B] },
  { id:'5', originalName:'bad.jpg', mimeType:'image/jpeg', qrCode:'', status:'invalid' },
  { id:'6', originalName:'none.jpg', mimeType:'image/jpeg', qrCode:'', status:'unread' },
  { id:'7', originalName:'stale.jpg', mimeType:'image/jpeg', qrCode:A, status:'unread' }
];

const result = core.groupImages(images);
assert.deepStrictEqual(Object.keys(result.groups).sort(), [A,B]);
assert.strictEqual(result.groups[A].length, 2);
assert.strictEqual(result.groups[B].length, 1);
assert.strictEqual(result.unresolved.length, 4);
assert.strictEqual(result.groups[A][0].originalName, 'a.png');
assert.strictEqual(result.groups[A][0].virtualName, A + '_01.png');
assert.strictEqual(result.groups[A][1].virtualName, A + '_02.jpg');
assert.strictEqual(result.groups[B][0].virtualName, B + '_01.webp');
assert.deepStrictEqual(result.unresolved.map(x => x.id), ['4','5','6','7']);

const again = core.groupImages(images);
assert.deepStrictEqual(
  again.groups[A].map(x => x.virtualName),
  [A + '_01.png', A + '_02.jpg']
);

console.log(JSON.stringify({
  ok: true,
  tests: 19,
  groups: Object.keys(result.groups).length,
  unresolved: result.unresolved.length,
  firstGroupVirtualNames: result.groups[A].map(x => x.virtualName)
}, null, 2));
