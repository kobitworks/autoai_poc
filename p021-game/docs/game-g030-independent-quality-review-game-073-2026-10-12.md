# GAME-G030「Orbit Switch Courier」独立品質審査 — GAME-073

- プロジェクト: P021 ゲーム開発 / 孫プロジェクト GAME-G030
- 実施: 2026-10-12 03:32:51 JST / AutoAI 1実行につき実作業1件
- 正本: kobitworks/autoai_poc / develop
- 前提: GAME-072 Done
- 検証ソース: [Main.gd](../sources/orbit-switch-courier-godot/Main.gd)、[実入力E2E](../qa/orbit-switch-courier-real-input.js)、[GAME-072監査](./game-g030-post-real-input-quality-gate-game-072-2026-10-12.md)
- 実測証跡: [GitHub Actions run 38157935714](https://github.com/kobitworks/autoai_poc/actions/runs/38157935714) / [artifact 11709811259](https://github.com/kobitworks/autoai_poc/actions/runs/38157935714/artifacts/11709811259)
- artifact name: p021-game-g030-real-input-evidence / ZIP SHA-256: 96171ebe7e6a6f15c3ed7919912db132d046e0c0df3bf7520ec0d66292e0e11a
- 含まれる実画像: phone-portrait/result・replay、phone-landscape/result・replay、tablet-portrait/result・replay、tablet-landscape/result・replay（PNG計8件）、results.json
- 審査対象は既存の技術検証証跡とリポジトリ正本。QAは ?qa=1 の決定的貨物を使用。通常公開URLでの新規実機操作試験、初見被験者試験、耳による実音声確認は今回未実施。

## 結論

**4 viewport の実入力 E2E：4/4 PASS。独立した証跡ベースの暫定品質スコア：58/100。一般公開品質（80点以上）：未認定。**

READMEの「84/100」は目標値であり、実測採点ではない。今回の58点は実画像・ソース・既存E2E結果から独立に付けた**証跡限定の暫定値**で、初見UX・実機タッチ感度・音声実出力を測定したかのようには扱わない。未検証項目は高得点で補填しない。改善後に再撮影と独立再審査を要する。

## 1. 証拠の読戻しと技術ゲート

1. GitHub Actions run 38157935714 の contract、export-web、browser-quality は全て completed/success。artifact 11709811259 は有効で、ZIPを実際に取得・解凍し、8 PNG/1 JSONを目視と内容照合した。ZIP SHA-256はGitHub API報告値と一致。
2. 390×844(touch)、844×390(mouse)、768×1024(touch)、1024×768(mouse)はいずれも results.json status=PASS。実クリック/タップによる軌道乗換・自然配達1件・RESULT・RETRY・再読込後BEST復元が合格。
3. 各viewportの配達得点とlocalStorage BESTは順に122、123、122、123。qaCommand=NEVER USED、stateOverride=NONE。成功窓を強制書換えするテストではない。
4. 先行QAは JS console/pageerror/requestfailed、Canvas/論理領域のはみ出しをチェック済み。ただしテスト合格だけで静止画の可読性、サウンド、遊びの面白さが合格したことにはならない。

## 2. 4画面の独立視覚レビュー

| 実画像 | 判断 | 改善点 |
|---|---|---|
| phone-portrait 390×844（result/replay） | 中央ゲーム画面・結果数値とRETRY導線は見える。軌道は色と形（円・三角・四角）を併用し識別可能。 | 上部TIME/DELIVER/SCORE/BESTのラベル、下部説明/CARGO・ENERGY文字が小さく低コントラスト。SOUNDが小さめ。 |
| **phone-landscape 844×390**（result/replay） | ゲーム盤は左、情報エリアは右。画面からはみ出さないが、情報のほとんどが非常に小さく、右の大部分が空白。 | **重大な可読性問題**。標題、HUDラベル、右側の日本語説明、結果/RETRY文字、SOUND切替が縮小され、目視で読みにくい。物理クリックでは成功しても初見ユーザーの理解や適切なタッチ領域は未証明。 |
| tablet-portrait 768×1024（result/replay） | 結果スコアと軌道グラフィックは視認しやすい。カード構成の破綻は目視ではない。 | フィールド下の細かな説明・指示が弱く、重要な行動誘導が中央に埋もれる。 |
| tablet-landscape 1024×768（result/replay） | 3軌道と配送シンボルが見える。左ゲーム/右情報の構図。 | 右カラムは大きな空白が多く、本文サイズと内容密度が釣り合わない。CARGO/HUDラベルが弱い。 |

### 根本要因（ソースから確認）

- Main.gd の _font_size は「min(size.x/390, size.y/700) を0.72〜1.25へclamp」し、最小9の**Godot論理px**を返す。物理画面の文字サイズを保証しない。
- 844×390の結果JSONでは論理 viewport_w=1826、viewport_h=844。Web canvasの表示倍率は約 844/1826=0.462 であり、9論理pxのラベルは画面上約4.2px相当。SOUNDボタンは論理94×37で、実表示は約43×17px相当（Main.gd の sound_rect、同viewport証跡より計算）。一般的なスマホタップ領域の目安からも小さく、読みにくい。
- landscapeでは info_rect をプレイフィールド残余幅へ配分する一方、説明文は少量・小フォントで、情報が右上に偏る。
- スクリーンショット8件は RESULT とリプレイ後の画面のみ。**初期intro画面の4サイズ画像は存在しない**。Main.gd にはルール/スタート文言の描画はあるが、30秒で説明を読めるかは未検証。

## 3. 音声・初見UX

- ソースはAudioStreamWAVとAudioStreamPlayerを生成し、SOUND ON/OFFボタンを _toggle_sound に割り当てる。results.jsonの read-onlyスナップショットは sound=true。
- ただし今回の artifact にはSOUND切替前後の自動操作記録、WebAudio出力波形、録音、実機で耳で聴いた証拠がない。**音声再生・無音化・音量は未検証**。実装が存在することをもって合格としない。
- 通常URLでの初見30秒理解度・説明文の可読性・初回タップから成功に至る迷い・タップ誤認識・端末での音声再生は未確認。QAは物理入力だがread-onlyテレメトリで成功ウィンドウを認識するため、初見の人が同様に遊べる証明にはならない。

## 4. P021 v1.2.0 — 独立証跡限定の暫定採点

| 項目（各10点） | 点 | 審査根拠・主な減点 |
|---|---:|---|
| ゲーム性 | 7 | 3軌道の切替→HUB配達、失敗時Energy減少など選択とリスクがある。楽しさの実測はない。 |
| 操作感 | 7 | 4 viewport実入力PASS。ただし画面上の押すべき位置と実機感度・連打誤操作は未確認。 |
| 難易度設計 | 5 | 窓判定/エネルギー/90秒の構造は存在。初見習熟曲線・成功率の根拠不足。 |
| UI/UX | 4 | 390縦は成立するが844横で著しい表示縮小、ラベル低コントラスト、ボタン小。初見導線未検証。 |
| グラフィック | 6 | 独自ベクタ風、シンボルと色の二重符号化。情報階層と小画面での線・文字の見やすさは不足。 |
| 演出・エフェクト | 5 | Spark/点滅等ソースに存在。ただし静止画だけではタイミング・動きの質を検証できない。 |
| サウンド | 3 | WAV合成・ON/OFF実装あり。音声許可・実音量・消音が未証明。 |
| コンテンツ量・変化 | 5 | 3軌道・3HUB・90秒・コンボあり。Stage 1中心で繰り返しの変化が限定的。 |
| リプレイ性 | 8 | RESULT→RETRY→リロード後BEST復元を4 viewportで検証。長期動機は未検証。 |
| 技術品質 | 8 | CI 3ジョブ、実入力4/4、BEST保存・例外監視OK。実機FPS/熱/公開URLの新規独立試遊は未確認。 |
| **合計（暫定）** | **58/100** | **80点以上の一般公開品質とは認定できない。** |

点数は今回取得可能な技術・視覚証跡に対する独立評価であり、未実施試験を通過したと解釈してはならない。

## 5. 改善・再検証（次回タスク GAME-074へ引継ぎ）

P0：**最初にスマホ横画面の可読性を改善する。** 物理ピクセル基準の最小表示文字、SOUND/RETRYの十分なタップ領域、低コントラストのHUD/説明、横画面の情報エリアレイアウトを再設計。スマホ縦・タブレット縦横を壊さない。

P0：イントロ初期画面とプレイ中、RESULT、RETRYの**4サイズ×各状態のスクリーンショット**を新規CI証跡に残す。30秒で「目的・第1操作・成功条件」が理解できるか、スクリプト非依存で検証できるシナリオを用意する（実ユーザー確認は別ゲート）。

P1：SOUND ON/OFFの実クリック/タップとブラウザ音声状態の自動化可能部分をテストし、必要なら録音/実機再生の人間確認依頼を明示する。音量/端末発熱/実機評価をAIが推測でPASSしない。

改善後に4 viewport実入力E2Eと目視を再実行し、各10点を再採点。80/100以上に達しても実音声・初見者の未確認ゲートは別途保持する。**このGAME-073では、コード改修、mainマージ、新規公開・課金・Cloudflare変更を実施していない。**
