# P021 / GAME-075 — GAME-G030 段階的ルート・初見導線・音声の再検証

- 着手: 2026-10-12 04:44:57 JST
- 進捗記録: 2026-10-12 04:50:08 JST
- 正本: kobitworks/autoai_poc / **developのみ**
- 対象: [Godot Main.gd](../sources/orbit-switch-courier-godot/Main.gd)、[Playwright実操作E2E](../qa/orbit-switch-courier-real-input.js)
- 変更コミット: [コード 1c026375](https://github.com/kobitworks/autoai_poc/commit/1c026375a88da91fe93d9a19839218144a2c16a8)、[ルート検証 bb8a0d15](https://github.com/kobitworks/autoai_poc/commit/bb8a0d15cacbc1b3136b588c1a20c5f491f162a7)、[撮影証跡 7d63aae5](https://github.com/kobitworks/autoai_poc/commit/7d63aae5de0ea732754c2d12582557f90e92a381)
- 検証対象CI: [Actions run 38169600759](https://github.com/kobitworks/autoai_poc/actions/runs/38169600759)
- 前提監査: [GAME-074 68/100](./game-g030-ui-sound-accessibility-game-074-2026-10-12.md)

## 実装された改善

1. **成長・変化**: 成功配達に応じて4段階（STARTER:0回、RUSH:1回、NIGHT:3回、ACE:6回）に遷移。各段階の配送期限は16秒→14秒→12秒→10秒。コンボ/ENERGY/BESTを維持し、単調な90秒1ステージから進行実感のあるゲームループへ変更。
2. **成功・ミスの理解**: 乗換成功、配達成功、ルート昇格、エネルギー減少に短い高コントラスト通知を重ねる。失敗と成功は緑/赤と短文で区別。ルート境界色、情報カードのルート名も段階に応じて変化。
3. **初見案内**: 3ステップ「配送先を探す→光る交差点でTAP→同じHUBでTAPして配達」を読みやすい表現に修正。日本語説明は事実として操作を誘導し、結果を保証しない。
4. **既存品質の保持**: SOUNDのON/OFF・BEST復元、描画RETRY、タッチ/クリック入力、4種類のviewportとQA telemetryを維持。QAの成功用コマンドでゲーム状態を改ざんしない。

## 検証項目

- [ ] Godot parser / Web export / CI3ジョブが成功したこと
- [ ] 390×844、844×390、768×1024、1024×768で実入力E2E **4/4 PASS**
- [ ] 通常タッチ/クリックによる実際の1配達の結果として RUSH、残り14秒へ段階遷移
- [ ] 各画面でintro、playing、route-rush、miss-feedback、result、retryの実画像を取得・比較
- [ ] SOUNDを物理操作でOFF→ONとし、内部音声プレイヤー観測を記録（実スピーカー出力とは区別）
- [ ] BESTリロード復元、HTML/canvasはみ出し、browser console errorsを再確認
- [ ] 10項目独立暫定スコアの根拠ある再採点と80点未満の場合の次改善を記録

**判定保留**: 上記チェックはCI/artifactのread-back後に埋める。CI開始だけでPASSや80点達成を宣言しない。実スマホ/タブレットでの音の聞こえ、イヤホン、初見30秒の人間理解、誤タップ率、FPS・発熱は自動証跡では検証できず **Human Gate** として保留する。mainマージ、有料利用、本番公開範囲変更はしない。
