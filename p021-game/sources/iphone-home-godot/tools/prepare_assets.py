#!/usr/bin/env python3
"""Prepare P021 GAME-G016 assets before Godot import.
Public Icons8 PNGs are packed into the exported PCK, not committed as source.
"""
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import json, math, struct, time, urllib.request, zlib

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
ICONS = ASSETS / "icons"
ICONS.mkdir(parents=True, exist_ok=True)

# Prefer colored Fluency assets. Each icon is downloaded at 96x96 (free PNG tier).
NAMES = {
 "photos": ["apple-photos", "photos", "image-gallery"],
 "camera": ["camera", "compact-camera"],
 "mail": ["mail", "new-post", "envelope"],
 "clock": ["clock", "time"],
 "maps": ["map", "google-maps", "marker"],
 "weather": ["partly-cloudy-day", "cloud", "sun"],
 "reminders": ["todo-list", "checked-checkbox", "task"],
 "notes": ["note", "notes", "edit"],
 "stocks": ["stocks", "combo-chart", "statistics"],
 "books": ["books", "open-book", "book"],
 "appstore": ["app-store", "app-store-ios", "apps"],
 "podcasts": ["podcast", "microphone"],
 "tv": ["retro-tv", "tv", "video"],
 "health": ["heart-with-pulse", "heart-health", "heart"],
 "home": ["home", "house"],
 "wallet": ["wallet", "bank-cards"],
 "facetime": ["video-call", "video-message"],
 "calendar": ["calendar", "tear-off-calendar"],
 "files": ["folder", "file-folder"],
 "contacts": ["contacts", "contact-card"],
 "shortcuts": ["lightning-bolt", "automation"],
 "find": ["location", "radar"],
 "calculator": ["calculator", "math"],
 "translate": ["translation", "language"],
 "voice": ["microphone", "voice-recognition"],
 "tips": ["idea", "light-on"],
 "news": ["news", "newspaper"],
 "settings": ["settings", "services"],
 "phone": ["phone", "call"],
 "safari": ["safari", "compass"],
 "messages": ["speech-bubble", "chat", "sms"],
 "music": ["music", "musical-notes"],
 "freeform": ["mind-map", "draw"],
 "fitness": ["activity", "running"],
 "measure": ["ruler", "measure"],
 "magnifier": ["search", "magnifying-glass"]
}

def png(path, width, height, colorfunc):
    out = bytearray()
    for y in range(height):
        out.append(0)
        for x in range(width):
            r, g, b, a = colorfunc(x, y)
            out.extend((min(255,max(0,int(r))),min(255,max(0,int(g))),min(255,max(0,int(b))),min(255,max(0,int(a)))))
    def chunk(name,data):
        return struct.pack(">I",len(data))+name+data+struct.pack(">I",zlib.crc32(name+data)&0xffffffff)
    payload = struct.pack(">IIBBBBB",width,height,8,6,0,0,0)
    Path(path).write_bytes(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",payload)+chunk(b"IDAT",zlib.compress(out,7))+chunk(b"IEND",b""))

def mix(c, b, f):
    f=max(0,min(1,f))
    return tuple(c[i]*(1-f)+b[i]*f for i in range(3))

def wallpaper(x,y):
    X=x/390.0; Y=y/844.0
    color=mix((25,53,113),(87,89,168),Y)
    blobs=[
      ((253,169,155),0.95,0.23,0.52,0.43,0.79),
      ((255,187,163),0.57,0.59,0.48,0.38,0.64),
      ((115,177,246),0.22,0.63,0.58,0.42,0.86),
      ((197,164,235),0.74,0.89,0.54,0.26,0.67),
      ((26,42,131),0.13,0.99,0.69,0.19,0.45)
    ]
    for shade,cx,cy,rx,ry,opacity in blobs:
        t=math.exp(-2.1*((X-cx)**2/rx**2+(Y-cy)**2/ry**2))*opacity
        color=mix(color,shade,t)
    return (*color,255)

png(ASSETS/"wallpaper.png",390,844,wallpaper)

def logo(n):
    def rgba(x,y):
        fx=x/n; fy=y/n
        c=mix((85,133,238),(241,139,190),fy)
        c=mix(c,(255,197,166),math.exp(-((fx-0.83)**2+(fy-0.25)**2)/0.12)*0.58)
        sx=n*.23; sy=n*.15; ex=n*.77; ey=n*.85; rad=n*.125
        inside=sx<=x<=ex and sy<=y<=ey
        if inside:
            dx=max(sx+rad-x,0,x-(ex-rad))
            dy=max(sy+rad-y,0,y-(ey-rad))
            if dx*dx+dy*dy<=rad*rad:
                c=(247,248,255)
                for gx,gy,rgb in [
                    (.34,.34,(55,183,244)),(.56,.34,(251,144,105)),
                    (.34,.55,(85,211,131)),(.56,.55,(165,136,245))]:
                    xx=n*gx; yy=n*gy; ss=n*.145; rr=n*.03
                    ddx=max(xx+rr-x,0,x-(xx+ss-rr))
                    ddy=max(yy+rr-y,0,y-(yy+ss-rr))
                    if xx<=x<=xx+ss and yy<=y<=yy+ss and ddx*ddx+ddy*ddy<=rr*rr:
                        c=rgb
        return (*c,255)
    png(ASSETS/("pwa%d.png"%n),n,n,rgba)

for n in (144,180,512):
    logo(n)

def get_icon(item):
    key, aliases = item
    for alias in aliases:
        for style in ("fluency","color","windows-11-color"):
            url="https://img.icons8.com/%s/96/%s.png"%(style,alias)
            try:
                req=urllib.request.Request(url,headers={"User-Agent":"Mozilla/5.0 (compatible; AutoAI-game-demo/1.0)","Accept":"image/png"})
                with urllib.request.urlopen(req,timeout=8) as resp:
                    b=resp.read()
                if b.startswith(b"\x89PNG\r\n\x1a\n") and len(b)>170:
                    (ICONS/(key+".png")).write_bytes(b)
                    return key,url
            except Exception:
                pass
    return key,None

success={}
with ThreadPoolExecutor(max_workers=12) as executor:
    for f in as_completed([executor.submit(get_icon,item) for item in NAMES.items()]):
        key,url=f.result()
        success[key]=url
        print(("Icons8" if url else "MISSING"),key,url or "")

(ASSETS/"icons8-provenance.json").write_text(json.dumps(success,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("Icons8 coverage:",sum(bool(v) for v in success.values()),"/",len(success))
if sum(bool(v) for v in success.values())<20:
    raise SystemExit("Too few Icons8 assets available; stop rather than publishing placeholder-heavy UI.")
