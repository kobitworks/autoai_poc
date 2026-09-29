# P013 QR商品出品支援 — DB / R2設計 v1

QR-012で確定した初期データ設計です。  
GitHub正本は `qr-listing/db/` 配下とし、実D1だけを直接変更してMigrationを残さない運用を禁止します。

## 1. P016標準との整合

P016 project_rule v1.1.0 / DBM-008以降の標準を採用します。

- D1は **P013につきproduction 1個だけ** を常設する。
- 新規staging D1は作らない。
- Migrationの事前検証はSQLite / CI等で行う。
- 静的PoCからD1へ直接接続せず、Worker API経由で操作する。
- R2はファイル混在防止のため **staging / production 2bucket**。
- Cloudflare API Token / S3 Secret等をブラウザやGitへ保存しない。
- productionへの破壊的Migration、実データ投入、本番公開は人間確認対象。

タスク管理のQR-013には旧ルールの「staging/production D1」表現が残っていますが、実行時は現行P016標準を優先し、**production D1 1個 + R2 staging/production 2bucket** と読み替えます。

## 2. 初期Migration

- `db/migrations/0001_initial_schema.sql`
- schema version: 1
- 技術IDはWorker側でUUID/ULID等の衝突しないTEXT IDを生成する。
- timestampはISO 8601文字列を基本とする。
- D1へ画像バイナリは保存しない。
- JSON列は文字列として保持し、API層でschema validationする。

## 3. テーブル構成

### upload_batches

複数画像アップロードの1回分を管理します。

主な項目:
- batch_id
- data_scope: staging / production
- status
- source_type
- image_count
- created_by / timestamps

状態:
`UPLOADING -> READY_FOR_SCAN -> SCANNED/PARTIAL -> COMPLETED`

中止時のみ `CANCELLED`。

### management_qr_codes

管理用QRコード台帳。

QR形式:
`QPMS + YYMMDDHHMMSS + 4桁番号`

合計20文字をDB CHECKでも検証します。

status:
- AVAILABLE: 正常発行済み
- DISCOVERED: 永続台帳投入前のPoC等で有効形式コードを検出し暫定登録
- VOID
- RETIRED

現PoCでは再発行機能を前提にしないため、商品1件につきprimary QRを1つに固定します。

### products

商品単位の正本。

主な項目:
- product_id: 技術ID
- primary_qr_code: 管理QR、unique
- data_scope
- status
- state_version: 楽観ロック用
- created/updated/archive timestamps

QR文字列を技術主キーにはせず、商品技術IDと分離します。

商品状態:
1. PHOTO_GROUPED
2. AI_PENDING
3. AI_RUNNING
4. AI_REVIEW
5. CONFIRMED
6. LISTING_READY
7. EXPORTED
8. ARCHIVED

AI解析失敗は `ai_analysis_runs.status=FAILED` に記録し、商品自体は再実行可能な状態へ戻します。

### product_images

商品写真のD1メタデータ。

主な項目:
- image_id
- batch_id
- product_id
- storage_object_id
- width/height
- qr_status
- qr_decision_source
- selected_qr_code
- scan_engine
- qr_raw_json

画像本体はR2に保存し、D1では `storage_object_id` のみ参照します。

qr_status:
- UNSCANNED
- UNRESOLVED
- MULTIPLE
- INVALID
- ASSIGNED

ASSIGNEDの場合はproduct_id / selected_qr_code / AUTOまたはMANUAL decisionを必須にします。

### image_qr_candidates

1画像で検出したQR候補を複数保持します。

- candidate_rank
- raw_value
- normalized_qr_code
- confidence
- detected_by
- is_selected

候補値は誤読・未登録QRを含み得るため、normalized_qr_codeに外部キーは張りません。
ユーザーが選択した値だけproduct_images.selected_qr_codeへ昇格します。

### ai_analysis_runs

ユーザー任意実行のAI解析1回を表します。

- product_id
- product_state_version
- status
- prompt_version
- model_ref
- input_snapshot_json
- result_json
- requested_by / timestamps

status:
`REQUESTED -> RUNNING -> SUCCEEDED / FAILED / CANCELLED`

撮影・アップロード時の自動実行はしません。

### ai_field_candidates

AIが生成した商品項目候補をフィールド単位で保存します。

想定field_name:
- title
- brand
- category
- color
- condition
- features
- description
- その他後続PoCで追加する項目

同一fieldに複数候補を持てるようcandidate_rankを保持します。

review_status:
- PROPOSED
- ACCEPTED
- REJECTED

AI結果だけで商品確定値へ自動反映しません。

### product_field_values

人が確認した商品の確定値です。

主キー:
`product_id + field_name`

source_type:
- MANUAL
- AI_ACCEPTED
- IMPORT

AI候補を採用した場合はsource_analysis_id / source_candidate_idを保持し、どのAI結果を人が承認したか追跡できます。
`confirmed_by` と `confirmed_at` を必須にします。

### listing_drafts

確認済み商品情報から生成する出品用構造化データです。

- product_id
- channel
- schema_version
- status
- generated_from_state_version
- payload_json
- external_reference

status:
- DRAFT
- READY
- EXPORTED
- VOID

PoCでは一覧、コピー、JSON/CSV等の内部出力を優先します。
外部サービスへの実登録や非公式自動操作はこのテーブルの存在だけでは許可しません。

### product_state_events

商品状態遷移の業務監査ログです。

- from_status
- to_status
- reason
- actor_subject
- occurred_at

状態更新時はproducts.state_versionをインクリメントし、同じWorker処理内でstate eventを記録します。

### storage_objects / storage_object_events

P016 R2標準のメタデータschemaを初期Migrationへ取り込みます。

- bucket / object key
- environment
- entity type / entity id / media role
- MIME type / size / ETag / SHA-256
- object status
- upload/download/delete等の監査イベント

R2 object keyを業務レコードへ直接散在させず、`storage_objects.object_id` を参照します。

## 4. 主な関連

- upload_batches 1:N product_images
- management_qr_codes 1:0..1 products
- products 1:N product_images
- product_images 1:N image_qr_candidates
- product_images 1:1 storage_objects（初期設計では原本写真1件につきstorage object 1件）
- products 1:N ai_analysis_runs
- ai_analysis_runs 1:N ai_field_candidates
- products 1:N product_field_values
- products 1:N listing_drafts
- products 1:N product_state_events

AI候補と確定値を分離し、再解析しても人が確定した値を無条件に上書きしない構成です。

## 5. Index方針

初期PoCで必要な検索だけを優先します。

- upload batch: data_scope + status + created_at
- QR台帳: status
- 商品: data_scope + status + updated_at
- 写真: batch + qr_status
- 写真: product + created_at
- 写真: selected QR + qr_status
- QR候補: image + rank
- 商品状態履歴: product + occurred_at
- AI解析: product + status + requested_at
- AI候補: analysis + field + rank
- AI候補review: review_status
- 確定値: product + field
- 出品draft: product + channel + status
- R2 metadata: entity / status / request_id

検索ニーズが固まる前に過剰なindexを追加しません。

## 6. R2設計

P016標準に従い、R2はstaging / productionを分離します。

想定bucket:
- staging: P016 Provisioning Workflowが生成するP013用files-staging
- production: P016 Provisioning Workflowが生成するP013用files-production

bucket名はP016 Workflowが実際に導出した値を正本とし、手作業で別bucketを増やしません。

### Object key

商品への紐付け前でも画像を保存でき、QR手動補正後にR2 objectのrenameを不要にするため、product_idではなくimage_idをentityにします。

標準:
`original/{yyyy}/{mm}/product-image/{image_id}/{object_id}-{safe_filename}`

例:
`original/2026/09/product-image/IMG-.../01k...-front.jpg`

ルール:
- QRコード、商品名、ブランド、住所、メール等をkeyへ入れない。
- object_idをR2識別の正本にする。
- safe_filenameは表示補助。
- 生成・検証のコード正本は `qr-listing/worker/p013-object-key.mjs` とし、path traversal/制御文字/過長名をWorker入力境界で拒否・縮約する。
- bucketは非公開。
- 通常はWorker R2 bindingを使用する。
- Browser直接転送が必要な場合のみWorkerが短期Presigned PUT/GETを発行する。
- BrowserへDELETE用Presigned URLを標準提供しない。

## 7. 保存フロー

### 画像アップロード

1. Workerがimage_id / object_id / object keyを採番。
2. storage_objectsをpendingで作成。
3. R2へupload。
4. checksum / size等を確認。
5. storage_objectsをactiveへ更新。
6. product_imagesを作成。
7. storage_object_eventsへ結果を記録。

アップロード未完了のobjectを商品写真として確定しません。

### QR仕分け

1. 画像単位にQR候補をimage_qr_candidatesへ保存。
2. 1候補かつ形式妥当ならAUTO候補。
3. 未検出、複数、形式不正は自動確定しない。
4. AUTOまたはMANUALで確定したQRだけselected_qr_codeへ保存。
5. QR台帳を確認し、PoC暫定コードならDISCOVEREDとして登録可能。
6. 同一QRの商品へ複数写真を関連付ける。
7. product状態をPHOTO_GROUPEDへ進める。

### AI解析・確認

1. ユーザー操作でai_analysis_runsをREQUESTED。
2. AI結果をai_field_candidatesへ保存。
3. 商品をAI_REVIEWへ遷移。
4. 人が候補を採用・修正。
5. product_field_valuesへ確定値を保存。
6. 必須項目確認後に商品をCONFIRMEDへ遷移。

### 出品データ

1. CONFIRMED商品のstate_versionを入力snapshotとしてlisting_draftsを生成。
2. channel別payloadを保存。
3. 人が確認後READY。
4. JSON/CSV等へ出力したらEXPORTED。
5. 外部サービス送信は別タスク・別承認。

## 8. concurrency / 冪等性

- products.state_versionを更新条件に含め、古い画面からの上書きを拒否する。
- AI解析開始時にproduct_state_versionをsnapshotする。
- listing_draftsにもgenerated_from_state_versionを記録する。
- Worker command系はP016共通標準のIdempotency-Keyを使用する。
- 同じupload完了通知やAI結果の再送で重複行を生成しない。

## 9. 保持・削除方針

初期段階では自動lifecycle deleteを設定しません。

- 商品: ARCHIVEDで論理終了し、即物理削除しない。
- QR台帳: 発行・失効履歴として保持する。
- AI runs / candidates: 確定値の由来確認に必要な範囲で保持する。
- listing drafts: export履歴とstate_versionを保持する。
- R2: P016標準の `delete_pending -> object delete -> deleted` を使う。
- staging R2はテストデータ専用とし、productionデータと混在させない。
- production bucket一括削除、保持期間短縮、自動lifecycle deleteは人間確認対象。
- 実個人情報・実顧客情報はPoC検証へ持ち込まない。

具体的な法定保存年数は本タスクでは断定せず、本番運用前に対象サービス・業務要件を確認します。

## 10. Migration方針

1. GitHubの `qr-listing/db/migrations/` を正本にする。
2. 初期Migrationは `0001_initial_schema.sql`。
3. 変更は `0002_...`, `0003_...` と追加し、適用済み過去Migrationを書き換えない。
4. SQLite/CIで構文、FK、index、基本CRUDを検証する。
5. QR-013でP016標準Workflowにより **production D1 1個** とR2 staging/production bucketをProvisioningする。
6. QR-014でMigrationを事前検証後、production D1へ適用し、schema version / Migration履歴をP016管理台帳へ記録する。
7. 破壊的変更は適用前バックアップと人間確認を行う。

## 11. 後続タスクへの入力

### QR-013

- project_id: P013
- system: QR商品出品支援
- D1: P016 production単一D1標準
- R2: staging / production 2bucket標準
- initial schema version: 0（Provisioning直後）
- initial migration: `qr-listing/db/migrations/0001_initial_schema.sql`

旧タスク文面のstaging D1は作成しません。

### QR-014

- schema v1をSQLite/CIで検証
- production適用前にバックアップ可否確認
- P016共通Worker APIのallowlist operationとして商品、QR、写真metadata、AI候補、確定値、listing draftを実装
- requestからの任意DB/table選択、自由SQLを禁止
- R2 upload/downloadはWorker bindingまたは短期Presigned URL

### QR-015

Worker API経由で以下をsmoke testします。

- upload batch保存/再読込
- QR候補/手動確定
- 同一QRへの複数写真関連付け
- 商品状態遷移
- AI candidateと人確認済み値の分離
- listing draft生成
- R2 staging画像upload/list/read
- 権限拒否
- 監査ログ
- 再読込後の永続化

## 12. QR-012完了範囲

本タスクではDB/R2 **設計とMigration正本の確定のみ**を行います。

実施しない:
- Cloudflare D1作成
- R2 bucket作成
- production Migration適用
- Worker deploy
- 実商品データ投入
- 外部サービスへの商品登録
- 本番公開
