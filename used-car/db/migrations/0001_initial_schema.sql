PRAGMA foreign_keys = ON;

-- P014 Used-car sales and maintenance management.
-- Schema v1. Business data lives in one production D1 per P016.
-- R2 object bytes live in staging/production buckets; D1 keeps metadata only.

CREATE TABLE IF NOT EXISTS staff_members (
  staff_id TEXT PRIMARY KEY,
  auth_subject TEXT UNIQUE,
  display_name TEXT NOT NULL,
  role TEXT,
  status TEXT NOT NULL DEFAULT 'ACTIVE'
    CHECK (status IN ('ACTIVE', 'INACTIVE', 'DELETED')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE TABLE IF NOT EXISTS customers (
  customer_id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  name_kana TEXT,
  phone TEXT,
  email TEXT,
  postal_code TEXT,
  prefecture TEXT,
  city TEXT,
  address_line1 TEXT,
  address_line2 TEXT,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'ACTIVE'
    CHECK (status IN ('ACTIVE', 'INACTIVE', 'DELETED')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE TABLE IF NOT EXISTS vehicles (
  vehicle_id TEXT PRIMARY KEY,
  manufacturer TEXT NOT NULL,
  model_name TEXT NOT NULL,
  grade TEXT,
  model_code TEXT,
  model_year INTEGER CHECK (model_year IS NULL OR (model_year >= 1900 AND model_year <= 2100)),
  registration_number TEXT,
  registration_number_normalized TEXT,
  chassis_number TEXT NOT NULL UNIQUE,
  color TEXT,
  first_registration_on TEXT,
  current_odometer_km INTEGER
    CHECK (current_odometer_km IS NULL OR current_odometer_km >= 0),
  status TEXT NOT NULL DEFAULT 'ACTIVE'
    CHECK (status IN ('ACTIVE', 'SOLD', 'TRADED_IN', 'DISPOSED', 'ARCHIVED')),
  state_version INTEGER NOT NULL DEFAULT 1 CHECK (state_version >= 1),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sales (
  sale_id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  customer_id TEXT NOT NULL,
  salesperson_staff_id TEXT,
  contract_no TEXT UNIQUE,
  sold_on TEXT NOT NULL,
  delivered_at TEXT,
  sale_price_yen INTEGER CHECK (sale_price_yen IS NULL OR sale_price_yen >= 0),
  warranty_until TEXT,
  status TEXT NOT NULL DEFAULT 'CONTRACTED'
    CHECK (status IN ('QUOTE', 'CONTRACTED', 'DELIVERED', 'CANCELLED')),
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (salesperson_staff_id) REFERENCES staff_members(staff_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS vehicle_ownerships (
  ownership_id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  customer_id TEXT NOT NULL,
  source_sale_id TEXT,
  valid_from TEXT NOT NULL,
  valid_to TEXT,
  ended_reason TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (source_sale_id) REFERENCES sales(sale_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

CREATE TABLE IF NOT EXISTS inspections (
  inspection_id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  customer_id TEXT,
  inspection_type TEXT NOT NULL
    CHECK (inspection_type IN ('SHAKEN', 'LEGAL_12M', 'LEGAL_6M', 'OTHER')),
  status TEXT NOT NULL DEFAULT 'PLANNED'
    CHECK (status IN ('PLANNED', 'CONTACTED', 'BOOKED', 'COMPLETED', 'CANCELLED')),
  contact_status TEXT NOT NULL DEFAULT 'NOT_CONTACTED'
    CHECK (contact_status IN ('NOT_CONTACTED', 'CONTACTED', 'BOOKED', 'DECLINED', 'NOT_REQUIRED')),
  due_on TEXT,
  scheduled_on TEXT,
  performed_on TEXT,
  result TEXT,
  odometer_km INTEGER CHECK (odometer_km IS NULL OR odometer_km >= 0),
  amount_yen INTEGER CHECK (amount_yen IS NULL OR amount_yen >= 0),
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS maintenance_records (
  maintenance_id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  customer_id TEXT,
  staff_id TEXT,
  performed_on TEXT NOT NULL,
  record_type TEXT NOT NULL
    CHECK (record_type IN ('MAINTENANCE', 'REPAIR', 'PARTS_REPLACEMENT', 'OTHER')),
  title TEXT NOT NULL,
  work_description TEXT,
  odometer_km INTEGER CHECK (odometer_km IS NULL OR odometer_km >= 0),
  amount_yen INTEGER CHECK (amount_yen IS NULL OR amount_yen >= 0),
  status TEXT NOT NULL DEFAULT 'COMPLETED'
    CHECK (status IN ('DRAFT', 'COMPLETED', 'VOID')),
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (staff_id) REFERENCES staff_members(staff_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS maintenance_parts (
  maintenance_part_id TEXT PRIMARY KEY,
  maintenance_id TEXT NOT NULL,
  part_name TEXT NOT NULL,
  part_number TEXT,
  quantity REAL NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_price_yen INTEGER CHECK (unit_price_yen IS NULL OR unit_price_yen >= 0),
  notes TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (maintenance_id) REFERENCES maintenance_records(maintenance_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS vehicle_odometer_readings (
  reading_id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  source_type TEXT NOT NULL
    CHECK (source_type IN ('MANUAL', 'SALE', 'INSPECTION', 'MAINTENANCE', 'IMPORT')),
  source_id TEXT,
  recorded_on TEXT NOT NULL,
  odometer_km INTEGER NOT NULL CHECK (odometer_km >= 0),
  created_at TEXT NOT NULL,
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

-- P016 R2 metadata baseline.
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

CREATE TABLE IF NOT EXISTS vehicle_documents (
  document_id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  customer_id TEXT,
  inspection_id TEXT,
  maintenance_id TEXT,
  storage_object_id TEXT NOT NULL UNIQUE,
  document_type TEXT NOT NULL
    CHECK (document_type IN (
      'VEHICLE_REGISTRATION',
      'VEHICLE_PHOTO',
      'INSPECTION_RECORD',
      'REPAIR_RECORD',
      'SALES_CONTRACT',
      'OTHER'
    )),
  title TEXT,
  document_date TEXT,
  classification_status TEXT NOT NULL DEFAULT 'MANUAL'
    CHECK (classification_status IN ('MANUAL', 'PENDING_AI', 'AI_CANDIDATE', 'CONFIRMED', 'REJECTED')),
  is_primary INTEGER NOT NULL DEFAULT 0 CHECK (is_primary IN (0, 1)),
  status TEXT NOT NULL DEFAULT 'ACTIVE'
    CHECK (status IN ('ACTIVE', 'ARCHIVED', 'DELETED')),
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (inspection_id) REFERENCES inspections(inspection_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (maintenance_id) REFERENCES maintenance_records(maintenance_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (storage_object_id) REFERENCES storage_objects(object_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_staff_members_status
  ON staff_members(status);

CREATE INDEX IF NOT EXISTS idx_customers_name
  ON customers(display_name, name_kana);

CREATE INDEX IF NOT EXISTS idx_customers_phone
  ON customers(phone);

CREATE INDEX IF NOT EXISTS idx_customers_email
  ON customers(email);

CREATE INDEX IF NOT EXISTS idx_customers_status
  ON customers(status);

CREATE INDEX IF NOT EXISTS idx_vehicles_registration
  ON vehicles(registration_number_normalized);

CREATE INDEX IF NOT EXISTS idx_vehicles_model
  ON vehicles(manufacturer, model_name, model_year);

CREATE INDEX IF NOT EXISTS idx_vehicles_status
  ON vehicles(status);

CREATE INDEX IF NOT EXISTS idx_sales_customer_date
  ON sales(customer_id, sold_on);

CREATE INDEX IF NOT EXISTS idx_sales_vehicle_date
  ON sales(vehicle_id, sold_on);

CREATE UNIQUE INDEX IF NOT EXISTS uq_vehicle_ownership_active
  ON vehicle_ownerships(vehicle_id)
  WHERE valid_to IS NULL;

CREATE INDEX IF NOT EXISTS idx_vehicle_ownership_customer
  ON vehicle_ownerships(customer_id, valid_to);

CREATE INDEX IF NOT EXISTS idx_inspections_due_status
  ON inspections(due_on, status);

CREATE INDEX IF NOT EXISTS idx_inspections_vehicle_due
  ON inspections(vehicle_id, due_on);

CREATE INDEX IF NOT EXISTS idx_inspections_customer_due
  ON inspections(customer_id, due_on);

CREATE INDEX IF NOT EXISTS idx_maintenance_vehicle_date
  ON maintenance_records(vehicle_id, performed_on);

CREATE INDEX IF NOT EXISTS idx_maintenance_customer_date
  ON maintenance_records(customer_id, performed_on);

CREATE INDEX IF NOT EXISTS idx_maintenance_type_date
  ON maintenance_records(record_type, performed_on);

CREATE INDEX IF NOT EXISTS idx_maintenance_parts_record
  ON maintenance_parts(maintenance_id);

CREATE INDEX IF NOT EXISTS idx_odometer_vehicle_date
  ON vehicle_odometer_readings(vehicle_id, recorded_on);

CREATE INDEX IF NOT EXISTS idx_storage_objects_entity
  ON storage_objects(environment, entity_type, entity_id, media_role, status);

CREATE INDEX IF NOT EXISTS idx_storage_objects_status
  ON storage_objects(environment, status, updated_at);

CREATE INDEX IF NOT EXISTS idx_storage_object_events_object
  ON storage_object_events(object_id, occurred_at);

CREATE INDEX IF NOT EXISTS idx_storage_object_events_request
  ON storage_object_events(request_id, occurred_at);

CREATE INDEX IF NOT EXISTS idx_vehicle_documents_vehicle
  ON vehicle_documents(vehicle_id, document_type, status);

CREATE INDEX IF NOT EXISTS idx_vehicle_documents_inspection
  ON vehicle_documents(inspection_id, status);

CREATE INDEX IF NOT EXISTS idx_vehicle_documents_maintenance
  ON vehicle_documents(maintenance_id, status);
