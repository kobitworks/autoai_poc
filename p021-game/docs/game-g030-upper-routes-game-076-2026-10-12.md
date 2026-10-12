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

### 18:19 JST / 追加CI最終結果・read-only診断
- [run 38228449796](https://github.com/kobitworks/autoai_poc/actions/runs/38228449796) は **contract=success, export-web=success, browser-quality=failure** と確定。全4 viewportのうちphone縦横2/4 PASS、tablet縦は **RUSH 1->2 lost energy**、tablet横は **NIGHT 1->0 lost energy**。4/4 PASSは未達。
- [artifact 11737247573](https://github.com/kobitworks/autoai_poc/actions/runs/38228449796/artifacts/11737247573) ZIPをダウンロードし results.json を独立読戻し。新規診断対象のtablet横にnightTelemetry=131 samples を確認。NIGHT 2->1はエネルギー3のまま実際に転送成功。直後の軌道1で angle=4.627 (19.691秒) → 4.443 (19.887秒) と飛び、QAが待つ 4.55..4.62rad の狭い観測帯をサンプルが通過した一方で入力イベントは発生していない。そのまま軌道1を周回して cargoLeft=0.03 (29.888秒) → 11.87・energy=2 (30.086秒) へ変わった。したがって **NIGHT1→0の失敗は貨物期限切れ前の初回有効交差をQAが捕捉できなかったことに整合**する。ゲーム自体の交差判定、端末実機の挙動、なぜPlaywright観測が遅れたかまでは未確定。
- tablet縦の失敗はRUSH段階のため現在のnightTelemetry収集範囲外。新規コードは診断情報を増やしたのみでゲームの成功条件・点数は無変更。根拠がない修正を重ねず、再開時にはQAの観測窓/ブラウザスケジューリングの設計とRUSH/NIGHT双方の証跡を照合する。タイミング依存テストの基盤自体を検討し直す。10軸独立80点/実機Human Gateは未完了、GAME-076はToDo維持。


## 2026-10-12 18:44 JST / AutoAI実行ID 20261012183458-AUTOAI — 実入力QA改善・CI完走

- 本実行の唯一の実作業は **GAME-076**。GAME-075=Done、他Doingなしを確認して開始。GitHub `develop` の [QA実入力スクリプト](../qa/orbit-switch-courier-real-input.js) の角度観測域だけを変更し、[commit 8a6d7e6](https://github.com/kobitworks/autoai_poc/commit/8a6d7e6657fee5f0ba58d6cfa53be26b7c6db7e6) / blob `ea9fb092443856566e876bcea4ae7b03f4df3c56` で独立読戻し一致。Godotゲーム本体、QA成功コマンド、ゲームstateの直接書換は変更していない。
- 変更した13箇所の観測域について、初期2入力＋上位11実操作の範囲がGodot正規物理判定（交差点 `SWITCH_WINDOW=0.19rad`、HUB `HUB_WINDOW=0.23rad`）内であることを静的検証。前回 [run 38228449796](https://github.com/kobitworks/autoai_poc/actions/runs/38228449796) の独立ZIP読戻しでもタブレット横の軌道角度 `4.627→4.443rad` / `196ms` 飛びを確認。以前の待機帯 `4.55..4.62` を観測できず、NIGHT 1→0 が期限切れに至った原因候補に整合する。
- 修正後の [GitHub Actions run 38231177626](https://github.com/kobitworks/autoai_poc/actions/runs/38231177626) を再取得し、**contract / export-web / browser-quality = success 3/3** を確認。保存済み [artifact 11739290056](https://github.com/kobitworks/autoai_poc/actions/runs/38231177626/artifacts/11739290056) の **results.json＋40 PNG** を実体ダウンロードし独立読戻し。

| viewport | 自然実入力E2E | NIGHT→ACE | ACE配達件数 | 最終スコア | SOUND・RETRY・BEST | 
|---|---|---|---:|---:|---|
| phone portrait 390×844 | PASS | PASS | 6 | 1109 | PASS |
| phone landscape 844×390 | PASS | PASS | 6 | 1110 | PASS |
| tablet portrait 768×1024 | PASS | PASS | 6 | 1108 | PASS |
| tablet landscape 1024×768 | PASS | PASS | 6 | 1110 | PASS |

- 全11のRUSH/NIGHT/ACE操作は通常のPlaywright `touchscreen.tap` / `mouse.click` によるもの。成果物JSONの `qaCommand=NEVER USED` / `stateOverride=NONE` を確認。ブラウザ内部のAudioStreamPlayer起動・SOUND ON/OFFは確認したが、実スピーカーの音質や音量は未確認。
- phone landscape のACE画像を目視。ルート/HUD/盤面/操作案内は画面内にあり、失敗前よりタイミング検証の自動化は改善。一方、小さい補助文字・暗いコントラストと操作中の初見理解には改善余地。前回の品質暫定 **74/100** は今回のCI PASSだけでは引き上げず、**80点の一般公開品質は未認定**。単一runの4/4PASSを再現性の証明にしない。
- **次回再開点**: 同じQAで複数回のCI再現性を確認。4端末サイズの画像と10軸の品質を独立採点し、スマホ横補助文字/余白活用/最初の30秒のガイドを改善。AIで到達可能な公開品質80点を目指す。実機スピーカー/イヤホン、FPS・発熱、初見ユーザーの操作成功率はHuman Gateで未検証継続。外部課金、mainマージ、本番化なし。GAME-076はToDo継続。


## 2026-10-12 再現性再検証・40画面画像独立採点（AutoAI）

実施日時: 2026-10-12 19:04 JST。今回のRunner実作業は **GAME-076の継続1件のみ**。前回のコード/QA commit `8a6d7e6657fee5f0ba58d6cfa53be26b7c6db7e6` の再現性と公開品質評価を分けて実施した。実機音質や初見ユーザーが未検証であることを維持する。

### 1. GitHub Actions 2回連続の実操作E2E（同じQA・同じコード）

- [workflow run 38231177626](https://github.com/kobitworks/autoai_poc/actions/runs/38231177626) の初回attemptは contract / export-web / browser-quality **3/3 success**。初回artifact [11739290056](https://github.com/kobitworks/autoai_poc/actions/runs/38231177626/artifacts/11739290056)、results.json SHA-256 `94b85f7926b9766f02b3a4de171836eccbf95a9c0e71d9bb3a415ddabfc414e7` をZIP実体から読戻し。
- GitHub Actionsのブラウザ品質ジョブ（当初job 114751200300）をGitHub上で **re-run** した。新attemptの browser-quality job 114758268629 も **completed/success**。contract / export-web / browser-quality は再試行時も3/3 success。[新artifact 11739921175](https://github.com/kobitworks/autoai_poc/actions/runs/38231177626/artifacts/11739921175)、results.json SHA-256 `3ba2cf1f5c1d819740f5834fd1d877e119c0d11a1902f0267aa243c9eeb6d5f3` を独立読戻し。
- 2つのZIPそれぞれに **4サイズ×10状態=40 PNGとresults.json（計41ファイル）**。QAの方法は通常のタッチ/マウス操作で、全ケース `qaCommand=NEVER USED`、`stateOverride=NONE`。ゲームのスコア/クリア状態を直接上書きした成果ではない。

| viewport | 初回E2E | 再実行E2E | 初回 ACE 6件 score | 再実行 ACE 6件 score | SOUND / RETRY / BEST |
| --- | --- | --- | ---: | ---: | --- |
| Phone Portrait 390×844 | PASS | PASS | 1109 | 1109 | 2回ともPASS |
| Phone Landscape 844×390 | PASS | PASS | 1110 | 1111 | 2回ともPASS |
| Tablet Portrait 768×1024 | PASS | PASS | 1108 | 1107 | 2回ともPASS |
| Tablet Landscape 1024×768 | PASS | PASS | 1110 | 1110 | 2回ともPASS |

前回のRUSH/NIGHTタイミング失敗に対して、同一commitで **4/4 PASSが2回連続**することを確認した。ただし2回の成功だけで将来の断続的失敗がゼロになると断定しない。

### 2. PNGを独立目視した残課題

- Phone Portrait: 最初のSTARTボタン・操作ステップ・HUD・SOUND/GAME HUBは区別可能。補助説明が細字/小文字で、初見者に届くかは未測定。
- **Phone Landscape 844×390**: 音声操作ボタンと2カラムは画面内に収まる一方、導入3行・右パネル下部の補助説明・HUD補助文字が淡色の小文字で読み取りづらい。とくに狭い高さで最初の操作を理解するまでの認知負荷が課題。
- Tablet Portrait: ルートACE時の3軌道と目標HUBが判別可能。結果/説明は中心にあるが、テキストとゲーム盤面のメリハリを改善できる。
- Tablet Landscape: 左の大きな盤面と右情報の分離は明瞭。一方、右パネルに余白が大きく、次の入力の具体的説明を上部へ強調できる。
- 静止画はレンダリング状態の確認に限る。**実機スピーカー/イヤホンの音量音質、FPS/発熱、初見30秒成功率、アクセシビリティ実測は未検証**。

### 3. P021 10軸・独立暫定採点（各10点）

| 指標 | 点数 | 根拠・次の不足 |
| --- | ---: | --- |
| ゲーム性 | 8 | 軌道乗換→配達→ルート昇格、実ユーザーの楽しさは未確認 |
| 操作感 | 8 | 4サイズ2回の実入力PASS。実機の誤タップ率は未測定 |
| 難易度設計 | 7 | STARTER/RUSH/NIGHT/ACEの配達数1/3/6件と時間制限の進行を全4サイズで実証 |
| UI/UX | 7 | 初見案内は存在するが、特にPhone Landscapeの小文字/低コントラストが残る |
| グラフィック | 7 | 統一した軌道/HUB/色・図形、素材/動きの洗練は残る |
| 演出・エフェクト | 6 | 色分けした昇格・成功/失敗の瞬間演出あり、動画での独立審査なし |
| サウンド | 6 | ON/OFFとエンジン内部再生は確認、実機出力未検証 |
| コンテンツ量・変化 | 8 | 4ルート/3段階昇格が実入力で成立、盤面/体験変化は少ない |
| リプレイ性 | 9 | RETRY・BEST永続化の2回×4サイズで再確認 |
| 技術品質 | 9 | 3ジョブ成功と実入力4/4×2、FPS/発熱未確認 |
| **合計** | **75/100（証跡限定暫定）** | **一般公開品質の80点には未達** |

GAME-075の74/100に対し、上位2ルート実入力証跡による難度/変化の確認を加点した一方、実画像からPhone Landscapeの読みづらさを減点して、今回75/100とした。点数は独立した目視と自動証跡に基づく暫定値である。

### 4. 同一GAME-076の残作業・次回再開点

1. `Main.gd` の初見3ステップを短く読みやすい日本語へ修正し、Phone Landscape 844×390の文字サイズ・配色・ボタン/案内の強調を改善する。
2. 「TAP NOW」で入力可能な瞬間を盤面下端へ視認しやすく強調し、右情報ペインの余白には次の行動を優先表示する。ゲームの配送判定やQA成功状態の直書きは禁止。
3. 改修後に **4 viewport×intro/playing/route-rush/route-ace/result/retry/sound等の実画像** と実入力E2Eを再取得して可読性と10軸を再採点する。80点未満ならGAME-076の改善を継続する。
4. 実機の音質/FPS/発熱/初見ユーザー30秒理解度はHuman Gateとして未確認維持。mainマージ、契約・課金・一般公開範囲拡大なし。

結論: **再現性検証は2回連続全PASSへ前進したが、品質80点未達のためGAME-076はToDo継続**。


## 2026-10-12 19:22 JST / AutoAI実行 20261012-191933-AUTOAI — 初見ガイド・行動表示の視認性改修

- 正本にて GAME-075=Done・GAME-076=ToDo・他Doingなしを確認し、今回の実行タスク **GAME-076の1件のみ** をDoingで排他取得。既存の2連続CI実入力4/4成功と75/100点の独立暫定品質評価を基準とした。
- `p021-game/sources/orbit-switch-courier-godot/Main.gd` だけをGitHub **develop** に修正反映。コミット: [0334a3a](https://github.com/kobitworks/autoai_poc/commit/0334a3a4395359ee974de685941f207141da1fe7)、blob SHA `5458e9f7bc7a3f7d3d032532a65478f359431a1c`（connector独立read-backで内容一致）。main、課金、有償サービス、本番化の変更なし。
- 初見3行を短い手順へ変更し、表示希望サイズを13→16 CSS px相当に拡大。描画可能幅を超える場合は12pxまで自動調整する `_draw_center_fit_text` を導入した。
- ゲーム盤面下の操作案内を36px高さの高コントラスト帯にし、実際に操作可能な `TAP NOW` の瞬間だけ緑色表示・17px優先文字で明示。既存のゲーム操作可能判定 `_near_action_prompt` に依存し、成功判定/コマンドや位置状態は改変していない。
- 右情報欄では実操作可能時の `TAP NOW` を優先表示し、広い横画面の説明を簡潔化、文字色/サイズ(13→14px)を改善。特に横画面での初見案内・次操作認知負荷を対象にした。
- GitHub commit diffは `Main.gd` **1ファイルのみ**であることを独立確認。Web版CIは新コミット [run 38235947964](https://github.com/kobitworks/autoai_poc/actions/runs/38235947964) に自動起動、`contract` はsuccess、`export-web` は実行中（19:22 JST確認時点）。新コードのGodot import/export、4 viewport browser-quality 実入力E2E、スクリーンショット比較、10軸再採点は**未確認**であり、以前の別コミットのPASSを新コードのPASSと混同しない。
- 実機スピーカー/イヤホン・初見ユーザー30秒操作・FPS・発熱は Human Gate に残す。公開品質80/100には**未到達/未認定**。タスクは未完了のため**ToDoへ戻して次回継続**とし、作業を他Taskへ切り替えない。

### 再開点
1. 上記新コミットのrun 38235947964を最終読戻しし、contract/export-web/browser-quality各ジョブを判定。失敗時は失敗ログを確認し `GAME-076` 内で修正する。
2. 4 viewportの実際のタップ/クリックでNIGHT3件→ACE6件到達、SOUND ON/OFF・RETRY・BEST保存を確認。QAコマンドやゲーム状態直接書換で合格を偽装しない。
3. 画像（スマホ縦横、タブレット縦横の初見・通常・成功・結果等）を独立比較し10項目の品質を再評価する。80点未満なら同タスク改善を継続し、実機人間確認Gateは未検証扱いのまま維持する。
