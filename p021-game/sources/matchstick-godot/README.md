# GAME-G015 Matchstick — Godot Web redesign

GAME-062 replaces the earlier static HTML/JS migration with a Godot 4.7.2 Web build while preserving the Matchstick core rule.

## Preserved rules

- Seven-segment digits.
- Move exactly one physical match from one digit to another.
- Easy: one-digit addition/subtraction.
- Normal: values up to two digits, addition/subtraction.
- Hard: values up to two digits, addition/subtraction/multiplication.
- Round choices: 1 / 3 / 5 / 7 / 10.
- Correct +2; incorrect or skip -1 with a floor of zero.
- Best score is higher-is-better and saved locally.

## GAME-062 redesign

- Godot CanvasItem rendering with wooden match visuals and glow feedback.
- Touch/mouse hit areas for selecting a removable match and a legal destination.
- Clear selected, placeable, correct, incorrect, round and score feedback.
- Synthesized interaction/success/error SFX with 100% / 60% / OFF volume control.
- Responsive layout for phone/tablet portrait and landscape.
- Deterministic QA mode at ?qa=1 with a small browser test bridge.
- Public URL remains p021-game/games/matchstick/.

## Quality target

The release gate is 82/100:
game feel 8, controls 9, difficulty 8, UI 9, graphics 8, effects 8, sound 7, content 7, replay 8, technical quality 10.
