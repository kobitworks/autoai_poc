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


## 2026-10-13 12:01 JST / AUTOAI-GAME076-20261013-1151 — 安定性再検証と旧artifact実画像独立監査（今回の1件）

- 共通Runner v1.38.0、P021 v1.2.0をFresh-read。依存GAME-075=Done、GAME-076=ToDo、他Doingなしを正本で確認し、本タスクのみDoing排他取得。先行PJは人間確認・前提・周期制約で着手なし。監視は09:21:17実施済み、Slack新規明示@autoaiなし。
- **同一ゲーム／QAコード再試行:** [Actions run38335126979](https://github.com/kobitworks/autoai_poc/actions/runs/38335126979) のbrowser-quality旧成功job115093687536を再実行。新job **115106905929**、attempt2。12:00:50 JSTではbrowser-quality=in_progress、contract/export-web=success。終了まで新E2EをPASS扱いしない。ゲーム/QA/main/課金/本番設定変更なし。
- **旧attempt1の独立ZIP検査:** [artifact11785345059](https://github.com/kobitworks/autoai_poc/actions/runs/38335126979/artifacts/11785345059) を取得。ZIP SHA256=b04fbbeb2de4868d7bf49bb4dbc0419dd427dab14cd67127815c061c401d0afc、CRC正常。**52 PNG（4 viewport×13状態）+ results.json**を検証。JSON SHA256=cdfe4dc1342d2ccf6d9ff6a1a2cfedac44d5496271706ce3d56b351cb3789bd5。前回文書で未確認だった実画像を今回初めてレビューした。
- **代表16PNG目視:** phone縦390×844、phone横844×390、tablet縦768×1024、tablet横1024×768の各intro / cue-stress / cargo-warning-3s / route-aceを確認。代表画像では致命的な画面外欠落は認めず、残り3秒の赤い警告と上位ルート／緑のアクション表示を確認した。ただし**全52枚を独立目視したわけではない**。
- **具体的UI改善候補:** phone横の最下段2ステップ説明が高さの少ない領域へ密集し補助文字が小さい。tablet横は右パネル「HOW TO PLAY」/「ROUTE MILESTONES」/最下段2行説明が近接し視線誘導が弱い。phone縦ROUTE/ENERGY等の小ラベルも初見可読性に疑問が残る。静的PASS_STATICは実機可読性を証明しない。
- **旧results.jsonのRUSH受動時系列再集計:** 4画面sample数=32/32/25/24、壁時計観測=2324/2327/2066/2063ms、最大サンプル間隔=106/112/125/127ms。angle開始1.851/1.813/2.225/2.190→終了4.401/4.344/4.386/4.330rad、全画面energy3・orbit1。NIGHT自然3配達→ACE自然6配達、SOUND ON/OFF、RETRY、BEST再読込4/4 PASS、得点1109/1111/1108/1110。qaCommand=NEVER USED / stateOverride=NONE。
- **品質:** 独立暫定76/100据置。以前のtablet縦RUSH 18秒タイムアウトは成功1回では根因解消を保証しない。実機音（スピーカー/イヤホン）、初見30秒、タッチ誤操作、実機可読性、FPS/発熱は未検証Human Gate。80点・一般公開品質は未認定。
- **次回:** 新attempt2の最終job/ZIP画像/JSONを旧トレースと比較。間欠FAILならwall/mono/angle/cargo/energy差で切り分け、必要最小修正と4画面実入力QAを行う。右欄密度・小文字の改善後、独立10軸を再採点。今回別タスクなし。完了未達でToDoへ戻す。


## 2026-10-13 12:50 JST / AUTOAI-GAME076-20261013-1242 — attempt2キャンセルの実証確認と部分証跡保全

- 今回のRunnerで選定・実作業したのは **P021 GAME-076の1件のみ**。GAME-075=Done、GAME-076=ToDo、他Doingなしを確認してDoingへ排他取得した。日次全体監視は09:21実施済み、対象Slackで12時以降の新規明示@autoaiなし。P010〜P020は未解除のHuman Gate、依存、日次実行条件などにより対象外。
- [run38335126979](https://github.com/kobitworks/autoai_poc/actions/runs/38335126979) attempt2の最新ジョブをFresh-read。contract(job115106931100)とexport-web(job115106932967)=completed/success、一方 **browser-quality(job115106905929)=completed/cancelled**。通常の4画面 simulated smoke はsuccessだが、実タップ／クリックE2Eのステップは途中cancelled。ログでは2026-10-13 12:18:39 JSTに `The operation was canceled`、理由の確定証拠はない。**attempt1の全画面PASSをattempt2のPASSと混同しない**。
- [attempt2 artifact11786886251](https://github.com/kobitworks/autoai_poc/actions/runs/38335126979/artifacts/11786886251)をZIPとして実体取得して検証。SHA-256=`bf8480926246289bb319b06ab7df31db54286be4bbfe1cd00c3b8a91f51990d4`、ZIP CRC正常。**50PNGのみ、results.jsonなし**。phone縦/横、tablet縦の各13状態が揃う一方、tablet横は11状態（cue-stressとcargo-warning-3s欠落）。この部分証跡だけでは最終成否を確定できない。
- 代表11PNG（phone縦/横/tablet縦のintro・残3秒警告・ACE、tablet横のintro・ACE）を独立目視。代表画面に致命的な画面外欠落は認めず、上位ルート・警告の表示を確認。phone横下段補助文字、tablet横右パネルの小文字・密集、実機初見可読性は改善課題として残す。**50枚すべて目視したとは記録しない**。
- 今回の原因切分け: QAコードは `results.json` を4画面ループ終了後に初めて作成するため、途中cancelled時に機械可読な部分結果が欠損する。対策として、[develop commit e09240a](https://github.com/kobitworks/autoai_poc/commit/e09240a80447387ae83ad8e42dbdf0bccd2e5c08)で `p021-game/qa/orbit-switch-courier-real-input.js` のみを修正。`results-checkpoint.json` に `STARTING`、各 `VIEWPORT_RUNNING`、各 `VIEWPORT_COMPLETED` を逐次記録し、件数・viewport・個別 evidence を保存する。**PARTIAL_CHECKPOINT_NOT_FINAL** と明示し最終合格の代用にしない。通常の `results.json` 生成、実入力、スコア、物理判定、ゲームロジックは不変。readback blob SHA=`bfe784efe00a8e73e84693e3285ffa6e11461d21` を照合済み。
- **未検証:** 新しいcheckpoint実装のCI実行・完走、次回runでの部分JSON出力と4画面実入力完走、attempt2キャンセル原因、ゲーム実機スピーカー/イヤホン、初見30秒行動理解、視認性、FPS/発熱。品質独立暫定**76/100据置き**、80点・一般公開品質未認定。GAME-076は要件未達のためToDoへ復帰し次回継続する。mainへのマージ、課金、本番・公開範囲変更なし。
- **次回:** 新checkpoint付きrunの結果をreadbackし、cancelled/timeout/並行実行の原因を特定、必要ならテスト実行時間・隔離方針を改善する。次いで4 viewport NIGHT3→ACE6の実入力、保存・音声切替、全画面の証跡と10軸独立採点を確認。Human Gateは未解決のまま人間の実機確認を待つ。


## 2026-10-13 13:15 JST / AUTOAI-GAME076-20261013-1308 — checkpoint導入後の4画面CI・証跡独立検証

- このRunnerで実タスクとして選定・着手したのはP021 GAME-076の1件のみ。共通Runner v1.38.0・P021 v1.2.0をFresh-readし、GAME-075=Done / GAME-076=ToDoを確認してDoing排他取得。日次監視09:21済、新規明示@autoai指示なし。先行PJは承認・依存・周期条件で着手せず。
- 前回のcancelled run38335126979/attempt2とは**別**に、checkpoint修正commit \`e09240a80447387ae83ad8e42dbdf0bccd2e5c08\` のpushから自動起動した [run38343537253](https://github.com/kobitworks/autoai_poc/actions/runs/38343537253) をFresh-read。contract(job115119659742), export-web(job115119707337), browser-quality(job115119979468) は**3/3 completed/success**。ブラウザ4画面の実タップ/クリックE2Eは全件PASS。旧cancelled実行をPASSへ読み替えていない。
- 新artifact [11788276184](https://github.com/kobitworks/autoai_poc/actions/runs/38343537253/artifacts/11788276184) をZIP実体としてダウンロード・独立検証。**SHA256=113966ff87608bbdd43ecc277229962c4cfafe145e8b3c648b695ffae421cef3**、ZIP CRC不良なし、**全54ファイル：PNG 52枚（phone縦/横、tablet縦/横各13枚）、results.json、results-checkpoint.json**。途中checkpointはstatus=PARTIAL_CHECKPOINT_NOT_FINAL、最終phase=VIEWPORT_COMPLETED、completedViewportCount=4、expectedViewportCount=4。一方results.jsonは別途存在する正規最終証跡。checkpointだけでPASSを代用しない設計が確認できた。
- 最終JSONから実入力で**4/4 PASS**、全画面**RUSH1→NIGHT3→ACE6**到達、QA success command=NEVER USED、stateOverride=NONE。音声切替soundOff/soundOn、リトライ、BEST保存→再読込が4/4。ACE配達6件時点の得点はphone縦1109、phone横1110、tablet縦1104、tablet横1109。ENERGY=3で上位ルートへ到達し、3秒以下の貨物警告画像も4/4保存。
- 4 viewport×4状態（intro/cue-stress/cargo-warning-3s/route-ace）の**代表16PNGを独立目視**。代表画像では致命的な画面外欠落なし、警告と上位ルート表示を確認。ただし**全52枚を目視したわけではない**。phone横の下段2ステップ補助説明、tablet横のHOW TO PLAY/ROUTE MILESTONESと右下ガイドが情報密集し、初見・実機可読性は未認定。
- 新checkpoint実装を含めてCI上の成功と証跡欠損改善を実証。前回のcancelled事象の原因と長時間実行の偶発FAILは未確定。実機スピーカー/イヤホン聴感、初見ユーザー30秒、タッチ誤操作、端末可読性、FPS/発熱は**Human Gate未検証**であり、静的contrast PASSを実機PASSに昇格させない。
- **10軸独立品質の暫定値は76/100を維持（目標80未達）**。GAME-076は完了条件未達のため次回継続としてToDo復帰。次回はphone横下段とtablet横右欄の視認性・情報階層を対象に最小変更し、CIの4viewport実入力/52PNG・10軸再評価、実機Human Gateを確認。今回ゲーム本体、main、有償利用、本番範囲・公開範囲の変更はなし。


## 2026-10-13 13:41 JST / AUTOAI-GAME076-20261013-1334 — 横画面の重複説明・ガイド重なりを抑制（今回の1件）

- 共通Runner v1.38.0、P021 rule v1.2.0をFresh-readし、日次全体監視09:21:17済、新規の明示的な @autoai 投稿なしを確認。P005〜P018/P020には今回は実行可能な通常タスクがなく、GAME-075完了・GAME-076 ToDo・他Doingなしを確認してGAME-076だけをDoingに変更した。
- **ソース変更**: [develop commit 4b130aa](https://github.com/kobitworks/autoai_poc/commit/4b130aab1fb1e80209301d9e96a025c1c33916cb)。対象は `sources/orbit-switch-courier-godot/Main.gd` の表示レイアウト1ファイルのみ。source blob `4c19feaa70c24864dfddf1d07df1928181ba8f0c` へ更新し、developの独立readbackと文言・境界値の一致を確認。
- Phone Landscapeの情報欄が220〜239 CSS px相当なら、下部ガイドを高さ24pxの1行表示へ切替。240〜275pxなら従来の2行を使用。275〜470pxの中間パネルでは2行表示を維持。低優先のルート進捗文字を315px未満では省略し、実操作を説明するNEXT ACTIONカードを優先する。470pxより高いTablet Landscape情報欄は中央HOW TO PLAYとROUTE MILESTONESが既に存在するため、末尾の重複した2行ガイドを描かず視線を分散させない。
- **静的配置検査**: 描画コードの縦方向積み上げ値から、panel h=220/230/239/240/255/275/276/300/315/390/470 CSS px相当で、action card下端とhelp帯の先端の差分がそれぞれ3/13/22/5/20/40/22/46/38/113/193pxと全て正。小型Portrait h<220や大きいTablet h>470は当該help帯なし。これは座標計算による静的確認であり、実ブラウザ画像の検査ではない。
- **CI**: 改修コミットに対して [GitHub Actions run38347625531](https://github.com/kobitworks/autoai_poc/actions/runs/38347625531) が自動起動。確認時点でcontract=success、export-web=in_progress、browser-qualityは未完了。ジョブ未完了をPASSとは記録しない。Pages [run38347625180](https://github.com/kobitworks/autoai_poc/actions/runs/38347625180) も確認時点では処理中。CI進捗は次回Fresh-readで確定させる。
- 正規実タップ/クリックによるRUSH1→NIGHT3→ACE6、RETRY/BEST・SOUND、4 viewport実画面、初見30秒、実機スピーカー/イヤホン/FPS・発熱は**このコミット以降の独立確認なし**。直近の別コミットCI成功を今回の改修の合格証明に流用しない。
- **品質判定**: 直近の独立暫定76/100を維持、目標80/100未達。Human Gateは未検証継続。ソースmain、本番化、契約・課金、公開範囲変更なし。GAME-076はDone条件を満たさずToDoへ戻し、次回はrun38347625531の3ジョブと新artifact結果・PNG実画像を再確認し、必要なら最小限の表示修正と10軸の再採点を行う。今回ほかのタスクは実行しない。
