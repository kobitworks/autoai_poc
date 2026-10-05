#!/bin/sh
set -eu

ROOT="p021-game/sources/one-square-farm-godot"
MAIN="$ROOT/Main.gd"

grep -q 'const CHALLENGES := {' "$MAIN"
for key in standard sprint drought; do
  grep -q "\"$key\": {" "$MAIN"
done

grep -q 'const RECORDS_PATH := "user://farm_records.cfg"' "$MAIN"
grep -q 'func _choose_challenge' "$MAIN"
grep -q 'challenge_max_day' "$MAIN"
grep -q 'challenge_target_coins' "$MAIN"
grep -q 'challenge_water_refill' "$MAIN"
grep -q 'func _is_challenge_cleared' "$MAIN"
grep -q 'func _save_result_record' "$MAIN"
grep -q 'record.best_coins' "$MAIN"
grep -q 'record.best_rank' "$MAIN"
grep -q 'record.cleared' "$MAIN"
grep -q 'intro_records' "$MAIN"
grep -q 'BEST %dG / RANK %s' "$MAIN"
grep -q 'main_grid.columns = 1 if is_portrait else 2' "$MAIN"

if grep -q 'elif event is InputEventMouseButton' "$MAIN"; then
  echo "FAIL: challenge buttons must not trigger generic click-to-start"
  exit 1
fi

echo "GAME-G001 challenge/record contract: PASS"
