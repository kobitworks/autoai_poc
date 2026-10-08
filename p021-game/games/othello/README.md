# GAME-G010 Othello

P021「ゲーム開発」に、既存の `kobitworks/kobit_jsgames` Othello を非破壊で静的移植したWeb PoCです。

- 元資産: `public/game/othello/app/controllers/main.php`, `css/style.css`, `js/main.js`
- 元リポジトリは変更しない
- PHP / DB / asset_stamp / 広告ゲート依存を除去
- 現行実行系で未読込だった `js/othello.js` は移植対象外
- 8×8、あなた先手/CPU先手、CPUレベル3/4/5、合法手ヒント、パス、終了判定を維持
- `platform_sdk` はP021用の薄いadapterに置換
- HOMEはP021共通ポータルへ戻る
- 外部API・DB・有料サービスなし

公開URL: https://kobitworks.github.io/autoai_poc/p021-game/games/othello/
