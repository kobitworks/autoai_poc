PRAGMA foreign_keys = ON;

-- P013 QR商品出品支援
-- Initial schema v1.
-- Cloudflare D1 is production-only per P016. R2 uses staging/production buckets.
-- Binary photo bytes are never stored in D1.

CREATE TABLE IF NOT EXISTS upload_batches (
  batch_id TEXT PRIMARY KEY,
  data_scope TEXT NOT NULL DEFAULT 'staging'
    CHECK (data_scope IN ('staging', 'production')),
  status TEXT NOT NULL DEFAULT 'UPLOADING'
    CHECK (status IN ('UPLOADING', 'READY_FOR_SCAN', 'SCANNED', 'PARTIAL', 'COMPLETED', 'CANCELLED')),
  source_type TEXT NOT NULL DEFAULT 'WEB_UPLOAD'
    CHECK (source_type IN ('WEB_UPLOAD', 'IMPORT')),
  image_count INTEGER NOT NULL DEFAULT 0 CHECK (image_count >= 0),
  created_by TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  completed_at TEXT
);

CREATE TABLE IF NOT EXISTS management_qr_codes (
  qr_code TEXT PRIMARY KEY,
  status TEXT NOT NULL DEFAULT 'AVAILABLE'
    CHECK (status IN ('AVAILABLE', 'DISCOVERED', 'VOID', 'RETIRED')),
  issued_sequence INTEGER,
  issued_at TEXT,
  issued_by TEXT,
  note TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  CHECK (
    length(qr_code) = 20
    AND substr(qr_code, 1, 4) = 'QPMS'
    AND substr(qr_code, 5) NOT GLOB '*[^0-9]*'
  )
);

CREATE TABLE IF NOT EXISTS products (
  product_id TEXT PRIMARY KEY,
  primary_qr_code TEXT NOT NULL UNIQUE,
  data_scope TEXT NOT NULL DEFAULT 'staging'
    CHECK (data_scope IN ('staging', 'production')),
  status TEXT NOT NULL DEFAULT 'PHOTO_GROUPED'
    CHECK (status IN (
      'PHOTO_GROUPED',
      'AI_PENDING',
      'AI_RUNNING',
      'AI_REVIEW',
      'CONFIRMED',
      'LISTING_READY',
      'EXPORTED',
      'ARCHIVED'
    )),
  state_version INTEGER NOT NULL DEFAULT 1 CHECK (state_version >= 1),
  created_by TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  archived_at TEXT,
  FOREIGN KEY (primary_qr_code) REFERENCES management_qr_codes(qr_code)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

-- P016 R2 object metadata baseline.
CREATE TABLE IF NOT EXISTS storage_objects (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  object_id TEXT NOT NULL UNIQUE,
  environment TEXT NOT NULL CHECK (environment IN ('staging', 'production')),
  bucket_name TEXT NOT NULL,
  object_key TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  media_role TEXT NOT NULL,
  original_filename TEXT,
  content_type TEXT NOT NULL,
  size_bytes INTEGER CHECK (size_bytes IS NULL OR size_bytes >= 0),
  etag TEXT,
  sha256 TEXT,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('pending', 'active', 'quarantined', 'delete_pending', 'deleted', 'failed')),
  created_by TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  UNIQUE (environment, bucket_name, object_key),
  CHECK (object_key <> '' AND substr(object_key, 1, 1) <> '/')
);

CREATE TABLE IF NOT EXISTS storage_object_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  request_id TEXT NOT NULL,
  object_id TEXT,
  environment TEXT NOT NULL CHECK (environment IN ('staging', 'production')),
  action TEXT NOT NULL
    CHECK (action IN (
      'upload_authorized',
      'upload_completed',
      'download_authorized',
      'download_completed',
      'delete_requested',
      'delete_completed',
      'quarantined',
      'metadata_changed',
      'access_denied'
    )),
  actor_subject TEXT NOT NULL,
  decision TEXT NOT NULL CHECK (decision IN ('allow', 'deny', 'result')),
  http_status INTEGER,
  bytes_transferred INTEGER CHECK (bytes_transferred IS NULL OR bytes_transferred >= 0),
  detail_json TEXT,
  occurred_at TEXT NOT NULL,
  FOREIGN KEY (object_id) REFERENCES storage_objects(object_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS product_images (
  image_id TEXT PRIMARY KEY,
  batch_id TEXT NOT NULL,
  product_id TEXT,
  storage_object_id TEXT NOT NULL UNIQUE,
  original_filename TEXT,
  width_px INTEGER CHECK (width_px IS NULL OR width_px > 0),
  height_px INTEGER CHECK (height_px IS NULL OR height_px > 0),
  qr_status TEXT NOT NULL DEFAULT 'UNSCANNED'
    CHECK (qr_status IN ('UNSCANNED', 'UNRESOLVED', 'MULTIPLE', 'INVALID', 'ASSIGNED')),
  qr_decision_source TEXT NOT NULL DEFAULT 'NONE'
    CHECK (qr_decision_source IN ('NONE', 'AUTO', 'MANUAL')),
  selected_qr_code TEXT,
  scan_engine TEXT,
  qr_raw_json TEXT,
  note TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (batch_id) REFERENCES upload_batches(batch_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (storage_object_id) REFERENCES storage_objects(object_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (selected_qr_code) REFERENCES management_qr_codes(qr_code)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CHECK (
    qr_status <> 'ASSIGNED'
    OR (product_id IS NOT NULL AND selected_qr_code IS NOT NULL AND qr_decision_source IN ('AUTO', 'MANUAL'))
  )
);

CREATE TABLE IF NOT EXISTS image_qr_candidates (
  candidate_id TEXT PRIMARY KEY,
  image_id TEXT NOT NULL,
  candidate_rank INTEGER NOT NULL CHECK (candidate_rank >= 1),
  raw_value TEXT,
  normalized_qr_code TEXT,
  confidence REAL CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
  detected_by TEXT,
  is_selected INTEGER NOT NULL DEFAULT 0 CHECK (is_selected IN (0, 1)),
  created_at TEXT NOT NULL,
  FOREIGN KEY (image_id) REFERENCES product_images(image_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  UNIQUE (image_id, candidate_rank)
);

CREATE TABLE IF NOT EXISTS product_state_events (
  event_id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL,
  from_status TEXT,
  to_status TEXT NOT NULL,
  reason TEXT,
  actor_subject TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS ai_analysis_runs (
  analysis_id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL,
  product_state_version INTEGER NOT NULL CHECK (product_state_version >= 1),
  status TEXT NOT NULL DEFAULT 'REQUESTED'
    CHECK (status IN ('REQUESTED', 'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED')),
  prompt_version TEXT NOT NULL,
  model_ref TEXT,
  input_snapshot_json TEXT NOT NULL,
  result_json TEXT,
  error_code TEXT,
  requested_by TEXT NOT NULL,
  requested_at TEXT NOT NULL,
  started_at TEXT,
  completed_at TEXT,
  FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS ai_field_candidates (
  candidate_id TEXT PRIMARY KEY,
  analysis_id TEXT NOT NULL,
  field_name TEXT NOT NULL,
  candidate_rank INTEGER NOT NULL DEFAULT 1 CHECK (candidate_rank >= 1),
  value_text TEXT,
  value_json TEXT,
  confidence REAL CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
  evidence_json TEXT,
  review_status TEXT NOT NULL DEFAULT 'PROPOSED'
    CHECK (review_status IN ('PROPOSED', 'ACCEPTED', 'REJECTED')),
  created_at TEXT NOT NULL,
  reviewed_by TEXT,
  reviewed_at TEXT,
  FOREIGN KEY (analysis_id) REFERENCES ai_analysis_runs(analysis_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  UNIQUE (analysis_id, field_name, candidate_rank)
);

CREATE TABLE IF NOT EXISTS product_field_values (
  product_id TEXT NOT NULL,
  field_name TEXT NOT NULL,
  value_text TEXT,
  value_json TEXT,
  source_type TEXT NOT NULL
    CHECK (source_type IN ('MANUAL', 'AI_ACCEPTED', 'IMPORT')),
  source_analysis_id TEXT,
  source_candidate_id TEXT,
  confirmed_by TEXT NOT NULL,
  confirmed_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (product_id, field_name),
  FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (source_analysis_id) REFERENCES ai_analysis_runs(analysis_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (source_candidate_id) REFERENCES ai_field_candidates(candidate_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS listing_drafts (
  listing_id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL,
  channel TEXT NOT NULL,
  schema_version TEXT NOT NULL DEFAULT '1',
  status TEXT NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT', 'READY', 'EXPORTED', 'VOID')),
  generated_from_state_version INTEGER NOT NULL CHECK (generated_from_state_version >= 1),
  payload_json TEXT NOT NULL,
  external_reference TEXT,
  created_by TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  exported_at TEXT,
  FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_upload_batches_scope_status
  ON upload_batches(data_scope, status, created_at);

CREATE INDEX IF NOT EXISTS idx_management_qr_status
  ON management_qr_codes(status, created_at);

CREATE INDEX IF NOT EXISTS idx_products_scope_status
  ON products(data_scope, status, updated_at);

CREATE INDEX IF NOT EXISTS idx_product_images_batch
  ON product_images(batch_id, qr_status, created_at);

CREATE INDEX IF NOT EXISTS idx_product_images_product
  ON product_images(product_id, created_at);

CREATE INDEX IF NOT EXISTS idx_product_images_qr
  ON product_images(selected_qr_code, qr_status);

CREATE INDEX IF NOT EXISTS idx_image_qr_candidates_image
  ON image_qr_candidates(image_id, candidate_rank);

CREATE INDEX IF NOT EXISTS idx_product_state_events_product
  ON product_state_events(product_id, occurred_at);

CREATE INDEX IF NOT EXISTS idx_ai_analysis_product
  ON ai_analysis_runs(product_id, status, requested_at);

CREATE INDEX IF NOT EXISTS idx_ai_field_candidates_analysis
  ON ai_field_candidates(analysis_id, field_name, candidate_rank);

CREATE INDEX IF NOT EXISTS idx_ai_field_candidates_review
  ON ai_field_candidates(review_status, created_at);

CREATE INDEX IF NOT EXISTS idx_product_field_values_product
  ON product_field_values(product_id, field_name);

CREATE INDEX IF NOT EXISTS idx_listing_drafts_product_channel
  ON listing_drafts(product_id, channel, status, updated_at);

CREATE INDEX IF NOT EXISTS idx_storage_objects_entity
  ON storage_objects(environment, entity_type, entity_id, media_role, status);

CREATE INDEX IF NOT EXISTS idx_storage_objects_status
  ON storage_objects(environment, status, updated_at);

CREATE INDEX IF NOT EXISTS idx_storage_object_events_object
  ON storage_object_events(object_id, occurred_at);

CREATE INDEX IF NOT EXISTS idx_storage_object_events_request
  ON storage_object_events(request_id, occurred_at);
