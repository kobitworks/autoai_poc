# GAME-G001「1マス農園」100点品質再レビュー

- review_date: 2026-10-06
- task_id: GAME-022
- target: develop / GAME-G001 current release (Godot v5)
- project_rule: P021 project_rule.md §10.5 / §10.6 / §11
- previous_score: 64 / 100 (GAME-019)
- result: 77 / 100
- classification: 公開候補（70〜79点）
- public_quality_target: 80点以上
- judgment: 80点未達

## Fresh-readで確認した改善

GAME-020 / GAME-021後の現行 `Main.gd` と公開用Web出力をFresh-readした。

- Kenney Interface Sounds (CC0) の7効果音を実装。
- 音量は100% / 70% / 40% / ミュートの4段階で変更でき、端末内保存する。
- 3チャレンジを実装。
  - スタンダード: 15日 / 150G
  - 10日スプリント: 10日 / 115G / 収穫2回以上
  - 節水チャレンジ: 15日 / 130G / 収穫3回以上 / 水補充1
- モード別に best_coins / best_rank / cleared / plays を端末内保存し、開始画面と結果画面へ表示。
- Godot viewportは390x844、stretch=canvas_items / aspect=expand、画面リサイズ時にPortrait=1列 / Landscape=2列へ切替。
- 現行Web出力は index.wasm 39,514,754 bytes / index.pck 7,016,192 bytes。
- GitHub Pages workflow run 37309122557 は build / deploy ともに success。

## 100点品質スコア

| 項目 | 点数 | 主な根拠 |
|---|---:|---|
| ゲーム性 | 8/10 | 3作物の収支・成長差、水・土・天候に加え、3チャレンジで日数・資金・収穫回数・水補充条件が変化し、判断の幅が増えた。1マス中心のため戦略幅はなお限定的。 |
| 操作感 | 8/10 | 58〜64px級ボタン、タッチ中心、キーボード補助、一時停止、速度変更、音量変更を実装。ゲーム本体は明確だが開始画面の横画面適合に課題。 |
| 難易度設計 | 8/10 | スタンダード / 短期 / 節水で制約が明確に変わる。段階的アンロックやプレイ中の難易度曲線はまだ薄い。 |
| UI/UX | 7/10 | タイトル、モード選択、記録、HUD、ログ、結果画面まで揃う。一方、新しい開始画面は縦積み固定でスクロールがなく、Phone Landscape 844x390で縦方向が収まりにくい構造。 |
| グラフィック | 8/10 | Kenney Tiny Farm (CC0) の統一アート、農園背景・畑・作物・木・柵・納屋・井戸・天候を継続利用。 |
| 演出・エフェクト | 7/10 | 植付け、水やり、土づくり、収穫、天候等の視覚演出はあるが、チャレンジ達成・BEST更新などの演出は簡素。 |
| サウンド | 8/10 | 7種のCC0効果音、4段階音量、設定保存、素材台帳を実装。BGMや環境音、独立音量調整は未実装。 |
| コンテンツ量・変化 | 8/10 | 3作物 × 3チャレンジ、天候、異なる制約で前回より明確に増加。マップ・設備・アンロック等はまだない。 |
| リプレイ性 | 8/10 | モード別BEST資金・最高ランク・CLEAR・挑戦回数を保存。ランキング、実績、アンロック等は未実装。 |
| 技術品質 | 7/10 | Godot 4.7.2 Compatibility、aspect=expand、レスポンシブ切替、Pages deploy成功を確認。ただし約46.5MBの初回配信量が残り、今回の新開始画面にはPhone Landscapeの静的レイアウトリスクがある。 |

**合計: 77 / 100**

## 4画面パターン再確認

現行ソースとResponsive Preview定義をFresh-readして以下を確認した。

- Phone Portrait 390x844: 既存Portrait構成と開始パネル幅350pxから、画面幅内に収まる構成。
- Phone Landscape 844x390: **FAIL / 要修正**。開始画面が3チャレンジボタン、説明、記録、開始ボタン等を縦積みし、開始画面自体にScrollContainerやLandscape専用再配置がないため、390px高では下部操作が欠けるリスクが高い。
- Tablet Portrait 768x1024: Portrait 1列構成、十分な高さあり。
- Tablet Landscape 1024x768: Landscape 2列構成、開始画面もPhone Landscapeより高さ余裕あり。

注: 公開URLの直接HTTP取得は今回の実行環境で外部DNS解決できなかったため、GitHub Pagesの最新deploy成功、develop上の公開用index.html、Responsive Preview定義、GodotソースのFresh-readを根拠とした。前回GAME-018では4パターン実ブラウザPASS済みだが、その後GAME-021で開始画面へ3チャレンジUIが追加されているため、旧PASSをそのまま流用せず新UIの構造を再評価した。

## 判定

77点で「公開候補」。80点以上の一般公開品質には未達。

主因は、GAME-021で追加された開始画面のPhone Landscape適合性と、約46.5MBの初回配信量。まずPhone Landscapeで開始〜プレイ開始まで確実に操作できるよう修正し、4画面を再検証したうえで再採点する。

## 次アクション

GAME-023として、開始画面のレスポンシブ修正と4画面再検証を追加する。
