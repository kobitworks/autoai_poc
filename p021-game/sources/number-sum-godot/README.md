# GAME-G009 Number Sum — Godot redesign

GAME-056 replaces the original static HTML/CSS/JavaScript presentation at the same public URL with a Godot Web build while preserving the puzzle rule:

1. Every cell contains a positive number.
2. The player marks each cell as **include** or **exclude**.
3. Included values must match every row target, every column target, and every colored-region target.
4. Easy / Normal / Hard remain 5x5 / 6x6 / 7x7.
5. Each bundled board was solver-checked for a unique solution before being added to `puzzles.json`.

## Public-experience changes

- responsive dark puzzle-board UI drawn in Godot
- touch/mouse cell input and keyboard shortcuts
- immediate over/complete target feedback
- include/exclude micro animation
- generated UI tones with SOUND ON/OFF
- hints with a +5 second record penalty
- local best-time records per difficulty
- NEW / RESET / replay / next-puzzle flow
- direct P021 Game Hub return
- 3 solver-checked boards per difficulty (9 total)
- four-viewport browser QA and URL-only playthrough

## Runtime

- Godot 4.7.2
- GDScript
- Compatibility renderer
- Web export, thread support disabled
- public path: `p021-game/games/number-sum/`

## 100-point review target

| Category | Score |
| --- | ---: |
| Game design | 9 |
| Controls | 9 |
| Difficulty | 9 |
| UI/UX | 9 |
| Graphics | 8 |
| Effects | 8 |
| Sound | 8 |
| Content / variation | 8 |
| Replayability | 9 |
| Technical quality | 10 |
| **Total** | **87 / 100** |

The score is accepted as **一般公開品質** only when the CI export and four-viewport URL-only browser QA both pass. The automated evidence is written to `p021-game/docs/qa/game-g009-godot-redesign/latest.json`.
