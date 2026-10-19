# Contract: 永続化する設定

`UserDefaults`（アプリのドメイン）に保存するキーの契約。値の意味と既定値は [data-model.md](../data-model.md) を参照。
キー名を変える場合は、旧キーから読み替える移行処理を同時に入れる。

| キー | 型 | 既定値 | 対応 |
|------|----|--------|------|
| `view.displayMode` | String（`list` / `thumbnails`） | `list` | FR-010 |
| `view.thumbnailSize` | Double | 128 | FR-014 |
| `view.sort.column` | String（`name` / `creationDate` / `kind`） | `name` | FR-012 |
| `view.sort.ascending` | Bool | true | FR-012 |
| `view.lastFolderPath` | String（絶対パス） | （未設定 = ホーム） | FR-003 |
| `playback.autoplay` | Bool | true | FR-031・032 |
| `playback.loop` | Bool | true | FR-031・032 |
| `fileOps.confirmBeforeExecuting` | Bool | true | FR-022・023 |

- ペイン幅は `NSSplitView` の自動保存名 `MainSplit` で別途保存する（FR-002・003）
- 読み込み時に型や値の範囲が不正なものは既定値に戻す（例: `thumbnailSize` を 48〜512 に丸める）
- フルスクリーン状態は保存しない。次回の起動は常に3ペイン表示から始める

## 設定ウインドウ（⌘,）

| 区分 | 項目 | 対応キー |
|------|------|----------|
| 動画 | 「動画を自動再生する」チェックボックス | `playback.autoplay` |
| 動画 | 「動画をループ再生する」チェックボックス | `playback.loop` |
| ファイル操作 | 「コピー・移動・名前の変更・ゴミ箱に入れる前に確認する」チェックボックス | `fileOps.confirmBeforeExecuting` |

チェックボックスの変更は即座に反映し、再起動を必要としない。
