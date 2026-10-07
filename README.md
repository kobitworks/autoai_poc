# autoai_poc

AI自動実行（オートAI）のWebシステムPoCを、プロジェクト単位のサブフォルダで管理する共通PoCリポジトリです。

## UI実装ルール

画面上のアイコン・ナビゲーション表現は [`UI_GUIDELINES.md`](./UI_GUIDELINES.md) に従います。Font Awesome / Icons8を標準とし、絵文字・Unicode記号・CSS疑似アイコンによる代用は原則行いません。

## ブランチ運用

- `develop`: PoC・開発確認用の標準ブランチ。オートAIによる通常の実装・修正は原則こちらへ反映します。
- `main`: 移行時点の基準状態として保持します。この共通PoCリポジトリでは日常のPoC更新先として使用しません。
- GitHub Pages: PoC・開発確認環境として `develop` を公開元にします。
- 本番化するプロジェクト: このリポジトリ内の対象フォルダを専用GitHubリポジトリへ移行し、専用リポジトリで `develop` / `main` を運用します。
- 専用リポジトリの `main`: Cloudflare本番環境のデプロイ元とし、人間承認後のマージを起点に自動デプロイする構成を標準とします。

## 本番化フロー

1. `autoai_poc/develop` でPoCを作成・更新
2. GitHub PagesでPoCを確認
3. 本番化を人間が承認
4. 対象プロジェクトフォルダを専用リポジトリへ移行
5. 専用リポジトリの `develop` で継続開発
6. 本番反映前にChatGPT / AIが差分・テスト結果・影響を整理
7. 人間が本番反映を承認
8. ChatGPT / AIが `develop` → `main` をマージ
9. Cloudflareが `main` 更新を検知し、本番へ自動デプロイ

## 現在のPoC公開状態

GitHub Pagesの公開元は `develop` へ切り替え済みです。
2026-09-27に一覧画面のPortal Versionを0.8へ更新し、`develop` へのpushを起点としてGitHub Pagesが更新されることを確認済みです。
