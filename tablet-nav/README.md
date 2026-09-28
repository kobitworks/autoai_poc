# P010 タブレットナビ — PoC Preview

NAV-006 で準備した共有PoC基盤です。

- Repository: `kobitworks/autoai_poc`
- Branch: `develop`
- Preview: GitHub Pages
- Path: `/tablet-nav/`
- Cloudflare: 現行AutoAI標準に従い、PoC段階では新規リソースを作成しない

## 実装状況

### NAV-006

Preview配信のための静的な基盤を準備済みです。

### NAV-007

GPS現在地・地図追従・速度・方角表示を develop に実装済みです。

- `watchPosition` による高精度GPS継続測位
- 現在地マーカーと精度円
- 初回fixでzoom 16、追従中は `panTo`
- 手動ドラッグで追従停止、「現在地へ」で追従再開
- `coords.speed` が得られる場合はGPS速度をkm/h表示
- `coords.speed` がnullの場合は、精度条件を満たす連続位置から速度を推定
- `coords.heading` が得られる場合は方位角を8方位へ変換して表示
- headingがnullの場合は、十分な移動量があるときだけ連続位置から移動方向を推定
- GPS精度が60mを超える場合は、端末が `speed` / `heading` を返していても断定表示せず `--` + `GPS精度低下` とする
- 主ステータス表示も同じ60m閾値へ統一し、61〜100mで「GPS受信中」と速度/方角の「GPS精度低下」が矛盾しないようにする
- 速度・方角が信頼できない場合は `--` とし、推測値を無理に表示しない

GPS速度は車両の法定速度計の代替ではなく補助表示です。

実機iPad/Androidでの測位・速度・方角確認は人間確認が必要なため、NAV-007完了Gateとして別途確認します。

### NAV-008

PWAと基本音声操作は後続タスクで扱います。
