# GAME-G030 GAME-074｜画面可読性・初見導線・SOUND・実入力E2E再検証

- 日時: 2026-10-12 04:34 JST
- AutoAI / P021 ゲーム開発 / GAME-G030 Orbit Switch Courier
- 実行タスク: **GAME-074（1回のRunner実行で実行した唯一のタスク）**
- ベースライン: [GAME-073独立品質監査 58/100](./game-g030-independent-quality-review-game-073-2026-10-12.md)
- 正本: kobitworks/autoai_poc、**develop のみ**（mainへマージなし）
- 修正: [Godot Main.gd](../sources/orbit-switch-courier-godot/Main.gd)、[実操作Playwright E2E](../qa/orbit-switch-courier-real-input.js)
- 最終証跡: [GitHub Actions run 38168227605](https://github.com/kobitworks/autoai_poc/actions/runs/38168227605)、[artifact 11712604788](https://github.com/kobitworks/autoai_poc/actions/runs/38168227605/artifacts/11712604788)

## 1. 実装内容

1. **論理ピクセル→可視CSSピクセル補正**: Web canvasのbounding boxとGodot viewportからUI倍率を算出し、フォント・パディング・HUD・オーバーレイ・タップ領域を視覚ピクセル基準で再配分。844×390の以前の約4px文字/約17px高SOUNDボタン問題を是正。縦横向き変更時は再計算。
2. **読みやすいステータスと画面内操作**: TIME/DELIVER/SCORE/BESTのフォントと色コントラストを改善。SOUNDを**116×48 CSS px**、RETRYを**高さ50 CSS px**とし、検証対象全4 viewportで幅・高さ44px以上。縦画面でGAME HUBボタンとHUDの上下領域を分離。カード説明文字は実フォント計測で省略記号を付与し、右端からはみ出さないようにした。
3. **初見導線**: 初期画面に「荷物とHUBの同記号を探す→光る交差点で軌道切替→同じHUBで配達」を3段階で表示。ランドスケープでは情報カードの余白を説明・操作ヒントに割当て、盤面との幅配分を改善。
4. **SOUND**: ボタンからの実タップ/クリックでON/OFF、OFF時は再生中サンプルを直ちに停止。read-only QA telemetryにSOUND/RETRY/HUD/HUBのボタン矩形、音声プレイヤー状態とUI倍率を追加（ゲーム状態の変更・QA成功近道には不使用）。
5. **自動証跡**: 4 viewportそれぞれ**intro / playing / result / retry / sound-off / sound-on / replay の7画像**を追加。現物入力でSOUND切替、RETRYの描画位置タップ、軌道切替→自然配達→RESULT→再挑戦→BEST復元をチェック。縦画面でのGAME HUBとHUDの重なり回帰アサーションも追加。

## 2. 最終CI / 実入力結果

GitHub Actions run **38168227605** の `contract`、`export-web`、`browser-quality` は全て **completed/success**。実入力のresults.jsonをダウンロードしてread-backし、以下4/4 PASSを確認。すべてQA commandで状態を直書きせず、実際のtouch/mouse入力と自然な軌道移動を利用。

| 画面 | 自然操作E2E / BEST復元 | SOUND OFF→ON | エンジン内音声プレイヤー起動観測 | SOUND物理領域 | RETRY物理領域 |
|---|---|---|---|---|---|
| スマホ縦 390×844 | PASS / 122点 | PASS | YES | 116×48px | 290×50px |
| **スマホ横 844×390** | **PASS / 123点** | **PASS** | **YES** | **116×48px** | **336×50px** |
| タブレット縦 768×1024 | PASS / 109点 | PASS | YES | 116×48px | 386×50px |
| タブレット横 1024×768 | PASS / 123点 | PASS | YES | 116×48px | 386×50px |

ブラウザconsole/pageerror/requestfailed異常なし。4 viewportのretryからintroへの復帰とlocalStorage BEST復元もPASS。縦画面のヘッダー/HUD非重複検査もPASS。

**重要な限界**: 「エンジン内音声プレイヤー起動観測=YES」はブラウザの実スピーカー音質・聞こえ・音量が検証された意味ではない。実機での音声/消音確認、イヤホン時の音、初見ユーザーが30秒で遊び方を理解できるか、触感・誤タップ率・FPS/発熱は**未確認（Human Gate）**。

## 3. 視覚的Before / After 独立比較

- Before: [GAME-071 artifact 11709811259](https://github.com/kobitworks/autoai_poc/actions/runs/38157935714/artifacts/11709811259)。844×390では9論理pxラベル約4px表示、SOUNDは実表示約43×17px。情報カード右側が広大な空白、説明文字が読みにくかった。
- After: artifact 11712604788の28 PNGをダウンロード。スマホ横イントロでは上部HUDと、同一記号をHUBへ届ける3ステップ、幅のあるSOUND、左右のカードが読める。RESULTでは123点と50px高RETRYの位置・大きさを画像で確認。スマホ縦/タブレット縦横でもGAME HUBとHUDの重なりが消え、長い説明のカード外へのはみ出しが解消した。
- 撮影された7状態/4サイズはCI証跡に保存済み。公開URLの実機レンダリングや独立ユーザー試遊での最終合格はまだ認めない。

## 4. P021品質10軸の証跡限定暫定再採点

| 指標 | GAME-073 | GAME-074 | 主な根拠・保留点 |
|---|---:|---:|---|
| ゲーム性 | 7 | 7 | 3軌道とHUB配達の選択。楽しさの実測未実施 |
| 操作感 | 7 | 8 | 4サイズ実入力E2E＋SOUND/RETRYボタン操作。実機誤タップ未評価 |
| 難易度設計 | 5 | 5 | 成功窓は現存。初心者習熟率未測定 |
| UI/UX | 4 | 7 | 視覚CSSピクセル補正、44px以上のボタン、初見3段階説明。人間の理解度未測定 |
| グラフィック | 6 | 7 | 横画面の情報密度/文字と色の改善。アート・動きは据置き |
| 演出・エフェクト | 5 | 5 | 既存演出のまま。動き品質の目視動画レビュー未実施 |
| サウンド | 3 | 6 | SOUND実操作4/4、音声プレイヤー再生起動観測4/4。スピーカーの実音は未確認 |
| コンテンツ量・変化 | 5 | 5 | Stage1と3軌道中心、バリエーション不足 |
| リプレイ性 | 8 | 9 | 描画RETRYボタンを物理クリックし、BESTリロード保存4/4 |
| 技術品質 | 8 | 9 | 3CIジョブ・4画面E2E成功、レイアウト非重複回帰。実機FPS/温度未計測 |
| **合計（暫定）** | **58** | **68 / 100** | **80点の一般公開品質は未達・未認定** |

68点は取得済み証拠と目視に基づく**保守的な暫定スコア**。内部E2Eの合格はユーザー満足・音質・初見理解の証明ではなく、未確認ゲートをPASSEDに昇格させない。

## 5. 残改善・次タスク案

1. P0: 実際にゲームを遊んだことのない人へ30秒初見導線を提示して誤解点を記録。画面表示と操作誘導、フィードバック、視線移動、ランドスケープ遊びやすさを改善（ユーザー参加は別Gate）。
2. P1: 実機スマホ/タブレットで音声ON/OFF・スピーカー/イヤホンでの聞こえ・FPS/発熱を検証する。ここは**人間確認待ち**とする（推測によるPASSは禁止）。
3. P1: 3軌道の周回以外のステージ変化、ユーザーへの成功/失敗フィードバックとサウンド演出を拡充。新しい改善後に10項目を再評価し、80点未満なら引き続き改善する。

このGAME-074で行ったのは**開発用developの変更とCI検証**だけ。mainマージ・有料契約・新規本番公開は行っていない。