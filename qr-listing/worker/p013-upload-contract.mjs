import { safeFilename, validateOriginalObjectKey } from "./p013-object-key.mjs";

const ALLOWED_IMAGE_MIME_TYPES = Object.freeze([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/heic",
  "image/heif",
]);
const ALLOWED_SET = new Set(ALLOWED_IMAGE_MIME_TYPES);
const MAX_CONTENT_BYTES = 25 * 1024 * 1024;
const SHA256_RE = /^[0-9a-f]{64}$/;
const EXACT_KEYS = Object.freeze([
  "content_length",
  "content_type",
  "image_id",
  "object_id",
  "object_key",
  "original_filename",
  "sha256",
]);

function assertPlainObject(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new TypeError("upload descriptor must be an object");
  }
}

function assertExactKeys(value) {
  const actual = Object.keys(value).sort();
  if (
    actual.length !== EXACT_KEYS.length ||
    actual.some((key, index) => key !== EXACT_KEYS[index])
  ) {
    throw new TypeError("upload descriptor has unknown or missing fields");
  }
}

function normalizeId(value, label) {
  const s = String(value ?? "").trim();
  if (!s) throw new TypeError(`${label} is required`);
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/.test(s) || s.includes("..")) {
    throw new TypeError(`${label} is invalid`);
  }
  return s;
}

function normalizeContentType(value) {
  const s = String(value ?? "").trim().toLowerCase();
  if (!ALLOWED_SET.has(s)) {
    throw new TypeError("content_type is not an allowed image MIME type");
  }
  return s;
}

function normalizeLength(value) {
  const n = Number(value);
  if (!Number.isSafeInteger(n) || n <= 0 || n > MAX_CONTENT_BYTES) {
    throw new TypeError("content_length is outside the allowed range");
  }
  return n;
}

function normalizeSha256(value) {
  const s = String(value ?? "").trim().toLowerCase();
  if (!SHA256_RE.test(s)) throw new TypeError("sha256 must be 64 hex characters");
  return s;
}

function assertObjectKeyMatches({ objectKey, imageId, objectId, filename }) {
  const key = String(objectKey ?? "");
  if (!validateOriginalObjectKey(key)) {
    throw new TypeError("object_key is invalid");
  }
  const parts = key.split("/");
  if (parts[4] !== imageId) {
    throw new TypeError("object_key image_id mismatch");
  }
  const expectedLeaf = `${objectId}-${filename}`;
  if (parts[5] !== expectedLeaf) {
    throw new TypeError("object_key object_id/filename mismatch");
  }
  return key;
}

export function normalizeUploadDescriptor(value) {
  assertPlainObject(value);
  assertExactKeys(value);

  const imageId = normalizeId(value.image_id, "image_id");
  const objectId = normalizeId(value.object_id, "object_id");
  const filename = safeFilename(value.original_filename);
  const contentType = normalizeContentType(value.content_type);
  const contentLength = normalizeLength(value.content_length);
  const sha256 = normalizeSha256(value.sha256);
  const objectKey = assertObjectKeyMatches({
    objectKey: value.object_key,
    imageId,
    objectId,
    filename,
  });

  return Object.freeze({
    image_id: imageId,
    object_id: objectId,
    original_filename: filename,
    content_type: contentType,
    content_length: contentLength,
    sha256,
    object_key: objectKey,
  });
}

export function isAllowedImageMimeType(value) {
  return ALLOWED_SET.has(String(value ?? "").trim().toLowerCase());
}

export const P013_UPLOAD_POLICY = Object.freeze({
  allowedImageMimeTypes: ALLOWED_IMAGE_MIME_TYPES,
  maxContentBytes: MAX_CONTENT_BYTES,
  sha256Format: "lowercase-hex-64",
  objectKeyPolicy: "p013-object-key-v1",
});
