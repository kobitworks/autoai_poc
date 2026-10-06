# GAME-G008「影渡りステルス」PoC仕様 v1.0

- Project: P021 ゲーム開発
- Game ID: GAME-G008
- Slug: shadow-step-stealth
- Genre: 2Dステルス / 光と影のルートパズル
- Engine: Godot 4.7.2 / GDScript / Compatibility renderer / Web single-thread
- Primary devices: smartphone / tablet
- Target play length: 1 stage 60–90 sec, 3 stages total
- Status: implementation-ready specification
- Date: 2026-10-07

## 1. 目的

「光の向きを読む → 安全な影を選ぶ → 移動タイミングを決める → 必要なら危険地帯へ情報片を取りに行く → 出口へ到達する」という短い判断ループを、タップ主体で直感的に遊べる2DステルスPoCとして検証する。

既存GAME-G001〜G007と異なる、視界・死角・待機・リスク/リターンを中心にしたゲーム性をP021の新しい作例とする。

PoC段階でも技術デモだけにせず、タイトル → 遊び方 → 3ステージ → リザルト → 再挑戦までをURL単独で一続きのゲーム体験として成立させる。

## 2. PoCスコープ

### 実装するもの

- 3ステージ
- 遮蔽物ノードを結ぶ移動グラフ
- タップ移動
- 長押しによる「様子見」表示
- 回転/往復するサーチライト
- 遮蔽物による視線遮断
- 発見ゲージと警戒段階
- 任意回収物「情報片」
- スコア / コンボ / 評価ランク
- タイトル / HOW TO PLAY / ステージ選択 / HUD / ポーズ / リザルト / 失敗画面
- ステージ別ベストタイム / 情報片 / 最高評価
- SFX音量設定
- Phone / Tablet の Portrait / Landscape
- Web Export
- Game Hub共通ランタイム構成
- headlessロジックテスト
- 4標準viewportブラウザQA
- QAモード
- 外部素材を使う場合のASSETS.md / CREDITS.md

### PoCでは実装しないもの

- ログイン
- DB
- オンラインランキング
- 課金
- 広告
- 外部AI/API
- マルチプレイ
- 本格的な経路探索AI
- 3D
- 敵との戦闘
- ランダム即死要素

## 3. 最初の30秒

初見ユーザーが30秒以内に以下を理解できることを必須とする。

1. 影の中にいる間は安全。
2. 隣接する遮蔽物をタップすると、その影へ移動する。
3. サーチライトに照らされ続けると発見ゲージが上がる。
4. 発見ゲージが100になる前に影へ戻れば回復できる。
5. 出口へ着けばクリア。
6. 情報片は任意。危険だが高得点につながる。

Stage 1開始時だけ、操作を止めない短い3ステップのオーバーレイを表示する。

- 「影から影へタップ」
- 「光に入ると発見ゲージ上昇」
- 「出口へ。情報片は任意」

文章だけに頼らず、影アイコン、指アイコン、光錐、出口マーカーを併用する。

## 4. 基本ゲームループ

タイトル
→ ステージ選択
→ 3秒カウントダウン
→ サーチライトの周期を観察
→ 隣接する影へタップ移動
→ 必要に応じて長押しで次の安全時間を確認
→ 情報片を取るか安全ルートを選ぶ
→ 警戒を管理
→ 出口へ到達
→ Score / Rank / Best更新
→ Next / Retry / Stage Select

失敗時は2タップ以内で再挑戦できること。

## 5. 2D座標と遮蔽物グラフ

ゲーム座標は基準1280 x 720のlogical spaceで管理し、実viewportへControl/CanvasItemで拡縮する。

### 5.1 CoverNode

各遮蔽物をCoverNodeデータとして保持する。

必須フィールド:

- id
- position: Vector2
- radius
- neighbors: Array[StringName]
- shadow_radius
- peek_offset
- visual_profile
- info_fragment_id: 任意
- tags: safe / risky / tutorial / exit_near 等

プレイヤーは原則としてCoverNode間だけを移動する。自由移動を初期PoCへ入れず、タッチ精度による理不尽さを避ける。

### 5.2 Edge

隣接ノード間をCoverEdgeとして定義する。

- from_id
- to_id
- travel_time_sec
- exposure_weight
- one_way: default false
- enabled: default true

移動中は線形補間だけにせず、ease-in/ease-outを付ける。標準移動時間は0.45〜0.85秒。長距離や危険ルートほど長くする。

### 5.3 遮蔽判定

遮蔽物はOccluderSegmentまたはPolygon2D相当の単純凸形状として判定用データを持つ。

視線判定は「サーチライト原点 → プレイヤー中心」の線分に対し、遮蔽物判定形状が先に交差した場合は遮蔽成立とする。

見た目と判定の乖離を抑えるため、判定形状は表示形状より5〜8%内側にする。

## 6. 入力仕様

### 6.1 タップ移動

- 現在CoverNodeのneighborsだけを選択可能。
- 選択可能ノードには薄いリングを出す。
- タップ対象は最低48 x 48 logical px相当を確保。
- タップ時に移動先リングを発光し、短いSFXを鳴らす。
- 移動中の別ノード連打はキューしない。現在移動完了後に再入力を受ける。
- 同じノードの連打で状態が破綻しないこと。

### 6.2 長押し「様子見」

隣接CoverNodeを0.45秒以上長押しすると移動せず、以下を最大1.2秒表示する。

- 対象ノードまでの想定移動時間
- 現在のサーチライト周期から見た「今なら安全 / まもなく危険」
- exposure_weightの3段階表示

これは攻略保証ではなく、現在フレーム時点の補助情報とする。指を離すと表示を閉じる。

### 6.3 PC補助入力

- Arrow / WASD: 選択可能ノードの方向選択
- Enter / Space: 決定
- Esc / P: ポーズ
- R: リザルト/失敗画面でRetry

キーボードを進行の必須条件にしない。

## 7. サーチライト視界判定

SearchLightデータ:

- id
- origin: Vector2
- angle_rad
- rotation_mode: sweep / loop / scripted
- min_angle
- max_angle
- angular_speed
- range
- half_fov_rad
- intensity
- warning_lead_sec
- stage_phase_offset

### 7.1 光錐内判定

プレイヤーへのベクトルをv、ライト向きをdとする。

- distance(v) <= range
- angle_between(normalize(v), d) <= half_fov
- Occluderによる遮蔽なし

上記すべてを満たした時だけvisible=trueとする。

境界のちらつきを避けるため、視界角には2度程度のヒステリシスを持たせる。

### 7.2 予告

- 光錐は半透明で常時描画する。
- 警戒上昇の0.25秒前から外周を明滅させる。
- 色だけでなく光錐の輪郭・アイコン・SFXでも危険を伝える。
- Stage 1の最初15秒は高速回転を使わない。

## 8. 警戒モデル

Alertは0.0〜100.0。

標準値:

- 完全遮蔽中: -32 / sec
- 光錐内かつ移動していない: +34 / sec
- 光錐内かつ移動中: +48 / sec
- 高強度ライト: 上昇量 x 1.20
- 情報片取得直後0.6秒: 上昇量 x 1.10（演出上の緊張だけで即死させない）

段階:

- 0–34: HIDDEN
- 35–69: SUSPICIOUS
- 70–99: DANGER
- 100: SPOTTED / FAIL

Alertが70を超えたら、HUD・画面周辺・SFXを強くする。70未満へ戻れば段階的に落ち着かせる。

一瞬光に触れただけで失敗しないことを必須とする。

## 9. 情報片・スコア・評価

### 9.1 情報片

- 各ステージ2〜4個
- すべて任意
- 安全ルートから1手以上外れた場所へ配置
- 取得すると+1200点
- 同一プレイ中の再取得不可

### 9.2 基本スコア

- Stage clear: +5000
- 情報片: +1200 / 個
- Alert peak 35未満: +2000
- Alert peak 70未満: +1000
- No spotted warning（Alert 70未満を維持）: +500
- Time bonus: 残秒 x 40、最大+2400
- 連続して安全移動成功: 3回目以降 +100 x combo、1回最大+500
- 移動中にAlert 70到達でcombo reset

### 9.3 Rank

各ステージの最大情報片数をinfo_max、取得数をinfo_getとする。

S:
- clear
- info_get == info_max
- alert_peak < 70
- par_time以内

A:
- clear
- info_get >= ceil(info_max * 0.67)
- alert_peak < 100

B:
- clear
- info_get >= 1

C:
- clear

FAILEDはRank対象外。

閾値は初回10プレイ程度の結果で調整してよいが、変更理由をタスク実行メモに残す。

## 10. 3ステージ仕様

### Stage 1「薄明の資料庫」

目的: タップ移動、遮蔽、Alert、出口を学ぶ。

- time_limit: 90 sec
- CoverNode: 9
- Edge: 12前後
- SearchLight: 2
- Info Fragment: 2
- Exit: 1
- 回転: ゆっくりしたsweep中心
- 分岐: 安全ルート1、高得点ショートカット1
- 最初15秒はTutorial safe zone
- par_time: 65 sec

### Stage 2「交差する警備区画」

目的: 複数ライトの周期差と安全/危険ルート選択。

- time_limit: 95 sec
- CoverNode: 13
- Edge: 19前後
- SearchLight: 3
- Info Fragment: 3
- Exit: 1
- 2灯の光錐が周期的に交差する区画を2か所
- 一方通行Edgeを1か所だけ導入
- 安全な遠回り / 危険な短距離ルートを明確化
- par_time: 72 sec

### Stage 3「零時の中枢保管室」

目的: これまでの判断を組み合わせる最終試験。

- time_limit: 105 sec
- CoverNode: 16
- Edge: 24前後
- SearchLight: 4
- Info Fragment: 4
- Exit: 1
- sweep / loop / scriptedを混在
- 途中で照射周期が1回だけ変化するPhase 2を導入
- Phase変化は2秒前に警告灯とSFXで必ず予告
- 高得点ルートは2回の危険横断を要求
- par_time: 82 sec

ランダムで突然パターンを変えず、同じstage seedでは同じ動作を再現できるようにする。

## 11. 画面・HUD

### タイトル

必須要素:

- 「影渡りステルス」
- 1行説明「光を避け、影から影へ。」
- PLAY
- STAGE SELECT
- HOW TO PLAY
- SOUND
- CREDITS（外部素材採用時）

ロード後5秒以内にジャンルと目的が分かること。

### HUD

常時表示:

- Stage
- Time
- Alert
- Info fragment count
- Score
- Combo
- Pause

最優先はAlertとTime。狭い画面ではScore/Comboを小さくまとめる。

Alertは色だけでなく、ラベル（HIDDEN / SUSPICIOUS / DANGER）、ゲージ形状、警戒アイコンを併用する。

### リザルト

- CLEAR / FAILED
- Rank
- Score
- Time
- Info
- Alert Peak
- BEST更新
- NEXT（clear時）
- RETRY
- STAGE SELECT

## 12. レスポンシブ仕様

Godot基準:

- logical viewport: 1280 x 720
- content scale mode: canvas_items
- aspect: expand
- UIはControl + Anchor + Containerで構成
- ゲーム座標とUI座標を分離

### Phone Portrait 390x844

- 上: 2段HUD
- 中央: ゲーム領域をほぼ正方形〜縦長で確保
- 下: 操作ヒント / 状態説明
- CoverNodeタップ領域は画面縮小後も48px相当以上
- 本文14px相当未満にしない

### Phone Landscape 844x390

- HUDは原則上部1段
- ゲーム領域を最大化
- Info/Comboを右上へ圧縮
- Pauseは右端
- ブラウザ上下UIを考慮し上下12 logical px以上の余白

### Tablet Portrait 768x1024

- HUDとゲーム領域の間に余白
- 情報片/スコア補助情報を別行表示可
- タップ対象を過度に巨大化させない

### Tablet Landscape 1024x768

- HUD 1段
- 最大のゲーム視界
- HOW TO/長押し補助表示を右側へ出してゲーム中央を塞がない

### 必須4 viewport

- Phone Portrait 390x844
- Phone Landscape 844x390
- Tablet Portrait 768x1024
- Tablet Landscape 1024x768

## 13. 保存データ

ConfigFile: user://shadow_step_stealth.cfg

[global]
tutorial_completed
unlocked_stage
sfx_volume_step

[stage_1]
best_score
best_time_ms
best_info
best_rank

[stage_2]
best_score
best_time_ms
best_info
best_rank

[stage_3]
best_score
best_time_ms
best_info
best_rank

ルール:

- Best更新はclear時のみ
- 欠損キーは安全な初期値
- 破損ファイル時は起動不能にせず初期化
- 設定画面に明示的な記録リセットを置く
- 保存処理失敗でプレイを停止しない

## 14. アート・演出・音

アート方向は「暗い施設 + 冷たい監視光 + 鮮明な影」を基本とする。

公開候補で単純な矩形と文字だけに見えないよう、最低限以下を用意する。

- 多層の施設背景
- 遮蔽物の輪郭と質感
- プレイヤーのシルエットと移動残像
- サーチライト光錐のグラデーション
- 影のビネット
- 情報片の発光
- Alert上昇時の画面周辺パルス
- 発見時の走査線 / 警告演出
- CLEAR時の出口解放演出

初期実装はGodotのPolygon2D / Line2D / GradientTexture / Particle系による独自描画を優先し、重い画像素材を必須にしない。

外部素材を使う場合は実装時に配布元とライセンスをFresh-readし、CC0等を優先する。出典不明、NC、検索画像直取得は使用しない。採用時点でASSETS.mdに素材名、作者、URL、取得日、ライセンス、改変可否、クレジット要否、配置先を記録する。

最低限のSFX:

- UI決定
- 移動開始
- 影へ到達
- 情報片取得
- Alert 70到達
- SPOTTED
- CLEAR
- FAIL

ブラウザ自動再生制限に合わせ、最初のユーザー操作後にAudioを開始する。SFXは100 / 70 / 40 / OFFの4段階。

## 15. Godot実装構成

推奨:

p021-game/sources/shadow-step-stealth/
- project.godot
- export_presets.cfg
- scenes/
  - Main.tscn
  - TitleScreen.tscn
  - StageSelect.tscn
  - StageRunner.tscn
  - Player.tscn
  - CoverNode.tscn
  - SearchLight.tscn
  - InfoFragment.tscn
  - HUD.tscn
  - ResultScreen.tscn
  - PauseMenu.tscn
- scripts/
  - Main.gd
  - StageRunner.gd
  - CoverGraph.gd
  - PlayerController.gd
  - VisibilityModel.gd
  - AlertModel.gd
  - SearchLight.gd
  - StageDefinition.gd
  - ScoreModel.gd
  - SaveManager.gd
  - AudioManager.gd
  - ResponsiveLayout.gd
  - QAMode.gd
- data/
  - stage_01.tres
  - stage_02.tres
  - stage_03.tres
- assets/
- tests/
- ASSETS.md
- CREDITS.md

責務:

- CoverGraph.gd: ノード/Edgeと隣接判定
- VisibilityModel.gd: 光錐・距離・遮蔽の純粋判定
- AlertModel.gd: Alert増減と段階遷移
- PlayerController.gd: tap / long-pressを正規化して移動
- SearchLight.gd: 角度更新と予告
- StageDefinition.gd: ステージ固有データ
- StageRunner.gd: ステージ進行、clear/fail、情報片
- ScoreModel.gd: score/rank計算
- SaveManager.gd: ConfigFile
- AudioManager.gd: 音量と主要SFX
- ResponsiveLayout.gd: viewport/orientation別UI
- QAMode.gd: 自動試験専用。通常プレイへ影響させない

主要signal:

- move_started(from_id, to_id)
- move_completed(node_id)
- visibility_changed(is_visible)
- alert_changed(value, state)
- info_collected(fragment_id)
- stage_cleared(result)
- stage_failed(reason)

## 16. Game Hub / Web Export

P021共通Game Hub方針を維持する。

公開想定:

p021-game/
- runtime/godot-4.7.2/
  - godot.js
  - godot.wasm
- games/shadow-step-stealth/
  - index.html
  - shadow-step-stealth.pck
  - icon.*
- sources/shadow-step-stealth/

方針:

- Godot JS/WASMは共通runtimeを参照。
- ゲーム固有PCKだけをゲーム配下へ置く。
- Godot versionとruntime checksumをCIで固定。
- Hub側でpreload、HTTP cache / Service Workerを利用。
- キャッシュキーはversionedにする。
- 共通runtime再利用が技術的に成立しない場合は、バイナリ重複を黙って追加せず、制約と計測値を実行メモへ残す。
- DB、R2、有料サービスは使わない。

## 17. QAモード

URL query ?qa=1 の時だけ有効。

QAモード:

- stage seed固定
- Stage 1〜3を全開放
- Light angle / visible / alert / current node / score / timerを小さなoverlayへ表示
- 自動QA用に安全な画面遷移フックを提供
- 通常URLではoverlayとQA shortcutを無効化

QA shortcutだけをゲーム性評価の代替にしない。

## 18. headlessロジックテスト

最低限:

1. CoverGraphで未接続ノードへ移動できない。
2. 接続ノードへ移動できる。
3. SearchLight距離外はvisible=false。
4. FOV外はvisible=false。
5. FOV内かつ遮蔽なしはvisible=true。
6. FOV内でもOccluderが間にあるとvisible=false。
7. FOV境界ヒステリシスでフレームごとのちらつきを抑制。
8. 遮蔽中Alertが減る。
9. 光錐内Alertが増える。
10. Alert 100でfail。
11. Alertが0未満/100超にならない。
12. 情報片は1プレイ1回だけ加点。
13. Score計算。
14. Rank判定。
15. Best record更新。
16. ConfigFile欠損/破損時fallback。
17. Retryを繰り返しても状態が初期化される。
18. Stage seed固定時にSearchLight周期が再現可能。

## 19. ブラウザQA

GitHub Actions + Playwright / Chromiumで4標準viewportを確認する。

各viewportで最低限:

- Webロード成功
- console error 0
- page error 0
- タイトル表示
- タッチ相当入力でPLAY
- Stage選択
- タップでノード移動
- 長押し補助表示
- Alert増減
- 情報片取得
- Result到達
- Retry
- Stage Selectへ戻れる
- HUD/ボタンがviewport外へはみ出さない
- canvasが表示領域へ収まる
- 重要文字が読める
- スクリーンショットartifact保存

GAME-G008の公開候補判定前に、QA shortcutを使わずStage 1を通常ルールで最低1回完走する手動/半自動試遊を行う。

## 20. P021品質ゲート対応

### 企画

- 30秒以内の目的理解: §3
- 明確なゴール: 出口到達
- 判断要素: 安全/高得点ルート、移動タイミング、情報片
- 変化: 3ステージでライト数、周期、分岐、Phase変化を増加
- リプレイ: Best time / Info / Rank / Score

### 実装

- タッチ主体
- 主要操作へ視覚/SFX feedback
- Alertは色だけに依存しない
- 失敗→Retryを2タップ以内
- Portrait / Landscape
- 連打耐性
- 視線判定を純粋ロジックへ分離

### 技術

- 実行時エラー0
- Godot Web single-thread
- 共通runtime
- deterministic QA
- save fallback
- 4標準viewport
- repeated retry

### 公開品質

公開候補判定前にproject_rule §10.5の10項目100点評価を行う。

- 70点以上: 公開候補
- 原則80点以上: 一般公開完了目標
- 80点未満: 不足項目を明示し、AIで改善可能な内容を次タスク化

## 21. GAME-036完了条件

本仕様で以下を確定したためGAME-036の完了条件を満たす。

- 3ステージ構成
- 2D座標 / CoverNode / Edgeグラフ
- サーチライト視界判定
- 遮蔽判定
- Alertモデル
- タップ / 長押し入力
- 情報片
- Score / Rank
- HUD
- タイトル / ポーズ / 結果
- 保存項目
- Phone / Tablet Portrait / Landscape
- アート / 演出 / 音
- 無料素材 / ライセンス方針
- Godot Scene / Script責務
- Game Hub共通runtime方針
- headlessロジックテスト
- 4標準viewport QA
- P021 project_rule §10品質ゲート

## 22. 次工程

次の実装タスクでは、まずGAME-G008のGodot基盤とStage 1を構築する。

優先順:

1. Godot project / scene skeleton
2. CoverGraph / VisibilityModel / AlertModel
3. tap / long-press input
4. StageDefinition
5. Stage 1「薄明の資料庫」
6. HUD / title / result
7. save / audio
8. Web Export / Game Hub共通runtime
9. headless tests
10. 4 viewport browser smoke

Stage 1で「観察 → タップ移動 → 警戒管理 → 情報片判断 → 出口」の基本ループが成立したことを確認してからStage 2 / 3へ展開する。
