# QR-011 E2E PoC 統合確認レポート

実施日: 2026-10-06 JST  
対象: P013 QR商品出品支援 / QR-011  
コード正本: `kobitworks/autoai_poc` develop

## 結論

内部PoCの主要工程は、同一ブラウザのIndexedDBを介して次の順序で接続されている。

1. `upload.html`: 複数商品画像をブラウザ内へ保存し、バッチID付きでQR解析へ遷移
2. `analyze.html`: QRを検出・手動補正し、同一QRを商品単位へグルーピングして商品レコードへ同期
3. `products.html`: 商品単位の写真セットと処理状態を一覧化し、AI解析・確認へ遷移
4. `ai-analysis.html`: ユーザー操作時のみ端末内AI候補を生成し、人が確認・修正した値を `confirmedProduct` として別保存
5. `listing-export.html`: `confirmedProduct` がある商品のみを `p013-listing-v1` へ変換し、一覧・JSON・CSVを生成

外部マーケットへの実登録・送信は行わない。

## 自動E2E契約テスト

追加:
- `qr-listing/e2e-poc-contract.test.js`
- `.github/workflows/p013-e2e-poc-test.yml`

GitHub Actions:
- Run: 37333363665
- Job: 111841831438
- Result: completed / success
- Commit: `7cb1d7d573bdb6b686d6d99cbccb1b541015f896`

テスト結果:

```text
P013 QR-011 E2E PoC contract: PASS
{"groupedProducts":2,"groupedImages":3,"unresolvedImages":1,"confirmedProducts":2,"listingRecords":2,"externalMarketplaceSubmission":false}
```

確認した契約:
- 2商品・3枚の確定画像を2商品へ正しくグルーピング
- 1枚の未確定画像を商品データから除外
- AI候補から人確認済み商品情報を作成
- 未確認商品を出品データから除外
- 確定済み2商品のみ汎用出品レコードへ変換
- 価格を推測せず空欄、通貨JPY、数量1、出品状態draftを維持
- CSV生成を確認
- メニュー→アップロード→QR解析→商品一覧→AI解析/確認→出品データの画面配線を静的検証

## 未解決点・実機での確認事項

以下は今回の自動契約テストでは完全には代替できない。

- 実スマホ/タブレットでのカメラ選択・画像投入操作
- BarcodeDetector / ZXing による実写真QR認識精度
- IndexedDBの端末別容量・再読込・ブラウザ消去時の挙動
- Transformers.jsモデルの初回読込時間、端末メモリ、実画像での推論品質
- スマホ/タブレットでの画面視認性・タップ操作性
- 外部マーケットへの実登録・送信（別承認・契約・権限が必要）

## ブランチ/公開状態

P013の最新PoC実装は `develop` に存在する。QR-011追加時、GitHub Pagesの `pages build and deployment` も `develop` commit `7cb1d7d...` で起動していることを確認した。公開ページの実ブラウザ操作確認は上記の実機確認事項として分離する。

## 判定

QR-011のAI実行範囲としては、内部PoCの工程接続・確定データ境界・出品データ生成契約が自動テストで成立したため完了とする。実端末/実写真/外部サービスの検証は、本タスクの自動確認では代替しない。
