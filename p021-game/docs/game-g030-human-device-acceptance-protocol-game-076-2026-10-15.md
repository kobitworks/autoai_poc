# GAME-076 / GAME-G030 実機初見・可読性・音・性能の受入試験票 v1
作成: 2026-10-15 JST / AutoAI P021（GAME-076継続）
対象: Orbit Switch Courier (Godot Web)。親タスク: GAME-076。
成果物区分: **試験手順と記録テンプレート**。実機テストの実施結果・承認ではない。

## 1. 基準ビルドと検証済み事項
- 正本コード: [autoai_poc/develop/p021-game](https://github.com/kobitworks/autoai_poc/tree/develop/p021-game)
- ゲーム本体: [Main.gd](https://github.com/kobitworks/autoai_poc/blob/develop/p021-game/sources/orbit-switch-courier-godot/Main.gd)
- 静的・ブラウザCI基準: [run 38619691662](https://github.com/kobitworks/autoai_poc/actions/runs/38619691662), 対象source commit `fd2c66f810be90c2a01233bb0794f36136f9c62f`。2026-10-15 04時台のAPI再確認で contract/export-web/browser-quality 3/3 completed/success。
- [独立監査（2026-10-15）](https://github.com/kobitworks/autoai_poc/blob/develop/p021-game/docs/game-g030-run-38539286622-independent-artifact-audit-game-076-2026-10-15.md)には標準4 viewport自然入力4/4 PASS、小型3 viewport実START後幾何3/3 PASS_GEOMETRY、画像の確認結果を保存済み。
- ゲームの独立暫定品質評価: **76/100**（一般公開品質目標80/100未達）。この試験票の作成だけで点数は加点しない。
- 過去CIのPASSは**実機での初心者の理解・タップ誤操作・音質・警告の瞬間認知・FPS/熱**の合格を意味しない。

## 2. テスト対象と記録欄
対象のWeb Exportバージョン（commit/Actions run）: ______
実機種別/OS・ブラウザversion・画面の向き: ______
テスト日時(JST): ______　　テスター（仮名可）: ______
音声経路: ☐本体スピーカー ☐イヤホン ☐無音　　画面倍率/文字サイズ設定: ______
画面撮影・録画: 任意。同意のない人物・個人情報・アカウント情報は含めない。
環境注記: GitHub Pages公開URLが上記developビルドと同一commitか未確認の場合、**同一ビルドであるとみなさない**。CI生成物、検証用Preview等のビルドIDが確認できる経路で実施。

## 3. 0〜30秒：説明ゼロの初見試遊（最重要）
試験者は予備説明・操作誘導をしない。端末とURLだけをテスターへ渡し、必要な場合のみ開始時刻を告げる。事前に録画の同意を確認。

| 区間 | 観察事項 | PASS目安 | 実結果/時刻/証拠 |
| --- | --- | --- | --- |
| 0〜10秒 | 初回画面から「何をするゲームか」を本人の言葉で説明できるか | 目標HUBへの配達とTAP操作の要点を理解 | 未実施 |
| 10〜20秒 | 「TAP TO START」を自分で見つけて押せるか | 他のUI誤操作なく自然にスタート | 未実施 |
| 20〜30秒 | 最初の正しい行動を選べるか | 緑の交差点での乗換を理解し、タイミングを狙える | 未実施 |
| 終了後 | 「同じ印のHUBで配達」の意味を理解しているか | ゴールの見分け方を本人が説明できる | 未実施 |

最初の誤タップ有無: ______ / 初回操作までの秒数: ______ / 困った箇所（本人の言葉）: ______
判定: ☐PASS ☐FAIL ☐UNTESTED。開発者が操作を手伝った回は初見PASSにしない。

## 4. 画面サイズ・向き・タッチ判定
各サイズで実機の縦/横切替後、タイトル→開始→プレイ→RESULT→RETRYの表示導線を確認。QAのブラウザ擬似viewportと実機は別物として両方記録する。
- 320×568 相当／スマホ縦：3段ガイドとSTARTの重なり・文字欠け・タップ位置確認
- 667×375 相当／スマホ横：横長UIのガイドが安全に読めるか・操作部と警告が衝突しないか
- 800×600 相当／小型タブレット横：ガイド・情報パネル・HUDが利用可能か
- 標準4 viewport回帰：390×844 touch、844×390 mouse、768×1024 touch、1024×768 mouse（既存CI）。実機結果で代用せずCIも保持
観察点：START高さのCI既知値44/44/48 CSS px（小型3画面）、説明最終行との間隔7/17/22 CSS px。寸法合格を**指での誤タップゼロの実証に置き換えない**。
向き変更でUIが再配置されるか：______ / 二重押下・押下不能・文字/ボタン衝突：______ / 結果：☐PASS ☐FAIL ☐UNTESTED

## 5. 本物のプレイ進行：難度と貨物警告
QAコマンド、直接状態書換え、成功値の注入は一切禁止。実際のtap/clickで進行する。
1. START → 緑交差点で乗換 → 同じマークのHUBへ配達。成功・失敗の視覚的違いを観察。
2. **NIGHT（3配達）**に到達し、難度と配送制限時間が理解できるか記録。
3. **ACE（6配達）**に到達し、理不尽な時間切れや操作不能がないか記録。
4. 自然プレイで残り**3秒以内の警告**を観察。赤い枠・残秒・進捗の表示だけでなく、本人が3秒以内に「急ぐ必要がある」と認識したかを分けて記録。
5. 結果画面→RETRY→BESTが保持されるか確認。
結果：NIGHT到達 ______ / ACE到達 ______ / 3秒警告本人認識 ______ / 成功・失敗理解 ______ / BEST保持 ______
CIの警告PNG描画確認は済みだが、実機3秒以内認知は現時点**UNTESTED**。

## 6. 音声・端末性能
- SOUND ON：本体スピーカーで決定/配達成功・失敗等の音を聞き分けられるか、音割れ・極端な音量差・無音がないか
- SOUND OFF：再生が止まるか。ONへ戻した時に復帰するか
- イヤホン使用時：ON/OFF・音質・遅延の違和感
- 3分以上の連続プレイ：カクつき、入力遅延、画面回転後の復帰、目立つ発熱/バッテリー消耗傾向（端末条件付きで記録）
端末・ブラウザ・観察時間を伴わない「FPS正常」「発熱なし」「音良好」はPASSにしない。
音声: ☐PASS ☐FAIL ☐UNTESTED / 性能: ☐PASS ☐FAIL ☐UNTESTED / エビデンス: ______

## 7. 判定と改修優先度
1. **P0**: 押せない/ゲーム不能、初見操作が理解不能、クリア進行不能、UI重大衝突。
2. **P1**: 320幅で文字が読めない、3秒警告を認識できない、誤タップ多発、失敗理由不明。
3. **P2**: 音質/演出/余白/表示密度/端末差の改善。
不具合1件につき、テスト端末・build・再現手順・期待/実動作・発生率・画像/動画・影響範囲を記録する。

## 8. 完了Gate（GAME-076へ結果を戻す条件）
- CI 4標準viewport自然入力E2E（NIGHT/ACE、BEST、ON/OFF）と小型3画面レイアウトに重大な回帰がない。
- 実機の初見30秒、タップ誤操作、警告の瞬間認知、音声（スピーカー/イヤホン）、FPS/発熱、縦横回転の**結果が記録され**、未実施は未実施と明記される。
- 10軸×10点を独立再採点し、加点は測定証拠に結びつける。**80/100未満なら未完了**として改善継続。
- Human Gate結果の入力前に、自動化テスト成功のみで実機項目をPASSへ昇格させない。
- mainへのマージ、本番化、新たな課金・公開範囲変更はこの試験票によって承認されたことにならない。

### テスター記録ひな形
```
build/commit: 
date JST / device / OS / browser / orientation:
first 30s: PASS|FAIL|UNTESTED, first action seconds:
mis-taps: __, explanation needed?:
NIGHT / ACE / 3s warning recognition:
START / RESULT / RETRY / BEST:
speaker / headphone / ON-OFF:
FPS/responsiveness / heat / rotation:
repro steps and screenshots (if any):
independent conclusion / unresolved items:
```
