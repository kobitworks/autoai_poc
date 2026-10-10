# GAME-G016 — iPhone Home Simulator (Godot 4 + PWA)

This is a visual, interactive **non-official iPhone-style home screen** mock-up, made with Godot. It is not iOS and has no real Apple services, biometrics, calling, mail, or notification access.

## Features
- Live clock, status bar, Dynamic Island-like decoration, wallpaper, widgets, 4-column app grid, translucent Dock and home indicator.
- Two pages; swipe left/right to switch. Tap a standard app to show a **demo-only** panel. Long press enters icon edit mode; tap Done to exit.
- Page 2 includes a functional **Site QR** icon (Icons8): tap to display a locally rendered and verified QR code targeting https://kobitworks.github.io/autoai_poc/p021-game/games/iphone-home/. Close to return home.
- The P021 Game Lab card also has a **QRを表示** button opening the same scannable QR in an accessible browser dialog. Generated with qrencode, verified by zbarimg; no third-party QR API or network request at display time.
- Landscape iPhone layout, portrait iPhone layout, and a centered phone preview on tablets/desktop.
- Published as a Godot Web PWA using Compatibility renderer and single-thread WebAssembly for iOS browsers.
- App icon art from **Icons8** (downloaded from the Icons8 PNG CDN during CI; originals are not committed). Attribution via Settings demo and the public Game Lab card.
- Original wallpaper and PWA launch image generated deterministically by tools/prepare_assets.py.
- Noto Sans JP font (SIL OFL 1.1) downloaded during CI.

## Browser
https://kobitworks.github.io/autoai_poc/p021-game/games/iphone-home/

## Build
Run `python3 tools/prepare_assets.py` inside this project (downloads PNG icons and builds wallpaper), download Noto Sans JP variable TTF into fonts/NotoSansJP.ttf, then:
```sh
godot --headless --editor --quit-after 4
godot --headless --export-release Web ../../games/iphone-home/index.html
```
The GitHub workflow automates this on every change to this folder, and also generates assets/site-qr.png using qrencode, copies it to games/iphone-home/site-qr.png, and tests QR decoding and Godot/browser interaction.

## License and trademarks
Icons8 icons are used with attribution under its free-license terms: https://icons8.com/license ; icons by https://icons8.com/ . Do not extract, redistribute or resell individual icon source files. This interface is a study in look and feel; it does not include Apple's copyrighted wallpapers, fonts, or proprietary app functionality. **Not affiliated with or endorsed by Apple.** Godot project code is for demonstration purposes; the bundled third-party graphics are subject to their respective licenses.
