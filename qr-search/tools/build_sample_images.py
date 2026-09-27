#!/usr/bin/env python3
import base64, hashlib, io, json, os, subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import qrcode
from barcode import Code128
from barcode.writer import ImageWriter
import cairosvg

ROOT = Path(__file__).resolve().parents[2]
SRC_DIR = ROOT / "qr-search" / "test-images"
DATA_DIR = ROOT / "qr-search" / "test-images-data"
OUT_DIR = ROOT / "qr-search" / "test-images-rendered"
OUT_DIR.mkdir(parents=True, exist_ok=True)

SCENES = [
    ("20260927_warehouse_a", SRC_DIR / "20260927_warehouse_a.svg"),
    ("20260927_warehouse_b", SRC_DIR / "20260927_warehouse_b.svg"),
    ("20260927_loading_zone", SRC_DIR / "20260927_loading_zone.svg"),
    ("20260927_uploaded_warehouse_01", DATA_DIR / "uploaded_warehouse_01.b64"),
    ("20260927_uploaded_warehouse_02", DATA_DIR / "uploaded_warehouse_02.b64"),
]

# Positions are normalized top-left anchors for 4 QR labels + 2 barcodes.
POSITIONS = {
    "20260927_uploaded_warehouse_01": [(0.12,0.18),(0.17,0.48),(0.60,0.08),(0.86,0.28),(0.17,0.74),(0.57,0.48)],
    "20260927_uploaded_warehouse_02": [(0.20,0.30),(0.50,0.42),(0.68,0.16),(0.78,0.46),(0.08,0.68),(0.67,0.76)],
    "20260927_warehouse_a": [(0.09,0.23),(0.28,0.46),(0.69,0.22),(0.78,0.49),(0.13,0.68),(0.56,0.67)],
    "20260927_warehouse_b": [(0.11,0.21),(0.35,0.22),(0.64,0.22),(0.71,0.48),(0.14,0.68),(0.57,0.67)],
    "20260927_loading_zone": [(0.12,0.24),(0.42,0.24),(0.72,0.24),(0.57,0.60),(0.20,0.68),(0.68,0.68)],
}

def font(size):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf"]:
        if Path(p).exists():
            return ImageFont.truetype(p, size=size)
    return ImageFont.load_default()

def load_scene(path):
    if path.suffix.lower() == ".svg":
        png = cairosvg.svg2png(bytestring=path.read_bytes(), output_width=1600, output_height=900)
        return Image.open(io.BytesIO(png)).convert("RGB")
    raw = base64.b64decode(path.read_text().strip())
    im = Image.open(io.BytesIO(raw)).convert("RGB")
    return im.resize((1600, 900), Image.Resampling.LANCZOS)

def code_values(key):
    h = hashlib.sha256(key.encode()).hexdigest()
    n = int(h[:12], 16)
    short = h[:6].upper()
    return {
        "url": f"https://example.com/package/{short.lower()}",
        "qr": [f"PKG-{short}", f"WH-{h[6:14].upper()}", f"BOX-{h[14:22].upper()}"],
        "barcodes": [f"49{n % 10**11:011d}", f"45{(n // 97) % 10**11:011d}"],
    }

def qr_label(value, size=184):
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, border=4, box_size=8)
    qr.add_data(value)
    qr.make(fit=True)
    q = qr.make_image(fill_color="black", back_color="white").convert("RGB").resize((size,size), Image.Resampling.NEAREST)
    label_h = 34
    out = Image.new("RGB", (size+16, size+label_h+16), "white")
    out.paste(q, (8,8))
    d = ImageDraw.Draw(out)
    label = value if len(value) <= 24 else value[:21] + "..."
    f = font(16)
    box = d.textbbox((0,0), label, font=f)
    d.text(((out.width-(box[2]-box[0]))/2, size+10), label, fill="black", font=f)
    return out

def barcode_label(value, width=300, height=118):
    bio = io.BytesIO()
    Code128(value, writer=ImageWriter()).write(
        bio, options={"module_width":0.32,"module_height":18,"quiet_zone":3,"font_size":11,"text_distance":2,"write_text":True}
    )
    im = Image.open(io.BytesIO(bio.getvalue())).convert("RGB")
    im.thumbnail((width,height), Image.Resampling.LANCZOS)
    out = Image.new("RGB", (width,height), "white")
    out.paste(im, ((width-im.width)//2,(height-im.height)//2))
    return out

def paste_with_shadow(bg, label, xy):
    x,y = xy
    shadow = Image.new("RGBA", (label.width+10,label.height+10), (0,0,0,0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((6,6,label.width+6,label.height+6), radius=4, fill=(0,0,0,100))
    bg_rgba = bg.convert("RGBA")
    bg_rgba.alpha_composite(shadow, (x-4,y-4))
    lab = label.convert("RGBA")
    bg_rgba.alpha_composite(lab, (x,y))
    return bg_rgba.convert("RGB")

def updated_at(path):
    try:
        ts = subprocess.check_output(["git","log","-1","--format=%cI","--",str(path.relative_to(ROOT))], cwd=ROOT, text=True).strip()
        return ts
    except Exception:
        return ""

manifest = []
for key, src in SCENES:
    bg = load_scene(src)
    vals = code_values(key)
    labels = [qr_label(vals["url"])] + [qr_label(v) for v in vals["qr"]] + [barcode_label(v) for v in vals["barcodes"]]
    pos = POSITIONS[key]
    for lab, (nx,ny) in zip(labels,pos):
        x = min(max(0,int(bg.width*nx)), bg.width-lab.width-4)
        y = min(max(0,int(bg.height*ny)), bg.height-lab.height-4)
        bg = paste_with_shadow(bg, lab, (x,y))
    out_name = key + ".png"
    out_path = OUT_DIR / out_name
    bg.save(out_path, "PNG", optimize=True)
    manifest.append({
        "name": out_name,
        "path": "test-images-rendered/" + out_name,
        "updatedAt": updated_at(src),
        "codes": vals,
    })

(OUT_DIR / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
print("generated", len(manifest), "images")
