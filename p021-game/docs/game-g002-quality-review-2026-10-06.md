# GAME-G002 品質レビュー — 2026-10-06

- Task: GAME-025
- Game: GAME-G002「過去の自分と協力するゲーム」 / PAST//SYNC
- Reviewed ref: `develop`
- Source: `p021-game/sources/past-self-coop-godot/`
- Web build: `p021-game/games/past-self-coop-v2/`
- Review basis: P021 project_rule §10.5 / §10.6 / §11

## 結論

**72 / 100 — 公開候補。一般公開品質の目標80点には未達。**

時間記録→PAST再生→NOWとの同時操作というゲーム核は明確で、3ステージ化、Kenney CC0 UI/SFX、Portrait/Landscape対応まで進んでいる。一方、モバイルで全クリア後に再挑戦できない、音量/ミュート設定がない、固定3ステージでスコア/記録/収集等の再挑戦動機が弱い、4画面パターンの自動ブラウザQAがないため、project_ruleの一般公開完了条件には届いていない。

## 100点品質スコア

| 項目 | 点数 | 根拠 |
|---|---:|---|
| ゲーム性 | 8/10 | 1回目の操作を記録しPASTとして再生、NOWと2スイッチを同時押しする核が独自で分かりやすい。 |
| 操作感 | 8/10 | WASD/矢印キーとタッチD-pad、記録終了、リトライを実装。入力への反応と状態変化が明確。 |
| 難易度設計 | 7/10 | 11秒→9秒→8秒と記録時間が短くなり、3ステージで段階的に難化。ヒントあり。攻略の幅はまだ狭い。 |
| UI/UX | 7/10 | Intro、REC/SYNC表示、残り時間、ステージ進捗、クリア表示、縦横レイアウトを実装。ただしCOMPLETE後の再挑戦はRキーのみで、タッチ端末に完結した再挑戦導線がない。 |
| グラフィック | 8/10 | SFトーンを統一し、Kenney UI Pack - Sci-Fiと独自Canvas描画を組み合わせている。 |
| 演出・エフェクト | 8/10 | PAST半透明表現、スイッチ状態、ゲート解除フラッシュ、クリア/完了オーバーレイ、パルス表現を実装。 |
| サウンド | 6/10 | Kenney Sci-fi Soundsの4系統SFXを開始/再生/解除/クリアへ割当。ただしミュート/音量調整がなく、project_rule §10.2-6の推奨を満たし切らない。 |
| コンテンツ量・変化 | 7/10 | 3ステージ、配置・記録秒数・ヒントが変化。短時間PoCとしては成立するが、追加ギミックや攻略分岐は少ない。 |
| リプレイ性 | 5/10 | ステージ再挑戦は可能だが、ベストタイム/ランク/達成記録/ランダム性等がなく、全クリア後のモバイル再挑戦導線も不足。 |
| 技術品質 | 8/10 | Godot 4.7.2 Compatibility、`stretch/aspect=expand`、Portrait/Landscape分岐、GitHub Pages最新develop deploy成功。現行Web出力は WASM 39,514,754 bytes + PCK 7,469,936 bytesで初回ロード最適化余地があり、4標準viewportの自動QAも未整備。 |
| **合計** | **72/100** | **公開候補。80点未達。** |

## Fresh-read確認事項

- `Main.gd` は3ステージ、REC→SYNC→CLEAR→COMPLETEを実装。
- Portrait / Landscapeを画面縦横で切替し、D-pad・記録終了・リトライUIを再配置。
- `project.godot` は960x640、canvas_items、aspect=expand、Compatibility renderer。
- `ASSETS.md` / `CREDITS.md` にKenney UI Pack - Sci-Fi（CC0）、Kenney Sci-fi Sounds（CC0）、Noto Sans JP（OFL）を記録。
- 現行Web buildは `past-self-coop-v2` に存在。
- 最新develop headは `bb4487955ab92bf28c54c0da1d81d10698f1f50a`。Pages run `37397565635` は completed / success。
- G002のMain.gd最終変更は `7249d27d27ad6bcc9706e7a5b465b7a6c6628db8`（responsive対応）。
- workflow `p021-game-g002-godot-web.yml` はheadless validationとWeb exportを行うが、4標準viewportのブラウザQAは含まれていない。

## 80点到達へ優先する改善

1. COMPLETE画面にスマホ/タブレットでも押せる「最初から」ボタンを追加し、全工程をタッチだけで完結させる。
2. SFXのミュート/音量設定を追加し、端末内へ保存する。
3. 総クリア時間、リトライ回数、ランク等のベスト記録を端末内保存し、結果画面へ表示して再挑戦動機を作る。
4. Phone Portrait 390x844 / Phone Landscape 844x390 / Tablet Portrait 768x1024 / Tablet Landscape 1024x768 の4パターンをブラウザQAし、開始→3面完走→COMPLETE→再挑戦まで確認する。
5. 改善後にproject_rule §10.5で再採点し、80点以上を確認する。

## 判定

GAME-025は品質評価として完了。実装改善は次タスクへ分離する。
