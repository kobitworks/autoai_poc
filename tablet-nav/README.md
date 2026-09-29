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
- `coords.accuracy` が欠損・非数値・負値の場合も高精度扱いにせず「精度 不明（GPS精度低下）」へ縮退し、速度・方角を `--` に保つ。精度円は不明値を0mとして描画せず一時的に非表示にする
- 主ステータス表示も同じ60m閾値へ統一し、61〜100mで「GPS受信中」と速度/方角の「GPS精度低下」が矛盾しないようにする
- GPSエラー発生時は速度/方角の差分計算用fixを破棄し、権限拒否時はwatchを終了する
- GPSエラー後に「現在地へ」を押した場合は、古い現在地表示だけに戻らず `watchPosition` を明示的に再開始する
- 画面が非表示になった場合は `clearWatch` でGPS測位を一時停止し、差分計算用 `lastFix` を破棄する。再表示時は `watchPosition` を新しく開始し、非表示前後の古い位置差分を速度・方角推定へ持ち込まない
- GPS watchの停止・再開始ごとに世代番号を更新し、旧watch由来の遅延callbackは無視する。再開直後に古い位置fixが現在位置・速度・方角推定へ混入しないようにする
- 初期ロード時点でページが非表示の場合は `watchPosition` を開始せず、表示状態へ戻った時点で初めてGPS測位を開始する
- 同一GPS watch世代内でも `Position.timestamp` が直前fix以下の場合は古い測位結果として破棄し、現在地・速度・方角の状態を巻き戻さない。watch停止・再開時はtimestamp履歴もリセットする
- 速度・方角が信頼できない場合は `--` とし、推測値を無理に表示しない

GPS速度は車両の法定速度計の代替ではなく補助表示です。

実機iPad/Androidでの測位・速度・方角確認は人間確認が必要なため、NAV-007完了Gateとして別途確認します。

### NAV-008

PWAと基本音声操作は後続タスクで扱います。
