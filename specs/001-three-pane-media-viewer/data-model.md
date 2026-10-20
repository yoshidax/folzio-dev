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
- `kind` はルートの種類の判定に使い、ツリーの行頭アイコンの選択にも使う（`IconPresentation`、FR-047）

## MediaFile（ファイルリストの項目）

| フィールド | 型 | 説明 |
|------------|----|------|
| `url` | URL | ファイルの場所（同一性のキー） |
| `name` | String | 拡張子を含むファイル名 |
| `kind` | MediaKind | 種類 |
| `typeDescription` | String | 「種類」列に出す OS のローカライズ名（例: 「JPEG イメージ」） |
| `creationDate` | Date? | 「作成日」列。取得できない場合は `nil` で、表示は「--」 |
| `fileSize` | Int64 | バイト数（並べ替えと a11y 用。列は表示しない） |

- リスト形式の行頭アイコンは `kind` からフォールバックを選び、`url` をキーに非同期取得した
  縮小画像で置き換える（`IconPresentation`）。`MediaFile` 自体には画像を保持しない

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

## ThumbnailScroll（サムネイル形式の追従スクロール・永続化しない）

フォーカス項目をビューポート内に保つための計算。状態として保存せず、キーボード移動のたびに
レイアウト結果から求める（FR-017、research.md R15）。

| 入力 | 型 | 説明 |
|------|----|------|
| `itemMinY` / `itemMaxY` | Double | フォーカス項目の縦範囲（コレクションビュー座標） |
| `visibleMinY` | Double | 現在の可視領域の上端（クリップビュー座標） |
| `visibleHeight` | Double | 可視領域の高さ。可視領域の下端は `visibleMinY + visibleHeight` |
| `contentHeight` | Double | スクロール内容の全高 |

| 出力 | 型 | 説明 |
|------|----|------|
| `offsetY` | Double | 項目全体が見える最小の縦スクロール原点。`0...(contentHeight - visibleHeight)` にクランプする |

- 項目全体が見えている場合は `visibleMinY` をそのまま返す（スクロールしない）
- 項目がビューポートより高い場合は上端を可視領域の上端に合わせる
- 横方向の値は持たない。横スクロールは発生させない（FR-015）
- フォーカスは `SelectionState.focused`（最後に移動した項目）と一致する。Shift+矢印で範囲を広げた場合も
  移動先の項目を基準にする
- サムネイルサイズ・ペイン幅・ウィンドウサイズの変更では追従スクロールを行わない（spec Clarifications）

## FocusNavigator（矢印キーによる選択移動・永続化しない）

ファイルリストとフルスクリーンの両方で使う、移動先インデックスの純粋計算（FR-017・046、research.md R16）。

| 入力 | 型 | 説明 |
|------|----|------|
| `currentIndex` | Int? | 現在のフォーカス位置。`nil` は未選択 |
| `fileCount` | Int | リストの件数 |
| `move` | `.left` / `.right` / `.up` / `.down` | 押された矢印キー |
| `layout` | `.list` / `.grid(columns:)` | 表示形式。グリッドの列数は 1 以上 |

| 出力 | 型 | 説明 |
|------|----|------|
| `targetIndex` | Int? | 移動先。空リスト、リスト形式の ←→、端での移動は `nil`（選択を変えない） |

- `.list` は ↑ で -1、↓ で +1、←→ は移動なし
- `.grid(columns:)` は ← で -1、→ で +1、↑ で -列数、↓ で +列数
- 結果は `0...(fileCount - 1)` にクランプする。リスト形式の ←→ は `currentIndex` に関わらず `nil`。
  それ以外で `currentIndex` が `nil` の場合は 0 を返す
- 列数が 0 以下の場合は 1 として扱う（ゼロ除算・同一行内の無限移動を避ける）

## FullScreenNavigationContext（フルスクリーン中のみ・永続化しない）

| フィールド | 型 | 説明 |
|------------|----|------|
| `layout` | `.list` / `.grid(columns:)` | 折りたたみ前の表示形式と列数のスナップショット |
| `isActive` | Bool | フルスクリーン中の keyDown モニタが有効か |

- 折りたたみ後はサムネイルビューの幅が 0 になり列数を再計算できないため、開始時の値を使う（R16）
- 解除時はコンテキストを破棄し、選択は移動後の `SelectionState` のまま維持する（spec Clarifications）
- 永続化しない。`ViewSettings` や `UserDefaults` には追加しない

## PreviewContent（プレビュー状態）

```text
empty ──(focused 設定)──→ loading ──→ image(DecodedImage) / animatedImage(URL) / video(URL)
                                  └──→ unavailable(name, reason)   ← 破損・非対応エンコード（FR-038）
任意 ──(focused が nil / ファイル消失)──→ empty
```

- 動画は `video` 状態になると、自動再生・ループの各オプションに従って再生を始める（FR-031・032）
- `focused` が変わったら、前の動画を停止してから遷移する（FR-034）
- 画像の表示矩形はレイアウトのたびに `FitCalculator` で求める。コンテナより小さい画像も拡大されるため、
  表示サイズは元画像の画素数を超えうる（FR-028）。拡大率は状態として保持しない（再計算で求まる）

## DisplayMode と ViewSettings（表示設定・永続化）

| フィールド | 型 | 既定値 | 制約 |
|------------|----|--------|------|
| `displayMode` | `.list` / `.thumbnails` | `.list` | FR-010 |
| `thumbnailSize` | Double（pt） | 128 | 48〜512 の範囲に丸める（FR-014） |
| `sortOrder` | SortOrder | 名前の昇順 | FR-012 |
| `lastFolder` | URL? | ホーム | 存在しない場合はホームに戻す（FR-003） |
| `showsToolbar` | Bool | false | 値がない・不正な型の場合は false（FR-003・049） |
| ペイン幅 | （分割ビューの自動保存） | 220 / 360 / 残り | 最小幅 160 / 240 / 320 pt（FR-002） |

## FileListChrome（下部バーとツールバーのスライダー・永続化しない）

表示形式とツールバーの表示状態から、ファイルリスト周辺の表示を決める純粋計算。

| 入力 | 型 |
|------|----|
| `displayMode` | `.list` / `.thumbnails` |
| `toolbarShown` | Bool |

| 出力 | 規則 | 要件 |
|------|------|------|
| `showsBottomSizeBar` | `displayMode == .thumbnails && !toolbarShown` | FR-052 |
| `toolbarSliderEnabled` | `displayMode == .thumbnails`（ツールバーが非表示でも値は同じ。表示時にそのまま使う） | FR-051 |

ツールバーの表示形式ボタンの選択位置は `displayMode` から直接決める（サムネイル = 0、リスト = 1）。

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

## IconPresentation（行頭アイコン・永続化しない）

ツリーとリスト形式の名前の先頭に出すアイコンの表現。モデルの状態としては保存せず、表示のたびに
`FolderNode.Kind` と `MediaKind` から決める（FR-047・048、research.md R17）。

| 対象 | 入力 | 表示 |
|------|------|------|
| ツリー | `FolderNode.Kind.home` | `house` の SF Symbol |
| ツリー | `FolderNode.Kind.volume` | `externaldrive` の SF Symbol |
| ツリー | `FolderNode.Kind.folder` | `folder` の SF Symbol |
| リスト（生成中・失敗時） | `MediaKind.jpeg` | `photo` の SF Symbol |
| リスト（生成中・失敗時） | `MediaKind.png` | `photo.on.rectangle` の SF Symbol |
| リスト（生成中・失敗時） | `MediaKind.gif` | `photo.stack` の SF Symbol |
| リスト（生成中・失敗時） | `MediaKind.webp` | `photo.circle` の SF Symbol |
| リスト（生成中・失敗時） | `MediaKind.mp4` | `film` の SF Symbol |
| リスト（生成中・失敗時） | `MediaKind.mov` | `video` の SF Symbol |
| リスト（取得後） | `ThumbnailProviding` の 64px 画像 | 内容の縮小画像（動画は代表フレーム） |

- アイコンは装飾で、選択・フォーカス・並べ替えのキーにはならない。a11y 要素にはせず、
  フォルダ名・ファイル名の読み上げを維持する
- リストの縮小画像は可視行だけを非同期に取得し、取得後に同じ URL のセルへだけ差し替える。
  セル再利用時は同じ URL・要求サイズの取得だけを取り消し、他のサイズ（サムネイル形式の
  128 / 256 / 512px）の要求は残す。取得結果はメモリ上のサムネイルキャッシュにのみ置く
- ツリーのアイコンは展開状態で変化しない。アイコン自体は永続化しない

## AppIcon（ビルド時のみ・Core の型ではない）

アプリバンドルのアイコン。実行時のモデルや永続化設定には含めない（FR-043〜045、research.md R14）。

| 項目 | 内容 |
|------|------|
| 原画の設計座標 | 1024×1024。角丸スクエア + 3ペインの図案。文字なし |
| 生成解像度 | 16 / 32 / 64 / 128 / 256 / 512 / 1024 px（iconset の @1x / @2x スロットを埋める） |
| 中間生成物 | `.build/AppIcon.raw/icon_<size>x<size>.png`（7サイズ） |
| iconset | `.build/AppIcon.iconset/`（標準名の10スロット） |
| バンドル成果物 | `Contents/Resources/AppIcon.icns` |
| バンドル参照 | `Info.plist` の `CFBundleIconFile = AppIcon` |
| 失敗時の扱い | 描画・解像度検証・`iconutil` のいずれかが失敗したら `.app` を作らず非ゼロ終了する |

- 原画は `Sources/make-icon/` のコードを正とし、生成済みの `.icns` はコミットしない
