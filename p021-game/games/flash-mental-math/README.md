# GAME-G012 Flash Mental Math

kobitworks/kobit_jsgames の既存 Flash Mental Math を、元リポジトリを変更せず P021 へ静的移植した版です。

- ID: GAME-G012
- slug: flash-mental-math
- engine: HTML / CSS / JavaScript
- score: higher（正解数が多いほど高評価）
- stages: Stage 1〜5
- levels: Lv1〜5
- rounds: 1〜10
- input: タッチテンキー / 数字キー / Backspace / Enter
- traps: alphabet / ひらがな / カタカナ / 漢字
- dependencies removed: PHP, asset_stamp, 広告ゲート, 元 Platform SDK
- P021 adapter: 結果表示、BEST正解数のlocalStorage保存、ゲーム一覧への戻り導線

通常プレイの計算・トラップ生成ロジックは既存 main.js を維持しています。QA時のみ `?qa=1` で待機時間を短縮します。
