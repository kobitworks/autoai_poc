# P021 / GAME-076 — RUSH時系列テレメトリと4画面実入力CIの確認（2026-10-13）

- 対象: GAME-G030 Orbit Switch Courier、GAME-076 継続タスク
- 確認日時: 2026-10-13 11:31 JST
- 実行ID: AUTOAI-GAME076-20261013-1130
- ソース正本: kobitworks/autoai_poc **develop限定**
- 検証対象コード: [real-input E2E](../qa/orbit-switch-courier-real-input.js) — 既存 commit [052cdf831a6e](https://github.com/kobitworks/autoai_poc/commit/052cdf831a6e8045e1b56aae0edd7895ba61db74) で導入済みのRUSH読取専用診断を今回検証（本実行でゲームコード・QAコードの変更はない）。

## 1. CIと成果物

- [Workflow run 38335126979](https://github.com/kobitworks/autoai_poc/actions/runs/38335126979): 2026-10-13 11:10 JSTまでに completed/**success**、attempt 1。head_sha=052cdf831a6e8045e1b56aae0edd7895ba61db74。
- 3ジョブとも success: contract (job 115093365903)、export-web (job 115093415740)、browser-quality (job 115093687536)。
- [E2E artifact 11785345059](https://github.com/kobitworks/autoai_poc/actions/runs/38335126979/artifacts/11785345059): GitHub上に実在、約4.0 MB、digest SHA-256 `b04fbbeb2de4868d7bf49bb4dbc0419dd427dab14cd67127815c061c401d0afc`。今回は**ジョブログ内の実行結果JSON**をパースして再確認した。artifact ZIP内のPNG実体を独立目視したとは扱わない。

## 2. 実タップ／クリック・自然配達（browser-qualityログ再解析）

| 画面 | 入力 | E2E | NIGHT（自然3件） | ACE（自然6件）のスコア | BEST再読込 | RUSH観測標本 | 標本期間 |
|---|---|---|---|---:|---:|---:|---:|
| Phone Portrait | touch | PASS | PASS / 12秒 | 1,109 | 1,109 | 32 | 2,324ms |
| Phone Landscape | mouse | PASS | PASS / 12秒 | 1,111 | 1,111 | 32 | 2,327ms |
| Tablet Portrait | touch | PASS | PASS / 12秒 | 1,108 | 1,108 | 25 | 2,066ms |
| Tablet Landscape | mouse | PASS | PASS / 12秒 | 1,110 | 1,110 | 24 | 2,063ms |

- 全4画面で**RUSH 1件→NIGHT 3件→ACE 6件**を通常入力で通過。ACE貨物制限10秒、NIGHT12秒。routeMovesは各11件。
- 各画面の `qaCommand="NEVER USED"`、`stateOverride="NONE"`。達成コマンド／ゲーム状態の直接書換えで成功を偽装していない。
- SOUND OFF→ONは各画面PASS、エンジンプレーヤー起動も確認。3回ミス→RESULT、RETRY、localStorage BEST再読込も各画面PASS。ただし**スピーカーの実音量・音質は未検証**。
- `cargoWarning.result="CAPTURED_UNREVIEWED"`。静的文字コントラスト `PASS_STATIC` は実画像・初見者・実機の可読性PASSを意味しない。

## 3. RUSH 0→1 トレース比較

- 既存診断は75ms間隔の read-only `wallMs/monoMs/angle/orbit/cargoLeft/timeLeft/energy/deliveries`、最大300標本。ゲーム内部への書込み、クリック代行、判定時間の延長なし。
- 今回、4画面とも最終観測は orbit=1、角度は **4.401 / 4.344 / 4.386 / 4.330rad**。RUSH区間の `energy=3` 維持、自然な移動を確認。
- 前回 [run 38330801226](https://github.com/kobitworks/autoai_poc/actions/runs/38330801226) 初回ではTablet Portraitが `RUSH 0→1 crossing` の18,000ms待機タイムアウト。失敗時の状態は orbit=0、angle=3.906rad、cargo_left=9.09、energy=2、deliveries=1。前回はこの粒度の時系列ログがなく、同一runのattempt2はPASS。
- **今回の成功のみでは一時失敗の原因を確定できない。** 描画負荷、ゲーム内時間と壁時計の乖離、入力待機と物理タップの相互影響は未確証の仮説に留める。RUSH診断による再現時の比較材料を確保したが、原因解消を宣言しない。

## 4. 判定と次の着手点

1. **技術ゲート:** 3ジョブsuccess・4画面実入力PASS。少なくとも今回のCI環境ではNIGHT/ACE進行と保存・音声UI状態の回帰なし。
2. **品質ゲート:** 前回の独立暫定 **76/100を据置き**。80点到達の証拠なし。新しい実画像の視覚監査、初見30秒の行動理解、実機のタッチ反応・文字可読性・FPS/発熱・スピーカー／イヤホン実音は未確認。
3. **次回:** タブレット縦のRUSH偶発失敗を再現した場合、成功トレースと壁時計／角度／cargo／energyの差分を比較して最小修正の可否判断。4画面の新PNGを独立確認し、右情報欄とスマホ横の可読性を重点レビューしてから10軸採点する。
4. GAME-076は完了条件未達のため **ToDo継続**。別タスクへ進まない。mainマージ、有料契約、本番構成変更、公開範囲拡大はなし。
