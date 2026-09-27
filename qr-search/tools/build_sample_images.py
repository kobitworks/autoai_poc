#!/usr/bin/env python3
import base64, io, json, subprocess
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC_DIR = ROOT / "qr-search" / "test-images"
DATA_DIR = ROOT / "qr-search" / "test-images-data"
OUT_DIR = ROOT / "qr-search" / "test-images-rendered"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# Rendered files are rebuilt from source images only.
for pattern in ("*.png", "*.jpg", "*.jpeg", "*.webp"):
    for old in OUT_DIR.glob(pattern):
        old.unlink()

SCENES = [
    {
        "key": "20260927_uploaded_warehouse_01",
        "src": DATA_DIR / "uploaded_warehouse_01.b64",
        "out_name": "20260927_uploaded_warehouse_01.jpg",
        "codes": None,
    },
    {
        "key": "20260927_uploaded_warehouse_02",
        "src": DATA_DIR / "uploaded_warehouse_02.b64",
        "out_name": "20260927_uploaded_warehouse_02.jpg",
        "codes": None,
    },
    {
        "key": "20260927_warehouse_new",
        "src": SRC_DIR / "20260927_warehouse_new.webp",
        "out_name": "20260927_warehouse_new.jpg",
        "codes": None,
    },
    {
        "key": "20260927_uploaded_warehouse_03",
        "src": DATA_DIR / "uploaded_warehouse_03.jpg",
        "out_name": "20260927_uploaded_warehouse_03.jpg",
        "codes": {
            "url": "https://example.com/package/WH7720",
            "qr": ["PKG-PLT3287", "ITEM-4509-A7", "ZX-1189-B03"],
            "barcodes": ["4580791234567", "TB6201002584"],
        },
    },
]

def load_scene(path):
    suffix = path.suffix.lower()
    if suffix in {".png", ".jpg", ".jpeg", ".webp", ".avif"}:
        return Image.open(path).convert("RGB")
    raw = base64.b64decode(path.read_text().strip())
    return Image.open(io.BytesIO(raw)).convert("RGB")

def updated_at(path):
    try:
        return subprocess.check_output(
            ["git","log","-1","--format=%cI","--",str(path.relative_to(ROOT))],
            cwd=ROOT, text=True
        ).strip()
    except Exception:
        return ""

manifest = []
for item in SCENES:
    src = item["src"]
    image = load_scene(src)

    # Keep the original visual content. Do not add QR/barcode overlays here.
    # Resize only when unusually large, preserving aspect ratio.
    if image.width > 1920:
        h = round(image.height * (1920 / image.width))
        image = image.resize((1920, h), Image.Resampling.LANCZOS)

    out_path = OUT_DIR / item["out_name"]
    image.save(out_path, "JPEG", quality=92, optimize=True, progressive=True)

    entry = {
        "name": item["out_name"],
        "path": "test-images-rendered/" + item["out_name"],
        "updatedAt": updated_at(src),
    }
    if item["codes"]:
        entry["codes"] = item["codes"]
    manifest.append(entry)

(OUT_DIR / "manifest.json").write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2),
    encoding="utf-8"
)
print("generated", len(manifest), "images without overlay duplication")
