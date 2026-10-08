# GAME-G011 Memory Game

kobitworks/kobit_jsgames の `text_matching_memory` を、元リポジトリを変更せず P021 向け静的Web版として移植したものです。

- Source: `public/game/text_matching_memory/app/controllers/main.php` + `css/style.css` + `js/game.js` + `js/charset_data.js`
- PHP / asset_stamp / 広告ゲート依存を除去
- Platform SDK は `platform-adapter.js` へ置換
- Lv1〜4、Stage 1〜10、Tier 1〜5、standard / compact を維持
- recent seed の localStorage 保存を維持
- DB / 外部API / 有償サービスなし
- HOME は P021 Game Development Lab へ戻る

PoC: https://kobitworks.github.io/autoai_poc/p021-game/games/text-matching-memory/
