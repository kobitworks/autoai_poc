# GAME-076 / GAME-G030 — 新HEADの自然入力・証跡ZIP独立監査
実施日: 2026-10-15 JST
実行ID: AUTOAI-GAME076-20261015-0002
対象タスク: GAME-076（進行中 / 完了条件未達）
Runner: v1.38.0 / P021 project_rule: v1.2.0

## 1. 検証対象と鮮度
- Repository: `kobitworks/autoai_poc`、`develop` のみ。main、本番環境、課金、公開範囲は変更しない。
- 前回18:04 JST時点で実行中だった [GitHub Actions run 38539286622](https://github.com/kobitworks/autoai_poc/actions/runs/38539286622) を今回Fresh-read。
- 最新job: `contract` = completed/success (115769759485)、`export-web` = completed/success (115769833000)、`browser-quality` = completed/success (115770405526)。
- 最新 source readback: `Main.gd` blob SHA `e25c598a181e99426bc864f8c1e6f61cfe29563a`、実 `SWITCH_WINDOW := 0.23`、`HUB_WINDOW := 0.23`。QA JS blob SHA `110f52c080d4f0f68a0e7b4cc0df3bb63c4ab9d8`、診断はソース定数から受理幅を導出する。

## 2. 証拠の真正性と解析範囲
- [Artifact 11882130836](https://github.com/kobitworks/autoai_poc/actions/runs/38539286622/artifacts/11882130836): `p021-game-g030-real-input-evidence`、4,368,281 bytes。
- ZIPバイナリSHA256 `cb08afc128f2183f6f388df37a9d289cbab48294587f8328b5491f93912524dc` はGitHub artifact metadataのdigestと一致。
- ZIP CRC `testzip` 正常、60ファイル = PNG58枚 + JSON2件。PNG58枚は全てデコード・verify成功。
- 判定は `results-checkpoint.json`（PARTIAL_CHECKPOINT_NOT_FINAL）ではなく、最終 `results.json` を独立パースして行った。CIログの最終JSONとも照合。
- 代表27枚の縮小コンタクトシート、および`phone-portrait-intro.png`を実画像として確認。重大な画面崩れは見られないが、縮小表示・画面画像で実機視認性や可読性の合否は確定できない。警告3秒表示画像の目視PASSも未判定。

## 3. 自然入力E2E最終結果
`results.json` に基づく。ゲームの状態直接設定やQA専用成功コマンドは使っていない。

| 画面 | 自然入力 | 最終判定 | RUSH pointerdown (rad) | 実物理受理端までの最小余裕 | NIGHT / ACE | BEST保存=再読込 |
| --- | --- | --- | ---: | ---: | --- | --- |
| phone 縦 390×844 | touch | PASS | 4.448 | 0.178 rad | 3 / 6 配達 | 1108=1108 |
| phone 横 844×390 | mouse | PASS | 4.384 | 0.114 rad | 3 / 6 配達 | 1111=1111 |
| tablet 縦 768×1024 | touch | PASS | 4.597 | 0.133 rad | 3 / 6 配達 | 1103=1103 |
| tablet 横 1024×768 | mouse | PASS | 4.405 | 0.135 rad | 3 / 6 配達 | 1109=1109 |

- 実受理帯域は4.27〜4.73 rad（4.50 ± 0.23）。4点すべて帯域内。QA観測・トリガ部分帯域4.31〜4.47 radを物理許容範囲と誤認しない。
- 全4画面で `qaCommand=NEVER USED` / `stateOverride=NONE`、NIGHT=3配達、ACE=6配達、SOUND OFF/ON変化とエンジン再生フラグ、保存BESTとリロード後BESTの一致を独立確認。
- 初見first tap guard 4/4 PASS。小型3画面（320×568 / 667×375 / 800×600）は `PASS_GEOMETRY` 3/3で、物理タップ/クリックによるSTART可能を確認。ただし小型画面の文字可読性はHuman Gate。
- `visualContract=PASS_STATIC` は静的文字コントラスト契約のみ。写真での警告、連続プレイ、スピーカー実音や初見ユーザーの理解を保証する判定ではない。

## 4. 合格していない・未確認の事項
- **独立暫定品質76/100（前回値を維持、80点以上の一般公開品質を未認定）。** 今回のCI正常終了は追加の技術証拠であって、スコアの自動加算理由ではない。
- 実端末での初見30秒理解、指の誤タップ、文字可読性、スピーカー・イヤホン実音、FPS・発熱、縦横回転後UIは **未検証 Human Gate**。
- Tablet縦のRUSH入力は今回成功し最小余裕0.133radだったが、単一成功だけで過去の偶発失敗の根因解決・再現性を断定しない。
- 3秒貨物警告は画像取得済みだが実端末での視認性と独立フルサイズ画面評価は未確定。
- 既通知済みの実機確認依頼は重複通知しない。

## 5. 次回再開点・タスク状態
1. 実機フィードバック回答の有無を確認し、取得できれば未検証Human Gateを各軸に反映。
2. 未回答なら `GAME-076` の範囲内で、自然入力の反復によるRUSHの安定性確認と小型表示の文字・警告改善を検討する。証拠は毎回新しいHEAD/attemptで独立評価。
3. 10軸を根拠付き再採点し、80点到達および必要な受入条件確認まで `GAME-076` は `ToDo` のまま継続。2件目のタスクに進まない。

この監査回ではゲーム本体/QAコードの変更なし。監査文書のみ `develop` に追加。

## 6. 追加反復監査: browser-quality再実行 (2026-10-15 01時台 JST)
- 00:50 JSTに再実行依頼した `browser-quality` の新job `115951596197` は `completed/success`。同一Actions run `38539286622` の `contract=success` (115951596616) / `export-web=success` (115951597947) も読戻し確認、3/3成功。
- 新jobの**最終ジョブログ内JSON**を独立抽出・パース。従前attemptの成果ではなく、新jobの結果として自然touch/mouse実入力を標準4画面で4/4 PASS、コンパクト3画面を3/3 PASS_GEOMETRY、静的コントラスト契約 `PASS_STATIC` と確認。
- `NIGHT` 到達3配達、`ACE` 到達6配達、各画面energy=3、SOUND OFF/ON切替、BESTを保存して再読込一致。4画面いずれも `qaCommand=NEVER USED`、`stateOverride=NONE`。
- 再実行の `RUSH` 実pointerdown角度: phone縦 **4.418**、phone横 **4.349**、tablet縦 **4.464**、tablet横 **4.358** rad。ゲーム実物理受理帯域4.27〜4.73 radの内側であり、最小端余裕は順に約0.148 / 0.079 / 0.194 / 0.088 rad。QA観測用部分帯域4.31〜4.47 radとは区別する。
- 新artifact [11908064802](https://github.com/kobitworks/autoai_poc/actions/runs/38539286622/artifacts/11908064802) はGitHub metadataで4,354,766 bytes / SHA256 `e51e7b2b82ed6f16cab870a4e99f79458f0da03d9a59c9dc4eba624f1e15a096`、uploadログ60ファイルを確認。**今回のZIPバイナリSHA/CRC/58PNG独立デコード・目視は未実施でありPASS宣言しない。** 旧artifact11882130836の監査と混同しない。
- 反復成功によってRUSH偶発失敗が完全解消したとは断定できない。品質スコアは前回の独立暫定 **76/100** のままで、80点未達。実機初見30秒、指の誤タップ、日本語小文字視認、スピーカー・イヤホン実音、FPS/発熱、画面回転は引き続きHuman Gateで未確認。同一理由のSlack再通知なし。
- 本回はGAME-076の継続検証1件のみ。タスク完了条件未達につきToDoへ復帰、次回は実機回答/小型画面改善候補と10軸再採点を確認。**ゲーム本体・QAコード・main・本番・課金・公開範囲は変更しない。**

## 7. ZIP実体の独立検証: 再実行attemptのアーカイブ直接照合（2026-10-15 01:30 JST）
- 対象は前節6の新artifact [11908064802](https://github.com/kobitworks/autoai_poc/actions/runs/38539286622/artifacts/11908064802)。ZIP本体をコネクタから別途取得し、実体から独立SHA/CRC/PNGデコードを実施。旧artifact 11882130836の実体検証結果は流用していない。
- ZIP実体4,354,766 bytes、SHA-256 = e51e7b2b82ed6f16cab870a4e99f79458f0da03d9a59c9dc4eba624f1e15a096。GitHubのartifact metadata digestと完全一致。
- ZIP全60ファイルのCRC検査に異常なし。PNG58枚 + 最終results.json・部分results-checkpoint.json各1件。58PNGすべてPillow Image.verifyおよびImage.loadで独立デコード成功（標準4画面×13枚=52枚、小型3画面×2枚=6枚）。
- 部分checkpointは status=PARTIAL_CHECKPOINT_NOT_FINAL のため合否正本とせず、最終results.jsonをパース。自然touch/mouse4画面 4/4 PASS、qaCommand=NEVER USED、stateOverride=NONE、NIGHT3配達、ACE6配達、RUSH後energy3、SOUND OFF/ON、BEST保存/再読込一致。小型3画面3/3 PASS_GEOMETRY。
- 実RUSH自然pointerdown角度はphone縦4.418、phone横4.349、tablet縦4.464、tablet横4.358rad。4画面とも物理受理範囲4.27〜4.73rad内。QA観測用部分帯域とは区別する。
- 代表12枚のスクリーンショットを独立縮小一覧で目視。標準4画面のイントロ/進行/ルート、3秒警告、長い説明、小型画面のイントロを含む。明白な全画面欠落・領域衝突・描画失敗は確認されない。3秒警告は枠色・表示エリアが画像に表れるが、実機での視認性・小文字可読性をPASSとは判定しない。
- 結論: 今回新attemptのZIP実体の真正性・CRC・画像復号・最終JSON整合は独立確認。RUSH偶発失敗が消滅したと断定せず、独立暫定品質76/100（一般公開目標80未達）を維持。
- 未検証Human Gate: 実機初見30秒での操作理解、指誤タップ、細字可読性、スピーカー/イヤホン実音、FPS/発熱、縦横回転。既存の同一確認を重複通知しない。
- 次回: Human Gateの回答があれば反映し、未回答ならGAME-076範囲内で小型画面視認性/警告導線を改善検討し、10軸を再評価する。
- ゲーム本体、QAコード、main、本番、課金、公開範囲は今回無変更。監査文書のみdevelopへ記録。


## 8. 新規CI run 38601415105 と独立ZIP・警告スクリーンショット監査（2026-10-15 02:13 JST）

- 対象: [Actions run 38601415105](https://github.com/kobitworks/autoai_poc/actions/runs/38601415105)、artifact [11914660519](https://github.com/kobitworks/autoai_poc/actions/runs/38601415105/artifacts/11914660519)。ヘッドは QA修正commit \`8e4253dabbe3c7569c722ef397a4bc0eedb39a80\`（develop）。
- GitHub APIで最新の実ジョブを再取得: contract \`115981938549\`、export-web \`115982040534\`、browser-quality \`115982702691\` が **3/3 completed/success**。前回run/attemptの結果を流用しない。
- GitHub成果物ZIPを新たにダウンロードして実体を検証: **4,358,361 bytes**、実SHA256 \`fefd33f813b0af80d0620155dc4c2b7a10185995fdc7908e2f3adcd87d5d2119\` はGitHub artifact digestと一致。60ファイル全件ZIP CRC正常。**PNG58枚はすべて画像のverify/loadに成功**。最終\`results.json\`を読み、部分\`results-checkpoint.json\`を合否正本に使わない。
- CI最終ログのJSONも独立パース。phone縦390×844 (touch)、phone横844×390 (mouse)、tablet縦768×1024 (touch)、tablet横1024×768 (mouse) の自然入力 **4/4 PASS**。全画面 \`qaCommand=NEVER USED\` / \`stateOverride=NONE\`。NIGHTは3配達、ACEは6配達に到達、energy=3、SOUND OFF/ON切替、BEST保存・再読込一致。最終BESTは各順に1110 / 1110 / 1108 / 1109。
- RUSHの実\`pointerdown\`角度は各順に **4.363 / 4.400 / 4.527 / 4.414 rad**。実物理受理帯域4.27〜4.73rad内であり、QA観測帯域4.31〜4.47radは合否閾値に使用しない。反復PASSは肯定材料だが、偶発失敗の完全解消を断定しない。
- 小型3画面（320×568 / 667×375 / 800×600）のINTROと自然START幾何は **3/3 PASS_GEOMETRY**。レイアウト衝突の静的判定と実機文字可読性は別物で、\`physicalLegibility=HUMAN GATE\`。
- 4画面の\`*-cargo-warning-3s.png\`と小型INTRO/PLAYINGの代表画像をアーカイブ実体から抽出し、比較目視。赤の警告枠・残秒優先テキストと独立HUBマーカーを確認。目視した画像上では大きな欠落や明白な重なりは認められないが、**phone縦および小型画面では警告文/日本語が小さく、実機での可読性・3秒以内の認識可否をPASSとはできない**。\`visualWarningPass=NOT VERIFIED\` / \`physicalLegibility=HUMAN GATE\` は維持。なおスクリーンショットは端末の実音・FPS・熱・回転や初見理解を検証できない。
- 10軸の評価条件を再確認。自動E2Eと静的/画像観察は技術品質と操作導線の肯定材料だが、**新たな人間実機根拠がないため独立暫定76/100を維持**。80点以上の一般公開品質は未認定。初見30秒、実タッチ誤操作、細字/警告可読性、スピーカー/イヤホン実音、FPS/発熱、実機縦横回転はHuman Gate未回答のまま。
- 次回再開: Human Gate回答があれば根拠として反映。未回答なら小型画面の緊急警告の可読性を優先して、GAME-076の同一タスク内で限定改修/再検証を検討し10軸再採点。今回の実装コード/QAコード、main、本番、課金、公開範囲は変更なし。今回の作業は**新run 38601415105を独立監査し監査文書に追記**する1タスクのみ。
