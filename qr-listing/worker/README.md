# P013 project-scoped Worker operations

QR-018で作成した、P013「QR商品出品支援」専用のoperation registry候補です。

## 対象

- `p013.product.get` — query / `p013.product:read`
- `p013.product.list` — query / `p013.product:read`
- `p013.product.create` — command / `p013.product:create`
- `p013.product.update_status` — command / `p013.product:update`

P016共通Worker runtimeの `handler({db,input,principal,requestId})` 契約に合わせています。commandのIdempotency-Key予約・replay、Cloudflare Access認証、P016 `permissions` によるdefault-deny認可、監査、CORS、rate limitは共通runtime側が担当します。

## 安全条件

- SQLはコード固定文字列のみ。
- 値はすべてprepared statement + `bind()`。
- input schemaは `additionalProperties:false`。
- 商品状態更新は `expected_state_version` を必須とし、`WHERE product_id=? AND state_version=?` の比較更新。
- 状態更新eventは、更新後version/status/updated_atが一致した場合だけ追加する。
- 商品作成は管理QRが `AVAILABLE` の場合のみ条件付きINSERTし、QRを `DISCOVERED` にする。
- 匿名finder、R2 upload/download、AI解析、出品連携はQR-018の範囲外。

## Operation / permission manifest

QR-020で `p013-operation-manifest.json` を正本追加する。
QR-014の権限登録は、registryやREADMEから手入力で転記せず、このmanifestをFresh-readして行う。

- operation: 4件
- 最小permission: `p013.product:read` / `p013.product:create` / `p013.product:update`
- wildcard resource/actionは禁止
- environmentとapi_clientはdeploy/登録時に外部から確定し、manifestへ固定しない
- `p013-operation-manifest.test.mjs` がWorker registry・ブラウザAPI client・manifestの1対1整合を検証する

## QR-014で行うこと

1. P016共通Worker deploymentへ本registryを統合。
2. `p013-operation-manifest.json` を正本として、P016 `api_clients/permissions` に必要最小権限を登録。
3. 共通runtimeのIdempotency-Key / audit / rate limit / CORSテストと結合。
4. production D1へMigration適用後にsmoke test。
5. R2はQR-013でstaging/production bucketが利用可能になってから接続。

QR-018ではCloudflare設定変更、Worker deploy、D1/R2書込、permission登録、本番データ投入を行いません。
