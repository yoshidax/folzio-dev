# Data Model: 3ペイン型メディアビューア

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-10-19

型はすべて `MediaViewerCore` に置き、AppKit に依存しない。永続化するのは表示設定と動作オプションだけで
（[contracts/settings.md](./contracts/settings.md)）、それ以外はファイルシステムから都度読み出す。

## MediaKind

対応形式の判定結果。拡張子だけで判定し、大文字小文字は区別しない（FR-009）。

| 値 | 拡張子 | 区分 |
|----|--------|------|
| `jpeg` | jpg, jpeg | image |
| `png` | png | image |
| `gif` | gif | image |
| `webp` | webp | image |
| `mp4` | mp4 | video |
| `mov` | mov | video |

- `MediaKind(fileExtension:)` は上の表以外の拡張子に対して `nil` を返す。`nil` のファイルはリストに表示しない（FR-008）
- `isVideo` プロパティで画像と動画を区別する

## FolderNode（ツリーのノード）

| フィールド | 型 | 説明 |
|------------|----|------|
| `url` | URL | フォルダの場所（同一性のキー） |
| `name` | String | 表示名（ボリュームの場合はボリューム名） |
| `kind` | `.home` / `.volume` / `.folder` | ルートの種類 |
| `children` | `[FolderNode]?` | `nil` は未読み込み。展開時に読み込む |
| `accessState` | `.unknown` / `.accessible` / `.denied` | 読み取り可否（エッジケース） |

- 子に含めるのはフォルダだけで、隠しフォルダとパッケージ（`.app` 等）は除く（FR-006）
- 並び順は名前の自然順（数字を数値として比較）
- ルートはホームフォルダ + マウント中のボリューム（FR-004）。ボリュームは取り外し通知で削除する

## MediaFile（ファイルリストの項目）

| フィールド | 型 | 説明 |
|------------|----|------|
| `url` | URL | ファイルの場所（同一性のキー） |
| `name` | String | 拡張子を含むファイル名 |
| `kind` | MediaKind | 種類 |
| `typeDescription` | String | 「種類」列に出す OS のローカライズ名（例: 「JPEG イメージ」） |
| `creationDate` | Date? | 「作成日」列。取得できない場合は `nil` で、表示は「--」 |
| `fileSize` | Int64 | バイト数（並べ替えと a11y 用。列は表示しない） |

## FolderListing（ファイルリストの内容）

| フィールド | 型 | 説明 |
|------------|----|------|
| `folder` | URL | 対象フォルダ |
| `files` | `[MediaFile]` | フィルタ済み・並べ替え済みのファイル |
| `state` | `.loading` / `.loaded` / `.empty` / `.denied` / `.failed(String)` | 表示状態 |

**状態遷移**:

```text
(フォルダ選択) → loading → loaded ─┐
                         ├→ empty   │← FSEvents による差分反映（loaded ⇄ empty）
                         ├→ denied  │
                         └→ failed  │
(別フォルダ選択) ── 任意の状態 → loading（前の読み込みは取り消す）
```

## SortOrder

| フィールド | 型 | 説明 |
|------------|----|------|
| `column` | `.name` / `.creationDate` / `.kind` | 並べ替え列（FR-012） |
| `ascending` | Bool | 昇順なら true |

- 既定は `.name` の昇順。名前は Finder と同じ自然順（`localizedStandardCompare`）で比較する
- 同じ値が並んだ場合は、名前の自然順を第2キーにする

## SelectionState

| フィールド | 型 | 説明 |
|------------|----|------|
| `selected` | `Set<URL>` | 選択中のファイル（複数選択: FR-016） |
| `focused` | URL? | 最後に選択・フォーカスされたファイル。プレビューの対象（FR-017） |

- 選択中のファイルが外部で削除されたら選択から外す。`focused` が消えた場合はプレビューを空にする
- 表示形式を切り替えても選択状態は維持する（US3-1）

## PreviewContent（プレビュー状態）

```text
empty ──(focused 設定)──→ loading ──→ image(DecodedImage) / animatedImage(URL) / video(URL)
                                  └──→ unavailable(name, reason)   ← 破損・非対応エンコード（FR-038）
任意 ──(focused が nil / ファイル消失)──→ empty
```

- 動画は `video` 状態になると、自動再生・ループの各オプションに従って再生を始める（FR-031・032）
- `focused` が変わったら、前の動画を停止してから遷移する（FR-034）

## DisplayMode と ViewSettings（表示設定・永続化）

| フィールド | 型 | 既定値 | 制約 |
|------------|----|--------|------|
| `displayMode` | `.list` / `.thumbnails` | `.list` | FR-010 |
| `thumbnailSize` | Double（pt） | 128 | 48〜512 の範囲に丸める（FR-014） |
| `sortOrder` | SortOrder | 名前の昇順 | FR-012 |
| `lastFolder` | URL? | ホーム | 存在しない場合はホームに戻す（FR-003） |
| ペイン幅 | （分割ビューの自動保存） | 220 / 360 / 残り | 最小幅 160 / 240 / 320 pt（FR-002） |

## PlaybackOptions と ConfirmationOptions（動作オプション・永続化）

| フィールド | 型 | 既定値 | 要件 |
|------------|----|--------|------|
| `autoplay` | Bool | true | FR-031・032 |
| `loop` | Bool | true | FR-031・032 |
| `confirmBeforeFileOperations` | Bool | true | FR-022〜024（false の場合は4操作すべてで確認を省略する） |

## FileOperation（ファイル操作）

| フィールド | 型 | 説明 |
|------------|----|------|
| `kind` | `.copy` / `.move` / `.rename(newName)` / `.trash` | 操作の種類（FR-018） |
| `sources` | `[URL]` | 対象（rename の場合は1件） |
| `destination` | URL? | 操作先フォルダ（copy・move の場合） |

**検証規則**:
- move: 移動先が元のフォルダと同じ場合は何もしない。フォルダを自分自身やその配下へ移動しようとした場合は拒否する
- rename: 空の名前、`/` または `:` を含む名前、先頭が `.` の名前、既存の名前（大文字小文字の違いのみも含む）は拒否する。
  拡張子が変わる場合は確認を求める（[research.md](./research.md) R10）

**実行の流れ**:

```text
requested ─(確認 ON)→ awaitingConfirmation ─(キャンセル)→ cancelled（ファイルシステムは変更しない: FR-022）
    │                       └─(OK)─┐
    └─(確認 OFF)───────────────────┴→ conflictCheck ─(衝突あり)→ awaitingConflictChoice
                                            │                    ├ 置き換える / 両方残す → executing
                                            │                    └ 中止 → cancelled
                                            └─(衝突なし)→ executing → completed(FileOperationResult)
```

## FileOperationResult

| フィールド | 型 | 説明 |
|------------|----|------|
| `succeeded` | `[URL]` | 操作後の URL（trash の場合はゴミ箱内の URL） |
| `failed` | `[(URL, reason: String)]` | 失敗した対象と理由（FR-026） |

- 1件の失敗で残りの処理を止めない。ただし各ファイルは「全部成功」か「変更なし」のどちらかにする
  （部分的にコピーされたファイルは削除する: エッジケース）
