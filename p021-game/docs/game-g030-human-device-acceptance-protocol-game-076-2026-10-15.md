# GAME-076 / GAME-G030 実機初見・可読性・音・性能の受入試験票 v1.3
作成: 2026-10-15 JST / AutoAI P021（GAME-076継続）
対象: Orbit Switch Courier (Godot Web)。親タスク: GAME-076。
成果物区分: **試験手順と記録テンプレート**。実機テストの実施結果・承認ではない。

## 1. 基準ビルドと検証済み事項（2026-10-15 16:10:55 JSTの実公開配信バイト検証結果へ同期）
- 正本コード: [autoai_poc/develop/p021-game](https://github.com/kobitworks/autoai_poc/tree/develop/p021-game)
- ゲーム本体: [Main.gd](https://github.com/kobitworks/autoai_poc/blob/develop/p021-game/sources/orbit-switch-courier-godot/Main.gd)
- **実機受入の最新CI基準**: [Godot Actions run 38679988812](https://github.com/kobitworks/autoai_poc/actions/runs/38679988812)、自然入力QA HEAD `cde75bd6e845d781e45f908ab623fba860cb36b5`（develop push）。旧run `38664938941` は履歴であり、最新版の合格証明には使わない。
- **GitHub API再照合（2026-10-15）**: このrunの `contract` / `export-web` / `browser-quality` は**すべて completed/success**。artifact [11948265436](https://github.com/kobitworks/autoai_poc/actions/runs/38679988812/artifacts/11948265436) は **4,938,123 bytes**、`sha256:d618473ece3c645f8783c0b7e635a7f3abff1493aa84742a75b8a5ea5eec97f6`、`expired=false`、対象HEAD一致。
- 今回のGitHub読戻しblob: Godot `Main.gd` = `10cb198d9b3fcd442f5c0257d29dc845246f48e3`、自然入力QA = `ecf3dbe1c13baf4177e92983e265040d877b2e06`。この組のソース・QAをテスト基準とし、後発の変更には別の合格証跡を要求する。
- [GAME-076独立監査](./game-g030-urgent-hud-text-qa-game-076-2026-10-15.md) による同一runの証跡: ZIP71件CRC正常、PNG69枚・JSON2件検査、標準4 viewportの自然入力**4/4 PASS**、小型3 viewportは**3/3 PASS_GEOMETRY**、320×568のPLAYING操作案内実描画値は `TAP · SWITCH` で省略なし。擬似viewport回転は縦→横／横→縦**2/2 PASS_ORIENTATION**。**小型3画面のフルルートE2Eや実端末での物理回転PASSを意味しない**。本試験票更新ではZIPを再ダウンロードしていない。
- **公開配信ビルドの同一性 Gate: `PASS_LIVE_BYTES`（2026-10-15 16:10:55 JSTの時点）**。検証済みURL: https://kobitworks.github.io/autoai_poc/p021-game/games/orbit-switch-courier/ 。read-only GitHub Actions [run 38697001992](https://github.com/kobitworks/autoai_poc/actions/runs/38697001992) / job `116295822548` は `completed/success`。公開URLから実際にHTTP取得した `build.json`（387B）、`index.html`（5,625B）、`index.js`（279,815B）、`index.pck`（6,958,476B）、`index.wasm`（39,514,754B）の**5/5件がdevelop配布物とサイズ・SHA-256・バイト単位で一致**（`PASS_LIVE_BYTES`, exit 0）。`build.json` の `source_commit=847838737ec419b4fc1948ef4e256c155e87d393`, Godot CI `workflow_run_id=38687898088`, attempt `1`, `quality_target=80` を確認。**これは検証時点の配信同一性であり、後日の再デプロイ・キャッシュ変化まで保証しない。実機の初見可読性や音声・性能・合格を意味しない**。
- 独立暫定品質は**76/100**（一般公開品質目標80/100未達）。初見30秒・指誤タップ・3秒警告の即時認知・スピーカー/イヤホン実音・FPS/発熱・物理画面回転は**UNTESTED**。結果を人間が記録するまで各項目をPASSにしない。

### 1.1 実機テスト開始前のビルド同一性Gate
1. 対象URLまたは配布Web Exportの出所、取得日時、コミット（取得可能な場合）とActions run番号を記録する。
2. 上記公開URLは2026-10-15 16:10:55 JST時点で5ファイル一致を実測済み。実機試験時のURL・アクセス日時・配信ビルドの識別情報を別途記録する。**別URL、後日の再デプロイ、差分がある場合はその配信への検証結果を流用せず、改めてbyte照合する**。同一性を確認できない新しいビルドによるHuman Gate合格は保留し、参考試遊として記録する。
3. CIの結果は実機での文字認知・操作・音声・性能のPASSへ転用しない。ビルドが一致しても、セクション3〜6の各項目を実際の人間・実端末で観察する。
4. 後続のコード/QA変更で別runが合格した場合は、そのrunのHEAD、artifact、差分を照合してから本基準を更新する。古いrunのPASSを流用しない。

### 1.2 公開配信 byte Gate の監査識別子と保持条件

- 検証方法: [read-only Node22検証器](https://github.com/kobitworks/autoai_poc/blob/develop/p021-game/qa/orbit-switch-courier-live-build.js) と [検証Actions定義](https://github.com/kobitworks/autoai_poc/blob/develop/.github/workflows/p021-game-g030-live-delivery-verify.yml)（導入commit `fff9722a6ccfcafd1b88c4ef7355345443fc8bb9`）。GitHub Actionsの**実ジョブログ**で5ファイルそれぞれ `localSha256==liveSha256`, `match=true` を再確認した（実公開HTTP GET、API応答の単純転記ではない）。
- 原本: [GitHub Actions artifact 11955280783](https://github.com/kobitworks/autoai_poc/actions/runs/38697001992/artifacts/11955280783) （821Bの結果ZIP、digest `sha256:77ba0a8fbad42cdaca28869a2d8d6f202d8ccf79aec2e2342bb9a6646d71ab92`）。保持は約7日で、2026-10-22頃に期限が来るため、後日に検証する場合は期限切れの旧artifactに依存せず検証Actionsを再実行する。
- **Gateを分離**: `PASS_LIVE_BYTES` = 配信同一性のみ。Godot CI自然入力4画面PASS / 小型3画面幾何PASS / 疑似縦横回転2/2 PASS / **物理端末Human Gate=UNTESTED** を混同しない。独立暫定76/100から、追加測定なしに80/100へ加点しない。
- 同一性検証とHuman Gateの実施日時・buildは必ず分けて残す。テスターが試した時点のURL/ビルド識別が不明なら、今回の過去の配信一致のみでその試遊を本Gateの正式PASSへ昇格させない。

## 2. テスト対象と記録欄
対象Web ExportのURL・配信経路/取得日時: ______
基準とのビルド同一性: ☐確認済 ☐不一致 ☐未確認（根拠: ______）
検証対象のソース/QA commit・Actions run・artifact識別子: ______
実機種別/OS・ブラウザversion・画面の向き: ______
テスト日時(JST): ______　　テスター（仮名可）: ______
音声経路: ☐本体スピーカー ☐イヤホン ☐無音　　画面倍率/文字サイズ設定: ______
画面撮影・録画: 任意。同意のない人物・個人情報・アカウント情報は含めない。
環境注記: 指定のGitHub Pages URLは2026-10-15 16:10:55 JST時点に限り`PASS_LIVE_BYTES`。**試験時に別ビルドが配信された可能性がある場合は再照合し、別URL・新しいデプロイの同一性を推測しない**。CI/Pages一致だけでHuman GateをPASSにしない。

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

### 4.1 最新QAで新たに検証済み／実機で確認すべき点
- **320×568 Portrait、PLAYING下段案内**: QAでは実描画 `TAP · SWITCH`、省略なし。実機では指で操作しながら文字が自然に読めるか、視線移動や端末の文字拡大設定で欠けないかを別途記録する。読みやすさは自動テストの非省略判定だけでは確定しない。
- **縦→横→縦、横→縦→横**: ブラウザ疑似viewport切替と戻し、自然タッチでのSTART、PLAYING再配置は2/2自動合格。実機ではOSの実画面回転時にタッチ座標・情報パネル・START/SOUNDと下段案内が正しく再配置されるかを観察する。物理回転の合否は未検証。
- **ビルド記録**: ソース/QAのCI検証は `run38687898088` (`source_commit=847838737ec419b4fc1948ef4e256c155e87d393`)、実配信byte一致の証跡は `run38697001992`（2026-10-15 16:10:55 JST時点）を使用する。旧 `run38679988812` は実行履歴。試験時の配信が更新されていれば新たに5ファイル照合する。

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
- 320×568 Portrait PLAYING案内の実描画非省略、疑似縦横切替2系列のCI証跡と、実機の表示・指操作・物理回転の観測を**別欄で**記録する。
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
