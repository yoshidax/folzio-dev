# Contract: ツールバーのラベルとツールチップ

ラベル = セット名（名詞）。ツールチップ = 押したときの動作＋ショートカット。アクセシビリティの読み上げはツールチップと同じ文言。
ショートカットは `specs/product/contracts/keyboard-and-menus.md` と一致させる。英語は案（保守者のレビュー対象）。

## ラベル（カスタマイズ画面・テキスト表示）

| 識別子 | 文言キー | 日本語（新） | 英語（案） | 現行（日本語 / 英語） |
|---|---|---|---|---|
| history | `toolbar.history` | 戻る / 進む | Back/Forward | 履歴 / Back/Forward |
| paneLayout | `toolbar.panes` | 表示 | Panes | ペイン / Panes |
| slideshow | `toolbar.slideshowLabel`（新） | スライドショー | Slideshow | （メニュー文言を流用） |
| previewZoom | `toolbar.zoomGroup` | プレビューサイズ | Preview Size | 拡大・縮小 / Zoom |
| mediaTypeFilter | `toolbar.mediaType` | メディアタイプ | Media Type | 種類 / Media Type |
| zipVisibility | `toolbar.zipFilesLabel`（新） | zipファイル | Zip Files | （メニュー文言を流用） |
| viewMode | `toolbar.viewMode` | ファイルリスト表示形式 | File List View | 表示形式 / View |
| thumbnailSize | `toolbar.thumbnailSizeLabel`（新） | サムネイルサイズ | Thumbnail Size | サイズ / Size |

サイズバー（ファイルリスト下部）のラベル `toolbar.size`（サイズ / Size）は変えない。

## ツールチップ（セグメントごと）

| ボタン | 文言キー | 日本語 | 英語（案） |
|---|---|---|---|
| 戻る | `toolbar.goBackHelp`（新） | 戻る（⌘[） | Back (⌘[) |
| 進む | `toolbar.goForwardHelp`（新） | 進む（⌘]） | Forward (⌘]) |
| ファイルリストのみ表示 | `toolbar.showFileListOnlyHelp`（新） | ファイルリストのみ表示（⌃⌘2） | Show File List Only (⌃⌘2) |
| プレビューのみ表示 | `toolbar.showPreviewOnlyHelp`（新） | プレビューのみ表示（⌃⌘3） | Show Preview Only (⌃⌘3) |
| スライドショー | `toolbar.startSlideshowHelp` | スライドショーを開始（⇧⌘S） | Start Slideshow (⇧⌘S)（変更なし） |
| 拡大・表示領域に合わせる・縮小 | `toolbar.zoomInHelp` ほか | 変更なし | 変更なし |
| 画像のみ | `toolbar.showImagesOnlyHelp`（新） | 画像のみ表示（⇧⌘I） | Show Images Only (⇧⌘I) |
| 動画のみ | `toolbar.showVideosOnlyHelp`（新） | 動画のみ表示（⇧⌘M） | Show Videos Only (⇧⌘M) |
| zipファイル | `toolbar.zipFilesHelp`（新） | zipファイルを表示（⌃⌘Z） | Show Zip Files (⌃⌘Z) |
| サムネイル | `toolbar.thumbnails` | サムネイル（⌘1） | Thumbnails (⌘1) |
| リスト | `toolbar.list` | リスト（⌘2） | List (⌘2) |
| サムネイルサイズ | `toolbar.thumbnailSize` | サムネイルサイズ（⌃⌘. / ⌃⌘,） | Thumbnail Size (⌃⌘. / ⌃⌘,) |

検査: 日英のキーが一致し、`TextKey` の説明を持つこと（`CatalogConsistencyTests`）。メニューの文言（`menu.*`）は変えない。
