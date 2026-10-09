# GAME-G012 Flash Mental Math — Godot redesign

GAME-059 replaces the previous static HTML/CSS/JavaScript presentation at the same public URL with a Godot Web build while preserving the original play rules.

## Preserved rules

- Stage 1: addition
- Stage 2: addition + distraction traps
- Stage 3: addition / subtraction
- Stage 4: addition / subtraction + distraction traps
- Stage 5: four operations + distraction traps
- Level 1-5 controls flash speed, digit count and sequence length.
- Round count remains selectable from 1 through 10.
- Trap tokens must be ignored when calculating the answer.
- Score is the number of correct rounds; higher is better.

## Redesign

- high-contrast neon arithmetic arena optimized for fast visual recognition
- responsive portrait / landscape layouts for phone and tablet
- large center flash token with countdown and phase guidance
- touch-first numeric keypad with negative-answer support
- keyboard input on desktop
- correct / miss / streak feedback and result overlay
- local best result per Stage / Level / Round combination
- generated UI tones with SOUND ON/OFF
- direct Game Hub navigation
- QA-only accelerated timing and deterministic completion controls
- four-viewport URL-only browser QA

## Runtime

- Godot 4.7.2
- GDScript
- Compatibility renderer
- Web export with thread support disabled
- public path: `p021-game/games/flash-mental-math/`

## 100-point review target

| Category | Score |
| --- | ---: |
| Game design | 9 |
| Controls | 10 |
| Difficulty | 9 |
| UI/UX | 9 |
| Graphics | 9 |
| Effects | 9 |
| Sound | 8 |
| Content / variation | 9 |
| Replayability | 9 |
| Technical quality | 10 |
| **Total** | **91 / 100** |

General-public quality is accepted only when Godot import/export and all four browser viewports pass. Evidence is written to `p021-game/docs/qa/game-g012-godot-redesign/latest.json`.
