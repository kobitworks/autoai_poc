# P005 モノリンク DB設計

P016「DB管理基盤」の標準に従う、モノリンクの業務D1設計です。

## 正本
- Migration正本: `monolink/db/migrations/`
- 初期Migration: `0001_initial_schema.sql`
- DB変更は既存Migrationを編集せず、`0002_...` 以降を追加する
- stagingへ先に適用・検証し、成功後にproductionへ同一Migrationを適用する
- D1の作成・P016管理台帳登録はMONO-013でDBM-004標準Workflowを使用する
- Migration適用とWorker API接続はMONO-014で実施する

## P016標準との整合
- 1システムにつきstaging / productionの2環境
- GitHub上のMigrationをDB変更履歴の正本とする
- GitHub Pages等の静的フロントエンドからD1へ直接接続しない
- P016共通Worker APIを1プロジェクト×1環境で展開する
- Workerからrequestでproject / environment / databaseを自由選択させない
- prepared statement + bind、default-deny認可、監査、CORS、Rate Limit、command冪等性を使用する
- Cloudflare管理Secretをブラウザへ配布しない

## 主なテーブル

| テーブル | 役割 |
| --- | --- |
| users | 認証主体との内部紐付け。メール・電話番号を業務D1へ必須保存しない |
| organizations / organization_members / facilities | 鉄道・店舗等の組織、担当者、拠点 |
| items | 物品の現在状態、現在管理者、匿名連絡ルート、公開表示モード、state_version |
| qr_codes | 公開QRトークンのハッシュ、QRライフサイクル、交換関係 |
| ownerships | 管理権履歴。PRIMARY_MANAGER / CO_MANAGER |
| lost_cases | 紛失案件と任意謝礼表示 |
| finder_sessions | 非会員拾得者の一時匿名セッション |
| found_reports | 拾得報告。位置は自由文または施設IDで保持し正確なGPS座標は保存しない |
| messages | 匿名スレッド本文。保持期限・redactを前提 |
| custody_records | 施設保管・受付番号・内部保管場所・法定手続状況 |
| transfers | ギフト・譲渡トランザクションと一回使用受領tokenのハッシュ |
| notifications | Web内通知の参照情報 |
| item_events | 業務状態の追記型イベント履歴。P016のAPI audit_logsとは役割を分離 |

## ID / Token
- 内部IDはWorker側でUUID等の推測困難なIDを生成する
- QRの公開tokenは十分な乱数で生成し、D1には原則SHA-256等のハッシュだけを保持する
- ギフト受領tokenも平文保存せずclaim_token_hashのみを保持する
- sticker_codeは問い合わせ用の短い識別子であり、認証・管理権限には使用しない

## 状態設計

### QR
`UNREGISTERED -> ACTIVE -> SUSPENDED / REPLACED / REVOKED`

紛失はQR状態ではなく物品・紛失案件側で管理する。REPLACED旧QRから新しいpublic tokenへ自動転送しない。

### Item
`NORMAL / LOST / FOUND_CONTACT / RETURNING / CUSTODY / RETURNED / ARCHIVED`

items.state_versionをすべての重要状態変更でインクリメントする。ギフト受領などは開始時versionと現在versionを比較し、紛失・施設保管・QR無効化などが途中で成立した場合に古い受領処理を失敗させる。

### Transfer
`DRAFT -> OFFERED -> COMPLETED`
分岐: `CANCELLED / EXPIRED`

OFFERED中はcurrent_manager_user_id、contact_route_user_idを贈与元のまま維持する。accept成立時にownership履歴更新、items.current_manager_user_id、items.contact_route_user_id、public_view_mode、state_version、Transfer.statusを1トランザクションで更新する。

### Custody
`RECEIVED -> OWNER_NOTIFIED -> PICKUP_PLANNED -> HANDED_OVER -> CLOSED`
分岐: `TRANSFERRED / CANCELLED`

施設保管は管理権移転ではない。ACTIVEな保管中はギフトacceptを原則拒否する。

## 競合制御
- 同一Itemの有効PRIMARY_MANAGERは部分unique indexで1件に制限
- 同一Itemの有効LostCase、Custody、Transferを部分unique indexで重複抑止
- DB制約だけに依存せず、Worker commandはtransaction + state_version比較更新を使用する
- commandはP016標準のIdempotency-Keyを必須とする
- QR無効化・交換、紛失開始、施設保管開始などTransfer acceptを無効にすべき操作でもitem.state_versionを更新する

## 個人情報最小化
- 所有者のメール・電話番号・住所を公開QRから参照できる形で保存しない
- usersは認証主体auth_subjectと内部表示用aliasを基本とする
- finder_sessionsには拾得者の氏名・メール・電話番号を必須保存しない
- 正確なGPS緯度経度は業務D1へ保存しない
- item_events/detail_jsonおよびP016 audit_logsへメッセージ本文、JWT、Secretを保存しない
- private_note / public_messageは用途を分離し、public_message側へ直接連絡先を入力させない入力検証を後続APIで実装する

## 保持方針（技術初期案）
本番前にMONO-010で残した法務・所管確認を行い、最終期間を確定する。期間はWorker/cleanup処理の設定値とし、SQLへ固定値を埋め込まない。

- Core: items / qr_codes / ownerships / transfersは物品管理中は保持。退会・削除時は必要な履歴を匿名化して削除可能にする
- Communication: finder_sessionsは短期保持、messagesは返却完了・スレッド終了後に期限を設定し本文をredact可能にする
- Operations: lost_cases / found_reports / custody_records / notificationsは問い合わせ対応に必要な期間のみ保持
- Business history: item_eventsは本文を持たない最小監査として比較的長めに保持
- API audit: P016 CONTROL_DBのaudit_logsで別管理し、業務本文は保存しない

初期運用案として finder session 30日、message本文90日、通知180日、業務イベント1年を候補にするが、本番値は法務・運用確認後に確定する。

## R2
MONO-012時点のコア要件では写真・PDF等のバイナリ保存は必須ではないためR2は作成しない。今後、物品写真・証明書類などが要件化された場合のみ、P016 R2標準に従う追加Migration/タスクでメタデータ連携を追加する。

## MONO-013への引継ぎ
- project_id: `P005`
- system_name: `Monolink` を候補とする
- DBM-004 `provision-project-databases.yml` を利用
- 新規D1はschema version 0で作成
- MONO-014で `0001_initial_schema.sql` をstagingに適用・smoke test後、同一ファイルをproductionへ適用する
