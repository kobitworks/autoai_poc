#!/bin/sh
set -eu

ROOT="p021-game/sources/one-square-farm-godot"

grep -q 'const SFX_PATHS' "$ROOT/Main.gd"
grep -q 'AUDIO_SETTINGS_PATH' "$ROOT/Main.gd"
grep -q '_cycle_audio_level' "$ROOT/Main.gd"
grep -q '_play_sfx("plant")' "$ROOT/Main.gd"
grep -q '_play_sfx("water")' "$ROOT/Main.gd"
grep -q '_play_sfx("compost")' "$ROOT/Main.gd"
grep -q '_play_sfx("harvest")' "$ROOT/Main.gd"
grep -q '_play_sfx("success"' "$ROOT/Main.gd"
grep -q '_play_sfx("error")' "$ROOT/Main.gd"

for file in select_001.ogg click_001.ogg click_002.ogg click_003.ogg confirmation_001.ogg confirmation_004.ogg error_001.ogg; do
  test -s "$ROOT/audio/$file"
done

grep -q 'Kenney Interface Sounds' "$ROOT/ASSETS.md"
grep -q 'Creative Commons CC0 1.0' "$ROOT/ASSETS.md"
grep -q '## Audio' "$ROOT/CREDITS.md"

echo "GAME-G001 audio contract: PASS"
