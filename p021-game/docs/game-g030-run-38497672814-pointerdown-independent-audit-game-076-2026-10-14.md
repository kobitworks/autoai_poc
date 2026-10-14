# GAME-076 / GAME-G030 — RUSH実入力の独立証跡監査（2026-10-14）

- 実施: AutoAI Runner 2026-10-14 11:15〜 JST（本監査はGAME-076の継続1件のみ）
- 対象リポジトリ: `kobitworks/autoai_poc`、`develop`、変更対象は本監査記録のみ
- 原則: 成功コマンド・ゲーム状態直書きは禁止。実画面へのtouch/mouse自然入力で判断。mainマージ・本番・課金・実機評価の代行なし。

## 1. 比較した実行

| 項目 | 前回（失敗） | 今回（成功） |
|---|---|---|
| Actions | [38490620078 attempt 2](https://github.com/kobitworks/autoai_poc/actions/runs/38490620078) | [38497672814](https://github.com/kobitworks/autoai_poc/actions/runs/38497672814) |
| HEAD | `15139e2eb47d4575d41acd5488302d2b55773fff` | `ae448b999037c6e9e2a91d2e0584e5a99f98f4e4` |
| contract / export-web / browser-quality | success / success / failure | success / success / success |
| 実入力E2E 4 viewport | 3 PASS / 1 FAIL（tablet-portrait） | **4 PASS / 0 FAIL** |
| artifact ID | `11863379652` | `11864439352` |
| ZIP SHA256 | `3e13b4ba25a05af2a902304abe2cc27b184a5387258150d2c09e4af5613eaa20` | `152666ab03ca66511bdad6ffe758d30f5d8d73bd315b3adeb2ea1603959288c7` |
| ZIP実体の独立取得・検査 | 53ファイル（51 PNG + 2 JSON）、CRC正常 | 60ファイル（58 PNG + 2 JSON）、CRC正常 |

双方のZIP実体をGitHub Actions artifactから取得し、ローカルSHA256をGitHub公開digestと照合して一致。今回の58 PNGは全件デコード・検証成功、`results.json`を読戻し。途中段階の`results-checkpoint.json`は合否の正本に採用しない。今回の16画像（4画面×INTRO/PLAYING/RUSH/RESULT）は一覧で目視し、明白な主要導線の隠れ・画面間の破綻は認めなかったが、実機での文字可読性やタップ誤操作は判定外。

## 2. 今回の実イベント計測（RUSH 0→1）

実イベント発生時にpassive listenerが読み取った`pointerdown`の角度・残時間と、QA入力呼出所要時間を比較した。計測は観測専用で、ゲーム物理、状態、合否条件を変更しない。

| viewport | 入力 | pointerdown角度(rad) | 貨物残秒 | 入力呼出ms | 自然入力E2E |
|---|---|---:|---:|---:|---|
| phone-portrait 390×844 | touch | 4.479 | 11.31 | 110 | PASS |
| phone-landscape 844×390 | mouse | 4.329 | 11.36 | 3 | PASS |
| tablet-portrait 768×1024 | touch | 4.550 | 11.46 | 217 | PASS |
| tablet-landscape 1024×768 | mouse | 4.537 | 11.28 | 72 | PASS |

今回観測された4角度は物理ウィンドウの目安4.50±0.19rad（4.31〜4.69）に収まる。自然入力のRUSH経路判定は`results.json`上すべてPASS、energy3保持。実験では小型3画面のINTRO/START配置geometryも3/3 PASS（案内とSTARTの間隔7/17/22 CSS px）。

## 3. 前回失敗との比較と未確定点

前回attempt2のtablet-portraitでは、RUSH 0→1で`waitForFunction: Timeout 3500ms`、energy3→2、orbit0 / delivery1のまま失敗。read-only近傍サンプルは角度4.458rad、inputCall=221msだったが、当時は実`pointerdown`角度を計測しておらず、要求角度と物理発火角度を同一視できない。今回のtablet-portraitはinputCall=217msと似た遅延でも実`pointerdown`4.550radで成功した。よって「入力呼出時間の長さだけが原因」とは断定できない。時間依存・フレーム進行・入力到達のずれ等は**仮説**にとどめる。

**今回1回の成功でフレーク解消は確定しない。** 今回は診断用受動ログを追加した別HEADであり、QA観測の因果関係と長期安定性は未立証。失敗再現時に`pointerdown`角度・時刻、ゲーム側実判定、サンプル間隔を照合する。

## 4. GAME-076継続判定と次回再開点

- 最新HEADのCI 3/3成功、自然操作4/4 PASS、追加geometry3/3 PASS、証拠ZIP/PNG/JSON整合性PASSを確認。
- ただし暫定品質は従前の**76/100を据え置き**（今回の機械テスト成功だけで80点へ加点しない）。ゲーム体験の独立10軸再採点は未完了。
- 実機Human Gate：初見30秒の正しい操作、iOS/Androidの縦横、文字可読性、誤タップ、スピーカー/イヤホン実音、FPS・発熱を未検証として維持。重複するSlack確認依頼は送信しない。
- 次回は同HEADで自然入力を複数回反復し、特にtablet-portraitの`pointerdown`角度とRUSH合否を比較。フレーク再発時は受動診断で原因切り分け。実機結果を得た後に10軸品質を独立再採点し、80点未満なら改善を継続。
- 本回はGAME-076以外のタスクを開始しない。GAME-076は未完了につき実行メモを更新して`ToDo`へ復帰する。
