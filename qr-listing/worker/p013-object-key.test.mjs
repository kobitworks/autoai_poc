import assert from "node:assert/strict";
import {
  P013_OBJECT_KEY_POLICY,
  buildOriginalObjectKey,
  safeFilename,
  validateOriginalObjectKey,
} from "./p013-object-key.mjs";

const key = buildOriginalObjectKey({
  capturedAt: "2026-09-30T06:00:00Z",
  imageId: "IMG-01K8ABCDEF",
  objectId: "01K8OBJECT001",
  filename: " front photo (1).jpg ",
});
assert.equal(
  key,
  "original/2026/09/product-image/IMG-01K8ABCDEF/01K8OBJECT001-front_photo_(1).jpg",
);
assert.equal(validateOriginalObjectKey(key), true);
assert.equal(
  buildOriginalObjectKey({
    capturedAt: new Date("2026-09-30T23:59:59+09:00"),
    imageId: "IMG-01K8ABCDEF",
    objectId: "01K8OBJECT001",
    filename: "front.jpg",
  }),
  "original/2026/09/product-image/IMG-01K8ABCDEF/01K8OBJECT001-front.jpg",
);

assert.equal(safeFilename("商品 写真.jpg"), "商品_写真.jpg");
assert.equal(safeFilename("a:b?c#d%.jpg"), "a_b_c_d_.jpg");
assert.throws(() => safeFilename("../secret.jpg"), /path/);
assert.throws(() => safeFilename("a\\secret.jpg"), /path/);
assert.throws(() => safeFilename("bad\u0000name.jpg"), /control/);
assert.throws(() => buildOriginalObjectKey({
  capturedAt: "not-a-date", imageId: "IMG-1", objectId: "OBJ-1", filename: "x.jpg",
}), /capturedAt/);
assert.throws(() => buildOriginalObjectKey({
  capturedAt: "2026-09-30T00:00:00Z", imageId: "../IMG", objectId: "OBJ-1", filename: "x.jpg",
}), /imageId/);
assert.throws(() => buildOriginalObjectKey({
  capturedAt: "2026-09-30T00:00:00Z", imageId: "IMG-1", objectId: "OBJ/1", filename: "x.jpg",
}), /objectId/);

const longName = "商品".repeat(80) + ".jpeg";
const truncated = safeFilename(longName);
assert.ok(new TextEncoder().encode(truncated).length <= P013_OBJECT_KEY_POLICY.maxFilenameBytes);
assert.ok(truncated.endsWith(".jpeg"));

assert.equal(validateOriginalObjectKey("original/2026/13/product-image/IMG-1/OBJ-1-x.jpg"), false);
assert.equal(validateOriginalObjectKey("original/2026/09/product-image/../OBJ-1-x.jpg"), false);
assert.equal(validateOriginalObjectKey("other/2026/09/product-image/IMG-1/OBJ-1-x.jpg"), false);
assert.equal(validateOriginalObjectKey(key + "/extra"), false);

const same = {
  capturedAt: "2026-09-30T06:00:00Z",
  imageId: "IMG-01K8ABCDEF",
  objectId: "01K8OBJECT001",
  filename: "front.jpg",
};
assert.equal(buildOriginalObjectKey(same), buildOriginalObjectKey(same));

console.log(JSON.stringify({
  ok: true,
  assertions: 18,
  sample: buildOriginalObjectKey(same),
  maxFilenameBytes: P013_OBJECT_KEY_POLICY.maxFilenameBytes,
}, null, 2));
