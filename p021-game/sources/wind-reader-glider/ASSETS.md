# GAME-G003 Asset Register

Updated: 2026-10-07 (GAME-032)

GAME-G003「風読みグライダー」は、3ステージすべてで外部有料素材を使わず、Godotの独自描画とランタイム生成SFXを使用する。

| asset_id | asset | source | license / rights | use |
|---|---|---|---|---|
| font-notosansjp | Noto Sans JP variable font | https://github.com/google/fonts/tree/main/ofl/notosansjp | SIL Open Font License 1.1 | Japanese UI text; CI downloads and bundles the font |
| procedural-flight-art | Sky gradient, sun/clouds, mountain layers, glider, gates, wind-flow trails, obstacles, boost trail, feedback flashes | `scripts/Main.gd` | Project-original procedural drawing; no third-party asset license | Stage 1「朝凪の丘」/ Stage 2「峡谷の横風」/ Stage 3「雷雲の切れ間」 |
| procedural-sfx | UI, gate, bonus, miss, boost, collision, clear, fail PCM tones | `scripts/Main.gd` `AudioStreamWAV` runtime synthesis | Original procedural synthesis; no third-party audio asset license | Actual in-game SFX connected to SFX 100% / 70% / 40% / OFF |

No paid assets, NC assets, external runtime APIs, unverified image-search assets, or separately downloaded sound packs are used by GAME-032.
