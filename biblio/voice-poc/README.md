# Biblio キャラクター音声 無料PoC

Task: BQS-VOICE-001  
Date: 2026-10-11

## 結論

Phase 1 はブラウザ標準の Web Speech API `speechSynthesis` を採用する。
外部TTS API契約、課金、音声ファイル生成は不要。家入 紗六と渡 淳二の2名で、端末の日本語音声・話速・高さを切り替えるPoCを実装した。

## PoC

- `index.html`
- ユーザー操作時のみ再生（自動再生なし）
- セリフ本文を常時表示
- `speechSynthesis.getVoices()` と `voiceschanged` に対応
- `ja-JP` を優先し、同言語音声が複数ある場合は2キャラクターへ別音声を初期割当
- `SpeechSynthesisVoice.localService` を表示し、端末内音声を優先
- 停止ボタン、話速・高さ調整、API非対応時のフォールバック表示あり

## 方式比較

| 観点 | ブラウザ標準TTS | 事前生成音声ファイル |
|---|---|---|
| 費用 | 外部API費用なし | 生成手段次第。配布許諾も要確認 |
| 声の再現性 | 端末・OS・ブラウザで異なる | 同じ音声を全端末で再生可能 |
| スマホ | Web Speech API対応端末で利用可能 | HTML audio対応が広い |
| ネットワーク | localServiceなら端末内の可能性。remote voiceは通信依存 | 初回取得に通信。バンドル/キャッシュで軽減可 |
| 容量 | 音声ファイルを持たない | セリフ数に比例して増加 |
| QA | 声名・品質が端末差あり | 音声そのものを固定してQA可能 |
| アクセシビリティ | 元テキストを画面に残す | 元テキスト/同等情報を画面に残す |
| ライセンス | 実行時読み上げのみ。録音・再配布はプラットフォーム規約確認が必要 | 生成元の利用規約で商用配布・二次利用許諾を必ず確認 |

## 推奨実装

1. Phase 1: Web Speech APIを「任意の読み上げ補助」として導入。
2. キャラクターIDごとに `voiceURI/name`, `rate`, `pitch` の希望値を保持するが、声名が端末にない場合は `ja-JP` の既定音声へフォールバック。
3. 自動再生しない。セリフごとに再生/停止をユーザーが操作する。
4. 画面上の本文を正本とし、音声は追加表現にする。
5. Phase 2で「ブランドとして同じ声が必須」と判断した場合のみ、配布権を確認した事前生成音声ファイルへ切り替える。
6. 実在人物・俳優・声優を想起させる模倣指示は使わない。

## 課題

- Web Speech APIの声一覧・品質・`localService` は利用端末に依存する。
- オフライン動作は一律保証しない。
- 声を固定したい場合は音声ファイル方式が有利だが、容量と権利確認の運用が増える。
- 長文Chapterを全読み上げするより、キャラクター会話や重要ヒント等の短い発話から導入する方が品質管理しやすい。

## 参照

- MDN: https://developer.mozilla.org/en-US/docs/Web/API/Window/speechSynthesis
- MDN getVoices: https://developer.mozilla.org/en-US/docs/Web/API/SpeechSynthesis/getVoices
- MDN voiceschanged: https://developer.mozilla.org/en-US/docs/Web/API/SpeechSynthesis/voiceschanged_event
- MDN localService: https://developer.mozilla.org/en-US/docs/Web/API/SpeechSynthesisVoice/localService
- MDN autoplay guide: https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay
- MDN audio element: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/audio
- W3C WCAG 2.2 SC 1.2.1: https://www.w3.org/WAI/WCAG22/Understanding/audio-only-and-video-only-prerecorded

## 非採用

- 有料クラウドTTSをPoC必須要件にすること
- 実在人物の声のクローン/模倣
- 音声の自動再生
- 音声だけに情報を持たせること
