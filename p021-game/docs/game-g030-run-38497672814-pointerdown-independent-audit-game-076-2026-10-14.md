# GAME-076 / GAME-G030 — RUSH実入力の独立証跡監査（2026-10-14）

- 実施: AutoAI Runner 2026-10-14 11:15〜 JST（本監査はGAME-076の継続1件のみ）
- 対象リポジトリ: `kobitworks/autoai_poc`、`develop`、変更対象は本監査記録のみ
- 原則: 成功コマンド・ゲーム状態直書きは禁止。実画面へのtouch/mouse自然入力で判断。mainマージ・本番・課金・実機評価の代行なし。

## 1. 比較した実行

| 項目 | 前回（失敗） | 今回（成功） |
|---|---|---|
| Actions | [38490620078 attempt 2](https://github.com/kobitworks/autoai_poc/actions/runs/38490620078) | [38497672814](https://github.com/kobitworks/autoai_poc/actions/runs/38497672814) |
| HEAD | `15139e2eb47d4575d41acd5488302d2b55773fff` | `ae448b999037c6e9e2a91d2e0584e5a99f98f4e4` |
| contract / export-web / browser-quality | success / success / failure | success / success / success |
| 実入力E2E 4 viewport | 3 PASS / 1 FAIL（tablet-portrait） | **4 PASS / 0 FAIL** |
| artifact ID | `11863379652` | `11864439352` |
| ZIP SHA256 | `3e13b4ba25a05af2a902304abe2cc27b184a5387258150d2c09e4af5613eaa20` | `152666ab03ca66511bdad6ffe758d30f5d8d73bd315b3adeb2ea1603959288c7` |
| ZIP実体の独立取得・検査 | 53ファイル（51 PNG + 2 JSON）、CRC正常 | 60ファイル（58 PNG + 2 JSON）、CRC正常 |

双方のZIP実体をGitHub Actions artifactから取得し、ローカルSHA256をGitHub公開digestと照合して一致。今回の58 PNGは全件デコード・検証成功、`results.json`を読戻し。途中段階の`results-checkpoint.json`は合否の正本に採用しない。今回の16画像（4画面×INTRO/PLAYING/RUSH/RESULT）は一覧で目視し、明白な主要導線の隠れ・画面間の破綻は認めなかったが、実機での文字可読性やタップ誤操作は判定外。

## 2. 今回の実イベント計測（RUSH 0→1）

実イベント発生時にpassive listenerが読み取った`pointerdown`の角度・残時間と、QA入力呼出所要時間を比較した。計測は観測専用で、ゲーム物理、状態、合否条件を変更しない。

| viewport | 入力 | pointerdown角度(rad) | 貨物残秒 | 入力呼出ms | 自然入力E2E |
|---|---|---:|---:|---:|---|
| phone-portrait 390×844 | touch | 4.479 | 11.31 | 110 | PASS |
| phone-landscape 844×390 | mouse | 4.329 | 11.36 | 3 | PASS |
| tablet-portrait 768×1024 | touch | 4.550 | 11.46 | 217 | PASS |
| tablet-landscape 1024×768 | mouse | 4.537 | 11.28 | 72 | PASS |

今回観測された4角度は物理ウィンドウの目安4.50±0.19rad（4.31〜4.69）に収まる。自然入力のRUSH経路判定は`results.json`上すべてPASS、energy3保持。実験では小型3画面のINTRO/START配置geometryも3/3 PASS（案内とSTARTの間隔7/17/22 CSS px）。

## 3. 前回失敗との比較と未確定点

前回attempt2のtablet-portraitでは、RUSH 0→1で`waitForFunction: Timeout 3500ms`、energy3→2、orbit0 / delivery1のまま失敗。read-only近傍サンプルは角度4.458rad、inputCall=221msだったが、当時は実`pointerdown`角度を計測しておらず、要求角度と物理発火角度を同一視できない。今回のtablet-portraitはinputCall=217msと似た遅延でも実`pointerdown`4.550radで成功した。よって「入力呼出時間の長さだけが原因」とは断定できない。時間依存・フレーム進行・入力到達のずれ等は**仮説**にとどめる。

**今回1回の成功でフレーク解消は確定しない。** 今回は診断用受動ログを追加した別HEADであり、QA観測の因果関係と長期安定性は未立証。失敗再現時に`pointerdown`角度・時刻、ゲーム側実判定、サンプル間隔を照合する。

## 4. GAME-076継続判定と次回再開点

- 最新HEADのCI 3/3成功、自然操作4/4 PASS、追加geometry3/3 PASS、証拠ZIP/PNG/JSON整合性PASSを確認。
- ただし暫定品質は従前の**76/100を据え置き**（今回の機械テスト成功だけで80点へ加点しない）。ゲーム体験の独立10軸再採点は未完了。
- 実機Human Gate：初見30秒の正しい操作、iOS/Androidの縦横、文字可読性、誤タップ、スピーカー/イヤホン実音、FPS・発熱を未検証として維持。重複するSlack確認依頼は送信しない。
- 次回は同HEADで自然入力を複数回反復し、特にtablet-portraitの`pointerdown`角度とRUSH合否を比較。フレーク再発時は受動診断で原因切り分け。実機結果を得た後に10軸品質を独立再採点し、80点未満なら改善を継続。
- 本回はGAME-076以外のタスクを開始しない。GAME-076は未完了につき実行メモを更新して`ToDo`へ復帰する。


## 5. 同一HEADでの再実行 attempt 2（2026-10-14 11:45–11:50 JST）

- 対象: [Actions run 38497672814 attempt 2](https://github.com/kobitworks/autoai_poc/actions/runs/38497672814)、同一ゲーム/QA HEAD `ae448b999037c6e9e2a91d2e0584e5a99f98f4e4`。今回実行したのは既存browser-qualityジョブの再実行のみで、ゲーム本体とQAコードは変更していない。
- job 115652948555（browser-quality）= completed/success。contract / export-web / browser-quality は3/3 success。
- ジョブログから機械可読な最終 `results.json` を抽出・パースし、自然なタップ/クリックによる標準4画面実入力E2Eは **4/4 PASS**、小型レイアウト3/3 PASS_GEOMETRY、静的表示コントラクトPASS_STATICと確認。NIGHT 3配達、ACE 6配達、RUSHのenergy=3維持とACE貨物期限10秒を確認。
- 実 `pointerdown` イベント（passive listener、状態変更なし）のRUSH 0→1角度は以下。ゲーム側の判定窓の目安4.31–4.69 rad内に全件収まる。

| 画面 | 入力 | 今回pointerdown角度(rad) | 入力呼出ms | 判定 |
|---|---|---:|---:|---|
| phone-portrait 390×844 | touch | 4.468 | 103 | PASS |
| phone-landscape 844×390 | mouse | 4.387 | 36 | PASS |
| tablet-portrait 768×1024 | touch | 4.555 | 216 | PASS |
| tablet-landscape 1024×768 | mouse | 4.510 | 70 | PASS |

- 直前attempt 1の同列角度4.479 / 4.329 / 4.550 / 4.537 radと比較して両回4/4 PASS。ただし過去run 38490620078 attempt 2のtablet-portrait失敗原因は未特定であり、**2回の成功で偶発失敗の根絶を断定しない**。今回tablet-portraitの入力呼出216msでも成功したため、遅延時間の長さだけが根因とは判断しない。
- attempt 2のGitHub公開artifact metadata: ID `11866865251`、名前 `p021-game-g030-real-input-evidence`、digest `sha256:c026b935cae19a3b8dd8119babb8cc9e51efa487378474c98b7d95c86c1135e7`。本補遺はジョブログ内のJSONを読み戻した監査であり、**attempt 2のZIP本体SHA256照合・PNG独立目視は今回未実施**。attempt 1のZIP検証結果を今回分に流用しない。
- 品質は**独立暫定76/100のまま**、目標80未達。実機Human Gate（初見30秒、縦横の文字可読性、誤タップ、スピーカー/イヤホン音、FPS・発熱）も未確認。前回通知済みの同一確認依頼は重複送信しない。
- 次回は同HEADの自然入力反復とRUSHの偶発失敗監視、必要に応じてartifact ZIP/画面証跡の独立監査、実機確認後の10軸再採点。タスクは未完了としてToDo継続。mainマージ、本番変更、有償利用、二件目の実行はなし。

## 6. attempt 2 artifact ZIP 実体の独立検証（2026-10-14 12:16 JST / GAME-076継続）

前回セクション5で未検証とした attempt 2 の成果物本体をGitHub Actionsから**今回新たにダウンロード**し、ZIP実体・JSON・PNGを独立に検査した。ゲームコード/QAスクリプトや合否基準は変更していない。

- 対象: [run 38497672814 attempt 2](https://github.com/kobitworks/autoai_poc/actions/runs/38497672814)、head `ae448b999037c6e9e2a91d2e0584e5a99f98f4e4`、artifact **11866865251** `p021-game-g030-real-input-evidence`。
- 実取得ZIPサイズ **4,371,347 bytes**、ローカルSHA-256 **`c026b935cae19a3b8dd8119babb8cc9e51efa487378474c98b7d95c86c1135e7`**。GitHub artifact metadata の `digest` と完全一致。
- アーカイブ全件整合性 `zipfile.testzip() = None` / `unzip -t` 全件OK。計 **60ファイル = PNG 58枚 + JSON 2件**。PNG 58枚はPillowで**全件デコードおよびverify成功**。
- 標準4 viewport は各13枚（**52枚**、phone portrait 390×844 / landscape 844×390、tablet portrait 768×1024 / landscape 1024×768）。追加小型3画面は各2枚（**6枚**、320×568 / 667×375 / 800×600）。期待する画像種別・枚数との一致を確認。
- `results.json` を読込んだ最終結果: 標準4画面の自然なtouch/mouse実入力E2E **4/4 PASS**、小型レイアウト **3/3 PASS_GEOMETRY**、visualContract **PASS_STATIC**。自然入力でNIGHT 3配達→ACE 6配達を各画面で確認。4画面すべて `qaCommand=NEVER USED` / `stateOverride=NONE`。ACE到達時energy=3、BESTの結果・復元・localStorage一致はそれぞれ 1108 / 1111 / 1102 / 1108。
- RUSH 0→1の受動 `pointerdown` 角度はphone縦 **4.468**、phone横 **4.387**、tablet縦 **4.555**、tablet横 **4.510 rad**、4件とも実イベント計測で判定窓4.31〜4.69rad内。各E2EはPASS、過去の偶発失敗根因は依然未特定。
- `results-checkpoint.json` は `PARTIAL_CHECKPOINT_NOT_FINAL` を明記しており、**最終品質判定には使わず**、`results.json` の最終出力を正本として照合した。
- PNGの独立目視: 各標準画面のINTRO/PLAYING/RUSH/ACE（計16枚）と、初回タップガイド/長文キュー/残り3秒警告（計12枚）の合計**代表28枚**を一覧で確認。初回ガイドの緑色表示、貨物期限3秒未満での強調表示・`HURRY` の画面上の存在を確認。全体的な表示崩れ・主要UIの画面外逸脱はこれらの縮小画像では明白でない。ただし細かな日本語の可読性・実タッチの誤操作・実音・実端末FPS/発熱については**画像だけではPASS扱いしない**。
- この回で証拠ZIP未検証という不足は解消。一方、**品質暫定76/100（目標80未達）**、tablet縦RUSH偶発失敗の再現性・根因、実機Human Gateは未解決。次回は複数回自然入力反復で再現性を評価し、実機の30秒導入・音声・可読性・誤タップ・FPS/発熱の結果が得られれば10軸再採点する。
- 監査対象は既存 **GAME-076の継続1件のみ**。main変更・本番公開・有料利用・他タスクの実行はない。未完了のためGAME-076はToDo継続。

## 7. 同一HEADの実入力反復・第3回（2026-10-14 13:06 JST / AutoAI GAME-076）

- 本回は GAME-076 1件のみを選定。前回記録で未検証とした **RUSH偶発失敗の再現性** を調べるため、既存run [38497672814](https://github.com/kobitworks/autoai_poc/actions/runs/38497672814) の browser-quality job 115652948555 を GitHub Actions API で再実行要求し、success=true の応答を受領した。
- 再実行から新しい browser-quality job **115675057422** を確認。記録時 status=in_progress / conclusion未定。再実行対象は同一元ゲーム/QA HEAD \`ae448b999037c6e9e2a91d2e0584e5a99f98f4e4\`。contract job 115675057423 と export-web job 115675058687 は completed/success。**browser-quality の最終合否、自然入力4 viewportのPASS/FAIL、tablet縦のRUSH再発有無、artifact ZIP/PNGはまだ未検証**。旧attempt 1/2の4/4 PASSを今回の合格とは扱わない。
- 実験条件の継続: QA成功コマンド・状態直書きの禁止、touch/mouse通常入力、NIGHT3→ACE6、BEST保存再読込、音ON/OFF、RUSHの実pointerdownイベント角度を結果と照合する。新job完走後には \`results.json\` の最終JSONと実ZIPを再確認する。
- 独立暫定品質 **76/100（目標80点未達）**、実機Human Gate（初見30秒、iOS/Androidの可読性と誤タップ、スピーカー／イヤホン音、FPS・発熱）は未確認。今回はゲーム本体・QAスクリプト・main・本番・課金・承認待ち事項を変更していない。同一理由のHuman Gate依頼は重複送信しない。
- 今回未完了のためタスクGAME-076をToDoへ戻し、次回は job115675057422 の終了結果から再開する。2件目には着手しない。

## 8. attempt 3 の独立 ZIP・自然入力・画面監査（2026-10-14 13:35 JST / AutoAI GAME-076）

今回の1実行では、前回13:08時点で未確定だった同一HEADのGitHub Actions run [38497672814](https://github.com/kobitworks/autoai_poc/actions/runs/38497672814) attempt 3（新job `115675057422`）の結果を**新たに確認・検証**した。再実行要求は前回の処理で行われており、今回は新たな再実行やゲーム/QAソース変更を行っていない。

- GitHub Actionsの当該attempt: contract `115675057423` / export-web `115675058687` / browser-quality `115675057422` はすべて `completed/success`。過去attemptの結果を今回の結果に流用していない。
- 当該attemptのartifact **11869452028**（`p021-game-g030-real-input-evidence`）のZIP本体を新たに取得。実体 **4,377,772 bytes**、SHA-256 **`5384ea6579f4e501c0f6b97dfa3509333a75191defb42416af6556f9109af183`**。GitHub metadata の digest と完全一致。
- ZIPのCRCは全件正常。**60ファイル=58PNG+2JSON**、全58枚PNGの画像デコード/verify完了。各標準画面13枚×4＋小型画面2枚×3で構成。
- 合否の正本は `results.json` を使用。`results-checkpoint.json` は `PARTIAL_CHECKPOINT_NOT_FINAL` のため合否に使用しない。visual contract `PASS_STATIC`、自然touch/mouse START→RUSH→NIGHT(3配達)→ACE(6配達)の4 viewport **4/4 PASS**、小型3画面 **3/3 PASS_GEOMETRY**。各画面 `qaCommand=NEVER USED`、`stateOverride=NONE`、ACE到達時energy=3、SOUND ON/OFF操作確認、BEST保存/再読込/localStorage一致をJSONで確認。
- 主な自然入力／RUSH 0→1の実`pointerdown`受動観測（rad、投入時間ms、BEST）:

| viewport | 入力 | pointerdown rad | inputCall ms | BEST/復元 | 判定 |
|---|---|---:|---:|---:|---|
| phone portrait 390×844 | touch | 4.491 | 106 | 1108/1108 | PASS |
| phone landscape 844×390 | mouse | 4.404 | 40 | 1110/1110 | PASS |
| tablet portrait 768×1024 | touch | 4.599 | 212 | 1103/1103 | PASS |
| tablet landscape 1024×768 | mouse | 4.539 | 72 | 1108/1108 | PASS |

4件とも有効物理判定域の目安4.31–4.69rad内。tablet portraitの今回値4.599radは前回attempt2の4.555radより後寄りだが許容域内でPASS。自然入力3回連続成功は肯定的だが、過去tablet portrait RUSH失敗の根因の解消・無再発を**断定しない**。同端末の212msも失敗の必要十分条件とは結論しない。

画像28枚（4画面×INTRO/PLAYING/RUSH/ACE=16枚、4画面×初回タップ案内/長文cue/残り3秒警告=12枚）を縮小コンタクトシートで独立目視。明白な主要領域逸脱・初見導線消失は見られず、案内と警告表示を確認。ただし縮小画像から実機日本語可読性・誤タップ・スピーカー/イヤホン実音・FPS/発熱をPASSとは判定しない。

**結論:** GAME-076 は目標80/100を満たさず、独立暫定品質**76/100**のまま継続。実機の初見30秒・縦横画面読みやすさ・誤タップ・音・FPS/発熱はHuman Gate未確認。既通知の同一Human Gateを重複依頼せず、GAME-076は今回の実行後 `Doing→ToDo` に戻す。次回は実機結果の有無を先に確認し、なければtablet portraitの自然入力/RUSHを異なる環境・反復条件でさらに観測して原因を絞る。ゲーム本体/QAコード、main、本番公開、課金、二件目の実行はいずれも変更なし。

## 9. 同一HEAD 自然入力第4反復開始（2026-10-14 14:03 JST / AUTOAI-GAME076-20261014-1402）

- 本回の実タスクは **GAME-076 の1件のみ**。13:38までの同一HEAD `ae448b999037c6e9e2a91d2e0584e5a99f98f4e4` の3回連続4 viewport自然入力E2E PASS・小型3画面幾何PASS、ただし2026-10-14 10:45以前のtablet portrait RUSH偶発失敗は根因未確定である点を先にFresh-readした。
- GitHub Actions [run38497672814](https://github.com/kobitworks/autoai_poc/actions/runs/38497672814) のbrowser-quality **job115675057422** の再実行を要求し、GitHub API応答 `success=true` を得た。**attempt 4** の新job **115690367593** が `in_progress`、contract **115690367859** と export-web **115690368904** は `completed/success` を14:03時点に確認。**attempt 4のbrowser-quality最終合否、自然入力4画面・RUSH pointerdown・ZIP/PNG・BEST/SOUNDは、結果未確定のためPASSとは記録しない。**
- 今後の診断仮説（未実証）: orbit0の回転約1.12rad/s、観測band上端4.47rad、ゲーム許容上端4.69radでは、観測から実際のpointerdownまで約0.20秒以上の前イベント遅延があると判定窓外に進む可能性がある。一方、`inputCallMs` は送信〜完了までの全呼出時間であり前イベント遅延そのものではないため、単純な角度加算で原因確定しない。新実pointerdownイベントの角度・時刻と観測角度・観測窓スキップ・energy/転送成否を比較して検証する。実ゲーム仕様や成功判定は変更しない。
- 評価保留: **独立暫定76/100（一般公開目標80未達）**。実機初見30秒・iOS/Android日本語可読性/誤タップ、スピーカー/イヤホン実音、FPS/発熱はHuman Gate未確認。既通知の重複依頼は送らない。ゲーム/QAソース、main、本番、課金を変更せず、結果確定後は本節へ追記して再評価する。


## 10. 第4回反復の最終結果と自然入力診断（2026-10-14 14:51:16 JST / AutoAI GAME-076）

- 対象は **GAME-076 の継続1件のみ**。前回14:05時点で未確定だった [run 38497672814](https://github.com/kobitworks/autoai_poc/actions/runs/38497672814) の **attempt 4** を新規にFresh-read。browser-quality job `115690367593`、contract job `115690367859`、export-web job `115690368904` は全件 `completed/success`。再実行要求自体は前回の操作で、今回は行っていない。
- browser-quality job の最終ログに含まれるJSON全体を時刻プレフィックスを除いて再パースした。自然 touch/mouse 操作（成功コマンド・状態直書きなし）で標準4 viewport **4/4 PASS**、小型3 viewport **3/3 PASS_GEOMETRY**、静的表示コントラクト **PASS_STATIC**。NIGHT 3配達→ACE 6配達、ACE時energy=3、SOUND OFF/ON、BEST再読込を試験項目として保持。各画面 `qaCommand=NEVER USED` / `stateOverride=NONE`。
- RUSH 0→1 の実 `pointerdown` 受動計測（ゲーム判定窓の目安 4.31〜4.69 rad）：

| viewport | 入力 | 実pointerdown角度rad | inputCallMs | 判定 |
|---|---|---:|---:|---|
| Phone縦 390×844 | touch | 4.428 | 104 | PASS |
| Phone横 844×390 | mouse | 4.380 | 37 | PASS |
| Tablet縦 768×1024 | touch | 4.596 | 147 | PASS |
| Tablet横 1024×768 | mouse | 4.442 | 73 | PASS |

- Tablet縦の4.596 radは判定上端4.69 radとの差が約0.094 radであり、入力イベント前の角度進行が変化した場合に判定境界を越える**可能性**を残す。ただし今回の合否はPASSで、過去の偶発失敗の原因は断定できない。Tablet横は75ms読取観測帯内サンプル0件でも、実pointerdown角度4.442 radで成功しており、受動観測サンプル数をゲーム成功判定に混同しない。
- 今回新たに作成されたartifact: [11871805363](https://github.com/kobitworks/autoai_poc/actions/runs/38497672814/artifacts/11871805363)、`p021-game-g030-real-input-evidence`、GitHub metadata 4,376,779 bytes / `sha256:226c48fc115b4cc5e275c364fa0fe76f6bbc4b7785bad3c0b4b76fa50171f3ff`。ジョブログでは60ファイルのupload完了と同digestを確認。**今回はZIPバイナリ実体の独立SHA照合・58枚PNGの目視検証は未実施**（メタデータ一致と実体独立検証を区別）。
- 同一ゲーム/QA元HEADの第1〜第4回反復は自然入力4/4 PASSを記録。ただし過去の別runにTablet縦RUSHの偶発失敗があり、一般利用時の無再発性・人間が初見30秒で操作できるかは**未立証**。同一条件の反復テストのみを追加して品質スコアに加点しない。
- 継続判定: 独立暫定品質 **76/100**（目標80未達）を維持。実機の初見30秒・日本語可読性・誤タップ・スピーカー/イヤホン音・FPS/発熱はHuman Gate未確認。次の開発サイクルでは、反復テストの継続よりも、実機の初見導線／操作タイミング余裕の人間観察と、得られた結果に基づくゲーム体験の具体改善・10軸再採点を優先。機械検証のみではDoneにしない。同一内容の確認Slackを重複送信しない。ゲーム/QAソース、main、本番公開、有料利用、他タスクの実行は変更なし。
