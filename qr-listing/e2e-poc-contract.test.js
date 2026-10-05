'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const QR = require('./qr-grouping-core.js');
const AI = require('./ai-analysis-core.js');
const Confirm = require('./product-confirmation-core.js');
const Listing = require('./listing-export-core.js');

const A = 'QPMS2610060028240001';
const B = 'QPMS2610060028240002';

const groupedInput = [
  { id: 'a1', originalName: 'shoe-front.jpg', mimeType: 'image/jpeg', qrCode: A, status: 'grouped' },
  { id: 'a2', originalName: 'shoe-side.jpg', mimeType: 'image/jpeg', qrCode: A, status: 'grouped' },
  { id: 'b1', originalName: 'bag-front.png', mimeType: 'image/png', qrCode: B, status: 'manual' },
  { id: 'u1', originalName: 'unknown.jpg', mimeType: 'image/jpeg', qrCode: '', status: 'unread' }
];

const grouping = QR.groupImages(groupedInput);
assert.deepEqual(Object.keys(grouping.groups).sort(), [A, B]);
assert.equal(grouping.groups[A].length, 2);
assert.equal(grouping.groups[B].length, 1);
assert.equal(grouping.unresolved.length, 1);
assert.equal(grouping.groups[A][0].virtualName, A + '_01.jpg');
assert.equal(grouping.groups[A][1].virtualName, A + '_02.jpg');
assert.equal(grouping.groups[B][0].virtualName, B + '_01.png');

function makeConfirmedProduct(code, images, labels, rgb, at) {
  const fields = AI.buildFields({
    labels,
    dominantColor: rgb,
    photoCount: images.length,
    existing: {}
  });
  const confirmedProduct = Confirm.buildConfirmedProduct({
    fields,
    confirmedAt: at,
    sourceAnalysisExecutedAt: at,
    sourceCandidateSavedAt: at
  });
  return {
    code,
    files: images.map(x => x.virtualName),
    imageCount: images.length,
    processingState: 'product_confirmed',
    status: 'product_confirmed',
    confirmedProduct
  };
}

const productA = makeConfirmedProduct(
  A,
  grouping.groups[A],
  [{ label: 'running shoe', score: 0.94 }],
  { r: 42, g: 85, b: 180 },
  '2026-10-06T00:28:24+09:00'
);
const productB = makeConfirmedProduct(
  B,
  grouping.groups[B],
  [{ label: 'handbag', score: 0.91 }],
  { r: 120, g: 70, b: 35 },
  '2026-10-06T00:28:24+09:00'
);

const unconfirmed = {
  code: 'QPMS2610060028240003',
  files: ['pending.jpg'],
  aiAnalysis: { fields: { title: '未確定商品' } }
};

const records = Listing.buildListingRecords([productB, unconfirmed, productA]);
assert.equal(records.length, 2, 'human-confirmed products only');
assert.deepEqual(records.map(x => x.product_code), [A, B]);
assert.equal(records[0].title, 'スニーカー');
assert.equal(records[0].quantity, 1);
assert.equal(records[0].currency, 'JPY');
assert.equal(records[0].listing_status, 'draft');
assert.equal(records[0].price, '');
assert.match(records[0].image_files, /_01\.jpg/);
assert.equal(records[1].title, 'バッグ');

const csv = Listing.toCsv(records);
assert.match(csv, /商品ID/);
assert.match(csv, new RegExp(A));
assert.match(csv, new RegExp(B));

function page(name) {
  return fs.readFileSync(path.join(__dirname, name), 'utf8');
}
function has(name, pattern, label) {
  assert.match(page(name), pattern, label || (name + ' wiring'));
}

has('index.html', /\.\/upload\.html/, 'menu -> upload');
has('index.html', /\.\/products\.html/, 'menu -> products');
has('index.html', /\.\/ai-analysis\.html/, 'menu -> AI analysis');
has('index.html', /\.\/listing-export\.html/, 'menu -> listing export');

has('upload.html', /AutoAIStore\.saveImages/, 'upload persists images');
has('upload.html', /\.\/analyze\.html\?batch=/, 'upload -> QR analysis');

has('analyze.html', /QRCore\.groupImages/, 'QR analysis groups images');
has('analyze.html', /AutoAIStore\.syncProducts/, 'QR analysis syncs products');

has('products.html', /\.\/ai-analysis\.html\?product=/, 'products -> AI analysis');
has('products.html', /\.\/listing-export\.html\?product=/, 'confirmed product -> listing export');

has('ai-analysis.html', /AutoAIStore\.putProduct/, 'AI candidate/confirmation persists product');
has('ai-analysis.html', /confirmedProduct/, 'human-confirmed product stored separately');

has('listing-export.html', /Core\.buildListingRecords/, 'listing page builds generic records');
has('listing-export.html', /Core\.toCsv/, 'listing page exports CSV');

console.log('P013 QR-011 E2E PoC contract: PASS');
console.log(JSON.stringify({
  groupedProducts: Object.keys(grouping.groups).length,
  groupedImages: grouping.groups[A].length + grouping.groups[B].length,
  unresolvedImages: grouping.unresolved.length,
  confirmedProducts: records.length,
  listingRecords: records.length,
  externalMarketplaceSubmission: false
}));
