# AutoAI Web PoC Template

オートAIのWebシステムPoC向け共通テンプレートです。

## 標準運用
- PoCは `kobitworks/autoai_poc` のプロジェクト単位フォルダへ配置する
- 通常の開発・修正は `develop` ブランチへ反映する
- GitHub PagesをPoC・開発確認環境として利用する
- `main` は共通PoCの日常更新には使用しない
- 本番化が承認されたプロジェクトだけ専用GitHubリポジトリへ切り出す
- 専用リポジトリでは `develop` を開発/Preview、`main` をCloudflare本番デプロイ元とする
- `develop` → `main` の反映は人間承認後にChatGPT / AIが実行する
- `main` 更新後のCloudflare本番デプロイは自動化する

## Cloudflare
PoC段階ではCloudflare Workers / D1 / R2を一律には作成しません。
バックエンド、永続化、認証等がPoCに必要な場合のみ、必要最小限のリソースを利用します。
本番化時には、専用リポジトリとCloudflareを接続し、本番で必要なWorkers / D1 / R2 / Secrets / bindingsを構築します。

## 原則
- ソースコードの正本はGitHub
- 秘密情報はコミットしない
- Google Driveには仕様・タスク・判断記録を保持する
- 本番反映は人間承認を必須とする
