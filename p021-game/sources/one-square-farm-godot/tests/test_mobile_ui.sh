#!/bin/sh
set -u

ROOT="p021-game/sources/one-square-farm-godot"
MAIN="$ROOT/Main.gd"
PROJECT="$ROOT/project.godot"
fail=0

pass() { printf 'PASS: %s\n' "$1"; }
fail_msg() { printf 'FAIL: %s\n' "$1"; fail=1; }

width=$(sed -n 's/^window\/size\/viewport_width=//p' "$PROJECT" | head -n 1)
height=$(sed -n 's/^window\/size\/viewport_height=//p' "$PROJECT" | head -n 1)

if [ -n "$width" ] && [ "$width" -le 420 ]; then pass "phone-first viewport width"; else fail_msg "viewport width must be <= 420 (got ${width:-missing})"; fi
if [ -n "$height" ] && [ "$height" -ge 800 ]; then pass "phone-first viewport height"; else fail_msg "viewport height must be >= 800 (got ${height:-missing})"; fi

if grep -q 'ScrollContainer.new()' "$MAIN"; then pass "portrait content is scrollable"; else fail_msg "Main.gd must create a ScrollContainer"; fi
if grep -q 'vertical_scroll_mode' "$MAIN"; then pass "vertical scroll mode is configured"; else fail_msg "Main.gd must configure vertical_scroll_mode"; fi
if grep -q 'intro_scroll = ScrollContainer.new()' "$MAIN" && grep -q 'intro_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO' "$MAIN"; then pass "intro screen has independent vertical scrolling"; else fail_msg "intro screen must be vertically scrollable"; fi
if grep -q 'intro_challenge_grid.columns = 1 if is_portrait else 3' "$MAIN"; then pass "intro challenges reflow for landscape"; else fail_msg "intro challenge grid must reflow in landscape"; fi
if grep -q 'compact_landscape := not is_portrait and size.y <= 500.0' "$MAIN"; then pass "compact phone landscape layout is defined"; else fail_msg "compact phone landscape layout contract missing"; fi
if grep -q 'OptionButton.new()' "$MAIN"; then fail_msg "crop selector must not use OptionButton"; else pass "crop selector avoids dropdown"; fi
if grep -q 'crop_buttons' "$MAIN" && grep -q '_choose_crop' "$MAIN"; then pass "crop selector uses large crop buttons"; else fail_msg "crop_buttons/_choose_crop contract missing"; fi
if grep -q 'stats_grid = GridContainer.new()' "$MAIN" && grep -q 'stats_labels' "$MAIN"; then pass "status uses readable cards"; else fail_msg "stats card grid contract missing"; fi
if grep -q 'ui_theme.default_font_size = 18' "$MAIN"; then pass "default text is readable"; else fail_msg "default font size must be 18"; fi
if grep -Eq 'custom_minimum_size[[:space:]]*=[[:space:]]*Vector2\(0,[[:space:]]*58\)' "$MAIN"; then pass "touch targets are at least 58px"; else fail_msg "58px minimum touch target missing"; fi
if grep -Eq '(help|help_label)\.add_theme_font_size_override\("font_size", 15\)' "$MAIN"; then pass "help text is readable"; else fail_msg "help font size must be 15"; fi
if grep -q 'log_view.add_theme_font_size_override("font_size", 15)' "$MAIN"; then pass "log text is readable"; else fail_msg "log font size must be 15"; fi

PORTAL="p021-game/index.html"
REDIRECT="p021-game/games/one-square-farm-godot/index.html"
EXPORT="p021-game/games/one-square-farm-godot-v5/index.html"

if grep -q 'games/one-square-farm-godot-v5/' "$PORTAL"; then pass "portal points to v5"; else fail_msg "portal must point to v5"; fi
if grep -q '../one-square-farm-godot-v5/' "$REDIRECT"; then pass "stable URL redirects to v5"; else fail_msg "stable URL must redirect to v5"; fi
if [ -s "$EXPORT" ]; then pass "v5 Web export exists"; else fail_msg "v5 Web export index is missing"; fi

exit "$fail"
