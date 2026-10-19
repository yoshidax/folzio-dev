# Implementation Plan: 3ペイン型メディアビューア

**Branch**: `001-three-pane-media-viewer`（git 上は未作成。現在の作業ブランチは `master`） | **Date**: 2026-10-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-three-pane-media-viewer/spec.md`

## Summary

左にフォルダツリー、中央にファイルリスト（リスト形式 / サムネイル形式）、右にプレビューを並べた
macOS 用のメディアビューアを作る。画像（JPEG / PNG / GIF / WebP）と動画（mp4 / mov）を閲覧でき、
Finder 準拠の操作でファイルのコピー・名前の変更・ゴミ箱への移動・移動ができる。

実装は Swift 6 + AppKit のネイティブアプリとし、外部依存は持たない。選択・プレビュー・並べ替え・
ファイル操作の判断はすべて AppKit 非依存のライブラリ `MediaViewerCore` に置き、Swift Testing で検証する。
UI の `MediaViewerApp` は、`NSSplitViewController` の上に NSOutlineView / NSTableView / NSCollectionView /
AVPlayerView を配置して Core の状態を描画するだけにする。デコードは ImageIO でスクリーンサイズに
ダウンサンプリングし、前後1件を先読みして、上限付きのキャッシュに置く（詳細は [research.md](./research.md)）。

## Technical Context

**Language/Version**: Swift 6（strict concurrency、開発機のツールチェーンは 6.3.3）

**Primary Dependencies**: Apple 標準フレームワークのみ（AppKit, AVKit/AVFoundation, ImageIO,
QuickLookThumbnailing, UniformTypeIdentifiers, CoreServices[FSEvents]）。サードパーティ依存なし

**Storage**: `UserDefaults`（表示設定・動作オプション）と、`NSSplitView` の自動保存（ペイン幅）。
サムネイルとデコード済み画像はメモリ上のみに置く

**Testing**: Swift Testing（`swift test`）。単体・異常系の `MediaViewerCoreTests` と、性能計測の
`MediaViewerPerformanceTests`。フィクスチャはテスト実行時に生成する

**Target Platform**: macOS 15 以降（Apple Silicon / Intel）。非サンドボックス、ad-hoc 署名

**Project Type**: desktop-app（Swift Package: ライブラリ + 実行ターゲット）

**Performance Goals**: 画像の選択から表示まで 0.5 秒以内（24MP JPEG）、先読み済みの隣接ファイルへの
切替 0.1 秒以内、起動からリスト表示まで 2 秒以内、10,000 ファイルのフォルダの最初の表示 1 秒以内、
動画の再生開始まで 1 秒以内。サムネイルサイズやペイン幅の変更にはドラッグ中も途切れずに追従する

**Constraints**: オフラインで完結し外部通信をしない。UI スレッドでデコード・列挙・ファイル操作をしない。
デコード済みプレビューのキャッシュは 256MB、サムネイルは 128MB を上限とする。ファイルリストに横スクロールを出さない

**Scale/Scope**: 1ウィンドウ（3ペイン）+ 設定ウィンドウ + 確認・衝突ダイアログ。フォルダあたり最大で
数万ファイルを想定。単一ユーザー

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

憲章 v1.1.0 に対する評価。

| 原則 | 判定 | 根拠 |
|------|------|------|
| I. ローカル完結・プライバシー | ✅ 適合 | ネットワークを使う API も依存もない。サムネイルはメモリにのみ置き、ユーザーのフォルダにもディスクキャッシュにも書かない（R7）。ファイル操作はすべてユーザーの明示的な操作が起点になる。確認を省略できるのは、削除が常にゴミ箱経由で取り消せるため（v1.1.0 の「確認または取り消し可能性」、FR-021・024）。取り消せない上書きは常に衝突ダイアログで確認する（FR-025） |
| II. 体感パフォーマンス | ✅ 適合 | デコード・列挙・サムネイル生成・ファイル操作はすべてバックグラウンドで行う（R5・R7・R9・R10）。キャッシュの上限を明示した（R8）。基準値は `MediaViewerPerformanceTests` で計測する（quickstart）。注: 憲章の基準「起動からファイル指定で開いた最初の画像の表示 1 秒以内」は、ファイルを指定して起動する経路を前提にしている。この経路は本機能の範囲外なので、代わりに SC-002（前回フォルダの一覧表示まで 2 秒）を計測する。ファイル指定起動を追加する機能で 1 秒基準を適用する |
| III. キーボードファースト & a11y | ✅ 適合 | 全操作のキー割り当てを [contracts/keyboard-and-menus.md](./contracts/keyboard-and-menus.md) で網羅した。AppKit 標準部品の a11y を使い、プレビューとサムネイルのセルにはファイル名のラベルを付ける。ダークモードは AppKit 標準の配色で追従し、「視差効果を減らす」設定が有効な間は、アニメーション画像を自動で再生しない |
| IV. テスト必須 | ✅ 適合 | 判断ロジックをすべて `MediaViewerCore` に置き、UI から分離した（[contracts/core-api.md](./contracts/core-api.md)）。破損・非対応・巨大・権限なしのフィクスチャを自動生成してテストする |
| V. シンプルさ（YAGNI） | ✅ 適合 | 外部依存ゼロ。UI フレームワークは AppKit に統一し、SwiftUI と混在させない。ディスクキャッシュ・Undo・プラグインは作らない。ターゲットは Core / App / テスト2つ / フィクスチャ生成の最小構成 |

**Phase 1 設計後の再評価**: data-model・contracts・quickstart を確認したが、新たな違反はない。
FSEvents による監視（R9）は外部依存ではなく、OS 標準 API の利用にあたる。

## Project Structure

### Documentation (this feature)

```text
specs/001-three-pane-media-viewer/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── core-api.md
│   ├── keyboard-and-menus.md
│   └── settings.md
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
Package.swift
Sources/
├── MediaViewerCore/                 # AppKit 非依存。すべての判断ロジック
│   ├── Model/                       # MediaKind, MediaFile, FolderNode, SortOrder, SelectionState,
│   │                                #   PreviewContent, ViewSettings, PlaybackOptions, FileOperation
│   ├── Browser/                     # BrowserModel（選択・プレビュー・先読みの調停）
│   ├── FileSystem/                  # DirectoryLister, VolumeProvider, FileSystemWatcher (FSEvents)
│   ├── Imaging/                     # ImageDecoder, DecodedImageCache, ThumbnailProvider
│   ├── Layout/                      # FitCalculator, ThumbnailGridLayout
│   ├── Operations/                  # FileOperationService, NameValidation, uniqueName
│   └── Settings/                    # SettingsStore
├── MediaViewerApp/                  # AppKit UI。Core の状態を描画するだけ
│   ├── App/                         # main.swift, AppDelegate, MainMenu, MainWindowController,
│   │                                #   MainSplitViewController（フルスクリーン切替を含む）
│   ├── Tree/                        # DirectoryTreeViewController (NSOutlineView、ドロップ先)
│   ├── FileList/                    # FileListViewController, ListModeView (NSTableView),
│   │                                #   ThumbnailModeView (NSCollectionView), FileContextMenu
│   ├── Preview/                     # PreviewViewController, ImagePreviewView, VideoPreviewView
│   ├── Operations/                  # ConfirmationPresenter, ConflictPrompt
│   └── Settings/                    # SettingsWindowController
└── FixtureKit/                      # テスト・手動検証用のフィクスチャ生成（画像・動画・破損ファイル）
    └── make-fixtures/               # 実行ターゲット（scripts/make-fixtures.sh から呼ぶ）

Tests/
├── MediaViewerCoreTests/            # 単体・異常系
└── MediaViewerPerformanceTests/     # 性能基準の計測

scripts/
├── make-app.sh                      # .app バンドルの組み立てと ad-hoc 署名
└── make-fixtures.sh                 # 手動検証用フォルダの生成
```

**Structure Decision**: 単一の Swift Package に、ライブラリ `MediaViewerCore`・実行ターゲット
`MediaViewerApp`・フィクスチャ生成用の `FixtureKit` とテストターゲット2つを置く。Core を AppKit から
切り離すことで、憲章 原則 IV の「コアロジックを UI から分離し、単体でテスト可能に保つ」を構造で担保する。
Xcode プロジェクトは持たず、CLI（`swift build` / `swift test` / `scripts/`）だけで完結させる（R2）。

## Complexity Tracking

Constitution Check に違反はないため、記載事項なし。
