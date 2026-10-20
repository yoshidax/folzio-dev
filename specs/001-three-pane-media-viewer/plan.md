# Implementation Plan: 3ペイン型メディアビューア

**Branch**: `001-three-pane-media-viewer` | **Date**: 2026-10-20 (fullscreen arrow navigation, small-image upscale, tree/list icons, thumbnail scroll follow; original 2026-10-19) | **Spec**: [spec.md](./spec.md)

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
プレビューの画像は、縦横比を保ってペイン内の最大サイズにフィットさせる。ペインより小さい画像も
拡大率の上限なしで拡大し、フルスクリーンでも同じ規則を使う（FR-028、R5）。動画の表示サイズは
この規則の対象外とする。アプリバンドルには、3ペインをモチーフにした自前生成のアイコンを同梱する
（FR-043〜045、R14）。サムネイル形式では、矢印キーでフォーカスをビューポート外へ移したときに、
フォーカス項目全体が見える位置まで必要最小限のスクロールで追従する（FR-017、R15）。
フルスクリーン中も矢印キーでファイルリストの選択を移動し、プレビューを追従させる（FR-046、R16）。
移動規則は通常表示と共通の純粋計算に置き、リスト形式は上下、サムネイル形式は上下左右とする。
動画のフルスクリーンでは矢印キーをファイル移動に使い、シークは `<` / `>` キーに割り当てる。
ツリーのフォルダ名とリスト形式のファイル名の先頭にはアイコンを表示する（FR-047・048）。
ツリーはホーム・マウント中のボリューム・通常フォルダを SF Symbols で区別し、リスト形式は
`ThumbnailProviding` を小さなサイズで再利用して内容の縮小画像を出し、生成中・失敗時は
形式別の SF Symbol にフォールバックする。

## Technical Context

**Language/Version**: Swift 6（strict concurrency、開発機のツールチェーンは 6.3.3）

**Primary Dependencies**: Apple 標準フレームワークのみ（AppKit, AVKit/AVFoundation, ImageIO,
QuickLookThumbnailing, UniformTypeIdentifiers, CoreServices[FSEvents], CoreGraphics[アイコン生成]）。
サードパーティ依存なし

**Storage**: `UserDefaults`（表示設定・動作オプション）と、`NSSplitView` の自動保存（ペイン幅）。
サムネイルとデコード済み画像はメモリ上のみに置く

**Packaging**: `scripts/make-app.sh` が `scripts/make-icon.sh` を呼び、実行ターゲット `make-icon` が
1024px の設計座標から各解像度を描画して `.build/AppIcon.iconset` を作る。`iconutil` で
`.build/AppIcon.icns` にまとめ、`Contents/Resources/AppIcon.icns` として同梱する。
`Info.plist` の `CFBundleIconFile` は `AppIcon`。アイコンはコードから生成し、外部素材を置かない

**Testing**: Swift Testing（`swift test`）。単体・異常系の `MediaViewerCoreTests` と、性能計測の
`MediaViewerPerformanceTests`。フィクスチャはテスト実行時に生成する

**Target Platform**: macOS 15 以降（Apple Silicon / Intel）。非サンドボックス、ad-hoc 署名

**Project Type**: desktop-app（Swift Package: ライブラリ + 実行ターゲット）

**Performance Goals**: 画像の選択から表示まで 0.5 秒以内（24MP JPEG）、先読み済みの隣接ファイルへの
切替 0.1 秒以内、起動からリスト表示まで 2 秒以内、10,000 ファイルのフォルダの最初の表示 1 秒以内、
動画の再生開始まで 1 秒以内。サムネイルサイズやペイン幅の変更にはドラッグ中も途切れずに追従する。
小さい画像の拡大はレイヤー（GPU）のフレーム変更だけで行い、追加のデコード・再描画を伴わない

**Constraints**: オフラインで完結し外部通信をしない。UI スレッドでデコード・列挙・ファイル操作をしない。
デコード済みプレビューのキャッシュは 256MB、サムネイルは 128MB を上限とする。ファイルリストに横スクロールを出さない。
デコードはスクリーンの長辺ピクセルを上限にするため、表示先はそれを超えず、ペインのリサイズやフルスクリーン切替で
再デコードは不要。小さい画像はデコード済みの原寸を保ち、表示時にレイヤーで拡大する（R5）。
サムネイル形式のキーボード移動では、フォーカス項目全体が見える最小限の縦スクロールだけを行い、
横スクロールは発生させない（FR-015・017）。サムネイルサイズやペイン幅の変更時は追従しない。
フルスクリーン中の矢印移動では、折りたたみ前のサムネイル列数をスナップショットして使い、解除後に
必要なら同じスクロール追従でフォーカス項目を表示する（FR-046）。新しい永続化状態は増やさない。
ツリーとリストの行頭アイコンは表示時にだけ生成し、永続化しない。リストの縮小画像は可視行だけを
対象に非同期で取得し、セル再利用時は同じ URL・同じ要求サイズの取得だけを取り消す
（サムネイル形式の 128px 以上の要求を巻き込まない）。アイコン取得の完了を待たずにファイル名・
選択・スクロールを操作できる（FR-048、SC-012）。

**Scale/Scope**: 1ウィンドウ（3ペイン）+ 設定ウィンドウ + 確認・衝突ダイアログ。フォルダあたり最大で
数万ファイルを想定。単一ユーザー

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

憲章 v1.1.0 に対する評価。

| 原則 | 判定 | 根拠 |
|------|------|------|
| I. ローカル完結・プライバシー | ✅ 適合 | ネットワークを使う API も依存もない。サムネイルはメモリにのみ置き、ユーザーのフォルダにもディスクキャッシュにも書かない（R7）。アプリアイコンも外部素材を取得せず、コードから生成する（R14）。ファイル操作はすべてユーザーの明示的な操作が起点になる。確認を省略できるのは、削除が常にゴミ箱経由で取り消せるため（v1.1.0 の「確認または取り消し可能性」、FR-021・024）。取り消せない上書きは常に衝突ダイアログで確認する（FR-025） |
| II. 体感パフォーマンス | ✅ 適合 | デコード・列挙・サムネイル生成・ファイル操作はすべてバックグラウンドで行う（R5・R7・R9・R10）。キャッシュの上限を明示した（R8）。基準値は `MediaViewerPerformanceTests` で計測する（quickstart）。小さい画像の拡大はレイヤーのフレーム変更だけで行い、デコードや再描画を増やさない（R5）。リスト形式の行頭アイコンもサムネイル生成を可視行だけ遅延実行し、セル再利用時は同じ URL・サイズの要求だけを取り消すため、10,000 ファイルでも一覧表示を待たせない（R17）。注: 憲章の基準「起動からファイル指定で開いた最初の画像の表示 1 秒以内」は、ファイルを指定して起動する経路を前提にしている。この経路は本機能の範囲外なので、代わりに SC-002（前回フォルダの一覧表示まで 2 秒）を計測する。ファイル指定起動を追加する機能で 1 秒基準を適用する。アイコン生成はビルド時のみで、起動時間に影響しない |
| III. キーボードファースト & a11y | ✅ 適合 | 提供する全操作のキー割り当てを [contracts/keyboard-and-menus.md](./contracts/keyboard-and-menus.md) で網羅した。手動の拡大/縮小（ズーム）とパンは提供せず、フィットは画像選択時に自動で行うため、これらへのキー割り当ては存在しない（spec Assumptions）。AppKit 標準部品の a11y を使い、プレビューとサムネイルのセルにはファイル名のラベルを付ける。行頭アイコンは装飾として a11y 要素から外し、フォルダ名・ファイル名と選択状態は従来どおり読み上げられる（FR-047・048）。ダークモードは AppKit 標準の配色で追従し、「視差効果を減らす」設定が有効な間は、アニメーション画像を自動で再生しない。サムネイル形式でもキーボードだけで一覧を辿れるよう、フォーカス項目のスクロール追従を必須にする（FR-017）。フルスクリーン中も矢印キーで選択を移動でき（FR-046）、動画のシークは `<` / `>` に残すため、フルスクリーンでも主要操作をキーボードだけで完結できる |
| IV. テスト必須 | ✅ 適合 | 判断ロジックをすべて `MediaViewerCore` に置き、UI から分離した（[contracts/core-api.md](./contracts/core-api.md)）。破損・非対応・巨大・権限なしのフィクスチャを自動生成してテストする。フィット計算は拡大（縦横比・中央寄せ・1×1 などの極小サイズ）を含めて `FitCalculatorTests` で検証する。スクロール追従の最小移動量は純粋計算として Core に置き、`ThumbnailScrollTests` で「画面外の項目へ移動したときの計算」という不具合条件を検証する。キー入力からクリップビュー更新までの UI 配線は自動テストの対象外とし、T093 の手動再現で担保する。フルスクリーンの移動規則は `FocusNavigator` として Core に置き、リスト形式・サムネイル形式・フルスクリーンの全経路で同じ関数を使う。境界（先頭・末尾・行頭・行末）と空リストのケースを `FocusNavigatorTests` で検証する。行頭アイコンは小さな要求サイズの丸め（64px 段階）を `ThumbnailProviderTests` で検証し、表示とフォールバックは quickstart の手動確認で担保する。憲章 原則 IV は UI の見た目そのものの自動テストを必須としないため、この分担でテスト要件を満たす。アイコンはビルド生成物のため、解像度セットを `scripts/make-icon.sh` が検証し、表示は quickstart の手動確認で担保する |
| V. シンプルさ（YAGNI） | ✅ 適合 | 外部依存ゼロ。UI フレームワークは AppKit に統一し、SwiftUI と混在させない。ディスクキャッシュ・Undo・プラグインは作らない。ターゲットは Core / App / テスト2つ / フィクスチャ生成 / アイコン生成の最小構成。アイコン生成はビルド時専用で、実行時の抽象化や設定項目を増やさない。ツリーとリストの行頭アイコンは SF Symbols と既存のサムネイル経路を使い、新しい設定・永続化・外部素材を追加しない（R17）。フルスクリーン移動（FR-046）は既存の選択モデルとレイアウト計算を再利用し、新しい設定・永続化状態・依存を追加しない |

**Phase 1 設計後の再評価**: data-model・contracts・quickstart を確認したが、新たな違反はない。
FSEvents による監視（R9）は外部依存ではなく、OS 標準 API の利用にあたる。アイコン生成（R14）は
ビルド時のコード生成で、外部素材・追加依存・起動時コストを増やさない。
FR-028 の拡大フィット（2026-10-20）は `FitCalculator` の上限撤廃とテストの追加だけで成立し、
新しい依存・設定項目・永続化状態を増やさない（原則 V）。拡大はレイヤーのフレーム変更で行うため、
UI スレッドのデコードや再描画を追加しない（原則 II）。
FR-017 のスクロール追従（2026-10-20）は、既存の選択・レイアウト結果から縦オフセットを求める純粋計算と、
クリップビューの原点更新だけで成立する。計算は Core のテストで不具合条件を再現し、UI 配線は
quickstart の手動再現で確認する（原則 IV）。新しい依存・設定項目・永続化状態を増やさず（原則 V）、
キーボードだけで一覧を辿れる操作性を回復する（原則 III）。
FR-046 のフルスクリーン移動（2026-10-20）は、折りたたみ前に取得した表示形式とサムネイル列数、
および現在の選択インデックスだけから移動先を求める。新しい状態を永続化せず、依存も増やさない（原則 V）。
移動規則は Core の純粋計算に集約し、UI はキーイベントの振り分けと `BrowserModel.select` の呼び出しだけを
担う（原則 IV）。動画のシークは `<` / `>` に残すため、フルスクリーンでもキーボードだけで操作できる（原則 III）。
FR-047・048 の行頭アイコン（2026-10-20）は、ツリーの `FolderNode.Kind` と `MediaKind` から
SF Symbols を選ぶだけの UI 表現で、Core の判断ロジックを増やさない（原則 V）。リストの縮小画像は
既存の `ThumbnailProviding` を 64px 段階で再利用し、可視行だけを非同期に取得する（原則 II）。
キャンセルは URL と要求サイズの組で行い、リストの 64px 要求がサムネイル形式の 128px 以上の要求を
取り消さない（FR-013 の回帰防止）。新しい永続化・設定・外部素材は増やさず、アイコンは装飾として
a11y ツリーから外すため、ファイル名の読み上げを妨げない（原則 III）。

## Project Structure

### Documentation (this feature)

```text
specs/001-three-pane-media-viewer/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── app-bundle.md
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
│   ├── Layout/                      # FitCalculator, ThumbnailGridLayout, ThumbnailScroll, FocusNavigator
│   ├── Operations/                  # FileOperationService, NameValidation, uniqueName
│   └── Settings/                    # SettingsStore
├── MediaViewerApp/                  # AppKit UI。Core の状態を描画するだけ
│   ├── App/                         # main.swift, AppDelegate, MainMenu, MainWindowController,
│   │                                #   MainSplitViewController（フルスクリーン切替を含む）
│   ├── Shared/                      # IconCatalog（ツリー・リストの行頭アイコンの SF Symbol と寸法）
│   ├── Tree/                        # DirectoryTreeViewController (NSOutlineView、ドロップ先)
│   ├── FileList/                    # FileListViewController, ListModeView (NSTableView),
│   │                                #   ThumbnailModeView (NSCollectionView), FileContextMenu
│   ├── Preview/                     # PreviewViewController, ImagePreviewView, VideoPreviewView
│   ├── Operations/                  # ConfirmationPresenter, ConflictPrompt
│   └── Settings/                    # SettingsWindowController
├── FixtureKit/                      # テスト・手動検証用のフィクスチャ生成（画像・動画・破損ファイル）
├── make-fixtures/                   # 実行ターゲット（scripts/make-fixtures.sh から呼ぶ）
└── make-icon/                       # ビルド時のみ。CoreGraphics でアプリアイコンの各解像度を描画する

Tests/
├── MediaViewerCoreTests/            # 単体・異常系
└── MediaViewerPerformanceTests/     # 性能基準の計測

scripts/
├── make-app.sh                      # .app バンドルの組み立てと ad-hoc 署名
├── make-icon.sh                     # iconset の生成・解像度検証・icns 化
└── make-fixtures.sh                 # 手動検証用フォルダの生成
```

**Structure Decision**: 単一の Swift Package に、ライブラリ `MediaViewerCore`・実行ターゲット
`MediaViewerApp`・フィクスチャ生成用の `FixtureKit`・アイコン生成用の `make-icon` とテストターゲット2つを置く。
Core を AppKit から切り離すことで、憲章 原則 IV の「コアロジックを UI から分離し、単体でテスト可能に保つ」を
構造で担保する。`make-icon` はビルド時専用のツールで、実行時コードには含めない。
Xcode プロジェクトは持たず、CLI（`swift build` / `swift test` / `scripts/`）だけで完結させる（R2）。

## 変更点（2026-10-20: 小さい画像の拡大）

- `Sources/MediaViewerCore/Layout/FitCalculator.swift`: スケールの上限 `1` を外し、コンテナより
  小さい画像も拡大する。中央寄せ・縦横比維持・0 以下で `.zero` の扱いは変えない
- `Tests/MediaViewerCoreTests/FitCalculatorTests.swift`: 拡大の期待値に更新し、横長・縦長の拡大、
  極小（1×1）画像、中央寄せ、不正サイズのケースを追加する
- `Sources/MediaViewerApp/Preview/ImagePreviewView.swift`: コード変更は不要（`FitCalculator` の結果に
  レイヤーのフレームを合わせる既存の経路がそのまま拡大になる）。フルスクリーンも同じビューを通る
- 動画（`VideoPreviewView` / `AVPlayerView`）とデコード（`ImageDecoder`）は変更しない
- `README.md` の「小さい画像は原寸を超えて拡大しない」という記述を新しい挙動に合わせて直す

## 変更点（2026-10-20: サムネイル形式のキーボード追従スクロール）

- `Sources/MediaViewerCore/Layout/ThumbnailScroll.swift`（新規）: アイテム矩形と可視矩形から、
  アイテム全体が見える最小の縦スクロール位置を返す純粋計算を置く。既に見えていれば現在位置を返し、
  コンテンツ範囲 `0...(contentHeight - visibleHeight)` にクランプする。ビューポートより高いアイテムは
  上端を合わせる。横方向の値は扱わない（FR-015）
- `Tests/MediaViewerCoreTests/ThumbnailScrollTests.swift`（新規）: 下方向・上方向・一部見えている場合・
  既に見えている場合・先頭/末尾でのクランプ・ビューポートより高いアイテム・不正な寸法を検証する。
  画面外の項目へ移動したときの計算という不具合条件を再現するケースを含める（UI 配線は T093 で手動確認する）
- `Sources/MediaViewerApp/FileList/ThumbnailModeView.swift`: 矢印キーと Shift+矢印の移動後、
  および `scrollToFocused()` から共通の「フォーカス項目を表示」処理を呼ぶ。レイアウト済みの
  `layoutAttributesForItem(at:)` のフレームと `scrollView.contentView.bounds` から Core の計算で
  目標原点を求め、クリップビューを即時にスクロールする（アニメーションなし）。
  `layoutAttributesForItem(at:)` が nil の場合は、`ThumbnailGridLayout` とコンテンツ高から対象行の
  Y 範囲を推定する。推定も不能な場合のみ `NSCollectionView.scrollToItems(at:scrollPosition:)` を
  最終フォールバックにし、FR-017 が無言で満たされない状態を残さない。
  名前変更開始時のスクロールも同じ処理に統一する。リスト形式（`ListModeView`）は変更しない
- `specs/001-three-pane-media-viewer/contracts/keyboard-and-menus.md`: ファイルリストの矢印キーの行に、
  サムネイル形式の最小スクロール追従を追記する
- `specs/001-three-pane-media-viewer/contracts/core-api.md`: `ThumbnailScroll` の境界を追記する
- `specs/001-three-pane-media-viewer/quickstart.md`: 多数ファイルのサムネイル形式で、上下左右・
  Shift+矢印の移動にスクロールが追従する手動確認を追加する
- `Sources/MediaViewerApp/FileList/ListModeView.swift` と表示設定・永続化は変更しない

## 変更点（2026-10-20: フルスクリーン中の矢印キーによるファイル移動）

- `Sources/MediaViewerCore/Layout/FocusNavigator.swift`（新規）: 現在インデックス・件数・移動方向・
  レイアウト（リスト / サムネイルの列数）から移動先インデックスを返す純粋計算。リストは上/下を ∓1、
  左/右は移動なし。サムネイルは左/右を ±1、上/下を ∓列数。`0...(count-1)` にクランプし、端では
  `nil` を返す。空リスト、現在位置なし（先頭を選ぶ）、列数 0（1 として扱う）も定義する
- `Tests/MediaViewerCoreTests/FocusNavigatorTests.swift`（新規）: リスト・グリッドの4方向、先頭/末尾、
  行頭/行末、最終行の短い行、空リスト、列数不正を検証する
- `Sources/MediaViewerApp/FileList/ThumbnailModeView.swift`: `handleArrowKey` のインデックス計算を
  `FocusNavigator` に置き換える（既存の Shift+矢印の範囲選択とスクロール追従は維持）。移動先が `nil`
  のときは選択を変えずにキーを消費し、OS の既定動作へ渡さない。折りたたみ前の列数を取得できるよう、
  現在の列数を公開する
- `Sources/MediaViewerApp/FileList/FileListViewController.swift`: フルスクリーン開始時に表示形式と
  列数をスナップショットする `beginFullScreenNavigation()`、矢印移動をモデルへ反映する
  `moveFocusInFullScreen(_:)`、解除後に `scrollToFocused()` を呼ぶ `endFullScreenNavigation()` を追加する。
  フルスクリーン中の移動は単一選択にし、`BrowserModel.select([url], focused: url)` を使う
- `Sources/MediaViewerApp/App/MainSplitViewController.swift`: ペイン折りたたみ前にスナップショットを取得する。
  フルスクリーン中だけローカルの keyDown モニタを登録し、修飾キーなしの矢印を
  `moveFocusInFullScreen` へ、`<` / `>` を動画シークへ振り分ける。Cmd/Option/Control 付きのキー、
  Esc、Space は横取りしない。解除時（`windowDidExitFullScreen`）にモニタを外し、ペイン復元後に
  フォーカス項目が見える位置へそろえる
- `Sources/MediaViewerApp/Preview/PreviewViewController.swift` と `VideoPreviewView.swift`: `<` / `>`
  用に、現在位置から一定秒（5 秒）戻す / 送るシークを追加する。再生状態は変えない。
  動画以外では何もしない
- 通常表示のリスト形式・サムネイル形式のキー操作、選択状態、スクロール追従は変更しない。
  Shift+矢印による範囲選択はフルスクリーンでは対象外（spec の Outstanding）とし、イベントを横取りしない
- `specs/001-three-pane-media-viewer/contracts/keyboard-and-menus.md`、
  `contracts/core-api.md`、`data-model.md`、`quickstart.md`、`research.md` を更新する

## 変更点（2026-10-20: ツリーとリスト形式の行頭アイコン）

- `Sources/MediaViewerApp/Shared/IconCatalog.swift`（新規）: SF Symbols の選択と構成を一箇所に置く。
  - ツリー: `.home` → `house`、`.volume` → `externaldrive`、`.folder` → `folder`。展開状態では変えない
  - リストのフォールバック: `.jpeg` → `photo`、`.png` → `photo.on.rectangle`、`.gif` → `photo.stack`、
    `.webp` → `photo.circle`、`.mp4` → `film`、`.mov` → `video`。生成中・取得失敗時に使う
  - アイコンは template 画像として `NSImage.SymbolConfiguration` で 13〜16pt に構成し、
    選択・ダークモードの配色に追従させる。装飾なので a11y 要素にはしない
- `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift`: フォルダ列のセルを
  `imageView` + `textField` の `NSTableCellView` にし、`FolderNode.Kind` に応じたアイコンを設定する。
  テキストはアイコンの右に置き、既存のアクセス不可表示・選択・展開操作は変えない
- `Sources/MediaViewerApp/FileList/ListModeView.swift`: コンストラクタに `ThumbnailProviding` を追加。
  名前列のセルだけ `imageView` を持たせ、`representedObject` に URL を保持する。行の表示時に
  まず形式別フォールバックを設定し、`thumbnail(for:pointSize: 16, scale:)` を非同期に要求して
  取得後に同じ URL のセルへだけ差し替える。セル再利用時は
  `cancel(for:pointSize:scale:)` で同じ 64px 要求だけを取り消し、128px 以上のサムネイル形式の
  要求を巻き込まない。名前のインライン編集時もアイコンは残し、テキストの制約だけをアイコンの右側へ移す。
  行の高さはアイコンが収まる 20pt にする
- `Sources/MediaViewerCore/Imaging/ThumbnailProvider.swift`: 要求サイズの段階に 64px を追加し、
  `cancel(for:pointSize:scale:)` を URL + ピクセルサイズ単位のキャンセルに変更する
  （16pt × 2x = 32px を 64px に丸める）。既存の 128 / 256 / 512 の選択は変えない
- `Sources/MediaViewerApp/FileList/ThumbnailModeView.swift`: 進行中要求に `scale` を保持し、
  `cancel(for:pointSize:scale:)` へ移行する。要求サイズを変えたとき・セルを破棄したときに、
  同じ URL でも古いサイズの要求だけを取り消す
- `Tests/MediaViewerCoreTests/ThumbnailProviderTests.swift`: 50pt × 1x が 128 ではなく 64 になる
  期待値へ更新し、16pt × 1x / 2x、境界値、上限 512 のケースを追加する。URL + サイズ単位の
  キャンセルが他のサイズを巻き込まないことを、可能な範囲で再現する
- `Sources/MediaViewerApp/FileList/FileListViewController.swift`: 既存の `thumbnailProvider` を
  `ListModeView` へ渡す。表示形式の切替・フルスクリーン・ファイル操作の経路は変えない
- サムネイル形式（`ThumbnailModeView`）の表示、設定・永続化、Core の選択モデルは変更しない
- `specs/001-three-pane-media-viewer/contracts/core-api.md`、`data-model.md`、`research.md`、
  `quickstart.md` を更新する

## Complexity Tracking

Constitution Check に違反はないため、記載事項なし。
