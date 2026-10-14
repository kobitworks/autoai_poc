# GAME-076 / GAME-G030 — 実際に選ばれた緊急カウントダウン文言のQA監査

- 実行ID: AUTOAI-GAME076-20261015-0619
- 記録時刻: 2026-10-15 06:21 JST
- Runner: v1.38.0 / P021: v1.2.0
- 対象: GAME-G030 「Orbit Switch Courier」の残3秒警告（小型3 viewport）
- 既知の前回検証: run 38631506771 の旧HEADについて、contract/export-web/browser-quality 3件成功、実操作4標準画面4/4・小型3画面自然START/幾何3/3。これは**今回の新HEADの合格証拠ではない**。

## 本回の変更

1. Godotソース `p021-game/sources/orbit-switch-courier-godot/Main.gd` に `cargo_warning_rendered_text` を追加。緊急カウントダウンが本来の描画経路で選択した最終文字列を、既存のread-only QA bridgeへ公開する。ゲーム進行、ターゲット、入力・採点・タイマ、表示条件、音声は変更しない。
   - commit: `b6ec5a63665fb0cd19d2f8a4963254e755529c17`
   - GitHub読戻しblob: `6605acfb0f812e0bb3fe14f10c4b5ffc9d56f377` 一致。
2. QA `p021-game/qa/orbit-switch-courier-real-input.js` に、320×568 / 667×375 / 800×600 の3小型画面で「自然の残り3秒」へ到達した後、描画経路が `03s LEFT! HURRY` / `03s! HURRY` / `03s!` 相当の文字列を選択したことをassertし、実測値を結果JSONへ保存する受動検証を追加。QAコマンド・状態直接書換えは増やさない。
   - commit: `10a49a573de4ca4b0361cdae011e5ac4ddb0c4dd`
   - GitHub読戻しblob: `c702071b21136ee242fc50ff3493684f732fb285` 一致。
   - JavaScript静的構文パース: PASS。

## 監査境界と継続条件

- 今回の新HEADに対するGodot Web Export / GitHub Actions 3 jobs / 自然入力7 viewport / artifact ZIP・PNGは**未検証**。旧HEAD成功を転用しない。
- 自動検証が保証するのは描画コードが選択した文言のみ。文字の可読性、警告に3秒以内に気づくか、誤タップ、実音、fps、発熱、画面回転は実機Human Gateとして残す。
- 独立暫定品質76/100、目標80未達、公開品質認定はしない。
- 次回同タスクで新HEADのCI最終結果・artifactと小型3画面の `hudTextSelection` を確認し、失敗した場合のみ実装・QAを修正。実機回答が得られれば10軸再評価。
- 本回はdevelop限定。main・本番・有償サービス・公開範囲への変更なし。他タスク実行なし。
