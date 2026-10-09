# GAME-G013 Water Jug Lab — Godot Web

GAME-060 redesigns the existing Water Jug puzzle as a touch-first Godot 4.7.2 Web game.

## Preserved rules

- Easy / Normal / Hard puzzle generation
- solvability by GCD
- BFS shortest-move calculation
- Fill / Empty / Pour A→B / Pour B→A
- best record by moves, then elapsed time
- same public URL: `p021-game/games/water-jug/`

## Redesign

- procedural glass-and-water visuals with animated fill levels
- target-volume guide line on each compatible jug
- direct six-button actions plus tap-to-select jug and SPACE-to-pour
- clear rank based on distance from optimal moves
- generated action/pour/clear tones with SOUND ON/OFF
- responsive portrait/landscape layout for phone and tablet
- URL-only QA bridge exposed only as state data: `window.__P021_WATER_JUG`

## Keyboard / QA

- D: difficulty
- M: sound
- N/Enter: start
- R: reset
- 1 / 2 / 3: Fill A / Empty A / A→B
- 7 / 8 / 9: Fill B / Empty B / B→A
- A / B: select jug
- Space: pour selected jug into the other

No paid service, external API, login, DB, or network gameplay dependency is introduced.
