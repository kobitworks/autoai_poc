# GAME-076 / GAME-G030：入力判定拡大後のGitHub Actions証跡 独立監査

- 対象日：2026-10-14 JST / AutoAI実行ID `AUTOAI-GAME076-20261014-1722`
- 対象：`kobitworks/autoai_poc` `develop` / [run 38530789447](https://github.com/kobitworks/autoai_poc/actions/runs/38530789447) / HEAD `946bf48911f2e6043d8932d66c98be0ed9e3b5ba`
- 新しいゲームソースの確認：`p021-game/sources/orbit-switch-courier-godot/Main.gd`（GitHub blob SHA `e25c598a181e99426bc864f8c1e6f61cfe29563a`）の `SWITCH_WINDOW := 0.23`、`HUB_WINDOW := 0.23`。ゲーム本体の物理切替受理幅は中心4.50radに対して **4.27〜4.73rad**。
- 対象GitHub artifact：`p021-game-g030-real-input-evidence` / ID `11878566404`（4,371,858 bytes）。

## 1. 実体監査と判定

| 確認点 | 独立確認結果 |
|---|---|
| artifact ZIP SHA-256 | `0c5f074f2c5b59caa707b8b2dd3182cc039d9d5110f77f004fd9b000bca08fad`。GitHub artifact metadataのdigestと**一致** |
| ZIP健全性 | `ZipFile.testzip()` で不正エントリーなし、CRC正常 |
| 内訳 | 60ファイル＝58 PNG + `results.json` / `results-checkpoint.json` 各1 |
| PNG | 58/58をPillowで `verify()` およびデコード実施、いずれも正常。24枚の代表サムネイルと原寸2枚を独立に目視 |
| JSON合否正本 | `results.json` をパース。`results-checkpoint.json` は `PARTIAL_CHECKPOINT_NOT_FINAL` のため最終合否には使用しない |
| GitHub Actions | contract、export-web、browser-qualityの3ジョブすべて `completed/success` |
| 自然入力E2E | Phone縦touch / Phone横mouse / Tablet縦touch / Tablet横mouse の4/4が `PASS`。`qaCommand=NEVER USED` と `stateOverride=NONE` が各4件 |
| ゲーム進行・保存 | 各4画面で NIGHT=3配送、ACE=6配送、energy=3。SOUND OFF/ON切替の状態確認、BEST保存値と再読込値が全4画面一致 |
| 追加レイアウト | 小型Phone縦・横、コンパクトTablet横の3/3が `PASS_GEOMETRY`。`visualContract=PASS_STATIC`（実機可読性ではない） |

## 2. 実際のpointerdown位置と受理余裕

新HEADの物理ブラウザ入力イベント捕捉から、RUSH 0→1での **pointerdown時のorbit angle** を読取った。値はゲーム本体の受理判定を改変せず記録したもの。4.50±0.23radの境界へ至る前後の余裕（どちらか小さい方）は次のとおり。

| viewport | 入力 | pointerdown rad | 最小余裕 rad | 自然入力E2E |
|---|---|---:|---:|---|
| Phone縦 390×844 | touch | 4.438 | 0.168 | PASS |
| Phone横 844×390 | mouse | 4.400 | 0.130 | PASS |
| Tablet縦 768×1024 | touch | 4.636 | **0.094** | PASS |
| Tablet横 1024×768 | mouse | 4.472 | 0.202 | PASS |

Tablet縦の `inputCallMs=207` / `maxRushSampleGapMs=221`。今回は成功したが、±0.23rad拡大で偶発的失敗が完全解消したと断言できない。実機タップにおける遅延もこの数値からは推定しない。

## 3. 新たに見つけた観測上のズレ

`p021-game/qa/orbit-switch-courier-real-input.js` の `summarizeRushTrace()` は依然として診断用サンプリング帯域 `4.31..4.47` を使用している。これは新物理受理幅 `4.27..4.73` の**一部分**に過ぎず、Phone横では `observationBandSamples=0` でも物理 `pointerdown=4.400rad` でE2EはPASSした。サンプリング不在を操作不能・失敗と誤判定してはならない。

同QAの RUSH/NIGHT コメントに旧 `4.50 +/- 0.19` の記載が残る。次のAI作業では**診断上の名称・観測帯域と実受理幅の区別を明示し、コメントを新規ソースと整合させる**ことを推奨。ただし自然入力による実判定、state、energy、成功条件を緩めて証拠を偽装しない。

## 4. 目視監査と残るHuman Gate

代表24画像の縮小比較およびPhone横の期限警告/小型Phone横PLAYING原寸を確認した範囲では、START・警告・ガイド・RESULTの主要導線が完全に画面外へ消えるような明白な破綻は見られない。ただし、画像から実iPhone/iPadでの指操作・細字可読性・実音・フレームレート・発熱は確認できない。

- **独立10軸品質：暫定76/100を維持**（目標80未達）。ZIPのPASSと静的視認性だけで点数を上げない。
- 未検証Human Gate：初見30秒理解、指先タップ余裕、スマホ横/タブレット横の日本語可読性、スピーカー・イヤホンの効果音、FPS/発熱、縦横回転後のレイアウト。既存[実機受入手順](game-g030-device-first-play-acceptance-game-076-2026-10-14.md)で一次証拠を取得する。
- 同一理由のHuman Gate依頼をSlackへ再送しない。今回ゲーム本体・QAコード・main・本番・課金・公開範囲の変更は行っていない。
- 次回再開：実機結果の有無を先に確認。未着なら同HEADの追加自然入力反復で偶発失敗再現を観測し、旧±0.19コメント/診断範囲の鮮度を是正。10軸を証拠に基づき再採点する。完了条件未達なのでGAME-076をToDoで継続。
