---

description: "Task list for 3ペイン型メディアビューア"
---

# Tasks: 3ペイン型メディアビューア

**Input**: Design documents from `/specs/001-three-pane-media-viewer/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: 憲章 原則 IV（テスト必須）により、`MediaViewerCore` のコアロジックと異常系には自動テストを必ず付ける。
書く順序は問わない。各ストーリーでは実装タスクの直後にテストタスクを置く。UI の見た目の自動テストは作らず、
quickstart.md の手動シナリオで検証する。

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- Core（AppKit 非依存）: `Sources/MediaViewerCore/`
- UI（AppKit）: `Sources/MediaViewerApp/`
- フィクスチャ生成: `Sources/FixtureKit/`, `Sources/make-fixtures/`
- テスト: `Tests/MediaViewerCoreTests/`, `Tests/MediaViewerPerformanceTests/`
- 共通ルール: Swift 6 strict concurrency。Core から `import AppKit` しない。デコード・列挙・ファイル操作は
  UI スレッドで行わない（憲章 原則 II）。ネットワーク API（URLSession 等）は使わない（原則 I）

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Swift Package の骨組みと、ビルド・フィクスチャ生成のスクリプト

- [X] T001 `Package.swift` を作成する。内容は次のとおり:
  - `swift-tools-version: 6.0`、`platforms: [.macOS(.v15)]`、`swiftLanguageModes: [.v6]`
  - ターゲット: library `MediaViewerCore`、executable `MediaViewerApp`（依存: MediaViewerCore）、
    library `FixtureKit`（resources: `.process("Resources")`）、executable `make-fixtures`（依存: FixtureKit）
  - テストターゲット: `MediaViewerCoreTests`（依存: MediaViewerCore, FixtureKit）、
    `MediaViewerPerformanceTests`（依存: MediaViewerCore, FixtureKit）
  - 外部パッケージ依存は追加しない
- [X] T002 各ターゲットの最小のソースを置き、`swift build` と `swift test` が通る状態にする:
  `Sources/MediaViewerCore/MediaViewerCore.swift`（空の名前空間）、`Sources/FixtureKit/FixtureKit.swift`、
  `Sources/make-fixtures/main.swift`、`Tests/MediaViewerCoreTests/SmokeTests.swift`、
  `Tests/MediaViewerPerformanceTests/SmokeTests.swift`（Swift Testing の `@Test` を1件ずつ）
- [X] T003 `Sources/MediaViewerApp/App/main.swift` と `Sources/MediaViewerApp/App/AppDelegate.swift` を作成する。
  `NSApplication.shared` に `setActivationPolicy(.regular)` を設定し、AppDelegate を設定して `activate()` してから
  `run()` する。`swift run MediaViewerApp` で空のウインドウが前面に開くこと
- [X] T004 [P] リポジトリ直下に `.gitignore` を作成する（`.build/`, `.swiftpm/`, `*.xcodeproj/`, `DerivedData/`, `.DS_Store`）
- [X] T005 [P] `scripts/make-app.sh` を作成する。処理は次のとおり:
  - `swift build -c release --product MediaViewerApp` を実行する
  - `.build/MediaViewer.app/Contents/MacOS/MediaViewer` にバイナリを置く
  - `Contents/Info.plist` を生成する（CFBundleIdentifier=`local.my-img-viewer.MediaViewer`、
    CFBundleName=`MediaViewer`、LSMinimumSystemVersion=`15.0`、NSHighResolutionCapable=true、
    NSPrincipalClass=`NSApplication`）
  - `codesign --force --sign - .build/MediaViewer.app` で ad-hoc 署名する
  - 実行権限を付け、`set -euo pipefail` とする
- [X] T006 [P] `Sources/FixtureKit/ImageFixtures.swift` に、ImageIO（`CGImageDestination`）で画像のフィクスチャを
  書き出す関数を実装する:
  - `jpeg(at:width:height:)` と `png(at:width:height:)`
  - `animatedGIF(at:frames:)`
  - `grayscalePNG(at:width:height:)`（1億画素級の巨大画像用。8bit グレースケールでメモリを抑える）
- [X] T007 [P] WebP のフィクスチャを用意する:
  - `Sources/FixtureKit/WebPFixtures.swift` で、`CGImageDestinationCopyTypeIdentifiers()` に
    `org.webmproject.webp` が含まれていれば ImageIO で書き出す
  - 含まれなければ、バンドル済みの `Sources/FixtureKit/Resources/static.webp` / `animated.webp` をコピーする
  - 2ファイルは、`scripts/make-webp-fixtures.sh`（Homebrew の `webp` パッケージの `cwebp` / `img2webp` を使う、
    開発時に1回だけ実行する）で生成してコミットする。各 10KB 以下とする
- [X] T008 [P] `Sources/FixtureKit/VideoFixtures.swift` に、`AVAssetWriter`（H.264）で単色フレームの短い動画を
  書き出す関数を実装する: `mp4(at:width:height:seconds:)`、`mov(at:width:height:seconds:)`
- [X] T009 `Sources/FixtureKit/FixtureSets.swift` に、quickstart.md「検証用フォルダの準備」の5セットを生成する
  関数を実装する（T006〜T008 に依存）:
  - `mixed`: JPEG・PNG・アニメーション GIF・静止 WebP・アニメーション WebP・mp4・mov・`.txt`・`.pdf`・
    サブフォルダ `sub/`・隠しファイル `.hidden.jpg`
  - `broken`: 先頭 100 バイトだけの JPEG、中身が PNG の `fake.jpg`、0 バイトの `empty.mp4`
  - `huge(count:)`: 8×8 の JPEG を `img_00001.jpg` から連番で生成する。既定は 10,000 件
  - `bigImage`: 10000×10000 のグレースケール PNG
  - `ops`: 名前が `a.jpg`・`b.png`・`c 2.jpg` の画像と、空のサブフォルダ `dest/`
- [X] T010 `Sources/make-fixtures/main.swift` で第1引数のディレクトリに5セットすべてを生成し、
  `scripts/make-fixtures.sh` から `swift run make-fixtures "$1"` で呼び出す

**Checkpoint**: `swift build` / `swift test` が通り、`scripts/make-fixtures.sh ~/MediaViewerFixtures` でフィクスチャができる

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 全ストーリーが依存するモデル・設定・並べ替え・3ペインのウインドウ

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T011 [P] `Sources/MediaViewerCore/Model/MediaKind.swift` に `MediaKind` を実装する:
  - ケースと拡張子の対応: `jpeg`(jpg, jpeg)、`png`、`gif`、`webp`、`mp4`、`mov`
  - `init?(fileExtension:)` は「大文字小文字を区別しない」。表以外の拡張子では `nil` を返す
  - `isVideo` プロパティを持ち、型は `Sendable` とする
- [X] T012 [P] `Sources/MediaViewerCore/Model/MediaFile.swift` に `MediaFile` を実装する:
  - フィールド: `url`, `name`, `kind`, `typeDescription`, `creationDate: Date?`, `fileSize: Int64`
  - `url` を同一性のキーとして `Identifiable` / `Hashable` に準拠させ、`Sendable` とする
- [X] T013 [P] `Sources/MediaViewerCore/Model/FolderNode.swift` に `FolderNode` を実装する。
  フィールドは `url`, `name`, `kind`(`.home`/`.volume`/`.folder`), `children: [FolderNode]?`
  （`nil` は未読み込み）, `accessState`(`.unknown`/`.accessible`/`.denied`)
- [X] T014 [P] `Sources/MediaViewerCore/Model/BrowserState.swift` を実装する:
  - `FolderListing`: `folder`, `files`, `state`(`.loading`/`.loaded`/`.empty`/`.denied`/`.failed(String)`)
  - `SelectionState`: `selected: Set<URL>`, `focused: URL?`
  - `PreviewContent`: `.empty`, `.loading(URL)`, `.image(DecodedImage)`, `.animatedImage(URL)`, `.video(URL)`,
    `.unavailable(name: String, reason: String)`
  - `FocusDirection`: `.previous` / `.next`
- [X] T015 [P] `Sources/MediaViewerCore/Model/Settings.swift` に、data-model.md の表どおりの既定値で設定型を実装する:
  - `DisplayMode`(`.list`/`.thumbnails`)
  - `SortOrder`: `column` は `.name`/`.creationDate`/`.kind`、`ascending`。既定は名前の昇順
  - `ViewSettings`: `displayMode` 既定 `.list`、`thumbnailSize` 既定 128（「48〜512 の範囲に丸める」）、
    `sortOrder`、`lastFolder: URL?`
  - `PlaybackOptions`: `autoplay` 既定 true、`loop` 既定 true
  - `ConfirmationOptions`: `confirmBeforeFileOperations` 既定 true
- [X] T016 `Sources/MediaViewerCore/Settings/SettingsStore.swift` に `SettingsStore(defaults: UserDefaults)` を実装する
  （T015 に依存）:
  - キー名は contracts/settings.md の表のとおり（`view.displayMode`, `view.thumbnailSize`, `view.sort.column`,
    `view.sort.ascending`, `view.lastFolderPath`, `playback.autoplay`, `playback.loop`, `fileOps.confirmBeforeExecuting`）
  - 型や範囲が不正な値は既定値に戻す
  - `viewSettings` / `playback` / `confirmation` を読み書きできるようにする
- [X] T017 `Sources/MediaViewerCore/Model/Sorting.swift` に `sorted(_:by:)` を実装する:
  - 名前の比較は `localizedStandardCompare`（Finder と同じ自然順）で行う
  - 作成日の比較では `nil` を最後に置く。種類は `typeDescription` で比較する
  - 同じ値が並んだ場合は、名前の自然順を第2キーにする
- [X] T018 [P] `Tests/MediaViewerCoreTests/MediaKindTests.swift` に `MediaKind` のテストを書く:
  6形式の全拡張子を大文字・小文字・混在で判定できること、`txt`/`pdf`/`heic`/空文字で `nil` になること
- [X] T019 [P] `Tests/MediaViewerCoreTests/SettingsStoreTests.swift` に `SettingsStore` のテストを書く:
  - テストごとに専用のスイート名で `UserDefaults` を作り、終了時に削除する
  - 既定値、保存した値の往復、`thumbnailSize` の 10→48 / 900→512 の丸め、不正な文字列が既定値に戻ることを確認する
- [X] T020 [P] `Tests/MediaViewerCoreTests/SortingTests.swift` に `sorted(_:by:)` のテストを書く:
  `img2` < `img10` の自然順、昇順・降順、作成日が `nil` の項目の位置、同じ値のときの第2キー
- [X] T021 `Sources/MediaViewerApp/App/MainSplitViewController.swift` を作成する:
  - `NSSplitViewController` に縦3ペインの `NSSplitViewItem` を置く。中身はこの時点では空のプレースホルダ
  - 分割は `splitView.isVertical = true`（左右に並ぶ）とする
  - 初期幅は 220 / 360 / 残り、最小幅は「最小幅 160 / 240 / 320 pt」とする
  - ウインドウの幅を変えたときにプレビューペインが伸び縮みするよう、プレビューの `holdingPriority` を最も低くする
  - `splitView.autosaveName = "MainSplit"` を設定する
- [X] T022 `Sources/MediaViewerApp/App/MainWindowController.swift` を作成し、AppDelegate から開く:
  - タイトルは `MediaViewer` とし、中身に `MainSplitViewController` を置く
  - `minSize` は最小幅の合計（720pt）+ 仕切りの幅以上とし、ウインドウの位置と大きさは自動保存する
- [X] T023 `Sources/MediaViewerApp/App/MainMenu.swift` を作成する:
  - contracts/keyboard-and-menus.md「メニューバー」の骨組み（アプリ名 / ファイル / 編集 / 表示）を組み、
    `NSApp.mainMenu` に設定する
  - 項目はこの時点では「設定…（⌘,）」「終了（⌘Q）」と標準の編集項目のみ。各ストーリーで追加する

**Checkpoint**: 3ペインの空ウインドウが開き、仕切りをドラッグできて、再起動後も幅が戻る。Core の基礎テストが通る

---

## Phase 3: User Story 1 - フォルダを辿って画像をプレビューする (Priority: P1) 🎯 MVP

**Goal**: ツリーでフォルダを選ぶと対応メディアのみがリストに並び、選んだ画像がプレビューにフィット表示される

**Independent Test**: quickstart.md「US1」の手順。`mixed/` で非対応ファイル・サブフォルダ・隠しファイルが出ず、
↓ キーでプレビューが追従し、小さな画像が拡大されず、GIF が動き、WebP が動くか静止画で出る

### Core（US1）

- [X] T024 [P] [US1] `Sources/MediaViewerCore/FileSystem/DirectoryLister.swift` に `DirectoryListing` プロトコルと、
  その実装 `DirectoryLister` を作る:
  - `mediaFiles(in:)`: `contentsOfDirectory(at:includingPropertiesForKeys:[.creationDateKey, .isDirectoryKey,
    .contentTypeKey, .fileSizeKey, .localizedTypeDescriptionKey], options: .skipsHiddenFiles)` で列挙し、
    `MediaKind` が `nil` のものとフォルダを除く
  - `subfolders(of:)`: フォルダのみを返す（隠しフォルダとパッケージ `.isPackageKey` は除く）。名前の自然順に並べる
  - 権限なしは `ListingError.accessDenied`、存在しない場合は `.notFound` を投げる（typed throws）
- [X] T025 [P] [US1] `Sources/MediaViewerCore/FileSystem/VolumeProvider.swift` に `VolumeProviding` の実装を作る:
  - `rootNodes()` はホームフォルダ（`kind: .home`）と、`mountedVolumeURLs(includingResourceValuesForKeys:
    [.volumeLocalizedNameKey], options: .skipHiddenVolumes)` のボリューム（`kind: .volume`）を返す
  - `changes` は `NSWorkspace.didMountNotification` / `didUnmountNotification` を `AsyncStream` で流す。
    `NSWorkspace` は AppKit なので、通知の購読部分は `MediaViewerApp` 側から注入する
- [X] T026 [P] [US1] `Sources/MediaViewerCore/Imaging/ImageDecoder.swift` に `ImageDecoding` の実装を作る:
  - `decode(_:maxPixelSize:)` は `CGImageSourceCreateThumbnailAtIndex` に
    `kCGImageSourceCreateThumbnailFromImageAlways`, `kCGImageSourceThumbnailMaxPixelSize`,
    `kCGImageSourceCreateThumbnailWithTransform` を渡してデコードする
  - 結果は `DecodedImage`（`cgImage`, `pixelSize`, `originalPixelSize`, `byteCost`）で返す
  - `isAnimated(_:)` はフレーム数が2以上なら true を返す
  - 読めない場合は `DecodeError.unreadable`、壊れている場合は `.corrupted`、形式未対応の場合は `.unsupported` を投げる
- [X] T027 [P] [US1] `Sources/MediaViewerCore/Imaging/DecodedImageCache.swift` に `actor DecodedImageCache` を実装する:
  - `costLimitBytes`（既定 256MB = `256 * 1024 * 1024`）を上限とする LRU で、超えたら古い順に捨てる
  - API は `get(_ url:)` / `put(_ image:for:)` / `removeAll()` / `totalCost`
  - 上限値は `Sources/MediaViewerCore/Imaging/MemoryLimits.swift` に定数として一元化する（サムネイル 128MB も同じ場所）
- [X] T028 [P] [US1] `Sources/MediaViewerCore/Layout/FitCalculator.swift` に `FitCalculator.fit(imageSize:in:)` を実装する。
  縦横比を保ってコンテナ内で最大になる、中央寄せの矩形を返す。ただし「原寸より大きくはしない」（FR-028）
- [X] T029 [US1] `Sources/MediaViewerCore/Browser/BrowserModel.swift` に、`@MainActor @Observable final class BrowserModel` を
  実装する（T024・T026・T027 に依存）:
  - 依存（`DirectoryListing`, `ImageDecoding`, `DecodedImageCache`, `SettingsStore`）はイニシャライザで注入する
  - `selectFolder(_:)`: 実行中の読み込み `Task` を取り消し、`listing.state = .loading` にしてから
    `mediaFiles(in:)` → `sorted(by: sortOrder)` → `.loaded`、0件なら `.empty`、`accessDenied` なら `.denied` にする。
    `lastFolder` を保存する
  - `select(_:focused:)`: `selection` を更新し、`focused` のプレビューを読み込む。画像の場合は
    キャッシュ → `decode(maxPixelSize: screenMaxPixel)` の順に取得し、アニメーションなら `.animatedImage(URL)`、
    動画なら `.video(URL)`、デコード失敗なら `.unavailable(name:reason:)` にする
  - `moveFocus(_:)`: リスト順で前後の項目にフォーカスを移す
  - 先読み: フォーカスが変わるたびに、前後1件をバックグラウンドでデコードしてキャッシュに入れる
  - `screenMaxPixel` は UI から設定する（スクリーンの長辺ピクセル数）
- [X] T030 [P] [US1] `Tests/MediaViewerCoreTests/DirectoryListerTests.swift` に `DirectoryLister` のテストを書く:
  - FixtureKit の `mixed` を一時ディレクトリに生成し、対応形式7件だけが返ることを確認する（`.txt`/`.pdf`/`sub/`/`.hidden.jpg` は除外）
  - `subfolders` が `sub/` だけを返すこと
  - `chmod 000` にしたフォルダで `.accessDenied` になること（テスト後に権限を戻す）
  - 存在しないパスで `.notFound` になること
- [X] T031 [P] [US1] `Tests/MediaViewerCoreTests/ImageDecoderTests.swift` に `ImageDecoder` のテストを書く:
  - 4000×3000 の JPEG を `maxPixelSize: 1000` でデコードし、長辺が 1000 以下になること
  - アニメーション GIF で `isAnimated` が true、静止 PNG で false になること
  - `broken` の3件（先頭だけの JPEG・中身が PNG の .jpg・0 バイト）でクラッシュせず、エラーを投げるか正しくデコードできること
- [X] T032 [P] [US1] `Tests/MediaViewerCoreTests/DecodedImageCacheTests.swift` に `DecodedImageCache` のテストを書く:
  上限を超えたときに最も古いものが捨てられること、`get` で順位が更新されること、`totalCost` が上限を超えないこと
- [X] T033 [P] [US1] `Tests/MediaViewerCoreTests/FitCalculatorTests.swift` に `FitCalculator` のテストを書く:
  横長・縦長の画像の縮小、コンテナより小さい画像が原寸のまま中央に置かれること、幅または高さが 0 のときの扱い
- [X] T034 [US1] `Tests/MediaViewerCoreTests/BrowserModelTests.swift` に `BrowserModel` のテストを書く。
  依存はフェイクに差し替える:
  - フォルダを素早く2回選んだとき、最後のフォルダの一覧だけが残ること
  - `.empty` / `.denied` への遷移
  - `moveFocus` の端での挙動
  - フォーカスの前後1件がキャッシュに入ること
  - デコード失敗時に `.unavailable` になること

### UI（US1）

- [X] T035 [US1] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` を作成する:
  - `NSOutlineView`（列1つ、ソースリスト風）で `VolumeProvider.rootNodes()` を表示する
  - 子は展開時に `subfolders(of:)` で遅延読み込みする（読み込み中はバックグラウンドで行う）
  - `.denied` のノードは灰色にし、ツールチップを「アクセスできません」とする
  - 選択変更時に `BrowserModel.selectFolder` を呼ぶ
  - 起動時は `lastFolder`（存在しなければホーム）まで展開して選択する
  - キー操作は contracts の「ディレクトリツリー」の表のとおり（←→ と ⌥←→ は NSOutlineView 標準の動作を使う）
  - ボリュームのマウントと取り外しをルートに反映する
- [X] T036 [US1] `Sources/MediaViewerApp/FileList/FileListViewController.swift` を作成する:
  - 中身の表示形式（この時点ではリストのみ）を切り替える器にする
  - `listing.state` が `.empty` なら「対応するメディアファイルがありません」、`.denied` なら「アクセスできません」、
    `.loading` なら進捗表示を中央に出す
- [X] T037 [US1] `Sources/MediaViewerApp/FileList/ListModeView.swift` を作成する:
  - `NSTableView` に列「名前」「作成日」「種類」を置く。作成日は `DateFormatter` の medium/short 形式で、`nil` なら「--」
  - 行の選択を `BrowserModel.select` に伝え、↑↓ の選択移動でプレビューを追従させる
  - 複数選択（クリック・⌘クリック・⇧クリック・⇧矢印・⌘A）を許可する
  - 10,000 行でも滑らかにスクロールできるよう、セルは再利用する
- [X] T038 [US1] `Sources/MediaViewerApp/Preview/ImagePreviewView.swift` を作成する:
  - 静止画は `CALayer.contents` に `cgImage` を設定し、`FitCalculator` で求めた矩形に配置する。
    `layout()` のたびに再計算する
  - `.animatedImage(URL)` は `CGAnimateImageAtURLWithBlock` で再生する。エラーが返るか、1フレームしか届かなければ、
    先頭フレームの静止画にする。独自のフレーム送りは作らない（FR-030）
  - `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` が true の間は、アニメーションを再生せず先頭フレームを出す
  - `.unavailable` はファイル名と「表示できません」と理由を中央に表示する
  - ビューの a11y ラベルはファイル名とする
- [X] T039 [US1] `Sources/MediaViewerApp/Preview/PreviewViewController.swift` を作成する:
  - `BrowserModel.preview` の変化を監視し、`.empty` / `.loading` / `.image` / `.animatedImage` / `.unavailable` に
    応じて `ImagePreviewView` を更新する。`.video` は US2 で対応する
  - 表示先スクリーンの長辺ピクセル数を `BrowserModel.screenMaxPixel` に設定する
- [X] T040 [US1] `Sources/MediaViewerApp/App/MainSplitViewController.swift` で、3ペインのプレースホルダを
  T035・T036・T039 に差し替える:
  - `BrowserModel` を1つ生成して3者に注入する
  - Tab / ⇧Tab のフォーカス移動を `nextKeyView` の連鎖で「ツリー → リスト → プレビュー」の順に設定する
  - 表示メニューに ⌥⌘1 / ⌥⌘2 / ⌥⌘3（各ペインへフォーカス）を追加する（FR-040）

**Checkpoint**: MVP。quickstart.md の US1 と「キーボードだけで操作する」の前半が通る

---

## Phase 4: User Story 2 - 動画をプレビューで再生する (Priority: P2)

**Goal**: mp4 / mov が既定で自動ループ再生され、設定で自動再生・ループを個別にオフにできる

**Independent Test**: quickstart.md「US2」の手順（自動ループ、自動再生オフ、ループオフ、別ファイル選択で停止）

- [X] T041 [US2] `Sources/MediaViewerCore/Browser/BrowserModel.swift` に動画の制御を追加する:
  - `focused` が動画なら `.video(URL)` にする
  - 再生の指示 `playbackRequest`（`autoplay`, `loop`）を `SettingsStore.playback` から公開する
  - フォーカスが変わったら、新しい状態にする前に `stopPlaybackSignal` を発行する（FR-034）
- [X] T042 [US2] `Tests/MediaViewerCoreTests/BrowserModelVideoTests.swift` に動画制御のテストを書く:
  - 動画を選んだときに `.video` と、設定どおりの `autoplay` / `loop` が出ること
  - 動画から画像へフォーカスを移したときに停止の合図が先に出ること
- [X] T043 [US2] `Sources/MediaViewerApp/Preview/VideoPreviewView.swift` を作成する:
  - `AVPlayerView`（`controlsStyle = .inline`、`showsFullScreenToggleButton = false`）に `AVQueuePlayer` を接続する
  - `loop` が true なら `AVPlayerLooper` を使い、false なら1回だけ再生して終端で止める
  - `autoplay` が false なら先頭フレームで停止して表示する
  - 停止の合図を受けたら `pause()` し、looper とアイテムを解放して音声も止める
  - a11y ラベルはファイル名とする
- [X] T044 [US2] `Sources/MediaViewerApp/Preview/PreviewViewController.swift` で `.video` のときに `VideoPreviewView` を表示し、
  他の状態では外すよう切り替える
- [X] T045 [US2] `Sources/MediaViewerApp/FileList/ListModeView.swift` で、フォーカス中の項目が動画のときに Space キーで
  再生 / 一時停止を切り替える（`PreviewViewController` に転送する）
- [X] T046 [US2] `Sources/MediaViewerApp/Settings/SettingsWindowController.swift` を作成し、⌘, で開く:
  - 「動画」区分にチェックボックス「動画を自動再生する」（`playback.autoplay`）と
    「動画をループ再生する」（`playback.loop`）を置く
  - 変更は即座に `SettingsStore` に保存し、次に選択する動画から反映する。再起動は不要

**Checkpoint**: US1 + US2。quickstart.md の US2 が通る

---

## Phase 5: User Story 3 - リスト形式とサムネイル形式を切り替えて一覧する (Priority: P2)

**Goal**: 列による並べ替え、サムネイル形式への切替、サムネイルサイズの連続変更。どの幅でも横スクロールを出さない

**Independent Test**: quickstart.md「US3」の手順（切替で選択を維持、作成日の昇順・降順、スライダーとペイン幅で
折り返し、再起動で復元）

- [X] T047 [P] [US3] `Sources/MediaViewerCore/Imaging/ThumbnailProvider.swift` に `ThumbnailProviding` の実装を作る:
  - 生成には `QLThumbnailGenerator` を使う。要求サイズは「128 / 256 / 512 の段階に丸める」（`pointSize × scale` 以上で
    最小の段階、512 で頭打ち）
  - 結果は `NSCache`（`totalCostLimit` は MemoryLimits のサムネイル用 128MB）にのみ保存し、ディスクには書かない
  - `cancel(for:)` で、生成中の要求を取り消せるようにする
- [X] T048 [P] [US3] `Sources/MediaViewerCore/Layout/ThumbnailGridLayout.swift` に `ThumbnailGridLayout.columns(availableWidth:thumbnailSize:spacing:)` を実装する:
  - 列数は `max(1, floor((availableWidth + spacing) / (thumbnailSize + spacing)))` とする
  - セル幅は「利用可能な幅を超えない」（FR-015）。1列でも収まらない場合は、セル幅を `availableWidth` に縮める
- [X] T049 [P] [US3] `Tests/MediaViewerCoreTests/ThumbnailGridLayoutTests.swift` に `ThumbnailGridLayout` のテストを書く:
  - 幅 0〜2000 とサイズ 48〜512 の組み合わせを総当たりし、`count * cellWidth + (count-1) * spacing <= availableWidth` を検証する
- [X] T050 [P] [US3] `Tests/MediaViewerCoreTests/ThumbnailProviderTests.swift` に `ThumbnailProvider` のテストを書く:
  - 段階への丸め（例: 100pt×2 → 256、300pt×2 → 512）
  - `mixed` の JPEG と mp4 でサムネイルが返ること
  - `broken` のファイルで `nil` が返り、クラッシュしないこと
- [X] T051 [US3] `Sources/MediaViewerApp/FileList/ListModeView.swift` の各列に `sortDescriptorPrototype` を設定する:
  - 見出しのクリックで `BrowserModel.sortOrder` を更新し、並べ替え直す（同じ列の2回目のクリックで降順）
  - 並び順を `SettingsStore` に保存する
  - 表示メニューの「並べ替え（名前・作成日・種類）」と連動させる
- [X] T052 [US3] `Sources/MediaViewerApp/FileList/ThumbnailModeView.swift` を作成する:
  - `NSCollectionView` に縦スクロールの `NSCollectionViewFlowLayout` を設定し、セルの寸法は
    `ThumbnailGridLayout` で決める。`viewDidLayout` と、サイズ変更のたびに `invalidateLayout()` する
  - 横スクロールバーは `hasHorizontalScroller = false` で常に非表示にする
  - セルはサムネイルとファイル名（2行で省略）を表示する。生成中はファイルの種類のアイコンを代わりに出す
  - セルが見えなくなったら `cancel(for:)` で生成を取り消す。prefetch delegate で先行生成する
  - 選択を `BrowserModel.select` に伝え、↑↓←→ で選択を移動する
  - セルの a11y ラベルはファイル名とする
- [X] T053 [US3] `Sources/MediaViewerApp/FileList/FileListViewController.swift` に表示形式の切替とサイズ調整を追加する:
  - 下部のバーにサムネイルサイズのスライダー（48〜512、連続値）を置き、⌘+ / ⌘- で 16pt ずつ変える
  - ⌘1 でサムネイル形式、⌘2 でリスト形式に切り替える
  - 切り替えても `BrowserModel.selection` を維持し、選択項目が見える位置までスクロールする
  - 表示形式とサムネイルサイズを `SettingsStore` に保存し、起動時に復元する
  - 表示メニューに対応する項目を追加する

**Checkpoint**: US1〜US3。quickstart.md の US3 が通る

---

## Phase 6: User Story 4 - Finder と同じ感覚でファイルを整理する (Priority: P3)

**Goal**: コピー・名前の変更・ゴミ箱・移動を、右クリックメニュー・ショートカット・ドラッグ&ドロップで実行できる。
確認は設定で4操作まとめて省略でき、同名の衝突は常に確認する

**Independent Test**: quickstart.md「US4」の手順を `ops/` で行う

### Core（US4）

- [X] T054 [P] [US4] `Sources/MediaViewerCore/Model/FileOperation.swift` を実装する:
  - `FileOperation`: `kind` は `.copy`/`.move`/`.rename(newName)`/`.trash`、`sources: [URL]`、`destination: URL?`
  - `ConflictResolution`: `.replace`/`.keepBoth`/`.abort`
  - `FileOperationResult`: `succeeded: [URL]`、`failed: [(URL, reason: String)]`
- [X] T055 [P] [US4] `Sources/MediaViewerCore/Operations/NameValidation.swift` に2つの関数を実装する:
  - `validateNewName(_:for:existingNames:)`: 「空の名前、`/` または `:` を含む名前、先頭が `.` の名前、
    既存の名前（大文字小文字の違いのみも含む）は拒否する」。拡張子が変わる場合は `.needsExtensionChangeConfirmation` を返す
  - `uniqueName(for:existingNames:)`: `a.jpg` → `a 2.jpg` → `a 3.jpg`。`c 2.jpg` が既にあれば `c 3.jpg` にする
    （末尾の「 数字」を連番として扱う）
- [X] T056 [US4] `Sources/MediaViewerCore/Operations/FileOperationService.swift` に `FileOperating` の実装を作る（T054・T055 に依存）:
  - `conflicts(for:)`: copy / move の操作先にある同名のファイルを返す
  - `execute(_:resolution:)` はバックグラウンドで実行する。処理は次のとおり:
    - コピーは `copyItem`、移動は `moveItem`、名前の変更は同じフォルダ内の `moveItem`、ゴミ箱は `trashItem(at:resultingItemURL:)` で行う
    - `.keepBoth` では `uniqueName` で採番する。`.replace` では既存のファイルを先にゴミ箱へ入れてから置く
    - 移動先が元のフォルダと同じなら何もしない。フォルダを自分自身やその配下へ移動しようとした場合は失敗として返す
    - 1件の失敗で残りを止めない。途中まで書かれたコピー先は削除する（各ファイルは「全部成功」か「変更なし」のどちらか）
- [X] T057 [P] [US4] `Tests/MediaViewerCoreTests/NameValidationTests.swift` に `NameValidation` のテストを書く:
  拒否される名前（空・`a/b`・`a:b`・`.hidden`・`A.JPG` が `a.jpg` と衝突）、拡張子変更の確認、`uniqueName` の連番
- [X] T058 [US4] `Tests/MediaViewerCoreTests/FileOperationServiceTests.swift` に `FileOperationService` のテストを書く。
  `ops` フィクスチャを一時ディレクトリに作って次を確認する:
  - copy / move / rename / trash の結果（trash はゴミ箱内の URL が返り、元の場所から消えること）
  - 衝突時の `.replace` / `.keepBoth` / `.abort`
  - 書き込み不可のフォルダ（`chmod 555`）で失敗理由が返り、元のファイルが変わらないこと
  - 同じフォルダへの移動で何もしないこと

### UI（US4）

- [X] T059 [US4] `Sources/MediaViewerApp/Operations/ConfirmationPresenter.swift` を作成する:
  - `confirmBeforeFileOperations` が true のときだけ `NSAlert` のシートを出す。内容は操作名、件数、先頭最大5件の名前、操作先
  - 既定ボタンは「実行」とし、Esc で「キャンセル」にする
  - `suppressionButton`（「今後この確認を表示しない」）がオンなら設定を false に保存する
  - キャンセルした場合は何も実行しない
- [X] T060 [US4] `Sources/MediaViewerApp/Operations/ConflictPrompt.swift` を作成する:
  - 設定に関わらず、衝突があれば `NSAlert` で「置き換える / 両方残す / 中止」を出す
  - 「残りすべてに適用」のチェックボックスを置く
- [X] T061 [US4] `Sources/MediaViewerApp/Operations/FileOperationCoordinator.swift` を作成する:
  - 流れは 確認（T059）→ 衝突判定 → 衝突の選択（T060）→ `execute` → 結果表示（失敗があれば、対象の名前と理由を一覧で示す
    `NSAlert`）とする
  - 完了後は、対象のフォルダが表示中なら `BrowserModel` に一覧を読み直させる（FR-027）
  - 名前の変更は `validateNewName` の結果に応じて、エラー表示か拡張子変更の確認を挟む
- [X] T062 [US4] `Sources/MediaViewerApp/FileList/FileContextMenu.swift` を作成する:
  - contracts の「右クリックメニュー（ファイルリスト）」の11項目を、その順序と名前で作る
    （「開く」は `NSWorkspace.open`、「Finder に表示」は `activateFileViewerSelecting`）
  - リスト形式とサムネイル形式の両方に設定する
- [X] T063 [US4] `Sources/MediaViewerApp/FileList/FileListViewController.swift` にクリップボード操作を実装する:
  - ⌘C: 選択中のファイル URL を `NSPasteboard.general` に書く
  - ⌘V / ⌥⌘V: 表示中のフォルダへコピー / 移動する
  - ⌘D: 同じフォルダへの複製（`.copy` + `.keepBoth`）
  - ⌘Delete: ゴミ箱へ入れる
  - 処理は T061 経由で実行する。編集メニューとファイルメニューに項目を追加する
- [X] T064 [US4] 名前の変更をその場で編集できるようにする:
  - `Sources/MediaViewerApp/FileList/ListModeView.swift` の名前セルと、`ThumbnailModeView.swift` のセルの名前ラベルを
    Return で編集可能にする
  - 初期選択は拡張子を除いた部分とする
  - Return で確定して T061 に渡し、Esc で取り消して元の名前に戻す
- [X] T065 [US4] ドラッグ&ドロップを実装する:
  - `ListModeView.swift` と `ThumbnailModeView.swift` をドラッグ元にし、ファイル URL を pasteboard に載せる
  - `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` をドロップ先にし、フォルダノード上だけで受け付ける
  - ⌥ が押されていれば `.copy`、なければ `.move` として T061 に渡す。ドラッグ中のカーソル表示もこれに合わせる
  - ツリーの右クリックメニュー「ここにペースト / ここに移動ペースト / Finder に表示」と、⌘V / ⌥⌘V も追加する
- [X] T066 [US4] `Sources/MediaViewerApp/Settings/SettingsWindowController.swift` に「ファイル操作」区分を追加する。
  チェックボックス「コピー・移動・名前の変更・ゴミ箱に入れる前に確認する」（`fileOps.confirmBeforeExecuting`）を置く。
  T046 がない場合はここで設定ウインドウを新規作成する

**Checkpoint**: US1〜US4。quickstart.md の US4（確認オン・オフの両方）が通る

---

## Phase 7: User Story 5 - プレビューをフルスクリーンで見る (Priority: P3)

**Goal**: 画像はダブルクリック、画像・動画とも ⌃⌘F・表示メニュー・Esc・緑ボタンで全画面の切替・解除ができる。
動画の再生状態とペイン幅は保たれる

**Independent Test**: quickstart.md「US5」の手順

- [X] T067 [US5] `Sources/MediaViewerApp/App/MainSplitViewController.swift` に `togglePreviewFullScreen()` を実装する:
  - 入るとき: ツリーとリストの `NSSplitViewItem.isCollapsed = true` にしてから、`window.toggleFullScreen(nil)` を呼ぶ
  - 解除: `windowDidExitFullScreen` で折りたたみを戻す
  - 緑ボタンで入った場合（`windowWillEnterFullScreen` で、自分からの要求でない場合）も同じ状態として扱う
  - 解除後はペイン幅と選択がフルスクリーン前と同じであること
  - プレビューのビューは付け替えない（動画の再生を保つ: FR-037）
- [X] T068 [US5] `Sources/MediaViewerApp/App/MainMenu.swift` の表示メニューに「フルスクリーン」（⌃⌘F）を追加して
  T067 に接続する。`MainWindowController` で `cancelOperation(_:)`（Esc）を受け、フルスクリーン中なら解除する
- [X] T069 [US5] `Sources/MediaViewerApp/Preview/ImagePreviewView.swift` に `NSClickGestureRecognizer`
  （`numberOfClicksRequired = 2`）を付け、T067 を呼ぶ。`VideoPreviewView` には付けない（FR-035）

**Checkpoint**: US1〜US5。quickstart.md の US5 が通る

---

## Phase 8: User Story 6 - ペインの幅を調整する (Priority: P3)

**Goal**: 仕切りのドラッグで幅を変えられ、最小幅で止まり、再起動後に戻る。ウインドウのリサイズでプレビューが再フィットする

**Independent Test**: quickstart.md「US6」の手順と、US3 手順 4 のペイン幅の復元

- [X] T070 [US6] `Sources/MediaViewerApp/App/MainSplitViewController.swift` で、ペイン幅の挙動を仕上げる:
  - 最小幅「160 / 240 / 320 pt」を `NSSplitViewItem.minimumThickness` で守り、どのペインも消えないようにする
    （実装注記: `NSSplitViewController` は Auto Layout 使用時に `constrainMinCoordinate` / `constrainMaxCoordinate`
    の override と非互換で起動時に例外になるため、AppKit 推奨の minimumThickness で実現した。折りたたみはフルスクリーン時のみ許可）
  - 仕切りをダブルクリックしてもペインが折りたたまれないようにする（通常時は `canCollapse = false`、
    フルスクリーン時だけ true に切り替える）
- [X] T071 [US6] `Sources/MediaViewerApp/Preview/ImagePreviewView.swift` と `ThumbnailModeView.swift` で、ペインの幅や
  ウインドウの大きさを変えている間も、レイアウトの再計算だけで追従させる（再デコードしない）。
  `inLiveResize` 中もサムネイルを再要求しない

**Checkpoint**: 全ユーザーストーリーが独立して動作する

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: 外部の変更の反映（FR-042）、性能の計測（原則 II）、a11y と憲章への適合の確認

- [X] T072 [P] `Sources/MediaViewerCore/FileSystem/FileSystemWatcher.swift` に `FileSystemWatching` の FSEvents 実装を作る:
  - `FSEventStreamCreate` に `kFSEventStreamCreateFlagFileEvents` と `kFSEventStreamCreateFlagUseCFTypes` を渡す
  - `watch(_:)` で監視対象が変わったらストリームを作り直す
  - 発生したパスの親フォルダが監視対象に含まれるものだけを、0.3 秒のデバウンスで `events` に流す
- [X] T073 `Sources/MediaViewerCore/Browser/BrowserModel.swift` に `handleFileSystemEvent(_:)` を実装する（T072 に依存）:
  - 表示中のフォルダが含まれていれば一覧を読み直し、選択を保つ。消えたファイルは選択から外す
  - `focused` が消えたらプレビューを `.empty` にする
  - 表示中のフォルダ自体が消えた場合は親フォルダを選択する
- [X] T074 `Tests/MediaViewerCoreTests/FileSystemWatcherTests.swift` に、外部変更の反映のテストを書く:
  - 一時フォルダを監視し、ファイルの追加・削除・名前変更で 2 秒以内にイベントが届くこと
  - それを受けた `BrowserModel` の一覧・選択・プレビューが更新されること
- [X] T075 `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` で、展開中のノードと表示中のフォルダを
  `FileSystemWatcher.watch` に渡し、イベントで該当ノードの子を読み直す
- [X] T076 [P] `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift` に、quickstart.md「性能の検証」の
  基準値を計測するテストを書く。基準値を超えたら失敗させる:
  - 24MP JPEG のデコード（スクリーン長辺 5120px）が 0.5 秒以内
  - キャッシュ済みの隣接ファイルへの切替（`BrowserModel.moveFocus` からプレビュー確定まで）が 0.1 秒以内
  - `huge(count: 10_000)` の `mediaFiles(in:)` と並べ替えが 1 秒以内
  - 1億画素の PNG のデコードが完了し、`DecodedImage.byteCost` がスクリーンサイズ相当であること
  - 連続 100 回のフォーカス移動の後も `DecodedImageCache.totalCost` が 256MB 以下であること
- [X] T077 起動から前回フォルダの一覧表示までの時間（SC-002: 2 秒以内）と、動画の再生開始までの時間
  （SC-010: 1 秒以内）を、`os_signpost` で計測できるようにする:
  - signpost は `Sources/MediaViewerApp/App/AppDelegate.swift` と `Sources/MediaViewerApp/Preview/VideoPreviewView.swift` に入れる
  - 計測手順を quickstart.md「性能の検証」に追記する
- [X] T078 [P] 憲章 原則 I の確認として、`Sources/` 内に `URLSession`・`Network`・`NWConnection`・`http` の参照がないことを
  `scripts/check-no-network.sh`（grep。見つかれば終了コード 1）で確認できるようにし、実行する
- [ ] T079 Accessibility Inspector で、3ペイン・サムネイルのセル・プレビュー・設定ウインドウ・確認ダイアログのラベルを確認する。
  不足があれば各ビューで `setAccessibilityLabel` を補う（原則 III）
- [ ] T080 `scripts/make-app.sh` で `.app` を作り、quickstart.md の手動シナリオ（US1〜US6、キーボードだけの操作、異常系）を
  すべて実施して、結果を `specs/001-three-pane-media-viewer/checklists/validation.md` に記録する

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 依存なし。T009 は T006〜T008 に、T010 は T009 に依存する
- **Foundational (Phase 2)**: Setup の完了後に始める。全ストーリーを止める
- **US1 (Phase 3)**: Foundational の完了後に始める。MVP
- **US2・US3・US4 (Phase 4〜6)**: US1 の UI（プレビュー・リスト・ツリーの器）に機能を足すため、US1 の完了後に始める。
  この3つは互いに独立していて、どの順でも並行でも進められる
- **US5 (Phase 7)**: US1 の後に始められる。動画の再生状態の維持を確認するには US2 が必要
- **US6 (Phase 8)**: Foundational の T021 があれば始められる。T071 は US1・US3 のビューに依存する
- **Polish (Phase 9)**: 対象のストーリーが揃ってから行う。T072〜T075 は US1 の後ならいつでもよい

### User Story Dependencies

- **US1 (P1)**: Foundational のみに依存する
- **US2 (P2)**: US1 の `PreviewViewController` と `BrowserModel` に依存する
- **US3 (P2)**: US1 の `FileListViewController` / `ListModeView` に依存する
- **US4 (P3)**: US1 のリストとツリーに依存する。T064・T065 のサムネイル側は、US3 があれば対応する
- **US5 (P3)**: US1 に依存する
- **US6 (P3)**: Foundational に依存する

### Within Each User Story

- Core のモデル → Core のサービス → Core のテスト → UI → 結線の順に進める
- ストーリーごとに `swift test` を通してからチェックポイントで手動確認する

### Parallel Opportunities

- Setup: T004・T005・T006・T007・T008 は並行できる
- Foundational: T011〜T015 のモデルと、T018〜T020 のテストは並行できる
- US1: T024〜T028（Core の各サービス）と T030〜T033（そのテスト）は並行できる
- US3: T047〜T050 は並行できる
- US4: T054・T055・T057 は並行できる
- US1 の完了後、US2・US3・US4 はファイルが重ならない範囲で並行できる。ただし `ListModeView.swift` と
  `FileListViewController.swift` は US2・US3・US4 が共有するので、同時に編集しない

---

## Parallel Example: User Story 1

```bash
# Core の独立したサービスを同時に進める:
Task: "T024 DirectoryLister in Sources/MediaViewerCore/FileSystem/DirectoryLister.swift"
Task: "T026 ImageDecoder in Sources/MediaViewerCore/Imaging/ImageDecoder.swift"
Task: "T027 DecodedImageCache in Sources/MediaViewerCore/Imaging/DecodedImageCache.swift"
Task: "T028 FitCalculator in Sources/MediaViewerCore/Layout/FitCalculator.swift"

# 続いてテストを同時に進める:
Task: "T030 DirectoryListerTests"
Task: "T031 ImageDecoderTests"
Task: "T032 DecodedImageCacheTests"
Task: "T033 FitCalculatorTests"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1（Setup）と Phase 2（Foundational）を完了する
2. Phase 3（US1）を完了する
3. **STOP and VALIDATE**: `swift test` と、quickstart.md の US1 の手順を実施する
4. `scripts/make-app.sh` で `.app` を作って日常的に使い始める

### Incremental Delivery

1. Setup + Foundational → 3ペインの空ウインドウ
2. US1 → フォルダを辿って画像を見られる（MVP）
3. US2 → 動画の再生
4. US3 → サムネイル形式と並べ替え
5. US4 → ファイル整理
6. US5・US6 → フルスクリーンとペイン幅の仕上げ
7. Polish → 外部変更の反映、性能計測、a11y、全シナリオの検証

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- 性能に影響する変更の PR には、T076・T077 の計測結果を記載する（憲章 原則 II）
- 新しい操作を追加したら、contracts/keyboard-and-menus.md の表も更新する（憲章 原則 III）
- Commit after each task or logical group
