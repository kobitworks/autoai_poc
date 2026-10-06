# GAME-G007「風読みグライダー」PoC仕様 v1.0


> ID correction (GAME-034, 2026-10-07): 風読みグライダーの正しい孫プロジェクトIDは `GAME-G007`。旧 `GAME-G003` は CityCraft 3D の正本IDとして維持する。過去のActions run / artifact / commit等に残る `g003` 表記は、訂正前に生成された不変の監査証跡としてそのまま参照する。
- Project: P021 ゲーム開発
- Game ID: GAME-G007
- Slug: `wind-reader-glider`
- Engine: Godot 4.7.2 / GDScript / Compatibility renderer / Web single-thread
- Primary devices: smartphone / tablet
- Target play length: 1 stage 60–90 sec, 3 stages total
- Status: implementation-ready specification
- Date: 2026-10-06

## 1. 目的

「風を読む → 安全ルートか高得点ルートを選ぶ → 高度とブーストを管理する → ゲートを抜けてゴールする」という短い判断ループを、タッチ主体で直感的に遊べる2.5D滑空アクションとして検証する。

既存の GAME-G001「1マス農園」の資源・時間管理、GAME-G002「過去の自分と協力するゲーム」の記録再生パズルとは異なる、連続操作・速度感・ルート判断をP021の新しい作例とする。

PoC段階でも単なる技術デモにせず、タイトル → チュートリアル → 3ステージ → リザルト → 再挑戦までを一続きのゲーム体験として成立させる。

## 2. PoCスコープ

### 実装するもの

- 3ステージ
- タッチドラッグ型の仮想スティック
- タッチ可能なブーストボタン
- PC補助入力
- 2.5D座標・投影
- 風ゾーン
- 高度 / ブースト / 耐久
- 必須ゲート / ボーナスゲート
- 障害物
- スコア / コンボ / メダル
- タイトル / 遊び方 / ステージ選択 / HUD / ポーズ / リザルト / 失敗画面
- ステージ別ベスト記録
- 音量設定
- Phone / Tablet の Portrait / Landscape
- Web Export
- Game Hub向け共通ランタイム構成
- 自動ブラウザQAと品質確認用QAモード
- 外部素材台帳 `ASSETS.md` と必要時の `CREDITS.md`

### PoCでは実装しないもの

- ログイン
- DB
- オンラインランキング
- 課金
- 広告
- 外部API
- マルチプレイ
- 大規模3D
- 物理ベースの本格飛行シミュレーション

## 3. 最初の30秒

初見ユーザーが30秒以内に以下を理解できることを必須とする。

1. ゴール方向へ自動で前進する。
2. 左下のドラッグ操作で上下・奥行きを調整する。
3. 青系の上昇気流に入ると高度とブーストを回復できる。
4. ゲートを一定数通過してゴールすればクリア。
5. 狭いボーナスルートは高得点だが障害物が多い。
6. 右下のブーストは速いがゲージを消費する。

Stage 1開始時のみ、操作を止めない3枚以内の短いオーバーレイを順次表示する。文章だけで説明せず、指・矢印・ゲート・上昇気流のアイコンを併用する。

## 4. ゲームループ

```
タイトル
  ↓
ステージ選択
  ↓
3秒カウントダウン
  ↓
自動前進
  ↓
風を読む
  ↓
高度 / 奥行きを操作
  ↓
必須ゲート / ボーナスゲート / 上昇気流 / 障害物
  ↓
ブースト判断
  ↓
ゴール
  ↓
スコア・メダル・BEST更新
  ↓
次ステージ / 再挑戦 / ステージ選択
```

失敗時は2タップ以内で再挑戦できること。

## 5. 2.5D座標モデル

Godotの描画はNode2D中心とし、本格3Dを使わない。

シミュレーション座標を以下の3値で保持する。

- `x`: 進行距離[m]
- `y`: 高度 0.0–100.0
- `z`: 擬似奥行き -1.0–+1.0

`Vector3(x, y, z)` は独自ゲーム座標として扱い、物理判定はこの座標で行う。

### 画面投影

基準表示では機体を画面幅の約28%位置へ置き、カメラの `camera_x` を進行させる。

概念式:

```
screen_x = glider_anchor_x + (world_x - camera_x) * pixels_per_meter
screen_y = ground_y - world_y * altitude_scale + world_z * depth_offset
visual_scale = lerp(0.84, 1.12, (world_z + 1.0) * 0.5)
```

- `z=-1`: 奥
- `z=+1`: 手前
- 奥行きはスプライト拡縮、Yオフセット、描画順、パララックス速度で表現する。
- 当たり判定は見た目のスケールではなく世界座標で判定する。
- 地面・雲・遠景・前景を複数Parallax層へ分離する。

## 6. 入力仕様

### タッチ

左側55%を操舵領域とする。

- 1本目の指を置いた位置を仮想スティック中心とする。
- 最大半径: 72 logical px
- デッドゾーン: 12 logical px
- 水平: 擬似奥行き `z`
- 上方向: 上昇
- 下方向: 降下
- 指を離すと0へ0.15秒程度で戻す。

右下にブーストボタンを置く。

- 押下中のみブースト
- 最小タップ領域: 64 x 64 logical px
- 操舵とブーストの2点マルチタッチを許可
- 押下時にサイズ変化 + SFX + 発光で入力を明示

### PC補助入力

- W / Up: 上昇
- S / Down: 降下
- A / Left: 奥側へ
- D / Right: 手前側へ
- Space: ブースト
- Esc / P: ポーズ
- R: リザルト/失敗画面で再挑戦

キーボードをゲーム進行の必須条件にしない。

## 7. 飛行数値モデル

固定物理更新は60Hzを基準とする。

### 共通パラメータ

| パラメータ | 初期値 |
|---|---:|
| 高度 | 55 |
| 高度下限 | 0 |
| 高度上限 | 100 |
| ブースト | 60 / 100 |
| 耐久 | 100 / 100 |
| 自然沈下 | 1.2 m/s |
| 操舵最大上昇 | +6.5 m/s |
| 操舵最大降下 | -6.5 m/s |
| 上昇時前進速度減衰 | 最大12% |
| 降下時前進速度増加 | 最大5% |
| ブースト速度倍率 | +35% |
| ブースト消費 | 25 / sec |
| 通常ブースト回復 | 5 / sec |
| 上昇気流中の追加回復 | 18 / sec |
| 軽衝突ダメージ | 20 |
| 強衝突ダメージ | 35 |
| 衝突無敵時間 | 0.8 sec |
| コース外猶予 | 1.5 sec |

### 更新式

入力値を `steer_x, steer_y = -1.0..1.0` とする。

```
climb_target = steer_y * 6.5 - 1.2 + wind_lift
vertical_speed = move_toward(vertical_speed, climb_target, 12.0 * delta)

pitch_speed_factor =
    1.0 - max(steer_y, 0.0) * 0.12
        + max(-steer_y, 0.0) * 0.05

forward_speed =
    base_speed * pitch_speed_factor
    * (1.35 if boost_active else 1.0)
    + wind_forward

depth_target = steer_x * 0.85 + wind_cross
depth_speed = move_toward(depth_speed, depth_target, 2.5 * delta)

x += forward_speed * delta
y += vertical_speed * delta
z += depth_speed * delta
```

- `y <= 0`: 高度喪失で失敗
- `y > 100`: 100でクランプし、上昇入力はそれ以上効かない
- `abs(z) > 1.0`: コース外警告
- `abs(z) > 1.0` が1.5秒継続: コースアウトで失敗
- `abs(z) <= 1.0` に戻ればコース外タイマーをリセット
- 耐久0: 失敗
- ブースト残量5未満では新規ブースト開始不可

数値はStage 1の手動試遊で調整してよいが、変更時は `StageDefinition` または共通定数へ集約し、コード中へ散在させない。

## 8. 風モデル

風は `WindZone` データとして配置する。

共通フィールド:

- id
- type
- x_start / x_end
- y_min / y_max
- z_min / z_max
- strength
- direction
- turbulence_seed
- visual_profile

### 風種別

#### CALM
- 補正なし

#### UPDRAFT
- `wind_lift = +3.8 * strength`
- ブースト追加回復 `+18 * strength / sec`
- 上昇粒子とHUDの上向き矢印を表示

#### CROSSWIND
- `wind_cross = +/-0.22 * strength`
- 風向矢印を表示
- 色だけでなく矢印方向でも識別

#### TAILWIND
- `wind_forward = +4.0 * strength m/s`
- 速度線を強調

#### TURBULENCE
- seed固定のノイズで `wind_lift +/-1.5`, `wind_cross +/-0.12`
- 完全ランダムな即死要素にしない
- 同一seedなら同じ揺れ方を再現しQA可能にする

風の境界に入る0.5秒前から視覚予告を表示する。

## 9. ゲート・障害物

### 必須ゲート

`RequiredGate` は以下を持つ。

- world_x
- altitude_center
- depth_center
- altitude_tolerance
- depth_tolerance
- point_value = 1000

機体がゲートのx座標を前方から後方へ通過した瞬間に、高度・奥行きが許容範囲内なら成功。

失敗しても即ゲームオーバーにせず、通過数不足として扱う。

### ボーナスゲート

- point_value = 1500
- 必須ではない
- 障害物や強風の近くへ置き、リスク/リターンを作る

### 障害物

- 雲塊、岩壁、浮遊標識等
- 障害物ごとに軽衝突 / 強衝突を設定
- 当たり判定は見た目より5–10%小さくし、不公平な接触を避ける
- 衝突時はノックバック、画面揺れ、耐久減少、短い無敵を適用

## 10. ステージ仕様

### Stage 1「朝凪の丘」

- length: 1400m
- base_speed: 18.0m/s
- 想定: 70–85秒
- 必須ゲート: 8
- クリア必要数: 6
- ボーナスゲート: 3
- UPDRAFT: 4
- CROSSWIND: 2（弱）
- 障害物: 4（静的）
- 目的: 操作、上昇気流、ブーストを学ぶ
- 最初の30秒は強い乱気流を置かない

### Stage 2「峡谷の横風」

- length: 1550m
- base_speed: 19.5m/s
- 想定: 72–85秒
- 必須ゲート: 10
- クリア必要数: 8
- ボーナスゲート: 5
- UPDRAFT: 5
- CROSSWIND: 5
- TAILWIND: 2
- 障害物: 8
- 目的: 安全ルートと高得点ルートの選択
- 奥行き側ルートと高度側ルートの2択を最低2か所作る

### Stage 3「雷雲の切れ間」

- length: 1750m
- base_speed: 21.0m/s
- 想定: 75–90秒
- 必須ゲート: 12
- クリア必要数: 10
- ボーナスゲート: 6
- UPDRAFT: 6
- CROSSWIND: 4
- TURBULENCE: 5
- 障害物: 12
- 目的: これまでの操作を組み合わせる最終試験
- 雷は視覚/音演出に限定し、予告なしのランダムダメージには使わない

## 11. スコア・コンボ・メダル

### 基本スコア

- 必須ゲート成功: +1000
- ボーナスゲート成功: +1500
- 上昇気流の中心通過: 初回のみ +300
- 連続ゲート成功: `+250 * (combo - 1)`、1ゲート当たり最大+1000
- ダメージまたはゲート失敗でコンボ解除
- タイムボーナス: par timeより速い秒数 x 100、最大+2000
- クリーンボーナス:
  - 耐久100: +2000
  - 耐久80以上: +1000
  - それ未満: 0

### par time

- Stage 1: 80 sec
- Stage 2: 82 sec
- Stage 3: 86 sec

### メダル

クリアした時点でBronze。

| Stage | Silver | Gold |
|---|---:|---:|
| 1 | 9,000 | 13,000 |
| 2 | 11,500 | 16,000 |
| 3 | 14,000 | 19,000 |

初回プレイテスト10回程度の分布で閾値を調整してよい。変更理由を実行メモへ残す。

## 12. 画面・HUD

### タイトル

必須要素:

- ゲーム名
- 1行説明「風をつかみ、ゲートを抜けてゴールへ」
- PLAY
- STAGE SELECT
- HOW TO PLAY
- SOUND
- CREDITS（必要な外部素材がある場合）

ロード直後5秒以内に何のゲームか分かること。

### HUD

常時表示:

- Stage番号
- 進行率
- 必須ゲート `passed / target`
- Score
- Combo
- 高度
- Boost
- 耐久
- 風向 / 風強度

優先順位は「高度・Boost・耐久・ゲート」を高くし、画面が狭い場合にScore詳細を縮約する。

色だけで状態を表さず、アイコン・ラベル・ゲージ形状を併用する。

### ポーズ

- 続ける
- 最初から
- ステージ選択
- SOUND
- タイトルへ

### リザルト

- CLEAR / FAILED
- メダル
- Score
- Time
- Gate
- Damage
- Best更新
- 次ステージ
- 再挑戦
- ステージ選択

## 13. レスポンシブ仕様

Godot設定の基本:

- `display/window/size/viewport_width = 1280`
- `display/window/size/viewport_height = 720`
- stretch/content scale mode: `canvas_items`
- aspect: `expand`

UIは固定座標ではなくControl + Anchor / Containerで配置する。

### Phone Portrait — 390x844

- HUDは上部2段
- 操舵は左下
- Boostは右下
- 中央の機体・ゲート視界をUIで塞がない
- 重要文字は実表示14px未満にしない

### Phone Landscape — 844x390

- HUDは原則上部1段
- 操舵・Boostを左右下隅
- 高度/Boost/耐久は横長ゲージへ圧縮

### Tablet Portrait — 768x1024

- Phone Portraitを拡大するだけでなく、HUD余白と視界を増やす
- 操作UIを画面端へ寄せすぎない

### Tablet Landscape — 1024x768

- 最も広い視界
- HUDは1段または左右分割
- 操作UIは最大サイズを制限し、過度に巨大化させない

### セーフエリア

ブラウザの表示領域変化・モバイルの上下UIを考慮し、上下左右16 logical px以上のセーフマージンを設ける。

## 14. 保存データ

`ConfigFile` を使い `user://wind_reader_glider.cfg` に保存する。

保存項目:

```
[global]
tutorial_completed
unlocked_stage
sfx_volume_step
music_volume_step

[stage_1]
best_score
best_time_ms
best_medal

[stage_2]
best_score
best_time_ms
best_medal

[stage_3]
best_score
best_time_ms
best_medal
```

- 記録更新はクリア時のみ
- 破損/欠損時は安全な初期値へ戻す
- 旧キーがなくても起動できる
- リセット操作は設定画面から明示的に行う

## 15. アート・素材・音

### アート方向

「明るい空・風・雲・滑空」を主題とした統一感のある2Dイラスト調とする。

主要表示を単純な四角・丸・文字だけで終わらせず、最低限以下を用意する。

- グライダー
- 空/雲の背景レイヤー
- ゲート
- 上昇気流
- 障害物
- Boostエフェクト
- 衝突エフェクト
- CLEAR演出
- 風向アイコン
- 高度/Boost/耐久アイコン

### 素材方針

P021 `public-quality-and-asset-policy.md` を適用する。

優先順:

1. Kenney等のCC0素材
2. OpenGameArtのCC0
3. クレジット管理できるCC BY
4. 自作のオリジナル描画

禁止:

- NC
- 出典不明
- 画像検索からの直接取得
- 他ゲーム/映画/アニメ等の模倣素材
- ライセンス確認前の素材

外部素材は採用時点で個別ページをFresh-readし、`ASSETS.md` にasset_id / 作者 / URL / 取得日 / ライセンス / 改変可否 / クレジット / 配置先を記録する。

### 音

最低限:

- UI決定
- ゲート通過
- 上昇気流
- Boost
- 衝突
- CLEAR
- FAIL
- 風ループ

ブラウザ自動再生制限に合わせ、最初のユーザー操作後にAudioを開始する。

SFXは 100 / 70 / 40 / OFF の4段階を最低限用意する。BGMを入れる場合も同様に保存可能にする。

## 16. Godot実装構成

推奨ソース:

```
p021-game/sources/wind-reader-glider/
  project.godot
  export_presets.cfg
  scenes/
    Main.tscn
    TitleScreen.tscn
    StageSelect.tscn
    StageRunner.tscn
    Glider.tscn
    RequiredGate.tscn
    BonusGate.tscn
    WindZone.tscn
    Obstacle.tscn
    HUD.tscn
    ResultScreen.tscn
    PauseMenu.tscn
  scripts/
    Main.gd
    StageRunner.gd
    FlightModel.gd
    GliderController.gd
    StageDefinition.gd
    Gate.gd
    WindZone.gd
    SaveManager.gd
    AudioManager.gd
    ResponsiveLayout.gd
    QAMode.gd
  data/
    stage_01.tres
    stage_02.tres
    stage_03.tres
  assets/
  tests/
  ASSETS.md
  CREDITS.md
```

### 責務分離

- `FlightModel.gd`: 数値モデルのみ。UI・描画に依存させない
- `GliderController.gd`: 入力を正規化しFlightModelへ渡す
- `StageDefinition.gd`: ステージ固有値をResource化
- `StageRunner.gd`: 進行、ゲート、失敗/成功、スコア
- `SaveManager.gd`: ConfigFile
- `AudioManager.gd`: Audio設定と主要SFX
- `ResponsiveLayout.gd`: viewport/orientation別UI
- `QAMode.gd`: 自動試験用。通常プレイへ影響させない

信号例:

- `gate_passed(gate_id, type)`
- `gate_missed(gate_id)`
- `wind_changed(type, strength)`
- `durability_changed(value)`
- `boost_changed(value)`
- `stage_cleared(result)`
- `stage_failed(reason)`

## 17. Game Hub / Web Export構成

P021のGame Hub標準に合わせ、Godotランタイムの重複ダウンロードを避ける。

想定公開構成:

```
p021-game/
  index.html
  runtime/godot-4.7.2/
    godot.js
    godot.wasm
  games/wind-reader-glider/
    index.html
    wind-reader-glider.pck
    icon.*
  sources/wind-reader-glider/
```

方針:

- engine JS/WASMはGame Hub側の共通runtimeを参照する。
- ゲーム固有PCKだけをゲーム配下へ置く。
- Hubで共通runtimeをpreloadし、Service Worker / HTTP cacheで再ダウンロードを避ける。
- runtimeのchecksumとGodot versionをCIで固定する。
- ゲーム切替時に共通runtimeを利用できない技術的制約が判明した場合、重複バイナリを黙って増やさず、制約・代替案・計測結果を実行メモに残す。
- HTMLはゲーム固有PCKと共通runtimeの対応バージョンを明示する。
- キャッシュ更新時はversioned cache keyを使い、HTMLだけ古いまま残る状態を避ける。

## 18. QAモード

URLクエリ `?qa=1` のときだけQAモードを有効化する。

QAモード:

- RNG seed固定
- Stage選択を全開放
- 現在state / altitude / boost / durability / gates / scoreを小さなQA overlayへ出す
- F9で画面遷移用の安全なQA shortcutを許可
- 本番通常URLではQA overlayとshortcutを無効化

QA shortcutはゲーム性検証の代替ではなく、ブラウザでタイトル → Stage → Result → Retryの画面導線を安定して自動確認するためだけに使う。

## 19. 自動テスト・ブラウザQA

### ロジックテスト

Godot headlessで最低限以下を検証する。

- boostが0未満/100超にならない
- altitude 0でfail
- depthのコース外猶予1.5秒
- UPDRAFTで高度/boostが増える
- CROSSWIND方向
- collision damageと0.8秒無敵
- gate pass/miss
- required gate target判定
- score計算
- best record更新
- ConfigFile破損時fallback

### Web Build

CI条件:

- Godot 4.7.2固定
- Compatibility
- Web single-thread
- export成功
- PCK生成
- 共通runtime参照整合
- 禁止の外部有料APIなし

### 4画面ブラウザQA

Playwright / Chromiumを使用し、最低限以下を毎回実行する。

1. Phone Portrait 390x844
2. Phone Landscape 844x390
3. Tablet Portrait 768x1024
4. Tablet Landscape 1024x768

各ケースで:

- ロード成功
- console error 0
- page error 0
- タイトル表示
- タッチ相当でPLAY
- 仮想スティック操作
- Boost操作
- Stage進行
- CLEARまたはQA導線でResultへ到達
- Retry
- Stage Selectへ戻れる
- HUDがviewport外へはみ出さない
- スクリーンショットartifact保存

実ゲーム挙動については、Stage 1を通常ルールで最低1回完走する手動/半自動試遊を別途行い、QA shortcutだけで完了判定しない。

## 20. P021品質ゲートへの対応

### 企画

- 30秒以内の目的理解: 本仕様§3
- 明確なゴール: 必須ゲート + ゴール
- 判断要素: 安全/高得点ルート、Boost、上昇気流
- 変化: 3ステージで風と障害物を増加
- リプレイ: Score / Medal / Best

### 操作・UI

- タッチ主体
- マルチタッチ
- PCは補助
- 主要操作へ視覚/SFX feedback
- Retry / Pause / Stage Select
- 4標準viewport

### 技術

- エラー0
- single-thread Web
- common runtime
- deterministic QA
- save fallback
- repeated retryをQA

### 公開品質

公開候補判定前にP021の10項目100点評価を行う。

初回公開候補ライン: 70点以上  
一般公開完了目標: 80点以上

80点未満の場合は不足項目を具体化し、AIで改善可能な内容は継続タスク化する。

## 21. GAME-028完了条件

以下が本仕様で確定しているため、GAME-028は完了条件を満たす。

- 3ステージ構成
- 2.5D座標系
- タッチ/キーボード入力
- 風モデル
- 高度モデル
- ブーストモデル
- 耐久モデル
- スコア/メダル
- HUD
- タイトル/ポーズ/結果
- 4画面レスポンシブ
- 保存項目
- 無料素材方針
- 音
- Godot Scene/Script責務
- Game Hub向けWeb出力
- headlessロジックテスト
- 4画面ブラウザQA
- P021品質ゲート反映

## 22. 次工程

次の実装タスクでは、まず共通基盤とStage 1を作る。

優先実装順:

1. Godot project / scene skeleton
2. FlightModel
3. touch / keyboard input
4. StageDefinition
5. Stage 1
6. HUD / title / result
7. save / audio
8. Web export / Game Hub integration
9. logic tests
10. 4 viewport browser smoke

Stage 1で操作感・数値モデルが成立したことを確認した後、Stage 2 / 3へ展開する。
