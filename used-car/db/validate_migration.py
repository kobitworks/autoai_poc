#!/usr/bin/env python3
from __future__ import annotations

import json
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MIGRATION = ROOT / "migrations" / "0001_initial_schema.sql"

EXPECTED_TABLES = {
    "staff_members",
    "customers",
    "vehicles",
    "sales",
    "vehicle_ownerships",
    "inspections",
    "maintenance_records",
    "maintenance_parts",
    "vehicle_odometer_readings",
    "storage_objects",
    "storage_object_events",
    "vehicle_documents",
}

EXPECTED_INDEXES = {
    "idx_staff_members_status",
    "idx_customers_name",
    "idx_customers_phone",
    "idx_customers_email",
    "idx_customers_status",
    "idx_vehicles_registration",
    "idx_vehicles_model",
    "idx_vehicles_status",
    "idx_sales_customer_date",
    "idx_sales_vehicle_date",
    "uq_vehicle_ownership_active",
    "idx_vehicle_ownership_customer",
    "idx_inspections_due_status",
    "idx_inspections_vehicle_due",
    "idx_inspections_customer_due",
    "idx_maintenance_vehicle_date",
    "idx_maintenance_customer_date",
    "idx_maintenance_type_date",
    "idx_maintenance_parts_record",
    "idx_odometer_vehicle_date",
    "idx_storage_objects_entity",
    "idx_storage_objects_status",
    "idx_storage_object_events_object",
    "idx_storage_object_events_request",
    "idx_vehicle_documents_vehicle",
    "idx_vehicle_documents_inspection",
    "idx_vehicle_documents_maintenance",
}


def require_integrity_error(fn, label: str) -> None:
    try:
        fn()
    except sqlite3.IntegrityError:
        return
    raise AssertionError(f"{label}: expected sqlite3.IntegrityError")


def main() -> int:
    sql = MIGRATION.read_text(encoding="utf-8")
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.executescript(sql)

    tables = {
        row["name"]
        for row in conn.execute(
            "SELECT name FROM sqlite_master "
            "WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        )
    }
    if tables != EXPECTED_TABLES:
        raise AssertionError(
            f"table mismatch: missing={sorted(EXPECTED_TABLES - tables)} "
            f"extra={sorted(tables - EXPECTED_TABLES)}"
        )

    indexes = {
        row["name"]
        for row in conn.execute(
            "SELECT name FROM sqlite_master "
            "WHERE type='index' AND sql IS NOT NULL"
        )
    }
    if indexes != EXPECTED_INDEXES:
        raise AssertionError(
            f"index mismatch: missing={sorted(EXPECTED_INDEXES - indexes)} "
            f"extra={sorted(indexes - EXPECTED_INDEXES)}"
        )

    fk_before = list(conn.execute("PRAGMA foreign_key_check"))
    if fk_before:
        raise AssertionError(f"foreign_key_check failed after migration: {fk_before}")

    now = "2026-09-29T02:00:00Z"

    conn.execute(
        "INSERT INTO staff_members "
        "(staff_id, display_name, role, status, created_at, updated_at) "
        "VALUES (?, ?, ?, 'ACTIVE', ?, ?)",
        ("STF-001", "PoC担当", "SALES", now, now),
    )
    conn.execute(
        "INSERT INTO customers "
        "(customer_id, display_name, name_kana, phone, status, created_at, updated_at) "
        "VALUES (?, ?, ?, ?, 'ACTIVE', ?, ?)",
        ("CUS-001", "テスト顧客", "テストコキャク", "000-0000-0000", now, now),
    )
    conn.execute(
        "INSERT INTO vehicles "
        "(vehicle_id, manufacturer, model_name, model_year, registration_number, "
        "registration_number_normalized, chassis_number, current_odometer_km, "
        "status, state_version, created_at, updated_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'ACTIVE', 1, ?, ?)",
        (
            "VEH-001",
            "Test Motors",
            "Sample",
            2024,
            "品川 300 あ 12-34",
            "品川300あ1234",
            "CHASSIS-001",
            12000,
            now,
            now,
        ),
    )
    conn.execute(
        "INSERT INTO sales "
        "(sale_id, vehicle_id, customer_id, salesperson_staff_id, contract_no, "
        "sold_on, sale_price_yen, status, created_at, updated_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, 'DELIVERED', ?, ?)",
        (
            "SALE-001",
            "VEH-001",
            "CUS-001",
            "STF-001",
            "CN-001",
            "2026-09-01",
            1500000,
            now,
            now,
        ),
    )
    conn.execute(
        "INSERT INTO vehicle_ownerships "
        "(ownership_id, vehicle_id, customer_id, source_sale_id, valid_from, created_at) "
        "VALUES (?, ?, ?, ?, ?, ?)",
        ("OWN-001", "VEH-001", "CUS-001", "SALE-001", "2026-09-01", now),
    )
    conn.execute(
        "INSERT INTO inspections "
        "(inspection_id, vehicle_id, customer_id, inspection_type, status, "
        "contact_status, due_on, created_at, updated_at) "
        "VALUES (?, ?, ?, 'SHAKEN', 'PLANNED', 'NOT_CONTACTED', ?, ?, ?)",
        ("INSP-001", "VEH-001", "CUS-001", "2026-12-15", now, now),
    )
    conn.execute(
        "INSERT INTO maintenance_records "
        "(maintenance_id, vehicle_id, customer_id, staff_id, performed_on, "
        "record_type, title, odometer_km, amount_yen, status, created_at, updated_at) "
        "VALUES (?, ?, ?, ?, ?, 'MAINTENANCE', ?, ?, ?, 'COMPLETED', ?, ?)",
        (
            "MNT-001",
            "VEH-001",
            "CUS-001",
            "STF-001",
            "2026-09-20",
            "オイル交換",
            12100,
            5000,
            now,
            now,
        ),
    )
    conn.execute(
        "INSERT INTO maintenance_parts "
        "(maintenance_part_id, maintenance_id, part_name, quantity, unit_price_yen, created_at) "
        "VALUES (?, ?, ?, ?, ?, ?)",
        ("PART-001", "MNT-001", "エンジンオイル", 1, 3000, now),
    )
    conn.execute(
        "INSERT INTO vehicle_odometer_readings "
        "(reading_id, vehicle_id, source_type, source_id, recorded_on, odometer_km, created_at) "
        "VALUES (?, ?, 'MAINTENANCE', ?, ?, ?, ?)",
        ("ODO-001", "VEH-001", "MNT-001", "2026-09-20", 12100, now),
    )
    conn.execute(
        "INSERT INTO storage_objects "
        "(object_id, environment, bucket_name, object_key, entity_type, entity_id, "
        "media_role, original_filename, content_type, size_bytes, status, "
        "created_by, created_at, updated_at) "
        "VALUES (?, 'staging', ?, ?, 'vehicle', ?, 'document', ?, ?, ?, 'active', ?, ?, ?)",
        (
            "OBJ-001",
            "p014-files-staging-test",
            "document/2026/09/vehicle/VEH-001/OBJ-001-registration.jpg",
            "VEH-001",
            "registration.jpg",
            "image/jpeg",
            1024,
            "test",
            now,
            now,
        ),
    )
    conn.execute(
        "INSERT INTO storage_object_events "
        "(request_id, object_id, environment, action, actor_subject, decision, "
        "http_status, bytes_transferred, occurred_at) "
        "VALUES (?, ?, 'staging', 'upload_completed', ?, 'result', 200, 1024, ?)",
        ("REQ-001", "OBJ-001", "test", now),
    )
    conn.execute(
        "INSERT INTO vehicle_documents "
        "(document_id, vehicle_id, customer_id, inspection_id, maintenance_id, "
        "storage_object_id, document_type, title, document_date, "
        "classification_status, is_primary, status, created_at, updated_at) "
        "VALUES (?, ?, ?, ?, ?, ?, 'VEHICLE_REGISTRATION', ?, ?, "
        "'MANUAL', 1, 'ACTIVE', ?, ?)",
        (
            "DOC-001",
            "VEH-001",
            "CUS-001",
            "INSP-001",
            "MNT-001",
            "OBJ-001",
            "車検証サンプル",
            "2026-09-01",
            now,
            now,
        ),
    )
    conn.commit()

    due_count = conn.execute(
        "SELECT COUNT(*) AS c FROM inspections "
        "WHERE due_on <= ? AND status IN ('PLANNED', 'CONTACTED', 'BOOKED')",
        ("2026-12-31",),
    ).fetchone()["c"]
    if due_count != 1:
        raise AssertionError(f"inspection query smoke failed: due_count={due_count}")

    timeline_count = conn.execute(
        "SELECT COUNT(*) AS c FROM maintenance_records WHERE vehicle_id=?",
        ("VEH-001",),
    ).fetchone()["c"]
    if timeline_count != 1:
        raise AssertionError(f"maintenance query smoke failed: count={timeline_count}")

    cur = conn.execute(
        "UPDATE vehicles SET current_odometer_km=?, state_version=state_version+1, updated_at=? "
        "WHERE vehicle_id=? AND state_version=?",
        (12100, now, "VEH-001", 1),
    )
    if cur.rowcount != 1:
        raise AssertionError("state_version compare-and-update failed")
    stale = conn.execute(
        "UPDATE vehicles SET current_odometer_km=?, state_version=state_version+1, updated_at=? "
        "WHERE vehicle_id=? AND state_version=?",
        (12200, now, "VEH-001", 1),
    )
    if stale.rowcount != 0:
        raise AssertionError("stale state_version update was not rejected")

    require_integrity_error(
        lambda: conn.execute(
            "INSERT INTO vehicle_ownerships "
            "(ownership_id, vehicle_id, customer_id, valid_from, created_at) "
            "VALUES ('OWN-002', 'VEH-001', 'CUS-001', '2026-09-02', ?)",
            (now,),
        ),
        "active ownership uniqueness",
    )
    conn.rollback()

    require_integrity_error(
        lambda: conn.execute(
            "INSERT INTO sales "
            "(sale_id, vehicle_id, customer_id, sold_on, created_at, updated_at) "
            "VALUES ('SALE-BAD', 'VEH-MISSING', 'CUS-001', '2026-09-01', ?, ?)",
            (now, now),
        ),
        "foreign key rejection",
    )
    conn.rollback()

    fk_after = list(conn.execute("PRAGMA foreign_key_check"))
    if fk_after:
        raise AssertionError(f"foreign_key_check failed after CRUD smoke: {fk_after}")

    summary = {
        "migration": str(MIGRATION.relative_to(ROOT.parent.parent)),
        "tables": len(tables),
        "explicit_indexes": len(indexes),
        "foreign_key_check": "passed",
        "crud_smoke": "passed",
        "state_version_conflict": "passed",
        "active_ownership_unique": "passed",
        "production_d1_touched": False,
        "r2_touched": False,
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
