# GAME-G011 Text Matching Memory — Godot redesign

Task: GAME-058

## Preserved rules
- Four board levels: 4x3 (6 pairs), 5x4 (10 pairs), 6x4 (12 pairs), 6x5 (15 pairs).
- Ten character-set stages: digits, alphabet, mixed symbols, kanji and Hangul combinations.
- Five text-length tiers matching the former 1 / 1-2 / 2 / 2-3 / 3-character progression.
- Two-card memory flow: matching cards remain open; a mismatch flips back after a short delay.
- Time, misses, turns and matched-pair progress remain first-class results.
- Recent shuffle seeds are retained locally to reduce immediate repetition.

## Redesign
- Godot 4.7.2 Web / Compatibility renderer.
- Touch-first cards with distinct hidden, revealed and matched visual states.
- Responsive portrait/landscape layout for phone and tablet.
- Runtime-generated flip/match/miss/clear sounds with SOUND ON/OFF.
- Per level/stage/tier best record persisted locally.
- Game Hub navigation remains available.
- Keyboard helpers: 1-4 level, S stage, T tier, R reshuffle, M sound.
- ?qa=1 enables an automated pair-by-pair completion helper used only by CI.

## Public URL
https://kobitworks.github.io/autoai_poc/p021-game/games/text-matching-memory/

## Source
p021-game/sources/text-matching-memory-godot/

No paid game art or audio assets are used.
