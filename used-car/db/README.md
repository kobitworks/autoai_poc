# P014 中古車販売・車両整備管理 — DB設計 v1

CAR-009 で確定した初期DB設計です。  
GitHub正本はこの `used-car/db/` 配下とし、実D1を直接変更してMigrationを残さない運用を禁止します。

## 1. P016標準との整合

- D1: **1システムにつき production 1個**。常設staging D1は新規作成しない。
- Migration検証: SQLite/CI等で先に実施し、production D1への適用は後続タスクで行う。
- PoCファイル保存: **R2は使用しない**。車両写真・車検証・修理記録等のファイル本体は、モック、GitHub上の静的ファイル、LocalStorage / IndexedDB等のブラウザローカル保存で代替する。
- Browser → D1直接接続は禁止。D1を利用する業務操作はWorker API経由とする。
- Cloudflare API Token / S3 Secret等をブラウザやGitへ平文保存しない。
- 破壊的Migration、実顧客データ投入、本番公開は人間確認対象。

P016側のD1標準は develop ブランチの production単一D1方針を基準とする。PoCの費用0円ルール（runner_rule.md v1.34.0 §29）を優先し、R2はPoCではProvisioning・binding・権限追加・subscription有効化を行わない。CAR-009時点のR2設計記録は将来の本番検討用の履歴として残し、PoC実装要件からは除外する。

## 2. 初期Migration

- `db/migrations/0001_initial_schema.sql`
- schema version: 1
- IDはWorker側でUUID/ULID等の衝突しないTEXT IDを生成する。
- timestampはISO 8601文字列を基本とする。
- 業務日（販売日・車検満了日・整備実施日等）は `YYYY-MM-DD` を基本とする。
- 金額は円の整数、走行距離はkmの整数で保持する。

## 3. テーブル構成

### staff_members

販売担当・整備担当等の最小スタッフ台帳。  
本番ログイン方式は後工程なので `auth_subject` はNULL可とし、将来の認証主体との紐付け口だけ確保する。

### customers

顧客マスタ。

主な項目:
- 氏名
- 氏名カナ
- 電話
- メール
- 郵便番号・住所
- メモ
- ACTIVE / INACTIVE / DELETED

電話番号や住所等のPIIは外部ストレージ識別子やファイル名へ含めない。

### vehicles

車両マスタ。

主な項目:
- メーカー
- 車名
- グレード
- 型式
- 年式
- 登録番号
- 登録番号検索用正規化値
- 車台番号（unique）
- 色
- 初度登録日
- 現在走行距離
- 状態
- `state_version`（楽観ロック用）

### sales

販売履歴。顧客と車両を販売トランザクション単位で結ぶ。

主な項目:
- 車両
- 顧客
- 担当スタッフ
- 契約番号
- 販売日
- 引渡日時
- 販売価格
- 保証期限
- 状態

再販売・再譲渡が起きても過去販売履歴を上書きしない。

### vehicle_ownerships

現在所有者と過去所有者を時系列で保持する。

- `valid_from`
- `valid_to`
- 元販売 `source_sale_id`

`valid_to IS NULL` のactive所有関係は車両ごとに1件だけになるpartial unique indexを設定する。

### inspections

車検・法定点検の予定と実績を同一テーブルで管理する。

主な項目:
- 車両
- 対象顧客
- 種別（SHAKEN / LEGAL_12M / LEGAL_6M / OTHER）
- 状態
- 連絡状況
- 満了・期限日
- 予約日
- 実施日
- 結果
- 走行距離
- 金額

ダッシュボードの「車検が近い車両」は `due_on + status` indexを利用する。

### maintenance_records

整備・修理・部品交換履歴。

主な項目:
- 車両
- 顧客
- 担当スタッフ
- 実施日
- 種別（MAINTENANCE / REPAIR / PARTS_REPLACEMENT / OTHER）
- 作業名
- 作業内容
- 走行距離
- 金額
- メモ

車両詳細の履歴タイムラインは `vehicle_id + performed_on` indexを利用する。

### maintenance_parts

整備履歴に紐づく交換部品明細。

- 部品名
- 品番
- 数量
- 単価
- メモ

部品交換を整備履歴の本文だけに埋め込まず、将来検索・集計できる形に分離する。

### vehicle_odometer_readings

走行距離履歴。

販売・車検・整備・手入力・取込ごとに時系列で保持する。  
`vehicles.current_odometer_km` は現在値の表示用キャッシュとし、履歴の正本はこのテーブルと各業務記録の走行距離とする。

### storage_objects / storage_object_events

CAR-009で将来の外部オブジェクトストレージ連携を見据えて定義したメタデータ領域。PoCではR2へ接続せず、これらのテーブルを「実ファイルがR2へ永続保存済み」という意味では使用しない。

- storage provider / object key等の将来連携用メタデータ
- environment
- entity type / entity id
- media role
- MIME type / size / ETag / SHA-256
- status
- upload/download/delete等の監査イベント

PoCのファイル本体はモック・静的ファイル・LocalStorage / IndexedDB等で代替し、外部ストレージ連携が本番要件として承認された場合だけ、このメタデータ境界を再利用する。

### vehicle_documents

車検証、車両写真、車検記録、修理記録、売買契約書等の**業務上の分類・紐付け**を保持する。

主な項目:
- 車両
- 顧客
- 車検
- 整備履歴
- `storage_object_id`
- document type
- document date
- classification status
- primary flag

CAR-011のAI/OCRでは、抽出候補を即確定値にせず、人が確認した後に業務テーブルへ反映する。抽出候補専用テーブルはCAR-011で必要性を確定し、必要なら `0002_...` Migrationで追加する。

## 4. 主な関連

- customers 1:N sales
- customers 1:N vehicle_ownerships
- vehicles 1:N sales
- vehicles 1:N vehicle_ownerships
- vehicles 1:N inspections
- vehicles 1:N maintenance_records
- maintenance_records 1:N maintenance_parts
- vehicles 1:N vehicle_odometer_readings
- vehicles 1:N vehicle_documents
- storage_objects 1:1 vehicle_documents（初期設計）
- inspections / maintenance_records は vehicle_documents から任意関連できる

## 5. 検索Index方針

初期PoCで必要な検索を優先する。

- 顧客: 氏名/カナ、電話、メール、status
- 車両: 登録番号正規化、メーカー+車名+年式、status、車台番号unique
- 販売: 顧客+販売日、車両+販売日
- 所有: 車両active一意、顧客+valid_to
- 車検: due_on+status、車両+due_on、顧客+due_on
- 整備: 車両+実施日、顧客+実施日、種別+実施日
- 走行距離: 車両+記録日
- 書類: 車両+種別+status、車検、整備
- storage metadata（将来連携用）: entity、status、request_id

検索ニーズが固まる前に過剰なindexを増やさない。

## 6. PoCファイル保存設計（R2不使用）

PoCではCloudflare R2を使用しない。

採用する無料代替:
- 画面確認用のモックデータ / 静的ファイル
- 端末内だけで保持できる LocalStorage / IndexedDB
- GitHub Pagesで配布する検証用静的アセット（実顧客情報を含めない）

ルール:
- R2 subscriptionの有効化、bucket作成、R2 binding追加、R2用API Token権限追加を行わない。
- PoC画面で選択した車両写真・車検証・修理記録は、実運用の永続保存済みデータとして扱わない。
- 実顧客情報・個人情報をPoCのGitHub静的ファイルへ配置しない。
- ブラウザローカル保存を使う場合も、PoC用の架空・検証データだけを対象とする。
- 将来、本番でオブジェクトストレージが必要になった場合は、本番要件と費用を再評価し、ユーザーの明示承認後に別タスクとして設計する。
- CAR-009で残したstorage_objects / vehicle_documents等のスキーマは、将来の保存方式差し替え口として保持するが、PoCでR2利用を意味しない。

## 7. 保持・削除方針

初期段階では自動lifecycle deleteを設定しない。

- 顧客: soft delete可能な構造を用意し、最終保持期間は本番前に業務・法務確認する。
- 販売、車検、整備履歴: 監査・顧客対応上必要な履歴として上書き削除を避け、保持期間は本番前に確定する。
- PoCファイル: モック・静的ファイル・ブラウザローカル保存の範囲に限定する。外部オブジェクトストレージの削除ライフサイクルはPoC対象外とする。
- 将来の外部オブジェクトストレージ導入、保持期間短縮、lifecycle自動削除は人間確認対象。
- 実顧客データをPoCへ投入しない。

現時点で特定年数を法定保存期間として断定しない。

## 8. Migration方針

1. GitHub上の `db/migrations/` を正本にする。
2. 初期は `0001_initial_schema.sql`。
3. 変更は `0002_...`, `0003_...` の連番追加とし、過去Migrationを書き換えない。
4. SQLite/CIで構文・FK・index・基本CRUDを検証する。
5. CAR-012で既存production D1のP016管理台帳登録・読取状態を確認し、PoC構成からR2依存を除外する。
6. CAR-013でMigrationを事前検証後、production D1へ適用しschema version / Migration履歴をP016管理台帳へ記録する。
7. 破壊的変更はproduction適用前にバックアップと人間確認を行う。

## 9. 後続タスクへの入力

### CAR-012

- project_id: P014
- system: 中古車販売・車両整備管理
- D1: P016 production単一D1標準
- PoCファイル保存: R2不使用。モック / 静的ファイル / LocalStorage / IndexedDB等で代替
- schema version initial: 0（Provisioning時）→ CAR-013でMigration適用後1
- initial migration: `used-car/db/migrations/0001_initial_schema.sql`

### CAR-013

Migration v1をSQLite/CIで検証し、基本CRUD・FK/indexを確認後にproductionへ適用する。

### CAR-014

P016共通Worker APIで、顧客・車両・車検・整備・書類メタデータ操作をallowlistされたoperationとして実装する。

### CAR-015

Worker API経由のD1保存・再読込・権限拒否・監査をsmoke testし、ファイル本体はPoC用の無料代替保存で確認する。R2は使用しない。

## 10. CAR-009の完了範囲

本タスクではDB設計とMigration正本の確定を行う。CAR-009当時のR2設計は将来検討用の履歴として残るが、現行PoCではrunner_rule.md v1.34.0 §29によりR2不使用とする。

実施しない:
- Cloudflare D1作成
- R2 bucket作成
- production Migration適用
- Worker deploy
- 実顧客データ投入
- 本番公開
