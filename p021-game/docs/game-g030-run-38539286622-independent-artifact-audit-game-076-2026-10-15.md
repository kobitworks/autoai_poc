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
