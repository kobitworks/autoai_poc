# P021 / GAME-075 — GAME-G030 段階的ルート・初見UX・音声評価の独立再監査

- 対象: **GAME-G030 Orbit Switch Courier** / P021 ゲーム開発
- 実施: 2026-10-12 04:44:57〜2026-10-12 04:54:15 JST（今回の自動実行の実作業1件）
- 正本: kobitworks/autoai_poc の **develop のみ**。main変更・有料利用・新規公開範囲拡大なし
- 実装: [Godot Main.gd](../sources/orbit-switch-courier-godot/Main.gd)、[実入力E2E](../qa/orbit-switch-courier-real-input.js)
- 変更コミット: [本体 1c026375](https://github.com/kobitworks/autoai_poc/commit/1c026375a88da91fe93d9a19839218144a2c16a8)、[進行検証 bb8a0d15](https://github.com/kobitworks/autoai_poc/commit/bb8a0d15cacbc1b3136b588c1a20c5f491f162a7)、[状態別撮影 7d63aae5](https://github.com/kobitworks/autoai_poc/commit/7d63aae5de0ea732754c2d12582557f90e92a381)
- CI: [GitHub Actions run 38169600759](https://github.com/kobitworks/autoai_poc/actions/runs/38169600759) **completed/success**（contract / export-web / browser-qualityの3ジョブ）
- 最終実画像・JSON: [artifact 11713606413](https://github.com/kobitworks/autoai_poc/actions/runs/38169600759/artifacts/11713606413)、ZIP SHA-256 `cfa5359551556081b3b5309f17c4b34341afc00d27491defb0db3dbf686eae74`
- 比較ベースライン: [GAME-074 68/100](./game-g030-ui-sound-accessibility-game-074-2026-10-12.md)、[artifact 11712604788](https://github.com/kobitworks/autoai_poc/actions/runs/38168227605/artifacts/11712604788)

## 1. 改善実装

1. **配送成功によるルート成長**: STARTER=配達0件（貨物制限16秒）、RUSH=1件（14秒）、NIGHT=3件（12秒）、ACE=6件（10秒）の4段階に進行する仕組みを追加。ルート名と枠色・貨物ゲージに進行状態を反映。3/6件ルートはコード実装を確認したが、今回の実操作E2Eでは**1件でのRUSH遷移のみを実証**。
2. **タイミングのフィードバック**: 正常な軌道乗換、配達得点、ルート昇格、ミスによるENERGY減少を緑/赤の短い表示で区別。表示は1.65秒で消え、結果を得るためのQA成功近道は使っていない。
3. **初見導線**: 冒頭の3ステップ説明を「HUBの一致→交差点が光ったらTAP→配達先でTAP」と整理。SOUNDやRETRYを含むGAME-074の最低タップ領域を保持。

## 2. 実入力と保存の証跡（CI結果JSONを取得して独立read-back）

| viewport | 入力 | E2E | 配達得点 | 初回配達後 | SOUND OFF→ON | 再読込BEST |
|---|---|---|---:|---|---|---:|
| Phone Portrait 390×844 | touch | **PASS** | 122 | RUSH / 14秒 | PASS | 122 |
| Phone Landscape 844×390 | mouse | **PASS** | 123 | RUSH / 14秒 | PASS | 123 |
| Tablet Portrait 768×1024 | touch | **PASS** | 122 | RUSH / 14秒 | PASS | 122 |
| Tablet Landscape 1024×768 | mouse | **PASS** | 123 | RUSH / 14秒 | PASS | 123 |

- **4/4 PASS**。全4サイズで通常の物理touch/mouse操作から軌道乗換→自然配達→RUSH遷移→3ミス→RESULT→画面上RETRY→ブラウザ再読込→localStorage BEST復元まで確認。
- QA command / 物理ステート直接改変: **NONE**。`?qa=1`の決定的な初期貨物と**read-onlyの状態観測**は使用。初見者の自然な操作成功率を示すものではない。
- SOUNDの物理OFF→ONとAudioStreamPlayer起動観測は全4サイズで成功。しかし**実スピーカーの音量・音質・イヤホン出力は未検証**。
- 実画像は各viewportにつきintro、playing、**route-rush**、**miss-feedback**、result、retry、sound-off、sound-on、replayの**9状態**、計36 PNG。RESULTスコア、RETRYボタン、色・文字による成功/失敗、ルート変化を撮影した。

## 3. 4画面の画像を独立比較

GAME-074実画像28枚とGAME-075実画像36枚を別途ダウンロード・展開し、両実体を比較した。

| viewport | 視覚的判定と残課題 |
|---|---|
| Phone Portrait | 画面の上下構成が維持され、RUSHの緑通知・MISSEDの赤通知は中央の軌道領域に明瞭。説明カードの文字は読めるが、ユーザーが初見30秒で理解するかは実測していない。 |
| **Phone Landscape** | 844×390のPLAYとHUB案内、右のRUSH/CARGOが画面内に収まり、緑/赤の通知が可視。GAME-074で拡大したSOUND/RETRYサイズに回帰なし。右の補助説明とステータスは密度に改善余地。 |
| Tablet Portrait | 3軌道・貨物記号、RUSH/MISS表示、RESULT/RETRYが明確に区別可能。下部情報の文字は表示されるが実機視力テストは未実施。 |
| Tablet Landscape | 左ゲーム、右情報の二列構成を維持し、進行表示が右パネルにも反映。右カラムは面積に比べコンテンツが少なく、余白活用の改善余地が残る。 |

4サイズの画像は**自動化された特定場面の静止画**であり、動き・FPS・実音質や人間の理解度は判定対象外。

## 4. P021品質10軸の独立暫定再採点

| 指標（各10点） | GAME-074 | GAME-075 | 根拠・減点理由 |
|---|---:|---:|---|
| ゲーム性 | 7 | **8** | 配達で変化するルート目標を導入。面白さの実ユーザー評価はない。 |
| 操作感 | 8 | **8** | 実入力4/4を維持。初見者誤タップ率・実機操作感は未測定。 |
| 難易度設計 | 5 | **6** | 16→14→12→10秒で段階的な時間制限。上位2ルート実操作試験は未実施。 |
| UI/UX | 7 | **8** | 初見案内修正・色分けした即時通知。30秒理解テストなし。 |
| グラフィック | 7 | **7** | 既存描画を維持。アート水準は抜本改善なし。 |
| 演出・エフェクト | 5 | **6** | 配達/昇格/ミス通知を追加。動きの品質は動画で独立審査していない。 |
| サウンド | 6 | **6** | 実操作ON/OFFと内部再生観測維持。実音未確認。 |
| コンテンツ量・変化 | 5 | **7** | 4段階のルートと制限時間変化。進行の体感・3/6配達到達率は未測定。 |
| リプレイ性 | 9 | **9** | BEST永続化/RETRY継続4/4。 |
| 技術品質 | 9 | **9** | 3ジョブsuccess＋4画面E2E/計36画像。実機FPS/発熱未確認。 |
| **合計（証跡限定暫定）** | **68** | **74 / 100** | **80点未達。一般公開品質とは認定しない。** |

## 5. 未完了Gate・次の改善（GAME-076へ引継ぎ）

- **AI実施可能**: 3/6件配送までの正常到達を実物操作で再現するE2Eを追加し、NIGHT/ACEの難度・表示・時間を検証。初見プレイヤー向けの操作タイミング表示、30秒で「最初の正しい行動」にたどり着く導線、段階変化のメリハリ、余白の活用を改修。4 viewport再確認、10項目再採点、80点未満なら次改善へ。
- **Human Gate**: スマホ/タブレット実機でSOUND ON/OFFおよびイヤホン実音、FPS・発熱、初見ユーザーの30秒理解度/誤タップ率の測定。これらを未実施のままPASSとしない。
- 有料契約・mainマージ・別基盤への公開拡大は実施しない。今回のGAME-075では**AI実装/CI/画像レビュー/暫定採点を完了**した。人間判定を依存としてゲーム全体の改善を停止せず、AIで実行可能な次タスクを継続する。
