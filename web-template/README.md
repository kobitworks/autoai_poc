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

## P008の完全無料PoC
P008「Webシステム自動構築」のPoCは、費用が発生しない構成を必須とします。

- Cloudflare WorkersはWorkers Freeのみを使用する
- D1はWorkers Freeに含まれる無料範囲のみを使用する
- Workers Paidなどの課金契約が有効な場合はPreviewデプロイ前に安全停止する
- 課金プランへの変更、契約追加、課金設定変更は自動実行しない
- R2はPoCでは使用しない
- ファイル保存が必要なPoCは、GitHub上の静的ファイル、モックデータ、ブラウザのLocalStorage / IndexedDB等で代替する
- 無料枠を超えた場合は有料化せず、サービス側のFreeプラン制限により停止・失敗することを許容する

## Cloudflare
PoC段階ではCloudflareのリソースを一律には作成しません。
バックエンド、永続化、認証等がPoCに必要な場合のみ、無料で利用できる必要最小限のリソースを使用します。

P008の現在の検証対象はWorkers Preview + D1です。R2 bindingやR2 APIは使用しません。
本番化時に別のCloudflareサービスが必要になった場合は、費用・無料枠・停止条件を改めて確認し、人間承認後に構成します。

## P008 GitHub OAuth
WEB-004ではGitHub OAuthによるソーシャルログインを採用します。

- OAuth AppのClient Secretはソースコード・Google Drive・Slackへ保存しない
- OAuthのstateは短命・Secure・HttpOnly・SameSite=Lax Cookieで検証する
- ログイン後はGitHubの数値IDとlogin名だけを署名付きSecure/HttpOnly Cookieへ保持する
- メールアドレスのOAuth scopeは要求しない
- ユーザー識別情報はD1へ保存しない
- ログアウトはセッションCookieを失効させる
- 未設定時は `/auth/login` がfail-closedで `503 auth_not_configured` を返す

現在のPreview callback URL:
`https://develop-p008-web-template.shinozaki-ed1.workers.dev/auth/callback`

実ログイン検証を開始するには、GitHub OAuth Appを作成し、上記callback URLを設定したうえでClient ID / Client Secretを秘密情報管理へ登録する必要があります。秘密値をIssue、Drive、Slack、コミットへ記載しないでください。

## 原則
- ソースコードの正本はGitHub
- 秘密情報はコミットしない
- Google Driveには仕様・タスク・判断記録を保持する
- 本番反映は人間承認を必須とする
- PoCで従量課金へ自動移行する構成を採用しない
