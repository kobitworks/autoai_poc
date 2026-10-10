# GAME-G029 Jigsaw — Godot Web integration

GAME-064 ports the gameplay concept from `kobitworks/kobit_jsgames/public/game/jigsaw_canvas` into a self-contained Godot 4.7.2 Web game for P021.

## ID normalization

GAME-041 originally listed Jigsaw as the GAME-G016 candidate. During GAME-064 Fresh-read, the live P021 portal and repository already had **GAME-G016 assigned to iPhone Home Simulator**. The project rule forbids ID reuse, and GAME-G017 through GAME-G028 are already reserved in the earlier inventory plan. To avoid overwriting a live game or cascading the reserved mapping, this integration uses the next safe ID: **GAME-G029**. Task ID GAME-064 is unchanged.

## Game

- Grid sizes: 3×3 / 4×4 / 5×5 / 6×6 / 7×7.
- Four original local SVG illustrations: Aurora, Harbor, Garden, City Night.
- Tap one piece, then another piece to swap them.
- Timer, move count, correct-position count and 1.45-second full-image hint.
- Retry without leaving the game.
- Higher-is-better score with time, move and hint penalties.
- Per-grid/per-art local BEST saved in `user://jigsaw-best.json`.
- Mouse and touch input.
- Synthesized pick/swap/hint/clear SFX with 100% / 60% / OFF control.
- Responsive custom-drawn UI for phone/tablet portrait and landscape.
- QA bridge at `?qa=1` for deterministic browser verification.

## Dependencies removed

The P021 build does not use PHP, DB, `api_levels.php`, Font Awesome, Platform SDK, server-side filesystem level discovery, or remote puzzle images.

## Public URL

https://kobitworks.github.io/autoai_poc/p021-game/games/jigsaw/

## Quality target

Target: **84/100**.

- Game feel 8
- Controls 9
- Difficulty 8
- UI/UX 9
- Graphics 9
- Effects 8
- Sound 7
- Content/variation 8
- Replayability 8
- Technical quality 10

Total: 84/100.
