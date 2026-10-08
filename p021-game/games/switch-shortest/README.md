# GAME-G014 Switch Shortest

P021 Game Development Lab向けの静的移植版です。

- Source asset: `kobitworks/kobit_jsgames/public/game/switch_shortest`
- Migration: non-destructive; source repository is not modified.
- Runtime: HTML / CSS / JavaScript only.
- Difficulty: Easy 8 / Normal 10 / Hard 12 switches.
- Rule: pressing a switch toggles itself and its immediate neighbors.
- Goal: transform START into GOAL in as few moves as possible.
- Solver: BFS shortest-move calculation retained from the source.
- Input: click/tap and Enter/Space.
- Score: lower move count is better.
- External dependencies removed: PHP/asset_stamp, Font Awesome CDN, shared Platform SDK.
- P021 adapter: local CustomEvent + localStorage best score.
- Responsive QA: 390x844, 844x390, 768x1024, 1024x768.
