const SEGMENT_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/;
const CONTROL_RE = /[\u0000-\u001F\u007F]/;
const UNSAFE_FILENAME_RE = /[<>:"/\\|?*#%]/g;
const MAX_FILENAME_BYTES = 120;

function assertSegment(value, label) {
  const s = String(value ?? "").trim();
  if (!SEGMENT_RE.test(s) || s === "." || s === ".." || s.includes("..")) {
    throw new TypeError(`${label} is invalid`);
  }
  return s;
}

function pad2(n) {
  return String(n).padStart(2, "0");
}

function normalizeDate(value) {
  const d = value instanceof Date ? new Date(value.getTime()) : new Date(String(value ?? ""));
  if (!Number.isFinite(d.getTime())) throw new TypeError("capturedAt is invalid");
  return {
    yyyy: String(d.getUTCFullYear()).padStart(4, "0"),
    mm: pad2(d.getUTCMonth() + 1),
  };
}

function utf8Length(value) {
  return new TextEncoder().encode(value).length;
}

function truncateUtf8(value, maxBytes) {
  let out = "";
  for (const ch of Array.from(value)) {
    if (utf8Length(out + ch) > maxBytes) break;
    out += ch;
  }
  return out;
}

export function safeFilename(filename) {
  let s = String(filename ?? "").normalize("NFKC").trim();
  if (!s || s === "." || s === "..") throw new TypeError("filename is empty");
  if (CONTROL_RE.test(s)) throw new TypeError("filename contains control characters");
  if (/[\\/]/.test(s)) throw new TypeError("filename must not contain a path");
  s = s.replace(/\s+/g, "_").replace(UNSAFE_FILENAME_RE, "_");
  s = s.replace(/_+/g, "_").replace(/^[._ -]+|[._ -]+$/g, "");
  if (!s) throw new TypeError("filename has no safe characters");

  if (utf8Length(s) <= MAX_FILENAME_BYTES) return s;

  const dot = s.lastIndexOf(".");
  const ext = dot > 0 && dot < s.length - 1 ? s.slice(dot) : "";
  const base = ext ? s.slice(0, dot) : s;
  const extBytes = utf8Length(ext);
  const budget = Math.max(1, MAX_FILENAME_BYTES - extBytes);
  const truncated = truncateUtf8(base, budget).replace(/[._ -]+$/g, "");
  if (!truncated) throw new TypeError("filename cannot be safely truncated");
  const result = truncated + ext;
  if (utf8Length(result) > MAX_FILENAME_BYTES) {
    throw new TypeError("filename extension is too long");
  }
  return result;
}

export function buildOriginalObjectKey({ capturedAt, imageId, objectId, filename }) {
  const { yyyy, mm } = normalizeDate(capturedAt);
  const image = assertSegment(imageId, "imageId");
  const object = assertSegment(objectId, "objectId");
  const safe = safeFilename(filename);
  return `original/${yyyy}/${mm}/product-image/${image}/${object}-${safe}`;
}

export function validateOriginalObjectKey(key) {
  const s = String(key ?? "");
  const parts = s.split("/");
  if (parts.length !== 6) return false;
  const [root, yyyy, mm, entity, imageId, leaf] = parts;
  if (root !== "original" || entity !== "product-image") return false;
  if (!/^\d{4}$/.test(yyyy) || !/^(0[1-9]|1[0-2])$/.test(mm)) return false;
  try {
    assertSegment(imageId, "imageId");
  } catch {
    return false;
  }
  const dash = leaf.indexOf("-");
  if (dash < 1) return false;
  const objectId = leaf.slice(0, dash);
  const filename = leaf.slice(dash + 1);
  try {
    assertSegment(objectId, "objectId");
    return safeFilename(filename) === filename;
  } catch {
    return false;
  }
}

export const P013_OBJECT_KEY_POLICY = Object.freeze({
  prefix: "original",
  entityType: "product-image",
  maxFilenameBytes: MAX_FILENAME_BYTES,
});
