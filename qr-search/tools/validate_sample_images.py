#!/usr/bin/env python3
import json
import sys
from pathlib import Path
import cv2

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "qr-search" / "test-images-rendered" / "manifest.json"

def valid_ean13(value: str) -> bool:
    if len(value) != 13 or not value.isdigit():
        return False
    digits = [int(x) for x in value]
    check = (10 - ((sum(digits[:12:2]) + 3 * sum(digits[1:12:2])) % 10)) % 10
    return check == digits[12]

items = json.loads(MANIFEST.read_text(encoding="utf-8"))
errors = []
detector = cv2.QRCodeDetector()

for item in items:
    image_path = ROOT / "qr-search" / item["path"]
    image = cv2.imread(str(image_path))
    if image is None:
        errors.append(f"{item['name']}: image not found/readable")
        continue

    codes = item.get("codes", {})
    expected_qr = set(([codes.get("url")] if codes.get("url") else []) + list(codes.get("qr", [])))
    ok, decoded, points, _ = detector.detectAndDecodeMulti(image)
    actual_qr = {v for v in (decoded if ok else []) if v}
    missing = sorted(expected_qr - actual_qr)
    if missing:
        errors.append(f"{item['name']}: missing QR values: {missing}")

    invalid_barcodes = [v for v in codes.get("barcodes", []) if not valid_ean13(v)]
    if invalid_barcodes:
        errors.append(f"{item['name']}: invalid EAN-13 values: {invalid_barcodes}")

if errors:
    print("\n".join(errors))
    sys.exit(1)

print(f"Validated {len(items)} sample images: all expected QR values decoded; EAN-13 checksums valid.")
