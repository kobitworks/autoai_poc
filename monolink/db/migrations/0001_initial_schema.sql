PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  user_id TEXT PRIMARY KEY,
  auth_subject TEXT NOT NULL UNIQUE,
  display_alias TEXT,
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DELETED')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE TABLE IF NOT EXISTS organizations (
  organization_id TEXT PRIMARY KEY,
  organization_name TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'SUSPENDED', 'CLOSED')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS organization_members (
  organization_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('ADMIN', 'STAFF')),
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'SUSPENDED', 'REMOVED')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (organization_id, user_id),
  FOREIGN KEY (organization_id) REFERENCES organizations(organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS facilities (
  facility_id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL,
  public_name TEXT NOT NULL,
  public_address_text TEXT,
  pickup_instructions TEXT,
  opening_hours_text TEXT,
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'SUSPENDED', 'CLOSED')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (organization_id) REFERENCES organizations(organization_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS items (
  item_id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  category TEXT,
  private_note TEXT,
  public_message TEXT,
  item_status TEXT NOT NULL CHECK (item_status IN ('NORMAL', 'LOST', 'FOUND_CONTACT', 'RETURNING', 'CUSTODY', 'RETURNED', 'ARCHIVED')),
  current_manager_user_id TEXT NOT NULL,
  contact_route_user_id TEXT NOT NULL,
  public_view_mode TEXT NOT NULL CHECK (public_view_mode IN ('NORMAL', 'LOST', 'CUSTODY', 'UNAVAILABLE')),
  state_version INTEGER NOT NULL DEFAULT 1 CHECK (state_version >= 1),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (current_manager_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (contact_route_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS qr_codes (
  qr_id TEXT PRIMARY KEY,
  item_id TEXT,
  public_token_hash TEXT NOT NULL UNIQUE,
  sticker_code TEXT UNIQUE,
  status TEXT NOT NULL CHECK (status IN ('UNREGISTERED', 'ACTIVE', 'SUSPENDED', 'REPLACED', 'REVOKED')),
  replacement_qr_id TEXT,
  activated_at TEXT,
  replaced_at TEXT,
  revoked_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  CHECK ((status = 'UNREGISTERED' AND item_id IS NULL) OR (status <> 'UNREGISTERED' AND item_id IS NOT NULL)),
  FOREIGN KEY (item_id) REFERENCES items(item_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (replacement_qr_id) REFERENCES qr_codes(qr_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS ownerships (
  ownership_id TEXT PRIMARY KEY,
  item_id TEXT NOT NULL,
  manager_user_id TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('PRIMARY_MANAGER', 'CO_MANAGER')),
  valid_from TEXT NOT NULL,
  valid_to TEXT,
  ended_reason TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (item_id) REFERENCES items(item_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (manager_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS lost_cases (
  lost_case_id TEXT PRIMARY KEY,
  item_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('OPEN', 'FOUND_CONTACT', 'RETURNING', 'RESOLVED', 'CANCELLED')),
  lost_since TEXT NOT NULL,
  public_message TEXT,
  reward_offered INTEGER NOT NULL DEFAULT 0 CHECK (reward_offered IN (0, 1)),
  created_by_user_id TEXT NOT NULL,
  resolved_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (item_id) REFERENCES items(item_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (created_by_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS finder_sessions (
  finder_session_id TEXT PRIMARY KEY,
  session_token_hash TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'CLOSED', 'BLOCKED', 'EXPIRED')),
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL,
  closed_at TEXT
);

CREATE TABLE IF NOT EXISTS found_reports (
  found_report_id TEXT PRIMARY KEY,
  item_id TEXT NOT NULL,
  qr_id TEXT NOT NULL,
  lost_case_id TEXT,
  finder_session_id TEXT NOT NULL,
  facility_id TEXT,
  situation TEXT NOT NULL CHECK (situation IN ('IN_HAND', 'DELIVERED', 'LOCATION_ONLY')),
  status TEXT NOT NULL CHECK (status IN ('OPEN', 'OWNER_REPLIED', 'RETURNING', 'CLOSED', 'SPAM')),
  location_text TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  closed_at TEXT,
  FOREIGN KEY (item_id) REFERENCES items(item_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (qr_id) REFERENCES qr_codes(qr_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (lost_case_id) REFERENCES lost_cases(lost_case_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (finder_session_id) REFERENCES finder_sessions(finder_session_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (facility_id) REFERENCES facilities(facility_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS messages (
  message_id TEXT PRIMARY KEY,
  found_report_id TEXT NOT NULL,
  sender_type TEXT NOT NULL CHECK (sender_type IN ('OWNER', 'FINDER', 'FACILITY', 'SYSTEM')),
  sender_user_id TEXT,
  sender_finder_session_id TEXT,
  body TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('VISIBLE', 'REDACTED', 'DELETED')),
  created_at TEXT NOT NULL,
  expires_at TEXT,
  redacted_at TEXT,
  CHECK (
    (sender_type IN ('OWNER', 'FACILITY') AND sender_user_id IS NOT NULL)
    OR (sender_type = 'FINDER' AND sender_finder_session_id IS NOT NULL)
    OR sender_type = 'SYSTEM'
  ),
  FOREIGN KEY (found_report_id) REFERENCES found_reports(found_report_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (sender_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (sender_finder_session_id) REFERENCES finder_sessions(finder_session_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS custody_records (
  custody_id TEXT PRIMARY KEY,
  item_id TEXT NOT NULL,
  qr_id TEXT NOT NULL,
  facility_id TEXT NOT NULL,
  found_report_id TEXT,
  status TEXT NOT NULL CHECK (status IN ('RECEIVED', 'OWNER_NOTIFIED', 'PICKUP_PLANNED', 'TRANSFERRED', 'HANDED_OVER', 'CLOSED', 'CANCELLED')),
  category_snapshot TEXT,
  internal_location TEXT,
  receipt_no TEXT NOT NULL,
  pickup_method TEXT,
  legal_process_status TEXT NOT NULL DEFAULT 'NOT_RECORDED' CHECK (legal_process_status IN ('NOT_RECORDED', 'PLANNED', 'SUBMITTED_TO_POLICE', 'RETURNED_AT_FACILITY', 'NOT_APPLICABLE')),
  expires_at TEXT,
  transferred_to_facility_id TEXT,
  transferred_at TEXT,
  received_at TEXT NOT NULL,
  handed_over_at TEXT,
  closed_at TEXT,
  created_by_user_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE (facility_id, receipt_no),
  FOREIGN KEY (item_id) REFERENCES items(item_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (qr_id) REFERENCES qr_codes(qr_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (facility_id) REFERENCES facilities(facility_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (found_report_id) REFERENCES found_reports(found_report_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (transferred_to_facility_id) REFERENCES facilities(facility_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (created_by_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS transfers (
  transfer_id TEXT PRIMARY KEY,
  item_id TEXT NOT NULL,
  from_user_id TEXT NOT NULL,
  to_user_id TEXT,
  status TEXT NOT NULL CHECK (status IN ('DRAFT', 'OFFERED', 'COMPLETED', 'CANCELLED', 'EXPIRED')),
  claim_token_hash TEXT UNIQUE,
  created_state_version INTEGER NOT NULL CHECK (created_state_version >= 1),
  expires_at TEXT,
  completed_at TEXT,
  cancelled_at TEXT,
  created_by_user_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (item_id) REFERENCES items(item_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (from_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (to_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (created_by_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS notifications (
  notification_id TEXT PRIMARY KEY,
  recipient_user_id TEXT NOT NULL,
  notification_type TEXT NOT NULL,
  reference_type TEXT NOT NULL,
  reference_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('UNREAD', 'READ')),
  created_at TEXT NOT NULL,
  read_at TEXT,
  FOREIGN KEY (recipient_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS item_events (
  event_id TEXT PRIMARY KEY,
  item_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  actor_type TEXT NOT NULL CHECK (actor_type IN ('USER', 'FINDER', 'FACILITY', 'SYSTEM')),
  actor_ref TEXT,
  prior_status TEXT,
  new_status TEXT,
  state_version INTEGER NOT NULL CHECK (state_version >= 1),
  request_id TEXT,
  detail_json TEXT,
  occurred_at TEXT NOT NULL,
  FOREIGN KEY (item_id) REFERENCES items(item_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_org_members_user_status ON organization_members(user_id, status);
CREATE INDEX IF NOT EXISTS idx_facilities_org_status ON facilities(organization_id, status);
CREATE INDEX IF NOT EXISTS idx_items_manager_status ON items(current_manager_user_id, item_status);
CREATE INDEX IF NOT EXISTS idx_items_contact_route ON items(contact_route_user_id);
CREATE INDEX IF NOT EXISTS idx_qr_codes_item_status ON qr_codes(item_id, status);
CREATE INDEX IF NOT EXISTS idx_ownerships_item_valid_to ON ownerships(item_id, valid_to);
CREATE INDEX IF NOT EXISTS idx_ownerships_user_valid_to ON ownerships(manager_user_id, valid_to);
CREATE UNIQUE INDEX IF NOT EXISTS uq_ownerships_active_primary ON ownerships(item_id) WHERE role = 'PRIMARY_MANAGER' AND valid_to IS NULL;
CREATE INDEX IF NOT EXISTS idx_lost_cases_item_status ON lost_cases(item_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS uq_lost_cases_active ON lost_cases(item_id) WHERE status IN ('OPEN', 'FOUND_CONTACT', 'RETURNING');
CREATE INDEX IF NOT EXISTS idx_finder_sessions_status_expiry ON finder_sessions(status, expires_at);
CREATE INDEX IF NOT EXISTS idx_found_reports_item_status ON found_reports(item_id, status);
CREATE INDEX IF NOT EXISTS idx_found_reports_lost_case ON found_reports(lost_case_id, created_at);
CREATE INDEX IF NOT EXISTS idx_found_reports_session ON found_reports(finder_session_id, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_report_created ON messages(found_report_id, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_expiry ON messages(expires_at);
CREATE INDEX IF NOT EXISTS idx_custody_item_status ON custody_records(item_id, status);
CREATE INDEX IF NOT EXISTS idx_custody_facility_status ON custody_records(facility_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS uq_custody_active_item ON custody_records(item_id) WHERE status IN ('RECEIVED', 'OWNER_NOTIFIED', 'PICKUP_PLANNED');
CREATE INDEX IF NOT EXISTS idx_transfers_item_status ON transfers(item_id, status);
CREATE INDEX IF NOT EXISTS idx_transfers_expiry ON transfers(status, expires_at);
CREATE UNIQUE INDEX IF NOT EXISTS uq_transfers_active_item ON transfers(item_id) WHERE status IN ('DRAFT', 'OFFERED');
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_status_created ON notifications(recipient_user_id, status, created_at);
CREATE INDEX IF NOT EXISTS idx_item_events_item_occurred ON item_events(item_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_item_events_request_id ON item_events(request_id);
