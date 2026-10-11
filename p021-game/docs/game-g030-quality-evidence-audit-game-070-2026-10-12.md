# GAME-G030「Orbit Switch Courier」品質証跡監査 — GAME-070

- 実施日: 2026-10-12 JST
- 対象: P021 / GAME-G030 / 前工程 GAME-069
- 担当: AutoAI
- 監査目的: P021 project_rule.md v1.2.0 §9〜11の100点品質ゲートを、実装・自動テストから独立して証拠確認し、公開品質の誤認を防ぐ
- 実装正本: `p021-game/sources/orbit-switch-courier-godot/Main.gd` (develop, blob `897ebb9434e0cdd1d88954e9ec93412840579028`)
- QA正本: `p021-game/qa/orbit-switch-courier-responsive.js` (develop, blob `ac80ec748380e862332a51b0cfdaf5a35f550112`)
- 自動テスト証跡: [GitHub Actions run 38105707588](https://github.com/kobitworks/autoai_poc/actions/runs/38105707588)
- 試遊URL（今回の直接操作検証対象外）: https://kobitworks.github.io/autoai_poc/p021-game/games/orbit-switch-courier/

## 監査結論

**ビルドと既存のスクリプト化された技術スモークテストは合格。一方、一般公開品質80点達成は未立証。**

READMEの**84/100は「Quality score target（目標）」であり、測定した合格点ではない**。build.jsonにも `quality_target: 84` とある。QAスクリプトが出力する `general_public_quality: true` はテスト実行の結果から計算した品質スコアではなく、プログラム内の固定文字列である。この情報をもって「実測84点」「一般公開品質達成」と報告してはならない。

## 確認済みの事実

1. [run 38105707588](https://github.com/kobitworks/autoai_poc/actions/runs/38105707588) の `contract`, `export-web`, `browser-quality` は全て completed / success。
2. PlaywrightではPhone Portrait 390×844、Phone Landscape 844×390、Tablet Portrait 768×1024、Tablet Landscape 1024×768を巡回し、Canvas領域の画面内収まり、主要状態の変化、JavaScript console/pageerror/requestfailureなしを判定。
3. Godotの現行Main.gdには、90秒・3軌道・配達/乗換・コンボ・Energy/Result・BEST保存・音声ON/OFF・タッチ/クリック/Space入力処理が存在。
4. テストスクリプトは `?qa=1` の `window.__P021_ORBIT_COMMAND` を介し、`start` / `switch_success` / `deliver` / `fail` / `finish` を送信する。Godot側QAハンドラは配送機の軌道と角度を成功位置へ直接設定して `_attempt_action()` を呼ぶ。よって**本物のタップ位置・手動タイミング判断・操作しづらさを検査するものではない**。
5. BESTはテスト終了時の `best >= score` を見ているが、**ページ再読み込み後の復元**を明示的に検証していない。ソースに保存処理があることと、実ブラウザでの保存耐性の検証は別である。
6. QAはスクリーンショットを保存するが、静止画像の視認性、文字重なり、色/形の判別、演出品質について、人間または視覚ベースの独立採点を行っていない。
7. 実行環境からの公開URLへの直接ブラウザ試遊、モバイル実機の音声再生・タッチ感度の検証は今回実施していない。

## P021 §10.5 の10項目別エビデンス

| 項目 | 今回確認できた根拠 | 未検証ゲート |
|---|---|---|
| ゲーム性 | 配達・乗換・コンボ・Energy・90秒ルールをコードで確認 | 自然なプレイで面白さ・判断性を感じられるか |
| 操作感 | タッチ/クリック/Spaceの実装を確認 | 実入力の乗換タイミング、連打、押しやすさ |
| 難易度設計 | 軌道速度差・成功判定窓をコードで確認 | 初回プレイでの理解と難易度推移 |
| UI/UX | 四つのviewportの境界チェックに合格 | 初見チュートリアルの可読性と画面視覚確認 |
| グラフィック | 独自描画コードを確認 | 一般公開水準の見た目・形/色の判別 |
| 演出・エフェクト | Spark/軌跡/Good/Badフラッシュ用処理を確認 | 実表示時の知覚しやすさ・過剰/不足 |
| サウンド | 音生成/再生とSOUND切替処理を確認 | ブラウザの音声許可・実機音量・出力確認 |
| コンテンツ量・変化 | Stage 1の3軌道と配送対象変化を確認 | 数プレイ後の変化と飽きの早さ |
| リプレイ性 | score/BEST保存ロジックとコンボを確認 | リロード後保存・複数回プレイ検証 |
| 技術品質 | Godot Web Export、Actions 3ジョブ、4viewport合格 | 本番URL現地確認、実機/自然入力E2E |

**10項目の独立実測得点は現時点では付与しない。** 視覚・聴覚・実操作の確認が必要な項目を根拠なしに数値化すると、80点ゲートの監査価値を損なうため。

## 次工程提案（今回の監査とは別タスク）

- P0: PlaywrightでQAコマンドを使わず、実際のタッチ/クリックによる「開始 → 乗換 → 配達 → 結果 → 再挑戦」を検証する。成功窓への到達は物理的なゲーム進行から待機・観測し、状態直書きは禁止。
- P0: 各viewportの実スクリーンショットを人間/視覚評価で確認し、HUDの文字・コントラスト・ボタン/タップ領域を記録。
- P1: 音声ON/OFF、ページ再読込後のBEST保持、複数回プレイ/リスタート時の状態安定をテスト。
- 全ゲート完了後に10項目を根拠付きで各10点採点し、80点未満の場合は改善タスクへ戻す。

## 実行制約・注意

- 実装・公開設定・有償サービス・本番化は変更していない。
- 成果は「公開品質の証跡監査」であり、GAME-069の実装結果や過去のCI合格を取り消すものではない。
- 以前のスクリプト化されたPlaywright PASSは**自動テストとしては有効**である。ゲーム体験の人間評価の代用にはならない。
