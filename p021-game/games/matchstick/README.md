# GAME-G015 Matchstick

P021「ゲーム開発」へ、`kobitworks/kobit_jsgames` の既存 Matchstick を**元リポジトリ非破壊**で静的移植した版です。

## Source of truth used for migration

- `public/game/matchstick/app/controllers/main.php`
- `public/game/matchstick/css/style.css`
- `public/game/matchstick/js/main.js`
- source ref: `kobitworks/kobit_jsgames@main`
- Preflight: P021 / GAME-054

README/spec に記載されている `public/game/matchstick/index.php` は移植時点の現行 Contents には存在しないため、推測で代用していません。

## P021 migration changes

- PHP / `asset_stamp` 依存を除去し `index.html` 化
- 広告ゲート / 外部 Platform SDK 依存を持ち込まず、P021 単独静的版として実装
- Easy / Normal / Hard、1 / 3 / 5 / 7 / 10 Round、7セグ数字の「1本移動」ロジックを維持
- 元実装の「正解 +2、不正解/スキップ -1」に合わせ、P021側のスコア意味を **higher is better** と明示
- 端末内 `localStorage` に難易度・ラウンド数別BESTを保存
- 元CSS後半にあった未定義 custom properties と重複ルールを廃止し、P021向けにCSSを正規化
- スマホ/タブレットの Portrait / Landscape を想定してレスポンシブ化

## Score

`score_type: higher`

正解で加点される現行ゲームロジックに合わせた整理です。元 `games_upsert.sql` / README の `lower` 記載は現行実装と不整合のため継承していません。

## QA

`p021-game/qa/matchstick-responsive.js` で次の4 viewportを確認します。

- Phone Portrait 390×844
- Phone Landscape 844×390
- Tablet Portrait 768×1024
- Tablet Landscape 1024×768

確認対象は画面横はみ出し、難易度/ラウンド選択、開始、7セグの棒選択→移動、リセット、スキップ、結果画面、TOP復帰、console/page errorです。
