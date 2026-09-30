import assert from "node:assert/strict";
import {
  P013_UPLOAD_POLICY,
  isAllowedImageMimeType,
  normalizeUploadDescriptor,
} from "./p013-upload-contract.mjs";

const base = {
  image_id: "IMG-01K8ABCDEF",
  object_id: "01K8OBJECT001",
  original_filename: "front.jpg",
  content_type: "image/jpeg",
  content_length: 4_000_000,
  sha256: "A".repeat(64),
  object_key:
    "original/2026/09/product-image/IMG-01K8ABCDEF/01K8OBJECT001-front.jpg",
};

const normalized = normalizeUploadDescriptor(base);
assert.equal(normalized.content_type, "image/jpeg");
assert.equal(normalized.content_length, 4_000_000);
assert.equal(normalized.sha256, "a".repeat(64));
assert.equal(normalized.original_filename, "front.jpg");
assert.equal(normalized.object_key, base.object_key);

assert.equal(isAllowedImageMimeType("IMAGE/PNG"), true);
assert.equal(isAllowedImageMimeType("image/webp"), true);
assert.equal(isAllowedImageMimeType("image/heic"), true);
assert.equal(isAllowedImageMimeType("image/heif"), true);
assert.equal(isAllowedImageMimeType("image/gif"), false);

for (const mime of P013_UPLOAD_POLICY.allowedImageMimeTypes) {
  assert.equal(isAllowedImageMimeType(mime), true);
}

assert.throws(
  () => normalizeUploadDescriptor({ ...base, content_length: 0 }),
  /content_length/,
);
assert.throws(
  () =>
    normalizeUploadDescriptor({
      ...base,
      content_length: P013_UPLOAD_POLICY.maxContentBytes + 1,
    }),
  /content_length/,
);
assert.throws(
  () => normalizeUploadDescriptor({ ...base, content_length: 1.5 }),
  /content_length/,
);
assert.throws(
  () => normalizeUploadDescriptor({ ...base, content_type: "application/octet-stream" }),
  /content_type/,
);
assert.throws(
  () => normalizeUploadDescriptor({ ...base, sha256: "abc" }),
  /sha256/,
);
assert.throws(
  () =>
    normalizeUploadDescriptor({
      ...base,
      object_key:
        "original/2026/09/product-image/IMG-OTHER/01K8OBJECT001-front.jpg",
    }),
  /image_id mismatch/,
);
assert.throws(
  () =>
    normalizeUploadDescriptor({
      ...base,
      object_key:
        "original/2026/09/product-image/IMG-01K8ABCDEF/OTHER-front.jpg",
    }),
  /object_id\/filename mismatch/,
);
assert.throws(
  () => normalizeUploadDescriptor({ ...base, image_id: "../IMG" }),
  /image_id/,
);
assert.throws(
  () =>
    normalizeUploadDescriptor({
      ...base,
      original_filename: "../front.jpg",
    }),
  /path/,
);
assert.throws(
  () =>
    normalizeUploadDescriptor({
      ...base,
      extra: "not-allowed",
    }),
  /unknown or missing/,
);
assert.throws(
  () => {
    const { sha256, ...missing } = base;
    return normalizeUploadDescriptor(missing);
  },
  /unknown or missing/,
);

const jp = normalizeUploadDescriptor({
  ...base,
  original_filename: "商品 写真.heic",
  content_type: "image/heic",
  object_key:
    "original/2026/09/product-image/IMG-01K8ABCDEF/01K8OBJECT001-商品_写真.heic",
});
assert.equal(jp.original_filename, "商品_写真.heic");

console.log(
  JSON.stringify(
    {
      ok: true,
      assertions: 26,
      allowedMimeTypes: P013_UPLOAD_POLICY.allowedImageMimeTypes,
      maxContentBytes: P013_UPLOAD_POLICY.maxContentBytes,
      sample: normalized,
    },
    null,
    2,
  ),
);
