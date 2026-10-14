# P021 / GAME-076 — run 38490620078 の独立CI・Artifact監査（2026-10-14）

- 実行ID: AUTOAI-GAME076-20261014-0949
- 確認時刻: 2026-10-14 09:56 JST
- Runnerルール: v1.38.0 / P021ルール: v1.2.0
- 対象: GAME-G030 Orbit Switch Courier、タスクGAME-076（1件だけ）
- 変更範囲: 本文書を develop に追加するのみ。ゲーム本体 / E2E QA / main / 本番 / 課金設定は変更しない。

## 1. GitHub Actions 新HEADの結果

[run 38490620078](https://github.com/kobitworks/autoai_poc/actions/runs/38490620078)（head `15139e2eb47d4575d41acd5488302d2b55773fff` / develop）の最新ジョブをGitHub APIからFresh-readし、`contract`・`export-web`・`browser-quality` **全3件 completed/success** を確認した。前回09:31時点の「browser-quality未完了」は今回の結果により解消する。別HEADの結果を流用しない。

[artifact 11862325738](https://github.com/kobitworks/autoai_poc/actions/runs/38490620078/artifacts/11862325738) をZIP実体で取得し独立検査。

- GitHub API digest: `sha256:b88f269dd6b5358d85e78f2546a14dafea989a08e9eb47b1647a45cea17f3df4`
- 取得ZIP実測SHA256: `b88f269dd6b5358d85e78f2546a14dafea989a08e9eb47b1647a45cea17f3df4`。**完全一致**
- ZIP CRC異常なし。60エントリ = PNG58枚 + JSON2ファイル。
- PNG全58枚で画像形式のdecode/verifyに成功。JSON2ファイルともparse成功。
- 代表16枚（4標準viewportの紹介/プレイ/上位ルート/結果・エラー、3小型viewportの紹介等）をコンタクトシートで独立目視。重なりや警告の明白な欠落は認めない。ただし**58枚全数を人間が個別目視したとは扱わない**。
- `results-checkpoint.json` は `PARTIAL_CHECKPOINT_NOT_FINAL` と明示されるため、最終PASSの根拠にせず、`results.json` + ジョブ合否を用いる。

## 2. 独立results.json検証

| Viewport | 入力 | 自然E2E | RUSH 0→1後energy | ACE到達配達数 | BEST復元 | 診断観測数 / band標本 / 最大間隔 |
|---|---|---|---:|---:|---:|---|
| Phone Portrait 390×844 | touch | PASS | 3 | 6 | 1109 | 31 / 2 / 119ms |
| Phone Landscape 844×390 | mouse | PASS | 3 | 6 | 1112 | 32 / 1 / 124ms |
| Tablet Portrait 768×1024 | touch | PASS | 3 | 6 | 1108 | 17 / 1 / 172ms |
| Tablet Landscape 1024×768 | mouse | PASS | 3 | 6 | 1109 | 17 / 1 / 175ms |

- 4/4画面が実入力のRUSH・NIGHT自然3配達・ACE自然6配達へ到達。各画面の `qaCommand="NEVER USED"`、`stateOverride="NONE"`。スコアや進行条件をQAが直接書き換える経路は未使用。
- `rushDiagnostic.kind=READ_ONLY_DIAGNOSTIC_NOT_PASS_CRITERION`。観測角度窓は4.31..4.47rad、75ms周期。4画面とも `observationBandVisits=1`、`forwardBandSkipsWithoutSample=0`。実入力直近の観測スナップショット角度は4.313 / 4.350 / 4.258 / 4.404rad、cargo残11.44 / 11.33 / 11.54 / 11.38秒。**Tablet Portraitは最寄り標本が観測窓外**であり、75msサンプリングと入力の非同期による誤差を含む。診断値だけで入力の成功・失敗を決めない。
- SOUND ON/OFF、BEST再読込、RETRY/RESULTは各viewportのCI検証対象。実スピーカー音質・音量は未検証。
- 小型3viewport（320×568、667×375、800×600）は`PASS_GEOMETRY`。最終説明行とSTARTのCSS余白は順に7/17/22px（CI閾値4以上）、ヘッダー文字とSOUNDボタンの余白は約14px（閾値8以上）。初見ユーザーの認知・物理端末の可読性PASSではない。

## 3. 限界・品質判断と次回再開点

- 同一HEADの今回のCI成功は確認できたが、以前発生したRUSH 0→1の偶発的なenergy低下が**統計的に解消されたとは断定しない**。観測窓内標本が3/4画面で1件しかないため、短時間の端末負荷変動やタイミング差を見落とす可能性を残す。QA合格基準を緩めない。
- 代表画像ではコントラスト・警告表示とレイアウトに大きな欠落は見られないが、Phone Landscapeの細かな説明文、Tablet Landscapeの補助テキスト密度、日本語の実機可読性は依然改善・実測の対象。
- 実機の初見30秒理解、誤タップ、日本語・小文字可読性、スピーカー/イヤホン実音、FPS/発熱は**Human Gate未実施**。Playwright/PNG/静的コントラストの合格で代替しない。既通知の同一人間確認は再送しない。
- GAME-076の独立暫定品質は **76/100（80点目標未達）** のまま。新たな独立10軸再採点は行っていないため、数値を恣意的に上げない。
- 次回は同一HEADの自然入力E2Eの反復実行でRUSH移行の揺らぎを把握し、失敗時は今回`rushDiagnostic`の観測点・クリック時刻・cargo残を成功ケースと比較する。Human Gateが得られ次第UI/音/性能を再評価し、10軸採点を更新する。
- 本回実作業はGAME-076の継続検証1件だけ。Done条件未達なのでDoing→ToDoへ戻す。main/本番/有償/外部公開変更なし。
