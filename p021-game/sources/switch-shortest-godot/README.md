# GAME-G014 Switch Shortest — Godot redesign

GAME-061で、既存の静的Switch ShortestをGodot 4.7.2 Webへ全面リデザインした編集用ソースです。

## Preserved rules
- Easy 8 / Normal 10 / Hard 12 switches.
- 押したスイッチと左右の隣接スイッチが反転。
- STARTをTARGETへ一致させる。
- BFSで最短手数を算出し、少ない手数が高評価。
- 元の `kobitworks/kobit_jsgames` は非破壊で維持。

## Redesign
- circuit-console風の独自描画UIとON/OFFグロー表現。
- スマホPortraitではスイッチを2段に折り返し、Landscapeでは1列表示。
- タップ/クリックとキーボード操作に対応。
- 最短経路HINT、手数・OPTIMAL・BEST、CLEAR RANK、RETRY/NEW導線。
- スイッチ反転パルス、CLEAR演出、合成効果音、SOUND ON/OFF。
- パズルはTARGETから合法手を適用して生成するため必ず到達可能。
- QA用Web debug bridge: `window.__P021_SWITCH_SHORTEST`.

## Controls
- Tap/click: switch / toolbar buttons
- D: difficulty
- M: sound
- H: hint
- N: new puzzle
- R: retry
- 1–9: switch 1–9
- 0: switch 10

## Public URL
https://kobitworks.github.io/autoai_poc/p021-game/games/switch-shortest/
