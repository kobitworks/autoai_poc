# P021 / GAME-076 — GAME-G030 上位ルート実操作・初見UI改善（継続記録）

- 実行: 2026-10-12 05:40〜05:52 JST / このRunnerの実作業 **1件のみ**
- 正本: `kobitworks/autoai_poc` の `develop` のみ。main変更、有料サービス、新規本番公開なし。
- ベースライン: [GAME-075独立監査 74/100](./game-g030-progressive-routes-review-game-075-2026-10-12.md)
- 対象: [Godot Main.gd](../sources/orbit-switch-courier-godot/Main.gd)、[Playwright実入力E2E](../qa/orbit-switch-courier-real-input.js)
- **本タスクは未完了 / ToDo継続。80点達成・一般公開品質は未認定。**

## 変更内容（GitHub developへ反映済）
1. 実際に受理される配達・乗換窓でのみ「TAP NOW」を表示し、違うHUBでは誤タップを誘わない。操作可能なときプレイヤー周囲に緑のリングを描画。
2. 初見の3段階ガイドを「開始→TAP NOW→同じ記号のHUB」に変更。最初の配送先は実際に割り当てたcargo_targetを表示し、ランダムな本番操作時にSQUARE固定と誤案内しない。
3. ルート昇格目標（RUSH/NIGHT/ACE）を情報領域へ追加。貨物ゲージ分母を固定16秒からルートごとの16/14/12/10秒へ修正。
4. 4 viewportの実入力E2EにNIGHT=3件、ACE=6件までの合法的な軌道切替・配達を追加。QAコマンドによる強制成功やゲーム状態の直接上書きは使用しない。ゲーム本体のHUB許容角を0.115→0.15radに調整し、低フレーム端末の操作猶予を改善。
5. スマホ縦390×844 / 横844×390 / タブレット縦768×1024 / 横1024×768のSOUND ON/OFF、RETRY、BEST永続化も同一の実入力E2Eで検証対象に維持。

主要コミット: [00b4b871](https://github.com/kobitworks/autoai_poc/commit/00b4b871c9d790865e940c81e4523f56ac0a04d8) / [920edf14](https://github.com/kobitworks/autoai_poc/commit/920edf14024c5be48b6e95b2e8784da26cd6ec9e) / [645fdafb](https://github.com/kobitworks/autoai_poc/commit/645fdafb1107b9f5f94eab07e66e336ed867372f) / [546e9b94](https://github.com/kobitworks/autoai_poc/commit/546e9b9471dd0fe8158e00b289d4f65b995a4359) / [dfb1f73f](https://github.com/kobitworks/autoai_poc/commit/dfb1f73fc868ad1e36f0f9790e6147af570cb800) / [05d86747](https://github.com/kobitworks/autoai_poc/commit/05d86747775cd0683c92ec7d15b4550a503b1c74)。

## CI・証跡（作業終了時点）

[初回CI run 38173507994](https://github.com/kobitworks/autoai_poc/actions/runs/38173507994): contract、export-webはSUCCESS、browser-qualityはFAIL。
[初回証跡 artifact 11715111551](https://github.com/kobitworks/autoai_poc/actions/runs/38173507994/artifacts/11715111551) をZIPダウンロードし、results.jsonと36PNGを実物確認。

- Phone Portrait: **PASS**。NIGHT3件（361〜363点帯）、ACE6件（1109点）。SOUND、リトライ、BEST復元まで成功。
- Phone Landscape: **PASS**。NIGHT3件、ACE6件（1111点）。SOUND、リトライ、BEST復元まで成功。
- Tablet Portrait: **FAIL**。NIGHT3件までは自然操作で到達、4件目のHUB0待機がタイムアウトし貨物期限切れ。
- Tablet Landscape: **FAIL**。同じくNIGHT3件までは到達、4件目HUB0の角度観測窓0.07radを捕捉できずタイムアウト。

タブレットの失敗はゲーム挙動とテスト観測タイミングの切分け未完。狭い観測窓が一因と判断して、HUB操作許容角とテスト観測窓を拡大して再検証中。失敗分を合格とは扱わない。

[修正後のCI run 38173935846](https://github.com/kobitworks/autoai_poc/actions/runs/38173935846) は開始済みで、**このRunner終了時点では最終判定未確認**。これを後続サイクルで独立read-backすること。

## 次回再開点（優先順位）
1. CI run 38173935846の全3ジョブ結果と、最終artifactのresults.json・スクリーンショット44枚相当を独立read-back。四画面で3/6件配達、SOUND ON/OFF、RETRY、BEST復元、例外なしを確認。
2. FAILが残ればviewportと失敗した実操作箇所を特定し、正規ゲーム入力で再現/修正。テストの成功コマンド・状態直書きは禁止。
3. 実画像をGAME-075と独立比較。10軸品質を根拠付きで再採点。**80/100未満ならGAME-076の追加改善を継続**（この1回では完了扱いにしない）。
4. 実機スピーカー/イヤホンの実音・端末FPS/発熱・初見ユーザー30秒理解/誤タップ率は**Human Gate / 未検証**のまま保持。CIをもって実機合格とはしない。

この記録は1回のRunner時間制限に伴う中間成果であり、GAME-076はTask ToDoに戻し、別タスクは実行しない。


## 2026-10-12 06:45 JST 継続実行（今回のRunner）

- 正本GAME-076=ToDo、GAME-075=Done、他Doingなしを読戻し、GAME-076をDoingへ排他取得。今回の選定タスクはこの1件のみ。
- 前回保留run [38173935846](https://github.com/kobitworks/autoai_poc/actions/runs/38173935846)を確認。contract / export-web はSUCCESS、browser-quality はFAIL。artifact [11714908812](https://github.com/kobitworks/autoai_poc/actions/runs/38173935846/artifacts/11714908812)の37ファイル（36 PNG+results.json）を実体ダウンロードして独立読戻し。Phone Portrait / LandscapeはACE配達6件・SOUND切替・RETRY・BEST保存PASS。一方Tablet Portrait / LandscapeはNIGHT 3件の後、4件目HUB0待機中にタイムアウト。最終snapはenergy=1、cargo_target=2、deliveries=3（2回の貨物期限切れを含む）。4/4の成功ではない。
- 修正1 [a703cb94](https://github.com/kobitworks/autoai_poc/commit/a703cb941c71f88d9afdf69f69ff0aabdefa9eea): HUB実タップ許容角を0.15→0.23radへ拡げ、低FPS・大画面での操作猶予を確保。ゲームの正規判定のみの変更でQA成功コマンドやステート直書きなし。
- 修正2 [871686aa](https://github.com/kobitworks/autoai_poc/commit/871686aa9f9025e114ba120df23650647f269a6d): NIGHT HUB0の実入力E2E観測域を1.36..1.52→1.28..1.68radへ変更。拡大後の自然なゲーム側HUB窓内に限定し、実タップと自然配達の成立を必須とする。
- 再CI [38177790865](https://github.com/kobitworks/autoai_poc/actions/runs/38177790865): contractとexport-web SUCCESS、レスポンシブ4画面スモーク試験SUCCESS、実入力E2Eは実行中（この行の記録時点）。最終4画面・ACE6件・44 PNG+JSON・独立10軸採点は後続結果の確認まで**未検証**。mainマージ/課金/有償利用なし。
- GAME-075の36画像と前回GAME-076の36画像を実際に展開し、intro、PLAY、RUSH/NIGHT/ACE画面を比較。正しいTAPタイミングの文言と緑の操作リングの改善は確認できるが、スマホ横画面の情報密度と実機表示視認性・実音声/イヤホン/FPS・初見ユーザー実評価には改善/未検証余地が残る。

## 2026-10-12 17:26 JST 継続実行（AutoAI 1件）

- GAME-075=Done / GAME-076=ToDo、他DoingなしをFresh-readし、GAME-076のみDoingとして排他取得。別タスクには着手しない。
- CI [run 38177790865](https://github.com/kobitworks/autoai_poc/actions/runs/38177790865) を独立再確認。contract / export-web=SUCCESS、browser-quality=FAIL。タブレット縦横のNIGHT HUB0入力待機が18秒タイムアウト。失敗を合格扱いしない。
- 前回のread-only軌道75ms診断コミット [3e97a830](https://github.com/kobitworks/autoai_poc/commit/3e97a83001cb3fd8a6312b2e9e9fb2a4a362a4ef) を確認。ただしGitHub連携のWorkflow一覧はpull_request由来のrunのみ返すため、同コミット以降のpush由来run ID/証跡は本実行では特定できず、合否不明。
- 本実行で `qa/orbit-switch-courier-real-input.js` のcrossing / target HUB等の実入力タイミング検出をrAFポーリングから20msタイマーポーリングへ変更。[commit 29815639](https://github.com/kobitworks/autoai_poc/commit/29815639e6209a9a09653c5e94bcace45021ed1b)。ゲームロジック、難易度、成功判定、QA stateは無変更。新Blob SHA `333156d8a5d5ffcf67a73555450801b87ff2fb06` 再読込一致。
- **静的差分反映のみ。新コミット後の4 viewport実入力E2E、44画像、SOUND/RETRY/BEST、独立10軸80点は未検証・未認定。** 実機音声・FPS・発熱・初見30秒はHuman Gate継続。
- 再開点: [GitHub Actions](https://github.com/kobitworks/autoai_poc/actions) の最新develop/GAME-G030 browser-quality run ID/URLを取得し `results.json` の `nightTelemetry` と実操作証跡を確認。必要なら原因を特定した最小差分修正後、4/4PASS・80点評価。GAME-076はToDoで継続。mainマージ・課金・本番範囲拡大なし。


## 2026-10-12 18:15 JST / AutoAI 継続診断（今回の唯一の作業：GAME-076）

- 正本 GAME-075=Done / GAME-076=ToDo、他Doingなしを Fresh-read し、GAME-076 を Doing で排他取得。P010〜P020の有効先行PJには別のAI実行可能タスクなし。main、課金、本番化には着手しない。
- GitHub Actions develop push のrunを REST GitHub connector \`GET /repos/kobitworks/autoai_poc/actions/runs?branch=develop\` で直接取得可能であることを検証。以前のPR専用workflow取得経路でrun ID不明だった問題を回避し、新しい外部認証を追加せずCI証跡を参照できた。
- [run 38220480639](https://github.com/kobitworks/autoai_poc/actions/runs/38220480639) (commit 3e97a830) は contract/export-web/browser-quality=3/3 success。実物 [artifact 11733947099](https://github.com/kobitworks/autoai_poc/actions/runs/38220480639/artifacts/11733947099) の results.json + 40 PNG を読戻し。全4 viewport で実入力NIGHT 3件→ACE 6件、SOUND切替、RETRY、BEST復元PASS（スコア1110/1111/1107/1110）。これは**技術CIの1回の成功であり、安定性や品質80点を認定するものではない**。
- 続く [run 38223455169](https://github.com/kobitworks/autoai_poc/actions/runs/38223455169) (commit 29815639) は contract/export-web success、browser-quality failure。[artifact 11734938939](https://github.com/kobitworks/autoai_poc/actions/runs/38223455169/artifacts/11734938939) の results.json + 36 PNG を読戻し、phone縦横・tablet横=3/4 PASS、**tablet縦のみ NIGHT 1->0 lost energy**。成功と誤認していない。失敗時 snapshot は orbit=0 / deliveries=3 / energy=2 / cargo_target=1 / cargo_left≈8.25s / cue=TRANSFER OK。前のNIGHT 2->1はenergy=3。どの時点でenergyが減ったかは、既存失敗トレースが「NIGHT HUB0」の失敗時だけを収集する条件だったため不明。
- 3e97→29815 の比較で変更されたQAロジックは narrow inputWindow 待機を rAF→20ms polling に切り替えた点（Godotゲームのソースロジック変更なし）。ただし現時点では時間窓観測・配送タイムアウト・イベント重複のどれが根因か**未確定**であり、ゲームルールを推測で改変しない。
- 新たな証拠収集として既存のread-only 75ms \`__P021_NIGHT_TRACE\` を「NIGHT HUB0だけでなく全NIGHT失敗時」に添付するQA最小変更をdevelopに反映：[commit 77fcad6](https://github.com/kobitworks/autoai_poc/commit/77fcad6ae669648c8e78f815ae818260a74a621a)。ゲーム成功コマンド/state直書き/QA成績緩和なし。新CI [run 38228449796](https://github.com/kobitworks/autoai_poc/actions/runs/38228449796) はこの記録時点で進行中。前runのfailed-jobs rerunは新pushの並列排他でcancelledのため結果として数えない。
- 成功runの4 viewport intro/ACE画像8枚を独立で開き、指示とルート表示を確認。スマホ横では小型テキストと暗いHUDの可読性に改善余地がある。10軸80/100の証跡付き独立採点と初見30秒・実機音質/FPS/発熱のHuman Gateは**未完了**。
- **再開点**：run 38228449796 の3ジョブ結果とartifactを取得。FAILなら \`nightTelemetry\` のenergy/cargoLeft/angle/orbit時系列から根因を切り分け、原因の確定後に最小修正と実入力4/4再検証を行う。PASSでも1回だけの合格は安定性未証明として扱い、画像比較・10軸独立採点・必要なUX改善を継続する。GAME-076はToDo継続。実機Human Gate、80点未認定。