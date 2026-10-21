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
  縦横比を保ってコンテナ内で最大になる、中央寄せの矩形を返す。ただし「原寸より大きくはしない」（FR-028）。
  この上限は 2026-10-20 の FR-028 改定により T086 が撤廃する
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
  （拡大のケースは 2026-10-20 の FR-028 改定により T087 が追加・置換する）
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
  （ファイルがなければ作成する）
  - SC-004: ペイン幅とサムネイルサイズをそれぞれ 3 秒以上ドラッグし、画面収録または Instruments で
    100ms 以上の表示停止が 0 回であることを確認する

---

## Phase 10: アプリアイコン（FR-043〜045、SC-011）

**Purpose**: 3ペインをモチーフにしたアイコンをコードから生成し、`.app` に同梱する。
外部素材・追加依存は使わない（[research.md](./research.md) R14、[contracts/app-bundle.md](./contracts/app-bundle.md)）。
実行時コードには含めないビルド時専用の作業。

- [X] T081 [P] `Package.swift` に、アイコン生成用の実行ターゲットとプロダクトを追加する:
  - `.executable(name: "make-icon", targets: ["make-icon"])`
  - `.executableTarget(name: "make-icon")`（依存なし。`MediaViewerCore` と `MediaViewerApp` には依存させない）
  - 外部パッケージ依存は追加しない
- [X] T082 `Sources/make-icon/main.swift` にアイコン描画を実装する（T081 に依存）:
  - 第1引数に出力先のステージングディレクトリ（`.build/AppIcon.raw`）を受け取り、存在しなければ作成する。
    引数がなければ終了コード 1
  - CoreGraphics のビットマップコンテキストと ImageIO（`CGImageDestination`、UTI は `public.png`）だけを使い、
    AppKit・外部画像・フォント・ネットワークを使わない
  - 1024×1024 の設計座標で描く: 中央に 824×824・角丸半径 185 のスクエア、上下左右 100px の余白。
    背景は濃紺の縦グラデーション。内側に左から「フォルダ」「サムネイルのグリッド」「大きな画像と再生マーク」を
    表す3つの縦ペインを、細い区切り線で分けて描く。文字は描かない
  - 16 / 32 / 64 / 128 / 256 / 512 / 1024 px を、それぞれ独立したコンテキストに設計座標を拡大して描画する
    （1024px からの縮小はしない）。線幅は各サイズで最低 1 デバイスピクセルを確保する
  - `icon_16x16.png`・`icon_32x32.png`・`icon_64x64.png`・`icon_128x128.png`・`icon_256x256.png`・
    `icon_512x512.png`・`icon_1024x1024.png` を出力する
  - 書き出しに失敗したら、作成途中のファイルを残さず終了コード 1 で終わる
- [X] T083 `scripts/make-icon.sh` を作成する（T081・T082 に依存）:
  - `set -euo pipefail` とし、リポジトリ直下から実行する
  - `swift build -c release --product make-icon` の後、`--show-bin-path` の `make-icon` を実行して
    `.build/AppIcon.raw` に7サイズを生成する
  - 空の `.build/AppIcon.iconset` を作り、ステージングから標準名の10ファイルをコピーする:
    `icon_16x16.png`(16)、`icon_16x16@2x.png`(32)、`icon_32x32.png`(32)、`icon_32x32@2x.png`(64)、
    `icon_128x128.png`(128)、`icon_128x128@2x.png`(256)、`icon_256x256.png`(256)、`icon_256x256@2x.png`(512)、
    `icon_512x512.png`(512)、`icon_512x512@2x.png`(1024)
  - iconset には標準名の10ファイルだけを置く（`icon_64x64.png` や `icon_1024x1024.png` を残さない）
  - 各ファイルを `sips -g pixelWidth -g pixelHeight` で検証し、契約の寸法と違えば終了コード 1
  - `iconutil -c icns .build/AppIcon.iconset -o .build/AppIcon.icns` で `.build/AppIcon.icns` を作る
- [X] T084 `scripts/make-app.sh` にアイコンの同梱を追加する（T083 に依存）:
  - `swift build` の後に `scripts/make-icon.sh` を呼ぶ
  - `Contents/Resources/` を作り、`.build/AppIcon.icns` を `Contents/Resources/AppIcon.icns` にコピーする
  - 生成した `Info.plist` に `CFBundleIconFile` = `AppIcon` を追加する
  - アイコン生成が失敗した場合は `.app` を残さず非ゼロで終了する（冒頭の `rm -rf` 後に途中成果物を残さない）
  - 既存の ad-hoc 署名と実行権限の処理は維持する
- [ ] T085 `scripts/make-app.sh` を実行し、quickstart.md「アプリアイコンの検証」を実施して
  `specs/001-three-pane-media-viewer/checklists/validation.md` に結果を追記する
  （ファイルがなければ作成する。T084 に依存）:
  - `Contents/Resources/AppIcon.icns` の存在と `plutil -extract CFBundleIconFile raw ...` が `AppIcon`
  - `iconutil -c iconset` で10スロットが展開でき、`icon_16x16.png` が 16×16、`icon_512x512@2x.png` が 1024×1024
  - `open` 後、Finder・Dock・⌘Tab・About に同じ3ペインのアイコンが出る。16px と 32px でも判別できる
  - システム外観をライトとダークに切り替え、どちらでも同じアイコンが表示される
  - `swift run` はバンドルを持たないため標準アイコンになることを確認し、合格扱いとする

---

## Phase 11: プレビューの拡大フィット（FR-028 改定、US1）

**Purpose**: ビューポートより小さい画像を、縦横比を保ったままペイン（フルスクリーンでは画面）に
収まる最大サイズまで拡大する。拡大率の上限は設けない（[plan.md](./plan.md) の「変更点」、
[research.md](./research.md) R5）。動画は対象外とし、従来の表示サイズを維持する。

**Independent Test**: 400×300 の PNG を選び、ペインを広げても縦横比を保ってはみ出さずに拡大されること、
8×8 の画像でもクラッシュしないこと、mp4 の表示サイズが変わらないことを確認する
（[quickstart.md](./quickstart.md)「プレビューのフィット（FR-028）」）。

- [X] T086 [P] [US1] `Sources/MediaViewerCore/Layout/FitCalculator.swift` の `fit(imageSize:in:)` から
  スケールの上限 `1` を外し、コンテナより小さい画像も拡大する（T028 の「原寸より大きくはしない」を置き換える）:
  - スケールは `min(container.width / imageSize.width, container.height / imageSize.height)`。上限を付けない
  - 返す矩形は `imageSize × スケール` をコンテナ中央に置いたもの。縦横比を保ち、トリミングしない
  - 幅・高さのいずれかが 0 以下の入力では `.zero` を返す（ゼロ除算を避ける）。既存の挙動を変えない
  - 契約は [contracts/core-api.md](./contracts/core-api.md) の `FitCalculator` に合わせる
- [X] T087 [US1] `Tests/MediaViewerCoreTests/FitCalculatorTests.swift` を新しい FR-028 に合わせて更新する
  （T033 の「原寸のまま」を置き換える。T086 の後に通る）:
  - 200×80 を 500×500 に入れると `CGRect(x: 0, y: 150, width: 500, height: 200)` に拡大される
  - 80×200 を 500×500 に入れると `CGRect(x: 150, y: 0, width: 200, height: 500)` に拡大される
  - 1×1 を 500×500 に入れると `CGRect(x: 0, y: 0, width: 500, height: 500)` になる（極小画像で破綻しない）
  - ちょうど収まる画像（500×250 を 500×500）は同じ大きさで中央に置かれる
  - 既存の縮小2ケースと、0 以下のサイズで `.zero` を返すケースは維持する
- [ ] T088 [US1] `scripts/make-app.sh` で `.build/MediaViewer.app` を作り、`specs/001-three-pane-media-viewer/quickstart.md`
  の「プレビューのフィット（FR-028）」を実施して `specs/001-three-pane-media-viewer/checklists/validation.md` に
  結果を追記する（ファイルがなければ作成する。T086・T087 に依存）:
  - 実施前に `swift build` / `swift test` / `scripts/check-no-network.sh` を通す
  - `mixed/02-image.png`（400×300）がペインに収まる最大サイズまで拡大され、はみ出さない
  - ウィンドウの最大化と復帰、ペイン幅のドラッグに追従し、縦横比が崩れない（SC-004 の停止 0 回も確認する）
  - 画像のダブルクリックでフルスクリーンにすると画面に収まる最大サイズまで拡大され、解除で元に戻る
  - `huge/` の 8×8 画像でもクラッシュしない
  - mp4 / mov の表示サイズが従来のままである
  - `Sources/MediaViewerApp/Preview/ImagePreviewView.swift` は変更不要の見込み。差異があれば
    レイヤーのフレーム計算だけを最小限修正する
- [X] T089 [P] [US1] `README.md` の「画像の縦横比を保ったフィット表示（小さい画像は原寸を超えて拡大しない）」を、
  ペインとフルスクリーンに収まる最大サイズまで拡大する記述に直す

## Phase 12: サムネイル形式のキーボード追従スクロール（FR-017 改定、US1）

**Purpose**: サムネイル形式で矢印キーによりフォーカスをビューポート外へ移したとき、フォーカス項目全体が
見える位置まで必要最小限のスクロールで追従させる（[plan.md](./plan.md) の「変更点」、
[research.md](./research.md) R15）。リスト形式は OS 標準の追従で既に動作するため変更しない。

**Independent Test**: `huge/` をサムネイル形式で開き、↓ キーを押し続けてフォーカスがビューポートの下端を
越えても、フォーカス項目全体が見えるようスクロールが追従すること。⇧+↓ では移動先のフォーカス項目に追従し、
↑ では上端でも同様に動くこと。サムネイルサイズ変更だけでは追従せず、リスト形式の挙動が変わらないことを
確認する（[quickstart.md](./quickstart.md)「サムネイル形式のキーボード追従スクロール（FR-017）」）。

- [X] T090 [P] [US1] `Sources/MediaViewerCore/Layout/ThumbnailScroll.swift` を新規作成し、
  `ThumbnailScroll.offsetY(itemMinY:itemMaxY:visibleMinY:visibleHeight:contentHeight:)` を実装する
  （契約は [contracts/core-api.md](./contracts/core-api.md) の `ThumbnailScroll`）:
  - 項目全体が見えている場合（`itemMinY >= visibleMinY` かつ
    `itemMaxY <= visibleMinY + visibleHeight`）は `visibleMinY` を返し、スクロールしない
  - 項目が上側にはみ出している場合は `itemMinY`、下側にはみ出している場合は
    `itemMaxY - visibleHeight` を目標値にする
  - 目標値は `0...max(0, contentHeight - visibleHeight)` にクランプする
  - 項目がビューポートより高い場合は項目の上端（`itemMinY`）を可視領域の上端に合わせる
  - 非有限値、負の高さ、`visibleHeight <= 0` など不正な寸法では `visibleMinY` を返す（クラッシュしない）
  - 横方向の値は扱わない。`import AppKit` をしない（Core の制約）
- [X] T091 [P] [US1] `Tests/MediaViewerCoreTests/ThumbnailScrollTests.swift` を新規作成し、
  「画面外の項目へ移動したときの計算」を検証する（T090 に依存。キー入力からスクロール実行までの
  UI 配線は自動テストの対象外とし、T093 の手動再現で担保する）:
  - 不具合の再現: 可視 0〜100、項目 120〜220 のとき 120 を返す（`visibleMinY` のままにしない）
  - 上方向: 可視 40〜140、項目 30〜80 のとき 30 を返す
  - 部分的に見えている下側: 可視 0〜100、項目 80〜130 のとき 30 を返す
  - 部分的に見えている上側: 可視 40〜140、項目 20〜60 のとき 20 を返す
  - 既に見えている: 可視 0〜100、項目 30〜80 のとき 0 を返す
  - 末尾クランプ: コンテンツ高 200、可視高 100、項目 190〜220 のとき 100 を返す
  - ビューポートより高い項目: コンテンツ高 400、可視 0〜100、項目 10〜310 のとき 10 を返す
  - 非有限値・ゼロ高・負の高さでは `visibleMinY` を返し、クラッシュしない
- [X] T092 [US1] `Sources/MediaViewerApp/FileList/ThumbnailModeView.swift` に、フォーカス項目を表示する
  共通処理を実装する（T090 に依存）:
  - `layoutSubtreeIfNeeded()` の後で `collectionView.layoutAttributesForItem(at:)` のフレームを取得し、
    `scrollView.contentView.bounds` と `flowLayout.collectionViewContentSize.height` を
    `ThumbnailScroll.offsetY(...)` に渡す
  - 返った縦原点が現在と異なる場合、クリップビューをアニメーションなしでスクロールし、
    `reflectScrolledClipView` でスクロールバーを更新する。横原点は 0 のままにする（FR-015）
  - `scrollToFocused()`、`handleArrowKey(_:modifiers:)` の移動後（Shift+矢印を含む）、
    `beginRenameFromKeyboard()` の項目取得前から共通処理を呼ぶ
  - 既存の `collectionView.scrollToItems(at:scrollPosition:)` を主経路から外し、`scrollToFocused()`、
    `handleArrowKey`、`beginRenameFromKeyboard` の3か所を共通処理に置き換える（`scrollToItems` は
    レイアウト属性も推定も不能な場合の最終フォールバックにのみ残す）
  - レイアウト属性が取得できない場合は、`ThumbnailGridLayout.columns(...)` と
    `flowLayout.collectionViewContentSize` から対象行の Y 範囲を推定し、同じ計算を適用する。
    それもできない場合のみ `collectionView.scrollToItems(at:scrollPosition: .nearestVerticalEdge)` を
    最終フォールバックにし、無言で何もしない経路を残さない。サムネイルサイズ・ペイン幅・
    ウィンドウサイズの変更時には呼ばない
  - `Sources/MediaViewerApp/FileList/ListModeView.swift` は変更しない
- [ ] T093 [US1] 自動テストと手動確認を行う（T091・T092 に依存）:
  - `swift build`、`swift test`、`scripts/check-no-network.sh` を通す
  - `scripts/make-app.sh` で `.build/MediaViewer.app` を作り、ユーザーに起動と quickstart の確認を依頼する。
    依頼時は実行コマンドと確認ポイントを具体的に示す
  - `specs/001-three-pane-media-viewer/quickstart.md` の「サムネイル形式のキーボード追従スクロール（FR-017）」を
    実施し、↓・↑・⇧+↓ でフォーカス項目全体が見えること、横スクロールが出ないこと、
    サイズ変更だけでは追従しないこと、リスト形式が従来どおりであることを確認する
  - 修正前の状態ではフォーカスがビューポート外に残ることを再現し、修正後は追従することを確認する。
    再現手順と結果（実行日、OS、確認した項目、合否）を
    `specs/001-three-pane-media-viewer/checklists/validation.md` に記録する
  - サムネイルの再読み込み直後など、セルのレイアウト属性がまだ生成されていない状態でも
    追従すること（フォールバック経路の確認）

---

## Phase 13: フルスクリーン中の矢印キーによるファイル移動（FR-046 追加、US5）

**Purpose**: フルスクリーン表示中も、ファイルリストと同じ移動規則で矢印キーにより選択を移し、
プレビューを追従させる。動画のフルスクリーンでも同じ移動を行い、シークは `<` / `>` に移す
（[plan.md](./plan.md) の「変更点」、[research.md](./research.md) R16、[spec.md](./spec.md) FR-046）。

**Independent Test**: サムネイル形式とリスト形式それぞれでフルスクリーンにし、矢印キーで選択を移動して
プレビューが切り替わること。先頭・末尾で循環しないこと。解除後に移動後のファイルが選択され、
サムネイル形式では見える位置までスクロールしていること。動画のフルスクリーンで矢印移動すると
再生が止まり、`<` / `>` で 5 秒戻る / 送ることができること
（[quickstart.md](./quickstart.md)「US5: フルスクリーン」3〜5）。

### Implementation for User Story 5

- [X] T094 [P] [US5] `Sources/MediaViewerCore/Layout/FocusNavigator.swift` を新規作成し、
  `FocusMove`・`FocusLayout`・`FocusNavigator.targetIndex(currentIndex:fileCount:move:layout:)` を実装する
  （契約は [contracts/core-api.md](./contracts/core-api.md) の「矢印キーによる選択移動」）。
  規則は次のとおり:
  - `.list`: ↑ は -1、↓ は +1。←→ は `currentIndex` に関わらず `nil`（移動なし）
  - `.grid(columns:)`: ← は -1、→ は +1、↑ は -columns、↓ は +columns
  - 結果は `0...(fileCount - 1)` にクランプする。空リスト（`fileCount <= 0`）は `nil`
  - 端で同じ位置になる移動は `nil`。`currentIndex` が `nil` の場合は 0 を返す（リスト形式の ←→ を除く）
  - `columns` が 0 以下の場合は 1 として扱う（ゼロ除算・同一行内の無限移動を避ける）
  - `import AppKit` をしない（Core の制約）
- [X] T095 [US5] `Tests/MediaViewerCoreTests/FocusNavigatorTests.swift` を新規作成し、
  `FocusNavigator` を検証する（T094 に依存）:
  - リスト形式: ↑↓ が ±1、先頭の ↑ と末尾の ↓ が `nil`、←→ が常に `nil`
  - サムネイル形式: ←→ が ±1、↑↓ が ∓列数、行頭の ← と行末の → が隣の行へ移動しないこと
    （仕様どおり前後インデックスへ移動し、端で `nil`）
  - 最終行が短い場合に、↓ が範囲外へ出ずクランプされること
  - `currentIndex == nil` で 0 を返すこと（リスト形式の ←→ を除く）、空リストで `nil`
  - `columns` が 0 / 負の場合に 1 として動くこと
- [X] T096 [P] [US5] `Sources/MediaViewerApp/FileList/ThumbnailModeView.swift` の `handleArrowKey(_:modifiers:)` を
  `FocusNavigator` に置き換える（T094 に依存）:
  - 現在の `delta` 計算とクランプを削除し、`FocusLayout.grid(columns: columnCount())` と
    `FocusMove` を渡して移動先を得る
  - 返り値が `nil` のときは選択を変えず、キーを消費して `true` を返す（OS の既定動作へ渡さない）
  - Shift+矢印の範囲選択、`selectionAnchor`、`scrollItemIntoView(at:)` の既存挙動は維持する
  - フルスクリーン開始時のスナップショット用に、現在の列数を返す読み取り専用のプロパティ
    （例: `var currentColumnCount: Int`）を公開する。既存の `columnCount()` の計算を再利用し、
    0 以下なら 1 を返す
- [X] T097 [US5] `Sources/MediaViewerApp/FileList/FileListViewController.swift` に、フルスクリーン用の
  移動 API を追加する（T094・T096 に依存）:
  - `beginFullScreenNavigation()`: 現在の `displayMode` と、サムネイル形式なら
    `thumbnailModeView.currentColumnCount` を `FocusLayout` としてスナップショットする。
    二重呼び出しでは既存のスナップショットを上書きしない
  - `moveFocusInFullScreen(_ move: FocusMove) -> Bool`: スナップショットがなければ `false`。
    `model.selection.focused` から現在インデックスを求め、`FocusNavigator.targetIndex(...)` が
    `nil` なら `true`（キーは消費、選択は変更しない）。移動先があれば
    `model.select([url], focused: url)` を呼び、`true` を返す
  - `endFullScreenNavigation()`: スナップショットを破棄する。サムネイル形式だった場合は
    ペイン復元後のレイアウトで `thumbnailModeView.scrollToFocused()` を呼び、移動後の項目を
    必要最小限のスクロールで表示する。リスト形式は `ListModeView` の既存の
    `scrollRowToVisible` に任せ、新しい処理を足さない
  - 表示形式・サムネイルサイズ・選択の永続化は変更しない
- [X] T098 [US5] `Sources/MediaViewerApp/App/MainSplitViewController.swift` に、フルスクリーン中の
  キー振り分けを実装する（T097 に依存）:
  - `collapsePanesForFullScreen()` の先頭で `fileListViewController.beginFullScreenNavigation()` を呼び、
    ペインを折りたたむ前に表示形式と列数を取得する（アプリ起点と緑ボタンの両経路を同じ処理で覆う）
  - `windowDidEnterFullScreen` 相当のタイミングで `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`
    を登録し、トークンを保持する。`windowDidExitFullScreen` で必ず `removeMonitor` する
  - モニタ内では、イベントのウインドウが自ウインドウであること、修飾キーがないこと
    （`.command` / `.option` / `.control` / `.shift` を含まない）を確認する
  - ↑↓←→ は `fileListViewController.moveFocusInFullScreen(_:)` へ渡す。リスト形式では
    FocusNavigator が ←→ を `nil` にするため、その場合は選択を変えずキーだけ消費する
  - `<` / `>` は `previewViewController.seekVideo(by: -5 / +5)` へ渡す。処理したイベントは `nil` を返し、
    未処理のイベント（Esc、Space、Cmd 付きなど）はそのまま返す
  - 解除時はモニタを外した後、`restorePanesAfterFullScreen()` の完了後に
    `fileListViewController.endFullScreenNavigation()` を呼ぶ。レイアウトが確定する前に
    スクロールしないよう、必要なら次のメインループで実行する
- [X] T099 [P] [US5] `Sources/MediaViewerApp/Preview/VideoPreviewView.swift` と
  `Sources/MediaViewerApp/Preview/PreviewViewController.swift` に `<` / `>` 用のシークを追加する:
  - `VideoPreviewView.seek(by seconds: Double)`: `AVPlayer` の現在位置に `seconds` を加え、
    `0...duration.seconds` にクランプして `seek(to:toleranceBefore:.zero,toleranceAfter:.zero)` する。
    `duration` が非有限・不正な場合は何もしない。再生状態（rate）は変更しない
  - `PreviewViewController.seekVideo(by seconds: Double)`: `model.preview` が `.video` のときだけ
    `videoView.seek(by:)` を呼ぶ。画像・空・エラー時は何もしない
  - シーク量は 5 秒とする（`<` で -5、`>` で +5）
- [X] T100 [US5] 自動テストと手動確認を行う（T095〜T099 に依存）:
  - `swift build`、`swift test --filter MediaViewerCoreTests`、`scripts/check-no-network.sh` を通す
  - `scripts/make-app.sh` で `.build/MediaViewer.app` を作り、ユーザーに起動と GUI 確認を依頼する。
    依頼時は実行コマンドと確認ポイントを具体的に示す
  - `quickstart.md`「US5: フルスクリーン」の 3〜5 を実施する:
    サムネイル形式で ↑↓←→ による移動とプレビュー追従、端で停止、解除後の選択とスクロール、
    リスト形式で ↑↓ のみ有効、動画のフルスクリーンで矢印移動時に再生停止、`<` / `>` で 5 秒シーク
  - 動画から矢印で画像へ移ったときに音声も止まること、画像から動画へ移ったときに設定に従って
    再生が始まることを確認する（FR-031・034）
  - 結果（実行日、OS、確認項目、合否）を
    `specs/001-three-pane-media-viewer/checklists/validation.md` に記録する

**Checkpoint**: フルスクリーン中の矢印移動が通常表示と同じ規則で動作し、動画のキーボードシークも維持される

---

## Phase 14: ツリーのフォルダアイコン（FR-047 追加、US1）

**Purpose**: ツリーの各フォルダ名の先頭にアイコンを付け、ホーム・マウント中のボリューム・通常フォルダを
区別する（[spec.md](./spec.md) FR-047、[plan.md](./plan.md) の「変更点」、
[research.md](./research.md) R17、[quickstart.md](./quickstart.md) US1 の 2）。

**Independent Test**: ホームとマウント中のボリュームを含むツリーを表示し、3種類のアイコンが互いに
判別できること。展開・折りたたみ・選択・ドラッグ&ドロップの操作が従来どおり動くこと（SC-013）。

### Implementation for User Story 1

- [X] T101 [P] [US1] `Sources/MediaViewerApp/Shared/IconCatalog.swift` を新規作成する:
  - `import AppKit` と `import MediaViewerCore` のみを使い、外部素材・ネットワークを使わない
  - `static func treeIcon(for kind: FolderNode.Kind) -> NSImage?` を実装する。割り当ては
    `.home` → `house`、`.volume` → `externaldrive`、`.folder` → `folder`
  - リスト形式のフォールバック用に `static func fallbackIcon(for kind: MediaKind) -> NSImage?` も用意する。
    割り当ては `.jpeg` → `photo`、`.png` → `photo.on.rectangle`、`.gif` → `photo.stack`、
    `.webp` → `photo.circle`、`.mp4` → `film`、`.mov` → `video`
  - `NSImage.SymbolConfiguration` でツリーは 13pt、リストは 16pt に構成し、`isTemplate = true` にする。
    アイコン自体は装飾なので a11y 要素にしない（`setAccessibilityElement(false)`）
  - SF Symbol が取得できない場合は `nil` を返し、呼び出し側はアイコンなしでテキストだけを表示できる
- [X] T102 [US1] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` の
  `outlineView(_:viewFor:item:)` を、`imageView` + `textField` を持つ `NSTableCellView` に変更する
  （T101 に依存）:
  - 再利用セルにも毎回 `treeIcon(for:)` の結果を設定し、フォルダ種別が変わった行で古いアイコンを残さない
  - アイコンの左余白は 2pt、アイコンは 13〜16pt、テキストはアイコンの右 6pt に置き、
    `lineBreakMode = .byTruncatingMiddle` と中央揃えの既存挙動を維持する
  - 展開・折りたたみの三角、選択、アクセス不可の `disabledControlTextColor` とツールチップ、
    ドラッグ&ドロップ、コンテキストメニューは変更しない。展開状態でアイコンを変えない
  - アイコンは装飾として a11y 要素から外し、フォルダ名の読み上げだけを残す

### Verification for User Story 1

- [X] T103 [US1] ツリーアイコンの手動確認を行う（T102 に依存）:
  - `swift build` と `scripts/make-app.sh` を通し、ユーザーに `.build/MediaViewer.app` の起動と
    GUI 確認を依頼する。依頼時は実行コマンドと確認ポイントを具体的に示す
  - `quickstart.md`「US1」の 2 で、ホーム・マウント中のボリューム・通常フォルダの3種類の
    ツリーアイコンが判別できること、展開・折りたたみ・選択が従来どおり動くことを確認する
    （FR-047、SC-013）
  - 結果（実行日、OS、確認項目、合否）を
    `specs/001-three-pane-media-viewer/checklists/validation.md` に記録する

**Checkpoint**: US1 のツリーアイコンが独立して確認でき、既存のツリー操作がすべて従来どおり動く

---

## Phase 15: リスト形式の行頭アイコン（FR-048 追加、US3）

**Purpose**: リスト形式の各行のファイル名の先頭に内容の縮小画像を表示し、生成中・失敗時は形式別の
汎用アイコンにフォールバックする（[spec.md](./spec.md) FR-048、[plan.md](./plan.md) の「変更点」、
[research.md](./research.md) R17、[data-model.md](./data-model.md) の `IconPresentation`）。

**Independent Test**: `mixed/` と `broken/` をリスト形式で表示し、画像・動画の行頭に縮小画像が出ること、
生成中・失敗時は形式別アイコンになること、10,000 ファイルの `huge/` でもスクロールと選択が
アイコン生成を待たないこと（SC-012、quickstart.md US3 の 5〜7）。

### Tests for User Story 3

- [X] T104 [P] [US3] `Tests/MediaViewerCoreTests/ThumbnailProviderTests.swift` を更新し、
  64px 段階の期待値を先に書く（T105 の前に失敗することを確認する）:
  - 既存の `50pt × 1x` は 128 ではなく 64 になる
  - `16pt × 1x` と `16pt × 2x` は 64、`64pt × 1x` は 64、`64.1pt × 1x` は 128
  - `100pt × 2x` は 256、`300pt × 2x` と `1000pt × 1x` は 512 のまま
  - 非有限値は 64 を返し、クラッシュしない
  - URL + ピクセルサイズ単位のキャンセルが、同じ URL の別サイズを巻き込まないことを
    検証できる範囲で追加する（難しければ T109 の手動確認で補う）

### Implementation for User Story 3

- [X] T105 [US3] `Sources/MediaViewerCore/Imaging/ThumbnailProvider.swift` を更新する（T104 に依存）:
  - `sizeSteps` に 64 を追加し、`[64, 128, 256, 512]` にする。`pixelSize(forPointSize:scale:)` の
    丸め規則とキャッシュキー（URL + px）は変えない
  - `ThumbnailProviding.cancel(for:pointSize:scale:)` に合わせ、進行中要求を URL だけでなく
    丸め後のピクセルサイズでも照合して取り消す。同じ URL の別サイズの要求を残す。
    T047 で追加した URL だけの `cancel(for:)` を置き換える
  - `ThumbnailModeView` と `ListModeView` の呼び出し側は T106・T107 で更新する
- [X] T106 [US3] `Sources/MediaViewerApp/FileList/ThumbnailModeView.swift` を
  URL + サイズ単位のキャンセルへ移行する（T105 に依存）:
  - `ThumbnailRequest` に要求時の `scale` を保持する
  - `requestThumbnail(for:)` で表示サイズを変えたときと `cancelRequest(for:)` で、
    `cancel(for:pointSize:scale:)` に保存済みの `pointSize` と `scale` を渡す。
    T052・T047 の URL だけのキャンセル呼び出しを置き換える
  - 64px のリストアイコン要求が同じ URL の 128px 以上のサムネイル要求を取り消さないようにする。
    既存の表示・選択・スクロール・ズームの挙動は変えない
- [X] T107 [US3] `Sources/MediaViewerApp/FileList/ListModeView.swift` に、名前列の行頭アイコンを実装する
  （T101・T105 に依存）:
  - イニシャライザに `provider: any ThumbnailProviding` を追加する。呼び出し側は T108 で更新する
  - `name` 列のセルだけ `imageView` を持たせ、`imageScaling = .scaleProportionallyDown`、
    16×16pt、左余白 2pt にする。テキストはアイコンの右 6pt に置き、中央揃え・
    `.byTruncatingMiddle`・インライン編集の挙動を維持する
  - 行の表示時にまず `IconCatalog.fallbackIcon(for: file.kind)` を設定する。その後
    `provider.thumbnail(for: file.url, pointSize: 16, scale: window?.backingScaleFactor ?? 2)` を
    非同期に要求し、取得できたら `NSImage(cgImage:size:)` で 16×16pt にして差し替える。
    取得できなかった場合はフォールバックを残す
  - セルは表示中の URL を保持し、取得完了時に同じ URL を表示している場合だけ画像を差し替える。
    セルが別の行に再利用されたら、そのセルが要求した `pointSize` と `scale` を
    `provider.cancel(for:pointSize:scale:)` に渡し、同じ URL の他サイズ要求を巻き込まない
  - 他の列（作成日・種類）は従来のテキストのみとし、アイコンを付けない。行の高さは 20pt にする
  - アイコンは装飾として a11y 要素から外し、ファイル名の読み上げ・選択・複数選択・
    キーボード操作・並べ替え・名前変更の対象を変えない
- [X] T108 [US3] `Sources/MediaViewerApp/FileList/FileListViewController.swift` で、
  既存の `thumbnailProvider` を `ListModeView(model:provider:)` へ渡す（T107 に依存）。
  表示形式の切替、フルスクリーン、ファイル操作、設定の永続化は変更しない

### Verification for User Story 3

- [X] T109 [US3] 自動テストと手動確認を行う（T103・T108 に依存）:
  - `swift build`、`swift test`、`scripts/check-no-network.sh` を通す
  - `scripts/make-app.sh` で `.build/MediaViewer.app` を作り、ユーザーに起動と GUI 確認を依頼する。
    依頼時は実行コマンドと確認ポイントを具体的に示す
  - `quickstart.md`「US3」の 5〜7 で、画像と動画の行頭に縮小画像が出ること、`broken/` では
    形式別アイコンになること、名前変更中もテキストがアイコンの右にあること、
    `huge/` のスクロールと選択がアイコン生成を待たないことを確認する（FR-048、SC-012）
  - `huge/` のスクロールを画面収録または Instruments で計測し、100ms 以上の停止が 0 回であること、
    計測方法、最大停止時間を確認する。結果を `checklists/validation.md` に記録する（SC-012）
  - リスト形式とサムネイル形式を切り替えても、リスト側の 64px アイコン取得のキャンセルが
    サムネイル形式の 128px 以上の表示を欠けさせないことを確認する（FR-013 の回帰確認）
  - 結果（実行日、OS、確認項目、合否）を
    `specs/001-three-pane-media-viewer/checklists/validation.md` に記録する

**Checkpoint**: リスト形式の行頭アイコンが表示され、既存の閲覧・選択・スクロール性能と
サムネイル形式の表示を維持する

---

## Phase 16: 表示を切り替えられるツールバー（FR-049〜052 追加、US3）

**Purpose**: メインウィンドウに表示・非表示を切り替えられるツールバーを追加し、表示形式の2択ボタンと
サムネイルサイズのスライダーを置く。既定は非表示で、非表示のときは追加前と同じ画面にする
（[spec.md](./spec.md) FR-003・049〜052、[plan.md](./plan.md) の「変更点（表示を切り替えられるツールバー）」、
[research.md](./research.md) R18、[data-model.md](./data-model.md) の `ViewSettings`・`FileListChrome`、
[contracts/settings.md](./contracts/settings.md)、[contracts/keyboard-and-menus.md](./contracts/keyboard-and-menus.md)「ツールバー」）。

**Independent Test**: `view.showsToolbar` を消して起動するとツールバーが出ず、画面が追加前と同じであること。
⇧⌘T と「表示」メニューで切り替えられ、表示中はサムネイル形式の下部サイズバーが消えること。ツールバーの
ボタン・スライダーとメニュー（⌘1 / ⌘2 / ⌘+ / ⌘-）の状態が一致し、リスト形式ではスライダーが無効になること。
再起動後に表示状態が復元されること（quickstart.md「ツールバー」の 1〜8）。

### Tests for User Story 3

- [X] T110 [P] [US3] `Tests/MediaViewerCoreTests/SettingsStoreTests.swift` にツールバーの表示状態の
  テストを先に追加する（T112 の前に失敗またはビルドエラーになることを確認する）。既存の
  `UserDefaults(suiteName:)` の専用スイートを使う既存テストの形に合わせる:
  - 「未設定なら既定値になる」に `viewSettings.showsToolbar == false` を加える
  - 「保存した値が往復する」に `showsToolbar = true` を加え、読み戻すと `true` になることを確かめる。
    `false` に戻して保存すると `false` になることも確かめる
  - 「型が不正な値は既定値に戻る」に、`view.showsToolbar` へ文字列 `"yes"` を入れた場合に `false` になる
    ケースを加える
  - `showsToolbar` を書き換えても `displayMode`・`thumbnailSize`・並び順・`lastFolder` が変わらないことを確かめる
- [X] T111 [P] [US3] `Tests/MediaViewerCoreTests/FileListChromeTests.swift`（新規、`@Suite("FileListChrome")`）に、
  data-model.md の規則どおり 4 通りを検証するテストを先に書く（T113 の前に失敗またはビルドエラーになることを確認する）:
  - サムネイル形式 × ツールバー非表示 → `showsBottomSizeBar == true`、`toolbarSliderEnabled == true`
  - サムネイル形式 × ツールバー表示 → `showsBottomSizeBar == false`、`toolbarSliderEnabled == true`
  - リスト形式 × ツールバー非表示 → `showsBottomSizeBar == false`、`toolbarSliderEnabled == false`
  - リスト形式 × ツールバー表示 → `showsBottomSizeBar == false`、`toolbarSliderEnabled == false`

### Implementation for User Story 3

- [X] T112 [P] [US3] ツールバーの表示状態を `ViewSettings` と `SettingsStore` に追加する（T110 に依存）:
  - `Sources/MediaViewerCore/Model/Settings.swift`: `ViewSettings` に `public var showsToolbar: Bool` を追加し、
    イニシャライザに既定引数 `showsToolbar: Bool = false` を `lastFolder` の後に加える。既存の呼び出しは変更不要にする
  - `Sources/MediaViewerCore/Settings/SettingsStore.swift`: `Keys.showsToolbar = "view.showsToolbar"` を追加し、
    `viewSettings` の getter で `storedBool(forKey:) ?? false`、setter で `defaults.set(_:forKey:)` を行う。
    data-model.md の制約「値がない・不正な型の場合は false（FR-003・049）」をそのまま守る
  - `swift test --filter SettingsStoreTests` が通ることを確認する
- [X] T113 [P] [US3] `Sources/MediaViewerCore/Model/FileListChrome.swift`（新規）に、
  contracts/core-api.md の `public struct FileListChrome: Sendable, Equatable` を実装する（T111 に依存）:
  - `init(displayMode: DisplayMode, toolbarShown: Bool)`
  - `showsBottomSizeBar` は「`displayMode == .thumbnails && !toolbarShown`」（FR-052）
  - `toolbarSliderEnabled` は「`displayMode == .thumbnails`」（FR-051）
  - AppKit を import しない。`swift test --filter FileListChromeTests` が通ることを確認する
- [X] T114 [US3] `Sources/MediaViewerApp/FileList/FileListViewController.swift` に、ツールバーと状態を共有する
  入口を追加する（T113 に依存）:
  - `var isToolbarShown = false { didSet { updateModeVisibility() } }` を追加する
  - `updateModeVisibility()` の下部バーの判定を `FileListChrome(displayMode:toolbarShown:).showsBottomSizeBar`
    に置き換える（高さ 32 / 0 の切り替えと `isHidden` は既存のまま）
  - 読み取り用に `var currentDisplayMode: DisplayMode` と `var currentThumbnailSize: Double` を公開する
  - ツールバーから呼ぶ `func selectDisplayMode(_ mode: DisplayMode)`（既存の `setDisplayMode(_:)` を呼ぶ）と
    `func applyThumbnailSize(_ value: Double)`（既存の `setThumbnailSize(_:persist: true)` を呼ぶ）を公開する
  - `var onViewStateChange: ((DisplayMode, Double) -> Void)?` を追加し、`updateModeVisibility()` の末尾と
    `setThumbnailSize(_:persist:)` で表示形式とクランプ後のサイズを通知する。メニュー・下部バー・ツールバーの
    どこから変えても同じ経路で通知されるようにする
  - 既存のメニュー項目（⌘1 / ⌘2 / ⌘+ / ⌘-）、下部スライダー、フルスクリーン中の移動、ファイル操作は変えない
- [X] T115 [US3] `Sources/MediaViewerApp/App/MainToolbarController.swift`（新規、`@MainActor final class`、
  `NSObject` + `NSToolbarDelegate`）を作る（T113・T114 に依存）:
  - `init(fileList: FileListViewController, settings: SettingsStore)`。`let toolbar = NSToolbar(identifier: "MainToolbar")`
    を持ち、`delegate = self`、`displayMode = .iconOnly`、`allowsUserCustomization = false`、
    `allowsDisplayModeCustomization = false`、`autosavesConfiguration = false` にする
  - 項目は `toolbarDefaultItemIdentifiers` と `toolbarAllowedItemIdentifiers` の両方で
    `[viewMode, thumbnailSize, .flexibleSpace]` の順に固定する
  - `viewMode`: `NSToolbarItemGroup(itemIdentifier:images:selectionMode: .selectOne, labels: ["サムネイル", "リスト"],
    target: self, action:)`。画像は `NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "サムネイル")`
    と `"list.bullet"`（「リスト」）。グループのラベルは「表示形式」。選択時は `selectedIndex` 0 → `.thumbnails`、
    1 → `.list` を `fileList.selectDisplayMode(_:)` に渡す
  - `thumbnailSize`: `NSSlider`（`minValue = ViewSettings.minimumThumbnailSize`、`maxValue = ViewSettings.maximumThumbnailSize`、
    `isContinuous = true`、`controlSize = .small`、幅 120pt の制約）を `view` に持つ `NSToolbarItem`。
    ラベル「サイズ」、`toolTip` と `setAccessibilityLabel` は「サムネイルのサイズ」。`autovalidates = false`。
    値の変更は `fileList.applyThumbnailSize(_:)` に渡す
  - `func apply(displayMode: DisplayMode, thumbnailSize: Double)` で、グループの `selectedIndex`、スライダーの値
    （差が 0.01 以下なら書き換えない）、`FileListChrome(...).toolbarSliderEnabled` に基づくスライダーと項目の
    `isEnabled` を更新する。リスト形式でも項目を外さず、並びと位置を変えない（FR-051）
  - 生成時に `fileList.currentDisplayMode` / `currentThumbnailSize` で初期表示し、`fileList.onViewStateChange` を
    登録して `apply` を呼ぶ
  - `toolbar.observe(\.isVisible, options: [.new])` の KVO で、変化のたびに `settings.viewSettings` を読み出して
    `showsToolbar` だけを書き換えて保存し、`fileList.isToolbarShown` を更新する。KVO のコールバックは
    `MainActor.assumeIsolated` などで MainActor 上で処理する
- [X] T116 [US3] `Sources/MediaViewerApp/App/MainSplitViewController.swift` を更新する（T114 に依存）:
  - `fileListViewController` を `MainWindowController` から読めるよう、`private` を外して
    `private(set)` 相当の読み取り専用プロパティにする
  - `window(_:willUseFullScreenPresentationOptions:)` を実装し、提案値に `.autoHideToolbar` と `.autoHideMenuBar` を
    加えて返す。フルスクリーン中はツールバーがメニューバーと一緒に自動で隠れ、`isVisible` と保存値は変えない
  - 既存のペイン折りたたみ、フルスクリーン中のキー監視、`NSSplitViewDelegate` の禁止メソッドには触れない
    （AGENTS.md「AppKit UI の不変条件」）
- [X] T117 [US3] ツールバーをウィンドウとメニューに結線する（T112・T115・T116 に依存）:
  - `Sources/MediaViewerApp/App/MainWindowController.swift`: `init` で `SettingsStore()` と
    `splitViewController.fileListViewController` から `MainToolbarController` を作って保持する。保存値
    `viewSettings.showsToolbar` を `toolbar.isVisible` に設定し、`fileList.isToolbarShown` も合わせてから
    `window.toolbarStyle = .unified`・`window.toolbar = toolbar` を設定する（ウィンドウ表示前に行い、ちらつかせない）
  - 同ファイルに `@objc func toggleMainToolbar(_ sender: Any?)`（`window?.toolbar?.isVisible.toggle()`）と、
    `NSMenuItemValidation` の `validateMenuItem(_:)` を追加する。この項目は常に有効で、`title` を表示中は
    「ツールバーを隠す」、非表示中は「ツールバーを表示」にする。`NSWindow.toggleToolbarShown(_:)` は使わない（R18）
  - `Sources/MediaViewerApp/App/MainMenu.swift`: 「表示」メニューの先頭（フルスクリーン項目の前）に、
    タイトル「ツールバーを表示」、`action: #selector(MainWindowController.toggleMainToolbar(_:))`、
    `keyEquivalent: "t"`、`keyEquivalentModifierMask = [.command, .option]`、`target = nil` の項目と区切り線を追加する
  - ⇧⌘T が既存のキー割り当て（contracts/keyboard-and-menus.md）と重ならないことを確認する
  - 2026-10-20 変更: キーは当初の ⌥⌘T が常駐アプリと衝突したため ⇧⌘T にした。AppKit の自動ウィンドウタブ
    （「タブバーを表示」⇧⌘T）と衝突しないよう、`Sources/MediaViewerApp/App/AppDelegate.swift` の起動時に
    `NSWindow.allowsAutomaticWindowTabbing = false` を設定する
- [X] T118 [P] [US3] `README.md` の「主な機能」と「使い方（主なショートカット）」の表に、ツールバーの表示切替
  （⇧⌘T、表示メニュー。既定は非表示で、状態は次回起動時に復元される）を追記する。「設定の保存先」に
  `view.showsToolbar` を挙げている箇所があれば合わせて追記する

### Verification for User Story 3

- [X] T119 [US3] 自動テストと手動確認を行う（T110〜T118 に依存）:
  - `swift build`、`swift test`、`scripts/check-no-network.sh` を通す
  - `scripts/make-app.sh` で `.build/MediaViewer.app` を作り、ユーザーに起動と GUI 確認を依頼する。
    依頼時は実行コマンドと確認ポイントを具体的に示す。起動しない場合は AGENTS.md の lldb 手順で例外を止める
  - `quickstart.md`「ツールバー」の 1〜8 を確認する（FR-049〜052、FR-003）。特に 1 では、ツールバー非表示の
    タイトルバーと3ペインがツールバー追加前と同じであることを確認する。差がある場合は R18 の代替案
    （非表示時に `window.toolbar = nil`）へ切り替え、T117 を修正して再確認する
  - 回帰確認: ⌘1 / ⌘2 / ⌘+ / ⌘-、下部スライダー、フルスクリーン中の矢印移動、⌃⌘F / Esc が従来どおり動く
  - 結果（実行日、OS、確認項目、合否）を
    `specs/001-three-pane-media-viewer/checklists/validation.md` に記録する

**Checkpoint**: ツールバーを表示・非表示で切り替えられ、非表示のときは従来と同じ画面のまま、表示中は
表示形式とサムネイルサイズをツールバーから操作できる

---

## Phase 17: ツリーのダブルクリック開閉と開閉の三角（FR-053〜055 追加、US1）

**Purpose**: ツリーのフォルダの行のダブルクリックで開閉をトグルし、開閉の三角はサブフォルダがあると確認できた
フォルダ（と確認に失敗したフォルダ）にだけ出す。サブフォルダの有無は、表示されているフォルダの直下1階層だけを
最初の1件で打ち切って確認する（[spec.md](./spec.md) FR-053〜055・US1 の受け入れシナリオ 8・9、
[plan.md](./plan.md) の「変更点（ツリーのダブルクリック開閉と開閉の三角の表示条件）」、[research.md](./research.md) R19、
[data-model.md](./data-model.md) の `FolderNode`・「サブフォルダの有無の状態遷移」・`FolderDisclosure`、
[contracts/core-api.md](./contracts/core-api.md)「ディレクトリ・ボリューム」、
[contracts/keyboard-and-menus.md](./contracts/keyboard-and-menus.md)「ディレクトリツリー」）。

**Independent Test**: `swift test` で状態遷移・ダブルクリックの判断・`hasSubfolders(in:)`・並列数の上限が通ること。
`.app` で quickstart.md「ツリーのダブルクリック開閉と開閉の三角」の 1〜7 を確認し、サブフォルダのないフォルダに
三角が出ず、行のダブルクリックで選択とトグルが行われること。

### Tests for User Story 1

- [X] T120 [P] [US1] `Tests/MediaViewerCoreTests/FolderDisclosureTests.swift`（新規、`@Suite("FolderDisclosure")`）を先に書く
  （T123・T124 の前にビルドエラーになることを確認する）。`FolderNode(url:name:kind:)` で作ったノードに対して検証する:
  - 既定値: `subfolderState == .unknown`、`isExpandable == false`
  - `isExpandable` の 16 通り（`accessState` が `.unknown` / `.accessible` / `.denied` / `.unavailable` × `subfolderState` が
    `.unknown` / `.present` / `.absent` / `.failed`）。`true` になるのは「`accessState != .denied` かつ
    `subfolderState` が `.present` または `.failed`」の 6 通りだけ
  - `applySubfolderProbe(_:)`: data-model.md の状態遷移表どおり
    - `.success(true)` → `.present`、`accessState == .accessible`
    - `.success(false)` → `.absent`、`accessState == .accessible`
    - `.failure(.accessDenied)` → `accessState == .denied`、`isExpandable == false`
    - `.failure(.notFound)` と `.failure(.other("x"))` → `.failed`、`isExpandable == true`
    - 再確認: `.present` の後に `.success(false)` → `.absent`。`.denied` の後に `.success(true)` → `.present` かつ
      `accessState == .accessible`（外部の変更での回復）
  - `applySubfolderListing(_:)`:
    - `.success(3)` → `.present`、`accessState == .accessible`
    - `.success(0)` → `.absent`、`isExpandable == false`
    - `.failure(.accessDenied)` → `accessState == .denied`、`children == []`、`isExpandable == false`
    - `.failure(.notFound)` と `.failure(.other("x"))` → `accessState == .unavailable`、`subfolderState == .failed`、
      `children == nil`、`isExpandable == true`（三角を残して再展開で読み直す）
    - 回復: `.failure(.other("x"))` の後に `.success(2)` → `.present`、`accessState == .accessible`
  - `FolderDisclosure.doubleClickToggle(isExpandable:isExpanded:)` の 4 通り:
    `(true, false)` → `.expand`、`(true, true)` → `.collapse`、`(false, true)` → `.collapse`、`(false, false)` → `.none`
- [X] T121 [P] [US1] `Tests/MediaViewerCoreTests/DirectoryListerTests.swift` に `hasSubfolders(in:)` のテストを先に追加する
  （T125 の前にビルドエラーになることを確認する）。既存の `makeTemporaryDirectory()` と、権限を `defer` で
  `0o755` に戻す既存の `reportsAccessDenied` の形に合わせる。各ケースで、結果が `!subfolders(of:).isEmpty` と一致すること
  （エラーのケースでは同じ `ListingError` を投げること）も確かめる:
  - 空のフォルダ → `false`
  - ファイルだけ（`a.jpg`・`b.txt`）→ `false`
  - 隠しフォルダだけ（`.secret/`）→ `false`
  - Finder の非表示属性を付けたフォルダだけ（`URLResourceValues.isHidden = true` を `setResourceValues` で設定）→ `false`
  - パッケージだけ（`Sample.app/` ディレクトリ）→ `false`
  - サブフォルダが 1 つ（`sub/`）→ `true`
  - ファイル 50 個とサブフォルダ 1 つが混在 → `true`
  - 権限なし（フォルダを `0o000` にする）→ `ListingError.accessDenied` を投げる
  - 存在しないパス、およびファイルのパス → `ListingError.notFound` を投げる
- [X] T122 [P] [US1] `Tests/MediaViewerCoreTests/SubfolderProbeTests.swift`（新規、`@Suite("SubfolderProbe")`）を先に書く
  （T126 の前にビルドエラーになることを確認する）。テスト内に `private actor ProbeFakeLister: DirectoryListing` を置き、
  `hasSubfolders(in:)` で `inFlight` と `maxInFlight` と `started` を数え、`Task.sleep(for: .milliseconds(20))` の後に
  URL ごとに決めた結果を返す（`mediaFiles` と `subfolders` は空配列を返す）:
  - URL 10 件・`maxConcurrent: 3` → 結果は 10 件で、各 URL が 1 回ずつ。`maxInFlight <= 3`
  - 特定の 1 件だけ `.other("boom")` を投げる → その URL だけ `.failure(.other("boom"))`、他は `.success`
  - 空配列 → 結果 0 件ですぐ終わる
  - `maxConcurrent: 0` → 1 として扱い、10 件すべて返る（`maxInFlight == 1`）
  - 取り消し: URL 20 件・`maxConcurrent: 2` で、最初の 1 件を受け取ったら `for await` を抜ける。
    100ms 待った後、`started < 20` であること（ストリームの終了で未実行の確認を始めない）

### Implementation for User Story 1

- [X] T123 [US1] `Sources/MediaViewerCore/Model/FolderNode.swift` を更新する（T120 に依存）:
  - `AccessState` に `case unavailable` を追加する（data-model.md「権限以外の理由（応答なし・取り外し等）で展開時に
    読めなかった状態で、再展開で読み直す」）。既存の `== .denied` / `!= .denied` の比較はそのまま使える
  - `public enum SubfolderState: Sendable { case unknown, present, absent, failed }` を `FolderNode` の中に追加する
  - `public var subfolderState: SubfolderState` を追加し、イニシャライザの最後に既定引数 `subfolderState: SubfolderState = .unknown`
    を加える。既存の呼び出し（`DirectoryTreeViewController`・`VolumeProvider`・テスト）は変更不要にする。
    `==` と `hash(into:)` は `url` だけのまま変えない
  - `public var isExpandable: Bool`: `accessState != .denied && (subfolderState == .present || subfolderState == .failed)`
  - `public mutating func applySubfolderProbe(_ result: Result<Bool, ListingError>)`: `true` → `.present` + `.accessible`、
    `false` → `.absent` + `.accessible`、`.accessDenied` → `accessState = .denied`、`.notFound` / `.other` → `.failed`
  - `public mutating func applySubfolderListing(_ result: Result<Int, ListingError>)`: 1 以上 → `.present` + `.accessible`、
    0 → `.absent` + `.accessible`、`.accessDenied` → `accessState = .denied` + `children = []`、
    `.notFound` / `.other` → `accessState = .unavailable` + `subfolderState = .failed` + `children = nil`
  - AppKit を import しない
- [X] T124 [P] [US1] `Sources/MediaViewerCore/Model/FolderDisclosure.swift`（新規）に、contracts/core-api.md の
  `public enum FolderDisclosure` を実装する（T120 に依存）:
  - `public enum Toggle: Sendable, Equatable { case expand, collapse, none }`
  - `public static func doubleClickToggle(isExpandable: Bool, isExpanded: Bool) -> Toggle`: `isExpanded` なら `.collapse`、
    そうでなく `isExpandable` なら `.expand`、それ以外は `.none`
  - T123 と合わせて `swift test --filter FolderDisclosureTests` が通ることを確認する
- [X] T125 [US1] `Sources/MediaViewerCore/FileSystem/DirectoryLister.swift` に `hasSubfolders(in:)` を追加する（T121 に依存）:
  - `DirectoryListing` プロトコルに `func hasSubfolders(in folder: URL) async throws(ListingError) -> Bool` を追加し、
    `extension DirectoryListing` に既定実装 `try await !subfolders(of: folder).isEmpty` を置く。
    既存のテスト用フェイク（`BrowserModelTests` の `FakeLister`、`BrowserModelVideoTests` の `VideoFakeLister`）は変更不要にする
  - `subfolders(of:)` の事前チェック（`fileExists` と `isDirectory`、失敗で `.notFound`）を `private static func ensureDirectory(_:) throws`
    に、子の判定（`folderKeys` の `isDirectory == true` かつ `isPackage != true`）を `private static func isVisibleSubfolder(_:) -> Bool`
    に切り出し、`subfolders(of:)` と `hasSubfolders(in:)` の両方から使う。`subfolders(of:)` の結果と並び順は変えない
  - `DirectoryLister.hasSubfolders(in:)` は既存の `run { }` の中で、`FileManager.default.enumerator(at:includingPropertiesForKeys:
    options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .skipsPackageDescendants], errorHandler:)` を使い、
    `isVisibleSubfolder` を満たす最初の 1 件で `true` を返す。`errorHandler` では最初のエラーを保持して `false`（列挙中止）を返し、
    列挙後にエラーがあれば `listingError(from:)` で変換して投げる。`enumerator` が `nil` なら `.other("enumerator unavailable")` を投げる
  - T121 の権限なしのケースで `errorHandler` が呼ばれず `false` が返る場合は、事前チェックの後に
    `FileManager.default.isReadableFile(atPath:)` と `isExecutableFile(atPath:)` を確認し、どちらかが `false` なら `.accessDenied` を投げる
  - `swift test --filter DirectoryListerTests` が通ることを確認する
  - 2026-10-20 実装時の変更: enumerator 版は T127 で 0.05〜0.21 秒とばらつき基準を超えたため、`opendir` / `readdir` の
    `d_type` でディレクトリ以外を読み飛ばす実装にした（5〜9ms。research.md R19）。権限なしは `errorHandler` 版でも
    検出できたため、予備の `isReadableFile` 確認は不要だった
- [X] T126 [US1] `Sources/MediaViewerCore/FileSystem/SubfolderProbe.swift`（新規）に、contracts/core-api.md の
  `SubfolderProbeResult` と `SubfolderProbe.results(for:lister:maxConcurrent:)` を実装する（T122・T125 に依存）:
  - `public struct SubfolderProbeResult: Sendable { public let url: URL; public let result: Result<Bool, ListingError> }`
    （public の `init(url:result:)` を付ける）
  - `results` は `AsyncStream { continuation in ... }` の中で `Task` を 1 つ作り、`withTaskGroup(of: SubfolderProbeResult.self)` で
    `max(1, maxConcurrent)` 件ずつ `lister.hasSubfolders(in:)` を実行する。1 件終わるたびに `continuation.yield` し、
    `urls` の順に次の 1 件を追加する。`Task.isCancelled` なら新しい確認を追加せず `group.cancelAll()` する。
    最後に `continuation.finish()`
  - 失敗は `do { ... } catch { ... }`（typed throws の `ListingError`）で `.failure(error)` にして流し、他の URL に波及させない
  - `continuation.onTermination = { _ in task.cancel() }` でストリームの終了時に取り消す
  - `swift test --filter SubfolderProbeTests` が通ることを確認する
- [X] T127 [P] [US1] `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift` に
  `@Test("サブフォルダのない 10,000 ファイルのフォルダの hasSubfolders が 0.2 秒以内")` を追加する（T125 に依存）:
  - 一時ディレクトリに空ファイル `00000.jpg`〜`09999.jpg` を `FileManager.createFile(atPath:contents:)` で作る
    （作成時間は計測に含めない）。`defer` で削除する
  - `DirectoryLister().hasSubfolders(in:)` の所要時間を `ContinuousClock` で測り、結果が `false` で 0.2 秒以内であることを確かめる
    （quickstart.md「性能の検証」の基準値）。既存の他テストと同じく `.serialized` スイートの中に置く
- [X] T128 [US1] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` で、開閉の三角をサブフォルダの有無に従わせ、
  確認を始める（T123・T126 に依存）:
  - `outlineView(_:isItemExpandable:)` は `node.folder.isExpandable` を返す
  - `private enum ProbeKey: Hashable { case roots; case children(ObjectIdentifier); case recheck(ObjectIdentifier) }` と
    `private var probeTasks: [ProbeKey: Task<Void, Never>] = [:]` を追加する。同じキーで新しい確認を始めるときは古い `Task` を
    `cancel()` してから置き換える
  - `private func startProbes(for nodes: [Node], key: ProbeKey, force: Bool = false)` を追加する。`force == false` のときは
    `subfolderState == .unknown` かつ `accessState != .denied` のノードだけを、表示順のまま対象にする。対象の URL
    （`standardizedFileURL`）からノードへの辞書を作り、`SubfolderProbe.results(for:lister:)`（`maxConcurrent` は既定の 4）を
    `for await` で受ける。結果ごとに `node.folder.applySubfolderProbe(result.result)` を呼び、
    `outlineView.row(forItem: node) >= 0` のときだけ `outlineView.reloadItem(node, reloadChildren: false)` する。
    対象が空なら何もしない
  - `viewDidLoad` で `roots` を作った後に `startProbes(for: roots, key: .roots)` を呼ぶ
  - `applyRoots(_:)` で、同じ URL の既存ルートから `children` に加えて `folder.subfolderState` と `folder.accessState` を引き継ぎ、
    `reloadData()` の後に `startProbes(for: roots, key: .roots)` を呼ぶ（新しく現れたボリュームだけが確認される）
  - `loadChildrenIfNeeded(_:)`: 成功時は子のノードを作った後に `node.folder.applySubfolderListing(.success(children.count))` を呼ぶ。
    `reloadItem(node, reloadChildren: true)` の後、`node.folder.isExpandable` なら `expandItem(node)`、そうでなければ
    `collapseItem(node)` する。続けて `startProbes(for: children, key: .children(ObjectIdentifier(node)))` を呼ぶ。
    失敗時は既存の `accessState` の分岐を `node.folder.applySubfolderListing(.failure(error))` に置き換える。`node.children` は
    `node.folder.accessState` が `.denied` なら `[]`、`.unavailable` なら `nil`（次の展開で `loadChildrenIfNeeded` が読み直す）にし、
    `reloadItem(node, reloadChildren: true)`、`collapseItem(node)` を行う
  - `outlineView(_:viewFor:item:)` の「アクセスできません」表示（`disabledControlTextColor` とツールチップ）の条件を
    `accessState == .denied || accessState == .unavailable` にする。ドロップ先の判定（`!= .denied`）は変えない
  - `reloadChildren(of:)`: 既存の `node.children` から URL（`standardizedFileURL`）→ 旧ノードの辞書を作り、新しい子のノードへ
    `folder.subfolderState` と `folder.accessState` を引き継ぐ。成功・失敗の扱いは `loadChildrenIfNeeded` と同じにし、
    `.absent` になったら `collapseItem(node)` する。最後に `startProbes(for: children, key: .children(ObjectIdentifier(node)))`
    （新しく現れた子だけが確認される）。選択の復元は既存のまま
  - ノードの作成時に `FolderNode` の初期化引数は変えない（`subfolderState` は既定の `.unknown`）
- [X] T129 [US1] 同じ `DirectoryTreeViewController.swift` で、外部の変更と起動時の表示を三角に追従させる（T128 に依存）:
  - `private func displayedNodes() -> [Node]` を追加する。`roots` と、`outlineView.isItemExpanded(_:)` が `true` のノードの
    `children` を再帰的に集める（折りたたまれたノードの子は含めない）
  - `updateWatchSet()` は、既存の対象（表示中のフォルダと展開中のノード）に `displayedNodes()` の URL を加えて `watcher.watch` に渡す
  - `eventTask` のループで、`reloadExpandedNodes(in:)` の後に `recheckCollapsedNodes(in: changed)` を呼ぶ。
    `recheckCollapsedNodes` は `displayedNodes()` のうち、展開されておらず URL が `changed` に含まれるノードについて、
    `children` と `folder.children` を `nil` に戻し（次の展開で読み直す）、
    `startProbes(for: [node], key: .recheck(ObjectIdentifier(node)), force: true)` を呼ぶ。三角は確認が終わるまで今の表示のままにする
  - `reveal(_:)` は各段で `await loadChildrenIfNeeded(current)` を先に呼び、その後 `current.folder.isExpandable` かつ
    未展開なら `expandItem(current)` する（`.unknown` のノードへの `expandItem` は無視されるため、R19）。子の段も同じ順にする
- [X] T130 [US1] 同じ `DirectoryTreeViewController.swift` に、行のダブルクリックでの開閉を追加する（T124・T129 に依存）:
  - `loadView()` で `outlineView.target = self`、`outlineView.doubleAction = #selector(toggleClickedFolder(_:))` を設定する
  - `@objc private func toggleClickedFolder(_ sender: Any?)`: `outlineView.clickedRow` が `-1` なら何もしない。行のノードについて
    `FolderDisclosure.doubleClickToggle(isExpandable: node.folder.isExpandable, isExpanded: outlineView.isItemExpanded(node))`
    の結果が `.expand` なら `outlineView.expandItem(node)`、`.collapse` なら `outlineView.collapseItem(node)`、`.none` なら何もしない
  - 選択は 1 回目のクリックで既存の `outlineViewSelectionDidChange` が行うため、ここでは選択を変えない（FR-053）
  - T132 で三角の素早い 2 回クリックによって `doubleAction` も動くと分かった場合は、`outlineView.frameOfOutlineCell(atRow:)` が
    クリック位置（`outlineView.convert(NSApp.currentEvent!.locationInWindow, from: nil)`）を含むときに何もしないようにする
  - 右クリックメニュー、ドラッグ&ドロップ、キー操作（FR-005）、行頭アイコン（FR-047）は変えない
- [X] T131 [P] [US1] `README.md` の「主な機能」とツリーの操作説明に、フォルダの行のダブルクリックで開閉できることと、
  開閉の三角はサブフォルダ（隠しフォルダ・パッケージを除く）があるフォルダにだけ表示されることを追記する

### Verification for User Story 1

- [X] T132 [US1] 自動テストと手動確認を行う（T120〜T131 に依存）:
  - `swift build`、`swift test`、`scripts/check-no-network.sh` を通す。T127 の計測値を記録する（憲章 原則 II）
  - `scripts/make-app.sh` で `.build/MediaViewer.app` を作り、ユーザーに起動と GUI 確認を依頼する。依頼時は quickstart.md
    「ツリーのダブルクリック開閉と開閉の三角」の準備コマンドと確認ポイント 1〜7 を具体的に示す。
    起動しない場合は AGENTS.md の lldb 手順で例外を止める
  - quickstart.md の 6 では、上下キーで移動を続けたときの表示の停止を画面収録または Instruments で測り、
    100ms 以上の停止がないことを確認する（FR-055、SC-004 と同じ基準）
  - 回帰確認: ツリーの ↑ / ↓ / ← / →、⌥→ / ⌥←（読み込み済みの配下をエラーなく開閉し、未確認の孫以下を先読みしない）、
    開閉の三角のクリック、ツリーへのドロップ（`.unavailable` のフォルダへもドロップできる）、右クリックメニュー、
    起動時の前回フォルダの展開と選択（`reveal`）、行頭アイコン（quickstart.md US1 の 2）が従来どおり動く
  - 確認後に `chmod 755 ~/MediaViewerFixtures/tree/denied` で権限を戻すよう案内する
  - 結果（実行日、OS、確認項目、合否、T127 の計測値）を `specs/001-three-pane-media-viewer/checklists/validation.md` に記録する

**Checkpoint**: ツリーの行のダブルクリックで開閉でき、開閉の三角はサブフォルダがあるフォルダにだけ表示される。
確認は表示中のフォルダの直下1階層だけで、ツリーの操作を止めない

---

## Phase 18: 画像・動画の種類フィルタ（FR-056〜060 追加、US3）

**Purpose**: ファイルリストを「画像のみ表示」「動画のみ表示」の2つの独立したオン・オフで絞り込めるようにする。
ツールバーでは表示形式ボタンの左に2つのボタンを置き、「表示」メニューと ⇧⌘I / ⇧⌘M でも切り替える。
状態は保存せず、起動中はフォルダを移っても保つ（[spec.md](./spec.md) FR-056〜060・US3 の受け入れシナリオ 11〜18、
[plan.md](./plan.md) の「変更点（画像・動画の種類フィルタ）」、[research.md](./research.md) R20、
[data-model.md](./data-model.md) の `FolderListing`・`MediaTypeFilter`・`SelectionState`、
[contracts/core-api.md](./contracts/core-api.md)「ブラウザ状態」「種類フィルタ」、
[contracts/keyboard-and-menus.md](./contracts/keyboard-and-menus.md)「ファイルリスト」「ツールバー」「メニューバー」、
[contracts/settings.md](./contracts/settings.md)）。

**Independent Test**: `swift test` で `MediaTypeFilter` の4通り・選択の整理・`.noMatches`・フォルダ移動後の保持が通ること。
`.app` で quickstart.md「種類フィルタ」の 1〜11 を確認し、ツールバーのボタン・メニューのチェック・⇧⌘I / ⇧⌘M が
同じ状態を示し、再起動で両方オフに戻ること。

### Tests for User Story 3

- [X] T133 [P] [US3] `Tests/MediaViewerCoreTests/MediaTypeFilterTests.swift`（新規、`@Suite("MediaTypeFilter")`）を先に書く
  （T137・T138 の前にビルドエラーになることを確認する）。`MediaFile` は既存の `BrowserModelTests` の `file(_:in:)` と同じ形の
  ヘルパーをこのファイル内に `private` で置いて作る:
  - data-model.md の表の 4 通り（`imagesOnly` × `videosOnly`）それぞれで、`includes(_:)` を `MediaKind.allCases` の全 6 種に対して
    検証する。片方だけオンのときは「画像（`!kind.isVideo`）だけ」または「動画（`kind.isVideo`）だけ」、両方オン・両方オフは全種 `true`
  - `isFiltering` は「片方だけがオン」の 2 通りだけ `true`
  - 既定値: `MediaTypeFilter()` は `imagesOnly == false`、`videosOnly == false`
  - `apply(to:)`: `["b.mov", "a.jpg", "c.mp4", "d.png"]` の順の入力に対し、画像のみで `["a.jpg", "d.png"]`、動画のみで
    `["b.mov", "c.mp4"]`、両方オフ・両方オンで入力と同じ並び（並び順を保つ）。空配列は空配列
  - `noMatchesMessage`: 画像のみで「画像のみ表示中: 該当するファイルはありません」、動画のみで
    「動画のみ表示中: 該当するファイルはありません」、両方オフ・両方オンで `nil`
  - `SelectionState.restricted(toVisible:)`（data-model.md の表の 3 行と追加の境界）:
    - フォーカスが表示中のまま: `selected = {a, v}`、`focused = a`、表示 `[a, b]` → `selected == {a}`、`focused == a`
    - フォーカスが非表示になり選択が残る: `selected = {a, c, v}`、`focused = v`、表示 `[c, b, a]` → `selected == {a, c}`、
      `focused == a`（表示の並び順で最後のもの。`Set` の列挙順に依存しないことを、表示順を入れ替えた
      `[a, b, c]` で `focused == c` になることでも確かめる）
    - 選択が残らない: `selected = {v}`、`focused = v`、表示 `[a, b]` → `selected` は空、`focused == nil`
    - フォーカスなし: `selected = {a}`、`focused = nil`、表示 `[a]` → `selected == {a}`、`focused == nil`
    - 表示が空: 任意の選択 → `selected` は空、`focused == nil`
- [X] T134 [P] [US3] `Tests/MediaViewerCoreTests/BrowserModelTests.swift` に種類フィルタのテストを先に追加する
  （T139 の前にビルドエラーになることを確認する）。既存の `makeModel(lister:decoder:)`・`file(_:in:)`・`waitUntil` を使う。
  読み直しのケースのため、`FakeLister` の `responses` を `var` にして `func setResponse(_ response: Response, for folder: URL)` を
  追加する（既存のテストの呼び出しは変えない）。フォルダの中身は `a.jpg`・`b.mov`・`c.png`・`d.mp4` を基本にする:
  - 既定: 新しい `BrowserModel` の `mediaTypeFilter == MediaTypeFilter()`。`selectFolder` 後の `listing.files` は 4 件すべて、
    `listing.state == .loaded`
  - 画像のみ: `setMediaTypeFilter(MediaTypeFilter(imagesOnly: true))` で `listing.files.map(\.name) == ["a.jpg", "c.png"]`。
    動画のみで `["b.mov", "d.mp4"]`。両方オンで 4 件すべてに戻る。両方オンから「画像のみ表示」だけをオフにする
    （`MediaTypeFilter(videosOnly: true)`）と `["b.mov", "d.mp4"]` になる（US3-13）
  - `.noMatches` と `.empty`: 画像だけのフォルダで動画のみ → `listing.state == .noMatches`、`files` は空。空のフォルダで動画のみ →
    `.empty`（`.noMatches` にならない）。絞り込みを両方オフに戻すと `.loaded`
  - フォルダ移動で保持: 動画のみにしてから別のフォルダへ `selectFolder` → `mediaTypeFilter.videosOnly == true` のままで、
    移動先も動画だけになる
  - 並べ替え: 動画のみの状態で `sortOrder` を名前の降順にする → `["d.mp4", "b.mov"]`。`.noMatches` の状態で並べ替えても
    `.noMatches` のまま
  - 読み直し: 動画のみの状態で `setResponse` により `e.mov` を追加し `reloadCurrentFolder()` → `["b.mov", "d.mp4", "e.mov"]`
  - 選択の整理: `a.jpg` と `b.mov` を選び `focused = b.mov` で画像のみ → `selection.selected == [a.jpg]`、`focused == a.jpg`、
    `waitUntil` でプレビューが `.image` になる。`focused = a.jpg` で画像のみ → 選択とフォーカスは変わらず、
    `preview` が `.loading` に戻らない（読み直さない）
  - 選択が残らない: `b.mov` だけを選んで画像のみ → `selection.selected` は空、`focused == nil`、`preview` は `.empty`。
    両方オフに戻しても `selection.selected` は空のまま（選択を戻さない）
  - 同じ値の再設定: 同じ `MediaTypeFilter` を `setMediaTypeFilter` しても `listing` と `selection` が変わらない
  - 保存しない: `setMediaTypeFilter` の前後で `defaults.persistentDomain(forName: suite)` のキーの集合が変わらない
- [X] T135 [P] [US3] `Tests/MediaViewerCoreTests/BrowserModelVideoTests.swift` に
  `@Test("再生中の動画が種類フィルタで隠れると停止の合図が増えプレビューが空になる")` を先に追加する（T139 の前に
  ビルドエラーになることを確認する）。既存の `emitsStopSignal` と同じ準備（`clip.mov` と `photo.jpg`）で `clip.mov` を選び、
  `stopPlaybackSignal` を記録してから `setMediaTypeFilter(MediaTypeFilter(imagesOnly: true))` を呼ぶ:
  - `stopPlaybackSignal == baseline + 1`
  - `preview` が `.empty`、`selection.focused == nil`、`listing.files.map(\.name) == ["photo.jpg"]`
  - `photo.jpg` が自動で選ばれていない（`selection.selected` が空）

- [X] T136 [P] [US3] `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift` に
  `@Test("10,000 件への種類フィルタの適用が 0.05 秒以内")` を先に追加する（T137 の前にビルドエラーになることを確認し、
  T137 の後に通ることを確認する）。既存の
  `hugeFolderListingAndSortingWithinBudget` と同じく `FixtureSets.huge(in:count: 10_000)` を列挙・並べ替えした配列を作り
  （準備は計測に含めない）、`MediaTypeFilter(imagesOnly: true).apply(to:)` と `MediaTypeFilter(videosOnly: true).apply(to:)` の
  合計時間を `ContinuousClock` で測る。画像のみで 10,000 件、動画のみで 0 件であることと、0.05 秒以内であることを確かめる
  （quickstart.md「性能の検証」の基準値）

### Implementation for User Story 3

- [X] T137 [P] [US3] `Sources/MediaViewerCore/Model/MediaTypeFilter.swift`（新規）に、contracts/core-api.md の
  `public struct MediaTypeFilter: Sendable, Equatable` を実装する（T133 に依存）:
  - `public var imagesOnly: Bool`・`public var videosOnly: Bool`、`public init(imagesOnly: Bool = false, videosOnly: Bool = false)`
  - `isFiltering`: `imagesOnly != videosOnly`
  - `includes(_ kind: MediaKind) -> Bool`: `isFiltering` でなければ `true`。`imagesOnly` なら `!kind.isVideo`、`videosOnly` なら `kind.isVideo`
  - `apply(to files: [MediaFile]) -> [MediaFile]`: `isFiltering` でなければ入力をそのまま返し、そうでなければ
    `files.filter { includes($0.kind) }`（並び順を保つ）
  - `noMatchesMessage: String?`: 画像のみで「画像のみ表示中: 該当するファイルはありません」、動画のみで
    「動画のみ表示中: 該当するファイルはありません」、それ以外は `nil`（FR-060）
  - AppKit を import しない
- [X] T138 [US3] `Sources/MediaViewerCore/Model/BrowserState.swift` を更新する（T133 に依存）:
  - `FolderListing.State` に `case noMatches` を `empty` の後に追加する（data-model.md「対象ファイルはあるが種類フィルタで
    1件も残らない状態（FR-060）」）
  - `extension SelectionState` に `public func restricted(toVisible orderedURLs: [URL]) -> SelectionState` を追加する。
    `selected` は `orderedURLs` に含まれるものだけにする。`focused` は data-model.md の表のとおりに決める:
    `nil` なら `nil` のまま（選択が残っていてもフォーカスを作らない）、`orderedURLs` に含まれればそのまま、
    含まれなければ（非表示になった場合だけ）`orderedURLs` を後ろから探して最初に `selected` に含まれるもの、なければ `nil`
  - T137 と合わせて `swift test --filter MediaTypeFilterTests` が通ることを確認する。`.noMatches` の追加で App の網羅的な
    `switch` がビルドエラーになるため、`swift build` は T140 の後に確認する
- [X] T139 [US3] `Sources/MediaViewerCore/Browser/BrowserModel.swift` に種類フィルタを組み込む（T134・T135・T137・T138 に依存）:
  - `public private(set) var mediaTypeFilter = MediaTypeFilter()` と、並べ替え済みの全件 `private var allFiles: [MediaFile] = []` を追加する。
    `SettingsStore` からは読まず、書かない（FR-056）
  - `private func rebuildListing()` を追加し、`listing.files = mediaTypeFilter.apply(to: allFiles)`、
    `listing.state` を「`allFiles` が空なら `.empty`、`listing.files` が空なら `.noMatches`、それ以外は `.loaded`」にする
  - `loadFolder(_:)` と `reloadCurrentFolder()` の成功時は `allFiles = sorted(files, by: sortOrder)` の後に `rebuildListing()` を呼ぶ。
    失敗時と `selectFolder(_:)` の開始時は `allFiles = []` にする。`reloadCurrentFolder()` の選択の扱い（`available` との
    積を取り、フォーカスが消えたらプレビューを空にする）は、絞り込み後の `listing.files` に対してそのまま行う
  - `sortOrder` の `didSet` は、対象の状態に `.noMatches` を加え、`allFiles` を並べ替えてから `rebuildListing()` を呼ぶ
  - `public func setMediaTypeFilter(_ filter: MediaTypeFilter)`: 同じ値なら何もしない。`mediaTypeFilter = filter` と
    `rebuildListing()` の後、`selection.restricted(toVisible: listing.files.map(\.url))` を求める。`focused` が変わらなければ
    `selection` だけを差し替えて `schedulePrefetch(around:)` を呼ぶ。変わる場合は `select(_:focused:)` を呼ぶ
    （停止の合図・プレビュー・先読みは既存の経路に任せる）
  - `selectFolder(_:)` は `mediaTypeFilter` を変えない
  - `swift test --filter BrowserModelTests` と `--filter BrowserModelVideoTests` が通ることを確認する
- [X] T140 [US3] App の網羅的な `switch` に `.noMatches` を加える（T139 に依存）:
  - `Sources/MediaViewerApp/FileList/FileListViewController.swift` の `refresh()`: `.noMatches` で
    `messageLabel.stringValue = model.mediaTypeFilter.noMatchesMessage ?? ""` とし、`messageLabel.isHidden = false` にする。
    `.empty` の文言「対応するメディアファイルがありません」は変えない。`updateModeVisibility()` は既存のまま
    （`.loaded` 以外は一覧を隠す）
  - `Sources/MediaViewerApp/App/MainSplitViewController.swift` の `deliverInitialListingIfReady()`: `.noMatches` を
    `.loaded, .empty, .denied, .failed` と同じ表示済みの扱いに加える
  - `swift build` と `swift test` が通ることを確認する
- [X] T141 [US3] `Sources/MediaViewerApp/FileList/FileListViewController.swift` にメニューと共通の入口を追加する（T140 に依存）:
  - `installViewMenuItems()` で「サムネイルを縮小」の後ろに `.separator()` と、`NSMenuItem(title: "画像のみ表示",
    action: #selector(toggleImagesOnly(_:)), keyEquivalent: "I")`・`NSMenuItem(title: "動画のみ表示",
    action: #selector(toggleVideosOnly(_:)), keyEquivalent: "M")` を追加する（大文字で ⇧⌘ になる。既存の ⇧⌘T と同じ書き方）。
    `target = self`、`weak var` で保持する
  - `func applyMediaTypeFilter(_ filter: MediaTypeFilter)`: `isEditingText` のときは変更せず、
    `onMediaTypeFilterChange?(model.mediaTypeFilter)` で呼び出し元の表示を元に戻す。それ以外は `model.setMediaTypeFilter(filter)`
  - `toggleImagesOnly(_:)` / `toggleVideosOnly(_:)` は現在の `model.mediaTypeFilter` の該当フィールドを反転して
    `applyMediaTypeFilter(_:)` に渡す
  - `var onMediaTypeFilterChange: ((MediaTypeFilter) -> Void)?` を追加する。`private func observeMediaTypeFilter()` を
    既存の `observeModel()` と同じ `withObservationTracking` の形で作り、`model.mediaTypeFilter` が変わるたびに
    メニューの `state`（オンなら `.on`）を更新して `onMediaTypeFilterChange` を呼ぶ。`viewDidLoad` から開始する。
    `.noMatches` の文言も変わるため `refresh()` も呼ぶ
  - `validateMenuItem(_:)`: 2 つの項目は `isEditingText` のとき `false`、それ以外は `true`
  - `var currentMediaTypeFilter: MediaTypeFilter { model.mediaTypeFilter }` を公開する（ツールバーの初期表示用）
  - 既存の表示形式・サイズのメニュー、下部バー、ファイル操作、フルスクリーン中の移動は変えない
- [X] T142 [US3] `Sources/MediaViewerApp/App/MainToolbarController.swift` に種類フィルタのボタンを追加する（T141 に依存）:
  - `private static let mediaTypeFilterIdentifier = NSToolbarItem.Identifier("mediaTypeFilter")` を追加し、
    `toolbarDefaultItemIdentifiers` と `toolbarAllowedItemIdentifiers` を
    `[mediaTypeFilter, viewMode, thumbnailSize, .flexibleSpace]` の順にする（FR-057）
  - `NSToolbarItemGroup(itemIdentifier:images:selectionMode: .selectAny, labels: ["画像のみ表示", "動画のみ表示"],
    target: self, action: #selector(mediaTypeFilterSelected(_:)))`。画像は
    `NSImage(systemSymbolName: "photo", accessibilityDescription: "画像のみ表示")` と `"film"`（「動画のみ表示」）。
    グループのラベルとツールチップは「種類」。各サブ項目の `toolTip` もラベルと同じにする
  - `mediaTypeFilterSelected(_:)`: `MediaTypeFilter(imagesOnly: sender.isSelected(at: 0), videosOnly: sender.isSelected(at: 1))`
    を `fileList.applyMediaTypeFilter(_:)` に渡す
  - `func apply(mediaTypeFilter: MediaTypeFilter)` で `setSelected(_:at:)` を 0 と 1 に合わせる。生成時に
    `fileList.currentMediaTypeFilter` で初期表示し、`init` で `fileList.onMediaTypeFilterChange` を登録して呼ぶ
  - 既存の表示形式・サイズの項目、`isVisible` の KVO と保存は変えない
- [X] T143 [P] [US3] `README.md` の「主な機能」と「使い方（主なショートカット）」の表に、種類フィルタ（ツールバーの
  「画像のみ表示」「動画のみ表示」ボタン、表示メニュー、⇧⌘I / ⇧⌘M。両方オン・両方オフはすべて表示。状態は保存されず、
  起動のたびに両方オフで始まる）を追記する

### Verification for User Story 3

- [X] T144 [US3] 自動テストと手動確認を行う（T133〜T143 に依存）:
  - `swift build`、`swift test`、`scripts/check-no-network.sh` を通す。T136 の計測値を記録する（憲章 原則 II）
  - `scripts/make-app.sh` で `.build/MediaViewer.app` を作り、ユーザーに起動と GUI 確認を依頼する。依頼時は
    `scripts/make-fixtures.sh ~/MediaViewerFixtures` の準備コマンドと、quickstart.md「種類フィルタ」の確認ポイント 1〜11 を
    具体的に示す。起動しない場合は AGENTS.md の lldb 手順で例外を止める
  - quickstart.md の 2・3 で `selectAny` のボタンの押された状態が判別しにくい場合は、research.md R20 の代替案
    （`.pushOnPushOff` の `NSButton` を 2 つの `NSToolbarItem` にする）へ切り替え、T142 を修正して再確認する
  - ⇧⌘I / ⇧⌘M がアプリに届かない（常駐アプリなどに先取りされる）場合は、作業を止めてユーザーにキーの変更を相談する
  - quickstart.md の 11 では、`huge/` のリスト形式とサムネイル形式のそれぞれで切り替えを繰り返し、画面収録または
    Instruments で表示の停止を測る。100ms 以上の停止が 0 回であることを確認し、計測方法と最大停止時間を記録する
    （憲章 原則 II）。基準を超えた場合は作業を止めて状況を報告する
  - 回帰確認: ⇧⌘T・⌘1 / ⌘2・⌘+ / ⌘-・ツールバーの表示形式とスライダー、⌘A・⌘C・⌘Delete（表示中のファイルだけが対象）、
    名前の変更、フルスクリーン中の矢印移動と ⌃⌘F / Esc、FSEvents による一覧の更新が従来どおり動く
  - 結果（実行日、OS、確認項目、合否、T136 の計測値、quickstart.md 11 の最大停止時間）を
    `specs/001-three-pane-media-viewer/checklists/validation.md` に記録する

**Checkpoint**: ツールバー・メニュー・⇧⌘I / ⇧⌘M でファイルリストを画像だけ・動画だけに絞り込める。両方オン・両方オフは
すべてを表示し、絞り込みはフォルダを移っても保たれ、再起動で両方オフに戻る

---

## Phase 19: お気に入り（FR-061〜067 追加、US1）

**Purpose**: ツリーの最上部に仮想的な「お気に入り」の見出し（スターのアイコン、開閉の三角付き、起動時は折りたたみ）を置き、
登録したフォルダを三角なしの項目として登録順に並べる。登録は右クリックメニューと ⌃⌘T、削除はお気に入りの項目の
右クリックメニューと ⌘⌫ で、どちらも確認モーダル（ファイル操作と同じ省略設定）を通す。⇧⌘F で見出しへ移動する。
登録はパスの配列として保存し、見つからなくなった項目は淡色で残す（[spec.md](./spec.md) FR-061〜067・US1 の受け入れシナリオ 10〜14、
[plan.md](./plan.md) の「変更点（お気に入り）」、[research.md](./research.md) R21、
[data-model.md](./data-model.md) の `FavoriteFolders`・`FavoriteAvailability`・`TreeItemRole と FavoriteCommands`、
[contracts/core-api.md](./contracts/core-api.md)「お気に入り」「設定」、
[contracts/keyboard-and-menus.md](./contracts/keyboard-and-menus.md)「ペイン間のフォーカス移動」「ディレクトリツリー」
「右クリックメニュー（ツリー）」「メニューバー」「確認モーダルと衝突ダイアログ」、[contracts/settings.md](./contracts/settings.md)）。

**Independent Test**: `swift test` で `FavoriteFolders`・`FavoriteCommands`・`FavoriteProbe`・`SettingsStore.favorites` のテストが通ること。
`.app` で quickstart.md「お気に入り（FR-061〜067）」の 1〜19 を確認し、登録・選択・⇧⌘F・削除（右クリック・⌘⌫、確認モーダル）・
再起動後の復元・見つからない項目の表示が期待どおりであること。

### Tests for User Story 1

- [X] T145 [P] [US1] `Tests/MediaViewerCoreTests/FavoriteFoldersTests.swift`（新規、`@Suite("FavoriteFolders")`）を先に書く
  （T149 の前にビルドエラーになることを確認する）。URL は `URL(fileURLWithPath: "/tmp/fav/a", isDirectory: true)` のように作る:
  - 既定: `FavoriteFolders()` の `urls` は空
  - `add`: `a`・`b`・`c` の順に追加すると `urls == [a, b, c]`（登録順、新しいものを末尾）。戻り値はすべて `true`
  - 重複: `a` を登録済みのとき、`a` そのもの・末尾に `/` を付けたパス（`URL(fileURLWithPath: "/tmp/fav/a/")`）・
    `..` を含むパス（`/tmp/fav/x/../a`）の `add` はどれも `false` を返し、`urls` は変わらない（「同一性は
    `standardizedFileURL.path` で判定し、重複を持たない」）
  - `contains`: 上の3通りの表記すべてで `true`、未登録の `d` で `false`
  - `remove`: 登録済みの `b` で `true`、`urls == [a, c]`（順序を保つ）。未登録の `d` で `false`、`urls` は変わらない。
    `..` を含む表記の `b` でも取り除ける
  - `init(urls:)`: `[a, b, a, c, b]` から `urls == [a, b, c]`（重複は先勝ちで除き、順序を保つ）
- [X] T146 [P] [US1] `Tests/MediaViewerCoreTests/FavoriteCommandsTests.swift`（新規、`@Suite("FavoriteCommands")`）を先に書く
  （T150 の前にビルドエラーになることを確認する）。data-model.md「TreeItemRole と FavoriteCommands」の表の全行を検証する。
  `folder = URL(fileURLWithPath: "/tmp/fav/folder")`、`favorites = FavoriteFolders(urls: [registered])` とする:
  - `canAdd`: `.folder(未登録)` で `true`。`.folder(registered)`・`.favorite(registered)`・`.favoritesHeader`・`nil`（選択なし）で `false`
  - `removalTarget`: `.favorite(url)` で `url`。`.folder`・`.favoritesHeader`・`nil` で `nil`
  - `contextMenu(for:)`: `.folder` で `[.pasteHere, .movePasteHere, .separator, .addToFavorites, .separator, .revealInFinder]`、
    `.favorite` で `[.removeFromFavorites]`、`.favoritesHeader` で `[]`（「`.favoritesHeader` は項目なし（メニューを出さない）」）
  - `folderToShow(for:)`: `.folder(url)` と `.favorite(url)` で `url`、`.favoritesHeader` で `nil`（FR-065）
  - `acceptsFiles`: `.folder` だけ `true`、`.favorite` と `.favoritesHeader` は `false`
- [X] T147 [P] [US1] `Tests/MediaViewerCoreTests/FavoriteProbeTests.swift`（新規、`@Suite("FavoriteProbe")`）を先に書く
  （T151 の前にビルドエラーになることを確認する）。一時ディレクトリは `DirectoryListerTests` の `makeTemporaryDirectory()` と
  同じ形の `private` ヘルパーで作り、`defer` で削除する。並列数の検証は `SubfolderProbeTests` と同じ組み立てにする:
  - `folderExists(_:)`: 存在するフォルダで `true`、存在しないパスで `false`、通常のファイルで `false`。
    権限のないフォルダ（`chmod 0o000`。テスト後に `0o755` へ戻してから削除する）は存在するので `true`
  - `results(for:maxConcurrent:exists:)`: 遅延するフェイクの `exists`（`actor` で同時実行数の最大値を記録する）で、
    6 件・上限 2 のとき全 URL が1回ずつ流れ、同時実行数が 2 を超えないこと。`exists` の結果がそのまま
    `FavoriteProbeResult.exists` になること
  - 空の入力ですぐに終わる。上限が 0 以下なら 1 として扱う
  - ストリームを最初の1件で抜けたら、未実行の確認を始めない（フェイクの呼び出し回数で確かめる）
- [X] T148 [P] [US1] `Tests/MediaViewerCoreTests/SettingsStoreTests.swift` に `favorites` のテストを先に追加する
  （T152 の前にビルドエラーになることを確認する）。既存の `withDefaults` を使う:
  - 未保存のとき `store.favorites == FavoriteFolders()`。既存の `usesDefaults` にも `#expect(store.favorites.urls.isEmpty)` を加える
  - 保存と読み戻し: `[/tmp/fav/b, /tmp/fav/a]` を保存すると、新しい `SettingsStore` で同じ順に読める。
    `defaults.array(forKey: "favorites.paths") as? [String] == ["/tmp/fav/b", "/tmp/fav/a"]`（絶対パスの文字列配列）
  - 不正値: `"favorites.paths"` に文字列 1 つ（配列でない）を入れると空。`["/tmp/fav/a", 3, "", "relative/path", "/tmp/fav/a"]` を
    入れると `urls == [/tmp/fav/a]`（文字列でない要素・空文字・相対パスは捨て、重複は先勝ちで除く）
  - ほかのキーを壊さない: `favorites` を保存しても `viewSettings`・`playback`・`confirmation` の値が変わらない

### Implementation for User Story 1

- [X] T149 [P] [US1] `Sources/MediaViewerCore/Model/FavoriteFolders.swift`（新規）に、contracts/core-api.md の
  `public struct FavoriteFolders: Sendable, Equatable` と `public enum FavoriteAvailability: Sendable, Equatable { case unknown, available, missing }` を
  実装する（T145 に依存）:
  - `public private(set) var urls: [URL]`、`public init(urls: [URL] = [])`（重複は先勝ちで除き、順序を保つ）
  - 同一性のキーは `url.standardizedFileURL.path` とし、`private static func key(_ url: URL) -> String` にまとめる。
    比較で `URL` 同士の `==` を使わない（末尾の `/` の有無で不一致になるため）
  - `contains(_:)`、`@discardableResult mutating func add(_:) -> Bool`（未登録なら末尾に追加して `true`、登録済みなら `false`）、
    `@discardableResult mutating func remove(_:) -> Bool`（登録済みなら取り除いて `true`、未登録なら `false`）
  - 並べ替え・名前の変更は持たない。AppKit を import しない
  - `swift test --filter FavoriteFoldersTests` が通ることを確認する
- [X] T150 [US1] `Sources/MediaViewerCore/Model/FavoriteCommands.swift`（新規）に、contracts/core-api.md の `TreeItemRole`・
  `TreeContextMenuItem`・`FavoriteCommands` を実装する（T146・T149 に依存）:
  - `canAdd(_:favorites:)`: `.folder(url)` かつ `!favorites.contains(url)` のときだけ `true`
  - `removalTarget(_:)`: `.favorite(url)` のときだけ `url`
  - `contextMenu(for:)`・`folderToShow(for:)`・`acceptsFiles(_:)`: T146 の期待値（data-model.md の表）のとおり
  - AppKit を import しない。`swift test --filter FavoriteCommandsTests` が通ることを確認する
- [X] T151 [P] [US1] `Sources/MediaViewerCore/FileSystem/FavoriteProbe.swift`（新規）に、contracts/core-api.md の
  `FavoriteProbeResult`（`url`・`exists`、`public init(url:exists:)`）と `FavoriteProbe` を実装する（T147 に依存）:
  - `folderExists(_:)`: `FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)` が `true` かつ
    `isDirectory.boolValue` のとき `true`
  - `results(for:maxConcurrent:exists:)`: `SubfolderProbe.results(for:lister:maxConcurrent:)` と同じ構造
    （`AsyncStream` の中で `withTaskGroup`、同時実行数は `max(1, maxConcurrent)`、`continuation.onTermination` で取り消し、
    取り消し後は次の URL を追加しない）。`exists` の既定値は `{ folderExists($0) }`
  - `swift test --filter FavoriteProbeTests` が通ることを確認する
- [X] T152 [US1] `Sources/MediaViewerCore/Settings/SettingsStore.swift` に `favorites` を追加する（T148・T149 に依存）:
  - `Keys.favoritePaths = "favorites.paths"`
  - `public var favorites: FavoriteFolders { get nonmutating set }`。読み込みは `defaults.object(forKey:) as? [Any]` で、
    配列でなければ `FavoriteFolders()`。要素は `String` かつ空でなく `hasPrefix("/")` のものだけを
    `URL(fileURLWithPath: path, isDirectory: true)` にし、`FavoriteFolders(urls:)` に渡す（重複はそこで除く）。
    書き込みは `newValue.urls.map(\.path)` を `defaults.set(_:forKey:)` する
  - 既存のキーの読み書きは変えない。`swift test --filter SettingsStoreTests` が通ることを確認する
- [X] T153 [P] [US1] `Sources/MediaViewerApp/Operations/ConfirmationPresenter.swift` に、お気に入りの削除の確認を追加する（App のみ）:
  - `func confirmRemovingFavorite(named name: String) async -> Bool`。`settings.confirmation.confirmBeforeFileOperations` が
    `false` なら確認せず `true`（FR-024・064）
  - 既存の `confirm(_:)` のシート表示（`NSAlert`、`beginSheetModal`、「今後この確認を表示しない」の `suppressionButton` と、
    オンのとき `ConfirmationOptions(confirmBeforeFileOperations: false)` を保存する処理）を
    `private func present(messageText:informativeText:confirmTitle:) async -> Bool` に切り出し、両方から使う。
    `confirm(_:)` のボタン名「実行」と文言は変えない
  - お気に入りの文言: `messageText` は「お気に入りから削除しますか？」、`informativeText` は「対象: <name>」と
    「実際のフォルダは変更されません」の2行、ボタンは「削除」と「キャンセル」（Esc でキャンセル、既存と同じ `keyEquivalent = "\u{1b}"`）
- [X] T154 [P] [US1] `Sources/MediaViewerApp/Shared/IconCatalog.swift` に `static func favoritesIcon() -> NSImage?` を追加する
  （`symbol(named: "star.fill", pointSize: 13)`。template 画像、a11y 要素にはしない）。既存のアイコンは変えない
- [X] T155 [P] [US1] `Sources/MediaViewerApp/Settings/SettingsWindowController.swift` の確認のチェックボックスの文言を
  「コピー・移動・名前の変更・ゴミ箱に入れる・お気に入りから削除する前に確認する」に変える（contracts/settings.md）。
  保存先のキーと動作は変えない
- [X] T156 [US1] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` に「お気に入り」の見出しと項目を表示する
  （T149・T150・T152・T153・T154 に依存）:
  - コンストラクタに `settings: SettingsStore` と `confirmation: ConfirmationPresenter` を追加する。
    `Sources/MediaViewerApp/App/MainSplitViewController.swift` の `init()` で、既存の `settings` から
    `ConfirmationPresenter(settings: settings)` を作って両方を渡す（ビルドを通すため同じタスクで直す）
  - 行の型を追加する: `final class FavoritesHeader`（インスタンスは `private let favoritesHeader` の1つだけ）と、
    `final class FavoriteEntry`（`let url: URL`、`var name: String`、`var kind: FolderNode.Kind`、
    `var availability: FavoriteAvailability = .unknown`）
  - `private var favorites = FavoriteFolders()` と `private var favoriteEntries: [FavoriteEntry] = []`。`viewDidLoad` の
    `roots` 作成後に `favorites = settings.favorites` を読み、`rebuildFavoriteEntries()` を呼ぶ。`rebuildFavoriteEntries()` は
    `favorites.urls` の順に項目を作り直し、同じ URL の既存の項目の `availability` を引き継ぐ。表示名と `kind` は、
    `roots` に `standardizedFileURL.path` が同じルートがあればそのルートの `name`・`kind`、なければ `lastPathComponent` と `.folder`
  - `private func role(for item: Any?) -> TreeItemRole?`: `FavoritesHeader` → `.favoritesHeader`、`FavoriteEntry` →
    `.favorite(url)`、`Node` → `.folder(url)`、それ以外 → `nil`
  - データソース: トップレベルは `[favoritesHeader] + roots`（`numberOfChildrenOfItem(nil)` は `roots.count + 1`、
    `child(0, nil)` は見出し、`child(i, nil)` は `roots[i - 1]`）。見出しの子は `favoriteEntries`。
    `isItemExpandable` は見出しで常に `true`（登録が0件でも開閉できる）、項目で `false`、`Node` は従来どおり
  - 見出しは `isGroupItem` にしない（`outlineView(_:isGroupItem:)` を実装しない）。起動時は展開しない（折りたたみで始める）
  - セル（`viewFor`）: 見出しは `IconCatalog.favoritesIcon()` と「お気に入り」、文字色 `.labelColor`、ツールチップなし。
    項目は `IconCatalog.treeIcon(for: entry.kind)` と `entry.name`。`.missing` のときは `disabledControlTextColor` と
    ツールチップ「見つかりません」、それ以外（`.unknown` を含む）は `.labelColor` とツールチップなし。既存の `Node` のセルは変えない
  - `outlineViewSelectionDidChange`: `updateWatchSet()` の後、選択行の `role(for:)` を `FavoriteCommands.folderToShow(for:)` に渡し、
    `nil`（見出し）なら何もしない（`selectFolder` を呼ばないため、ファイルリスト・プレビュー・`lastFolder` は変わらない。FR-065）。
    URL があれば従来どおり `model.selectFolder(url)` を呼ぶ。項目のときも実際の階層は展開・選択しない（FR-063）
  - `toggleClickedFolder(_:)`（ダブルクリック）: 見出しは `FolderDisclosure.doubleClickToggle(isExpandable: true, isExpanded:)` で開閉する。
    項目は開閉しない（選択だけ）。`Node` は従来どおり
  - `reveal(_:)`・`rowForURL(_:)`・`reloadChildren(of:)`・`displayedNodes()`・`flattenedNodes(from:)` は `roots` だけを見るまま変えない
    （お気に入りの項目を選択中でも、実際の階層の選択へ戻さない）
  - `swift build` が通ることを確認する
- [X] T157 [US1] 同じ `DirectoryTreeViewController.swift` に、登録・削除・右クリックメニュー・⌘⌫ を実装する（T156 に依存）:
  - `outlineView.menu` に `NSMenuDelegate` として `self` を設定し、`menuNeedsUpdate(_:)` でメニューを作り直す。対象の行は
    `outlineView.clickedRow >= 0` ならその行、なければ選択中の行。`FavoriteCommands.contextMenu(for:)` の各要素を
    「ここにペースト」「ここに移動ペースト」「お気に入りに追加」（⌃⌘T を表示: `keyEquivalent = "t"`、`[.command, .control]`）・
    「Finder に表示」「お気に入りから削除」（⌘Delete を表示: `keyEquivalent` は `NSBackspaceCharacter`、`[.command]`）・区切り線へ変換する。
    空なら項目なし（メニューを出さない）。各項目の `representedObject` に対象の行の item を入れる
  - 既存の `paste(_:)`・`movePaste(_:)`・`revealInFinder(_:)` は、`sender` が `representedObject` を持つ右クリックメニューの項目なら
    その行を、そうでなければ（⌘V などのキー操作）従来どおり選択中の行を対象にする。`FavoriteCommands.acceptsFiles` が `false` の行
    （見出し・項目）では何もせず、`validateMenuItem` でも無効にする
  - `validateDrop`・`acceptDrop`: `role(for: item)` が `acceptsFiles == false` のときは `[]` / `false` を返す（見出し・項目は
    ドロップ先にならない）。`Node` の判定は従来どおり
  - 登録: `@objc private func addToFavorites(_:)`（右クリックメニュー）と、`MainSplitViewController` から呼ぶ
    `func addSelectedFolderToFavorites()`・`var canAddSelectedFolderToFavorites: Bool`。可否は
    `FavoriteCommands.canAdd(role, favorites:)`。登録したら `settings.favorites = favorites`、`rebuildFavoriteEntries()`、
    下記の `reloadFavorites()`、存在の確認（T158）を行う。見出しの開閉状態は変えない
  - 削除: `private func removeFavorite(_ entry: FavoriteEntry) async`。`await confirmation.confirmRemovingFavorite(named: entry.name)` が
    `false` なら何もしない。`true` なら、選択中の行がその項目のときは先に見出しの行を選択してから（`selectFolder` は呼ばれない）、
    `favorites.remove(entry.url)`・`settings.favorites = favorites`・`rebuildFavoriteEntries()`・`reloadFavorites()` を行う
    （消えた行の位置で別の項目が自動で選ばれ、ファイルリストが切り替わるのを防ぐ）。実際のフォルダには触れない（FR-064）
  - `reloadFavorites()`: 選択中の item を記録し、`isRestoringSelection = true` の間に `outlineView.reloadItem(favoritesHeader, reloadChildren: true)` と
    同じ item の行の選択し直しを行う。`outlineViewSelectionDidChange` は `isRestoringSelection` の間は何もしない
  - 右クリックメニューの「お気に入りから削除」（`@objc private func removeFavoriteFromMenu(_:)`）は `representedObject` の項目を、
    ⌘⌫ の `@objc func moveToTrash(_:)` は選択中の項目を `removeFavorite(_:)` に渡す。どちらも対象は
    `FavoriteCommands.removalTarget(role)` が URL を返す行だけ
  - `validateMenuItem`: `moveToTrash(_:)` は選択中の行が項目のときだけ `true` にして `menuItem.title = "お気に入りから削除"`、
    それ以外は `false` にして `menuItem.title = "ゴミ箱に入れる"`（FR-064 の「何もしない」）。`addToFavorites(_:)` は
    `canAdd(右クリックした行の role)`
  - `func focusFavoritesHeader()`（⇧⌘F 用）: 見出しの行を選択し、`scrollRowToVisible`、折りたたまれていれば `expandItem`、
    `view.window?.makeFirstResponder(outlineView)` の順に行う（FR-065）
  - `swift build` が通ることを確認する
- [X] T158 [US1] 同じ `DirectoryTreeViewController.swift` に、見つからない項目の確認（FR-067）を実装する（T151・T157 に依存）:
  - `private var favoriteProbeTask: Task<Void, Never>?` と `private func refreshFavoriteAvailability()`。進行中の確認を取り消してから、
    全項目の URL で `FavoriteProbe.results(for:)` を始める。結果は同じ URL の項目の `availability` に `exists ? .available : .missing` で
    反映し、値が変わった行だけ `outlineView.reloadItem(entry)` する（行がなければ値だけ更新する）
  - 確認の契機: `viewDidLoad`（項目を作った後）、`volumeTask` のループ（`applyRoots` の後）、`NSApplication.didBecomeActiveNotification`
    （`MainSplitViewController.makeVolumeChanges()` と同じく `addObserver(forName:object:queue: .main)` で `viewDidLoad` で登録し、
    返るトークンを `private var activationObserver: NSObjectProtocol?` に保持する。ツリーはアプリの終了まで生きるため、
    `volumeTask`・`eventTask` と同じく解除はしない）、`eventTask` のループで変更された URL に
    登録したフォルダの親フォルダが含まれるとき、登録の直後、項目を選択したとき（`outlineViewSelectionDidChange`）
  - `updateWatchSet()`: 登録した各フォルダの親フォルダ（`deletingLastPathComponent().standardizedFileURL`。パスが `/` の登録は除く）を
    監視対象に加える
  - `applyRoots(_:)`: `reloadData()` の前に見出しが展開中かを記録し、後で展開し直す。`rebuildFavoriteEntries()` で
    表示名と `kind` を更新し、`refreshFavoriteAvailability()` を呼ぶ
  - 確認は UI スレッドで `stat` しない（`FavoriteProbe` のタスク内で行う）。`swift build` が通ることを確認する
- [X] T159 [US1] メニューとショートカットを結線する（T157 に依存）:
  - `Sources/MediaViewerApp/App/MainMenu.swift`: 「ファイル」メニューの「Finder に表示」の後ろに
    `NSMenuItem(title: "お気に入りに追加", action: #selector(MainSplitViewController.addSelectedFolderToFavorites(_:)), keyEquivalent: "t")`
    （`keyEquivalentModifierMask = [.command, .control]`、`target = nil`）を追加する。「ファイル」「編集」メニューの `delegate` に、
    `MainMenu` が static で保持する `NSObject` + `NSMenuDelegate` の小さなオブジェクトを設定し、`menuNeedsUpdate(_:)` で
    `action == #selector(FileListViewController.moveToTrash(_:))` の項目の `title` を「ゴミ箱に入れる」に戻す
    （プレビューにフォーカスがあるときに「お気に入りから削除」の項目名が残らないようにする）
  - `Sources/MediaViewerApp/App/MainSplitViewController.swift`:
    - `@objc func addSelectedFolderToFavorites(_:)` を追加し、`treeViewController.addSelectedFolderToFavorites()` を呼ぶ
    - `installFocusMenuItems()` で「プレビューへフォーカス」の後ろに
      `NSMenuItem(title: "お気に入りへ移動", action: #selector(focusFavorites(_:)), keyEquivalent: "F")`
      （`keyEquivalentModifierMask = [.command]`。大文字で ⇧⌘ になる、`target = self`）を追加する。`focusFavorites(_:)` は
      `treeViewController.focusFavoritesHeader()` を呼ぶ
    - `NSMenuItemValidation` を実装する: `focusFavorites(_:)` は `!panesCollapsedForFullScreen && !fileListViewController.isEditingText`。
      `addSelectedFolderToFavorites(_:)` は `!fileListViewController.isEditingText && treeViewController.canAddSelectedFolderToFavorites`。
      それ以外のアクションは `true`（既存の項目の有効・無効を変えない）
  - `Sources/MediaViewerApp/FileList/FileListViewController.swift`: `isEditingText` の `private` を外して内部公開にする。ほかは変えない
  - `swift build` と `swift test` が通ることを確認する
- [X] T160 [P] [US1] `README.md` の「主な機能」と「使い方（主なショートカット）」の表に、お気に入り（ツリー最上部の「お気に入り」、
  右クリックの「お気に入りに追加」と ⌃⌘T、お気に入りの項目の右クリックの「お気に入りから削除」と ⌘Delete（確認あり、実際のフォルダは
  変えない）、⇧⌘F で見出しへ移動、登録は保存され、見つからないフォルダは淡色で残る）を追記する

### Verification for User Story 1

- [X] T161 [US1] 自動テストと手動確認を行う（T145〜T160 に依存）:
  - `swift build`、`swift test`、`scripts/check-no-network.sh` を通す。`swift test` に含まれる `MediaViewerPerformanceTests` が
    quickstart.md「性能の検証」の基準内であることを確かめ、主な計測値を記録する（憲章 原則 II）
  - 存在の確認がツリーの操作を止めないことを確かめる: お気に入りを 20 件以上登録した状態で、アプリを前面に戻した直後
    （`NSApplication.didBecomeActiveNotification` による確認中）にツリーを ↑↓ で移動し続け、画面収録または Instruments で
    100ms 以上の停止が 0 回であることを確認する。計測方法と最大停止時間を記録し、基準を超えた場合は作業を止めて状況を報告する
  - `scripts/make-app.sh` で `.build/MediaViewer.app` を作り、ユーザーに起動と GUI 確認を依頼する。依頼時は
    `scripts/make-fixtures.sh ~/MediaViewerFixtures` の準備コマンドと、quickstart.md「お気に入り（FR-061〜067）」の確認ポイント 1〜19 を
    具体的に示す。起動しない場合は AGENTS.md の lldb 手順で例外を止める
  - ⌃⌘T または ⇧⌘F がアプリに届かない（常駐アプリなどに先取りされる）場合は、作業を止めてユーザーにキーの変更を相談する
  - 回帰確認: ツリーの ↑↓←→・ダブルクリックの開閉・開閉の三角（FR-053〜055）、通常のフォルダの右クリックの「ここにペースト」
    「ここに移動ペースト」「Finder に表示」が右クリックした行に効くこと、ファイルのツリーへのドロップ（⌥ でコピー）、
    ファイルリストの ⌘Delete（ゴミ箱）と確認モーダル、⌥⌘1〜3、フルスクリーンの ⌃⌘F / Esc、外付けボリュームの抜き差しが従来どおり動く
  - 結果（実行日、OS、確認項目、合否、性能テストの主な計測値、存在の確認中の最大停止時間）を
    `specs/001-three-pane-media-viewer/checklists/validation.md` に記録する

**Checkpoint**: ツリーの最上部の「お気に入り」から、登録したフォルダをすぐに開ける。右クリックと ⌃⌘T で登録、右クリックと ⌘⌫ で
確認のうえ削除でき、⇧⌘F で見出しへ移動できる。登録は再起動後も残り、見つからなくなったフォルダは淡色で残る

---

## Phase 20: zip ファイルの中の閲覧（FR-068〜071・073〜075 追加、US1）

**Purpose**: ファイルリストに zip ファイルを出し、ダブルクリックか ⌘↓ で zip の中の一覧（先頭行の `...`・ディレクトリ・対応メディア）を
ファイルリストの中だけで辿れるようにする。⌘↑ か `...` で戻り、戻った先では出てきた行を選択する。zip の中でも表示形式・並べ替え・
画像のプレビュー（アニメーションを含む）・縮小画像・フルスクリーン・種類フィルタを通常のフォルダと同じに使え、zip の中は読み取り専用にする。
zip は Core の自前の読み取り器で読み、一時ファイルを作らない。名前の文字コードは UTF-8 → CP932 → CP437 の順に判定する
（[spec.md](./spec.md) FR-068〜071・073〜075・US1 の受け入れシナリオ 15〜20、[plan.md](./plan.md) の「変更点（2026-10-21: zip ファイル）」、
[research.md](./research.md) R22〜R24・R26〜R28、[data-model.md](./data-model.md) の `ListItemKind`・`MediaFile`・`FolderListing`・
`ArchiveLocation`・`ArchiveURL`・`ArchiveIndex と ArchiveEntry`・`ArchiveIdentity`・`ListItemCommands`・`PreviewContent`・`FocusNavigator`、
[contracts/core-api.md](./contracts/core-api.md)「形式判定」「ブラウザ状態」「種類フィルタ」「プレビュー用デコード」「サムネイル」
「矢印キーによる選択移動」「zip」、[contracts/keyboard-and-menus.md](./contracts/keyboard-and-menus.md)「ファイルリスト」「プレビュー」
「右クリックメニュー（ファイルリスト）」「メニューバー」、[contracts/settings.md](./contracts/settings.md)）。
zip の中の動画の再生と代表フレームは Phase 21 で行う。Phase 20 の時点では、zip の中の動画は一覧に出て選択できるが再生されず、
行頭アイコンは汎用アイコンのままでよい。

**Independent Test**: `swift test` で `ArchiveURL`・`ArchiveNameDecoder`・`ZipStructure`・`ArchiveIndex`・`ZipArchiveReader`・`ListItemCommands`・
`BrowserModel` の zip の操作・`FocusNavigator` の読み飛ばしのテストが通ること。`.app` で quickstart.md「zip ファイル（FR-068〜075）」の
1〜7・10〜16 を確認し、zip の行・中の表示・戻る操作と選択・読み取り専用・文字コード・異常系・外部変更が期待どおりであること。

### Preparation for User Story 1

- [X] T162 [US1] テスト用の zip を書き出す `Sources/FixtureKit/CRC32.swift` と `Sources/FixtureKit/ZipFixtureWriter.swift`（どちらも新規、
  `public`）を作る（research.md R28。T164〜T174 のテストはこれを使う）:
  - `CRC32.checksum(_ data: Data) -> UInt32` と、追記用の `update(_ crc: UInt32, _ bytes: UnsafeRawBufferPointer) -> UInt32`
    （多項式 0xEDB88320 の表引き。`"123456789"` で 0xCBF43926 になる）
  - `ZipFixtureEntry`: `name: String`、`rawName: Data?`（指定時は名前のバイト列をそのまま書く。CP932 の名前用）、
    `content: Content`（`.bytes(Data)` / `.zeros(count: UInt64)`。`.zeros` は全体をメモリに持たずに書く）、
    `method: Method`（`.stored` / `.deflated` / `.raw(UInt16)`。`.raw` は方式番号だけを書き、中身は無圧縮のまま）、
    `utf8Flag: Bool`（既定 true、汎用フラグのビット 11）、`encryptedFlag: Bool`（既定 false、ビット 0 を立てるだけで暗号化はしない）、
    `isDirectory: Bool`（名前の末尾を `/` にし、中身は空）、`usesDataDescriptor: Bool`（既定 false、ビット 3 とデータ記述子）、
    `modificationDate: Date`（DOS 日時で書く）、`unixModificationTime: Date?`（指定時は拡張タイムスタンプ 0x5455 を書く）
  - `ZipFixtureWriter.write(_ entries: [ZipFixtureEntry], to url: URL, forceZip64: Bool = false, comment: Data = Data()) throws`:
    ローカルヘッダ・データ・（必要なら）データ記述子・中央ディレクトリ・終端レコードを順に書く。deflate は Compression の
    `compression_stream`（`COMPRESSION_STREAM_ENCODE`、`COMPRESSION_ZLIB`）で 1MB ずつ圧縮して書き、CRC とサイズを書きながら計算する。
    `forceZip64` かサイズ・位置が 0xFFFFFFFF 以上なら、ZIP64 拡張フィールド（0x0001）・ZIP64 終端レコード・ロケータを書く。
    出力は `FileHandle` に追記し、1GB の `.zeros` を書く間もメモリの増加を 16MB 以下（1MB の圧縮の入出力バッファ程度）に保つ
  - `ZipFixtureWriter.archiveData(_ entries: [ZipFixtureEntry]) throws -> Data`: 同じ内容をメモリ上に作る（小さな解析テスト用）
  - `swift build` が通ることを確認する
- [X] T163 [US1] 一覧の行の種類を加える（R23）。`Sources/MediaViewerCore/Model/MediaKind.swift` に `ListItemKind`（`.media(MediaKind)` / `.archive` /
  `.directory` / `.parent`、`Sendable`・`Hashable`）と `isMedia`・`mediaKind`・`isVideo`（`.media` の動画だけ true）・
  `opensAsContainer`（`.archive` / `.directory` / `.parent` で true）を追加する。`Sources/MediaViewerCore/Model/MediaFile.swift` の `kind` の型を
  `ListItemKind` にする。続けて、ビルドが通るように既存の参照を直す:
  - `Sources/MediaViewerCore/FileSystem/DirectoryLister.swift`: `kind: .media(kind)`、`typeDescription` の既定は `kind.rawValue.uppercased()` のまま
  - `Sources/MediaViewerCore/Model/MediaTypeFilter.swift`: `includes` を `file.kind.mediaKind` で判定する（この時点では `.media` 以外は来ない）
  - `Sources/MediaViewerCore/Model/Sorting.swift`: 種類の第2キーを `ListItemKind` の文字列表現（`.media` は `MediaKind.rawValue`、ほかは
    `"archive"`・`"directory"`・`"parent"`）で比べる
  - `Sources/MediaViewerCore/Browser/BrowserModel.swift` の `file.kind.isVideo` は `ListItemKind.isVideo` でそのまま通す
  - `Sources/MediaViewerApp/Shared/IconCatalog.swift`: `fallbackIcon(for: MediaKind)` は残し、呼び出し側（`ListModeView`・`ThumbnailModeView`）は
    `file.kind.mediaKind` があるときだけ呼ぶ（メディア以外の行のアイコンは T190 で加える。この時点では nil でよい）
  - テスト（`SortingTests`・`MediaTypeFilterTests`・`BrowserModelTests`・`BrowserModelVideoTests`）の `MediaFile(... kind: .jpeg ...)` を
    `kind: .media(.jpeg)` に置き換える。期待値は変えない
  - `swift build` と `swift test`（既存のテスト）が通ることを確認する。新しいテスト（T164〜T174）はこのタスクの後に書く

### Tests for User Story 1

- [X] T164 [P] [US1] `Tests/MediaViewerCoreTests/ArchiveURLTests.swift`（新規、`@Suite("ArchiveURL")`）を先に書く（T175 の前にビルドエラーになる
  ことを確認する）。zip は `URL(fileURLWithPath: "/tmp/z/写真 集.zip")`:
  - `entry(archive:path: "sub/a b.jpg")` の `scheme == "mvzip"`、`lastPathComponent == "a b.jpg"`、`pathExtension == "jpg"`、`isFileURL == false`
  - `parse` で `(archive, "sub/a b.jpg", false)` に戻る。日本語・空白・`#`・`?`・`%` を含むパスと zip のパスでも往復で一致する
  - ディレクトリ `entry(archive:path: "sub/")` は末尾 `/` を保ち、最上位 `entry(archive:path: "")` は `mvzip:///?archive=…`
  - `parentLink(of: ArchiveLocation(archive:, directory: "sub/"))` の `fragment == "parent"`、`parse` の `isParentLink == true`、パスは `"sub/"`。
    同じ階層の `parentLink` 同士は `==`、別の階層とは `!=`
  - 同じ引数で作った URL は `==` で、`Set<URL>` で1つにまとまる。ファイル URL や `mvzip` 以外のスキームの `parse` は nil
  - `ArchiveLocation.parent`: `"a/b/"` → `"a/"`、`"a/"` → `""`、`""` → nil
- [X] T165 [P] [US1] `Tests/MediaViewerCoreTests/ArchiveNameDecoderTests.swift`（新規、`@Suite("ArchiveNameDecoder")`）を先に書く（FR-074、R27）:
  - `utf8Flag: true` の `"写真.jpg"` の UTF-8 バイト列 → `"写真.jpg"`。不正なバイトを含む場合も落ちずに置換文字を含む文字列を返す
  - `utf8Flag: false` で UTF-8 として正しいバイト列 → UTF-8 で読む（`"日本語/画像.png"`）
  - `utf8Flag: false` で CP932 のバイト列（`"写真①.jpg"` を `CFStringConvertEncodingToNSStringEncoding(CFStringEncodings.dosJapanese)` で
    エンコードしたもの）→ `"写真①.jpg"`。`"表示.png"`（2バイト目が 0x5C の文字を含む）も壊れない
  - `utf8Flag: false` で UTF-8 でも CP932 でもないバイト列（例: `[0x80, 0xFF, 0x41]`）→ CP437 で読んだ文字列（`"ÇA"` の前後を含む3文字）
  - ASCII だけの名前はフラグに関わらず同じ結果
- [X] T166 [P] [US1] `Tests/MediaViewerCoreTests/ZipStructureTests.swift`（新規、`@Suite("ZipStructure")`）を先に書く。入力は
  `ZipFixtureWriter.archiveData` の `Data`:
  - 終端レコードの探索: コメントなし・コメント 1KB・コメント 65535 バイトで見つかる。末尾が切れた `Data` と、ランダムな 1KB では
    `ArchiveError.notAZip`
  - 中央ディレクトリの解析: 名前のバイト列・汎用フラグ・方式・CRC・サイズ・ローカルヘッダの位置・DOS 日時・拡張フィールドが書いた値と一致する
  - データ記述子（ビット 3）の項目でも、サイズは中央ディレクトリの値になる
  - `forceZip64: true` の zip で、ZIP64 の終端レコードとロケータを辿り、ZIP64 拡張フィールドのサイズと位置を読む
  - 終端レコードのディスク番号を 1 に書き換えた `Data` → `ArchiveError.multiDisk`。中央ディレクトリの位置がファイルの外を指す → `.notAZip`
  - ローカルヘッダの解析: 名前の長さと拡張フィールドの長さから、データの開始位置（ローカルヘッダの位置 + 30 + 名前 + 拡張）を返す。
    中央ディレクトリと拡張フィールドの長さが違う項目でも正しい位置を返す
  - 0x5455 の更新時刻（UTC）を読み、なければ DOS 日時を `TimeZone.current` で `Date` にする
- [X] T167 [P] [US1] `Tests/MediaViewerCoreTests/ArchiveIndexTests.swift`（新規、`@Suite("ArchiveIndex")`）を先に書く（data-model の
  「ArchiveIndex と ArchiveEntry」）:
  - ディレクトリの項目がない `sub/deep/a.jpg` だけの zip で、`items(in: "")` は `sub`（`.directory`）、`items(in: "sub/")` は `deep`、
    `items(in: "sub/deep/")` は `a.jpg`（`.media(.jpeg)`）を返す
  - 「一覧に出さない項目: 名前の要素が `.` で始まるもの、`__MACOSX/` 以下、`..` を含む名前、対応メディア以外のファイル（入れ子の zip を含む）」:
    `.hidden.jpg`・`.git/x.png`・`__MACOSX/._a.jpg`・`a/../b.jpg`・`readme.txt`・`inner.zip` が出ない
  - 先頭の `/`・空の要素・`.` は取り除く（`/x//./y.png` → `x/y.png`）。`\` は名前の一部（`a\b.jpg` は最上位の1項目）
  - 「同じパスの重複は、中央ディレクトリで先に出たものを使う。ファイルとディレクトリが同じ名前ならディレクトリとして扱う」
  - `readability`: 方式 0・8 で暗号化なし → `.readable`、ビット 0 → `.encrypted`、方式 12 → `.unsupportedMethod`。3件とも `items(in:)` に出る
  - 行の値: `name` は判定後の名前、`creationDate` は更新日時、`fileSize` は展開後のサイズ、ディレクトリの `typeDescription == "フォルダ"`、
    メディアの `typeDescription` は空でない。`url` は `ArchiveURL.entry(archive:path:)` と一致する
  - `items(in:)` は `...` を含まない。存在しない階層は空配列
  - CP932 の名前（UTF-8 フラグなし）の `フォルダ/画像.png` で、`フォルダ` の中に `画像.png` が出る（FR-074）
- [X] T168 [P] [US1] `Tests/MediaViewerCoreTests/ZipArchiveReaderTests.swift`（新規、`@Suite("ZipArchiveReader")`）を先に書く。既存のテストと同じく、
  ファイル内の非公開の `makeTemporaryDirectory()`（`FileManager.default.temporaryDirectory` の下に UUID のフォルダを作る）に zip を書いて使い、テスト後に削除する:
  - `open` で索引ができ、`identity` のサイズ・更新日時・inode が `stat` と一致する
  - `data(for:limit:)`: 無圧縮・deflate・データ記述子・ZIP64 の各項目で、書いた内容と一致する
  - 展開後のサイズが `limit` を超える項目 → `.tooLarge`（読み出さずに失敗する）。暗号化 → `.entryEncrypted`、方式 12 → `.unsupportedMethod(12)`
  - 存在しない zip → `.notFound`。権限 `0o000` の zip → `.accessDenied`（テスト後に権限を戻す）。テキストの `.zip` と途中で切れた zip → `.notAZip`
    または `.corrupted`。どれもクラッシュしない
  - 索引にない項目の URL → `.corrupted`（または `.notFound`）。zip を開いた後に削除・上書きした場合の `identity(of:)` は nil・別の値になる
  - 同じ reader で2つの zip を交互に読んでも結果が混ざらない
  - `ArchiveError.message`: `.notAZip` → 「zip を開けません: zip ファイルとして読めません」、`.multiDisk` →
    「zip を開けません: 分割された zip には対応していません」、`.entryEncrypted` → 「暗号化されているため表示できません」、
    `.unsupportedMethod` → 「対応していない圧縮方式です」、`.tooLarge` → 「zip の中の画像が大きすぎるため表示できません」
- [X] T169 [P] [US1] `Tests/MediaViewerCoreTests/ListItemCommandsTests.swift`（新規、`@Suite("ListItemCommands")`）を先に書く。data-model の
  「ListItemCommands」の表の全行を検証する（`kind` 4種 + nil × `isBrowsingArchive` の true / false）。特に、zip の外の `.archive` は
  `allowsFileOperations == true`・`canOpenContainer == true`、zip の中はどの行でも `allowsFileOperations == false`・`allowsPaste == false`・
  `canGoUp == true`、`.media` の `canOpenContainer == false`、zip の外の `canGoUp == false`
- [X] T170 [P] [US1] `Tests/MediaViewerCoreTests/FocusNavigatorTests.swift` に `isNavigable` 付きのケースを追加する（FR-046）:
  - リスト形式で `[media, dir, dir, media]`、位置 0 から ↓ → 3。位置 3 から ↑ → 0
  - グリッド 2 列で `[parent, dir, media, media]`、位置 2 から ↑ → nil（上の行に移動できる行がない）。位置 3 から ← → 2
  - 移動先の方向にメディアがない（`[media, dir, dir]` の位置 0 から ↓）→ nil。全部がメディアでない → nil
  - `currentIndex: nil` → 先頭から順に最初のメディアの位置。メディアがなければ nil
  - `isNavigable` が常に true のとき、既存の関数と同じ結果になる（既存のケースを流用して比べる）
- [X] T171 [P] [US1] `Tests/MediaViewerCoreTests/MediaTypeFilterTests.swift` と `Tests/MediaViewerCoreTests/SortingTests.swift` にケースを追加する:
  - `apply(to:)`: `imagesOnly` で `.archive`・`.directory`・`.parent` の行が残り、並び順も保つ。`videosOnly` でも同じ
  - 並べ替え: `.parent` を含む配列を名前・作成日・種類の昇順と降順で並べても、`.parent` は先頭。ディレクトリとメディアは区別なく名前の
    自然順に混ざる（`b`（ディレクトリ）が `a.jpg` と `c.png` の間に入る）
- [X] T172 [P] [US1] `Tests/MediaViewerCoreTests/DirectoryListerTests.swift` と `Tests/MediaViewerCoreTests/ImageDecoderTests.swift` にケースを追加する:
  - `mediaFiles(in:)` が `a.zip` と `B.ZIP` を `kind == .archive` で返し、`typeDescription` が空でない。`x.zip` という名前の**ディレクトリ**は返さない。
    `.hidden.zip` は返さない
  - `subfolders(of:)` と `hasSubfolders(in:)` は zip ファイルを数えない（zip だけのフォルダで `false`）
  - `decode(data:maxPixelSize:)` が JPEG・PNG のファイルの中身から、ファイル URL の `decode` と同じ `pixelSize` を返す。壊れた `Data` は
    `.corrupted` か `.unreadable`。`isAnimated(data:)` はアニメーション GIF で true、静止画 PNG で false
- [X] T173 [US1] `Tests/MediaViewerCoreTests/BrowserModelArchiveTests.swift`（新規、`@Suite("BrowserModel の zip")`、`@MainActor`）を先に書く。
  一時フォルダに `cover.jpg` と `photos.zip`（`sub/deep/a.jpg`・`b.png`・`anim.gif`・`readme.txt`）を作り、実際の `DirectoryLister`・
  `ImageDecoder`・`ZipArchiveReader` で `BrowserModel` を作る:
  - `selectFolder` 後の `listing.files` に `photos.zip`（`.archive`）と `cover.jpg` が並び、`listing.state == .loaded`
  - zip の行を選ぶとプレビューは `.empty`（FR-075）。動画を再生中（`.video`）に zip の行へ移ると `stopPlaybackSignal` が増える
  - `openItem(<zip の URL>)`: `listing.archive == ArchiveLocation(archive:, directory: "")`、`listing.folder` は一時フォルダのまま、
    `files[0].kind == .parent`、続いて `sub`・`anim.gif`・`b.png`（名前の自然順、`readme.txt` なし）、選択は空、プレビューは `.empty`
  - `openItem(sub)` → `openItem(deep)` → `goToEnclosingLevel()` で `sub/` の一覧に戻り、`selection.selected == [deep の URL]`・
    `focused == deep の URL`。もう一度で最上位に戻り `sub` が選ばれる。もう一度でフォルダの一覧に戻り、`photos.zip` の行が選ばれ、
    `listing.archive == nil`。さらに `goToEnclosingLevel()` は何もしない
  - `openItem(<parent 行の URL>)` は `goToEnclosingLevel()` と同じ結果。メディアの行の `openItem` は何もしない
  - zip の中で `b.png` を選ぶと `.image`、`anim.gif` を選ぶと `.animatedImageData(url, data)` になる（`.loading` を経て）
  - `settings.viewSettings.lastFolder` は zip に入っても戻っても一時フォルダのまま（FR-003）
  - zip の中で `selectFolder(<別のフォルダ>)` を呼ぶと `listing.archive == nil` で、そのフォルダの一覧になる（FR-069）
  - 空の判定（FR-060）: `readme.txt` だけの zip で `files == [parent]`・`.empty`。ディレクトリだけの zip で `.loaded`。画像だけの zip で
    `videosOnly` にすると `files == [parent]`（とディレクトリ）・`.noMatches`。zip だけのフォルダは `.loaded`
  - 壊れた zip の `openItem` で `.failed("zip を開けません: …")`・`files == [parent]`。`goToEnclosingLevel()` で戻れる
  - 暗号化の画像を選ぶと `.unavailable(name:, reason: "暗号化されているため表示できません")`
  - FSEvents: zip の中で、zip を書き換えて（内容を変えて書き直す）`handleFileSystemEvent([一時フォルダ])` を呼ぶと、`listing.archive == nil` で
    フォルダの一覧に戻り、プレビューは `.empty`。zip を変えずに同じ呼び出しをした場合は zip の中のまま変わらない。zip を削除した場合も戻る
  - zip の中で `reloadCurrentFolder()` を呼んでも、zip の中の一覧のまま変わらない
- [X] T174 [P] [US1] `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift` に、10,000 個の小さな JPEG（各 1KB 前後、無圧縮）を持つ
  zip の `ZipArchiveReader.open` と `items(in: "")` の合計が 0.5 秒以内であることの計測を追加する（SC-015、quickstart.md「性能の検証」）。
  zip の生成時間は計測に含めない

### Implementation for User Story 1

- [X] T175 [P] [US1] `Sources/MediaViewerCore/Archive/ArchiveURL.swift` と `Sources/MediaViewerCore/Archive/ArchiveLocation.swift`（どちらも新規）を
  作り、T164 を通す。data-model の「ArchiveURL」の形（`mvzip:///<項目のパス>?archive=<zip の絶対パス>`、ディレクトリは末尾 `/`、最上位は空のパス、
  `...` は表示中の階層の URL + `#parent`）を `URLComponents` の `percentEncodedPath` と `percentEncodedQueryItems` で組み立て、文字列の連結はしない。
  パスの各要素は `/` 以外を `.urlPathAllowed` から `#`・`?`・`%`・`;` を除いた集合でエンコードする。`ArchiveLocation` は `archive: URL`・
  `directory: String`（「最上位は ""、それ以外は "a/b/"」）と `parent` を持つ
- [X] T176 [P] [US1] `Sources/MediaViewerCore/Archive/ArchiveNameDecoder.swift`（新規）を作り、T165 を通す（R27 の 1〜4 の順。CP932 は
  `CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosJapanese.rawValue))`、CP437 は `.dosLatinUS` を
  `String(data:encoding:)` に渡す。UTF-8 の厳密な判定は `String(validating:as: UTF8.self)` を使う）
- [X] T177 [US1] `Sources/MediaViewerCore/Archive/ArchiveError.swift` と `Sources/MediaViewerCore/Archive/ZipStructure.swift`（どちらも新規）を作り、
  T166 を通す（R22）:
  - `ArchiveError`（contracts/core-api.md の case）と `message`（T168 の文言。`.notFound` は「zip を開けません: zip ファイルが見つかりません」、
    `.accessDenied` は「zip を開けません: アクセスできません」、`.corrupted(reason)` は「zip を開けません: \(reason)」）
  - `ZipStructure` は `Data` を受けて構造体を返す純粋関数の集まりにし、ファイルを読まない:
    `endOfCentralDirectory(inTail:fileSize:)`（末尾 `min(fileSize, 65_557)` バイトの中で署名 0x06054b50 を後ろから探す。ディスク番号が 0 以外なら
    `.multiDisk`）、`zip64Locator(_:)`・`zip64EndOfCentralDirectory(_:)`、`centralDirectoryEntries(_:count:)`（署名 0x02014b50、
    ZIP64 拡張 0x0001 のうち値が 0xFFFFFFFF / 0xFFFF の項目だけを順に読む）、`dataOffset(localHeader:localHeaderOffset:)`（署名 0x04034b50）、
    `modificationDate(dosDate:dosTime:extra:)`。すべての読み出しで範囲を確かめ、範囲外は `.notAZip` か `.corrupted` にしてクラッシュしない
- [X] T178 [US1] `Sources/MediaViewerCore/Archive/ArchiveIndex.swift`（新規）に `ArchiveIndex`・`ArchiveEntry`・`ArchiveIdentity` を作り、T167 を通す。
  data-model の表のとおりに名前を `ArchiveNameDecoder` で判定し、パスを正規化し、隠し項目・`__MACOSX/`・`..`・重複・ファイルとディレクトリの衝突を扱い、
  途中のディレクトリを補った `children` を作る。`items(in:)` は直下のディレクトリ（`.directory`）と対応メディア（`MediaKind(fileExtension:)` が nil でない
  ファイル、`.media`）だけを `MediaFile` にして返す（並べ替えはしない）。メディアの `typeDescription` は
  `UTType(filenameExtension:)?.localizedDescription ?? 拡張子の大文字`、ディレクトリは「フォルダ」。`readability` を `ArchiveEntry` に持たせる
- [X] T179 [US1] `Sources/MediaViewerCore/Archive/InflateCursor.swift`（新規）を作る（R24・R25）。`compression_stream_init(..., COMPRESSION_STREAM_DECODE,
  COMPRESSION_ZLIB)` を包む `final class`。入力は「zip ファイルの記述子・データの開始位置・圧縮後のサイズ」から 64KB ずつ `pread` で読む。
  `position`（展開後の位置）、`reset()`（先頭から展開し直す）、`skip(to:)`（読み捨てて進む）、`read(into:maxLength:)`（展開して返す）を持つ。
  圧縮データの終わりより先を求められたら、展開できた分だけを返す。`deinit` で `compression_stream_destroy` を呼ぶ。直接のテストは T168 の
  deflate の読み出しで兼ねる
- [X] T180 [US1] `Sources/MediaViewerCore/Archive/ZipArchiveReader.swift`（新規）に `ArchiveReading` プロトコル（contracts/core-api.md の `open`・
  `data(for:limit:)`・`identity(of:)`。`stream(for:)` は Phase 21 の T203 で加える）と、その実装 `ZipArchiveReader`（`final class`、`@unchecked Sendable`、
  内部は `NSLock`）を作り、T168 を通す（R22・R24）:
  - zip ファイルは `open(2)`（`O_RDONLY`）で開き、記述子を `ArchiveFile`（`deinit` で `close`）として参照カウントで共有する。読み出しはすべて `pread`
  - `open`: `fstat` で `ArchiveIdentity` を作り、末尾を読んで `ZipStructure` で解析し、中央ディレクトリを1回の `pread` で読んで `ArchiveIndex` を作る。
    最後に開いた 2 つの zip の索引と `ArchiveFile` を、パスをキーに覚える（`data(for:)` で項目を引くため）。処理は `Task.detached` で行い、UI スレッドで読まない
  - `data(for:limit:)`: `ArchiveURL.parse` → 索引の項目 → `readability` を確かめ（`.encrypted` / `.unsupportedMethod`）→ 展開後のサイズを `limit` と比べ →
    ローカルヘッダからデータの開始位置を求めて項目ごとに覚え → 無圧縮は `pread`、deflate は `InflateCursor` で全体を読む。読んだサイズが展開後のサイズと
    違えば `.corrupted`
  - `identity(of:)`: `stat` の結果。消えていれば nil
  - `Sources/MediaViewerCore/Imaging/MemoryLimits.swift` に `archiveImageBytes = 512 * 1024 * 1024` を追加する（「1項目 512MB」）
- [X] T181 [P] [US1] `Sources/MediaViewerCore/Model/ListItemCommands.swift`（新規）を作り、T169 を通す（data-model の「ListItemCommands」の表のとおり）
- [X] T182 [P] [US1] `Sources/MediaViewerCore/Layout/FocusNavigator.swift` に `isNavigable` 付きの `targetIndex` を追加し、T170 を通す。既存の関数で
  1歩ずつ進め、`isNavigable` が true の行に当たるか nil になるまで繰り返す（最大 `fileCount` 回）。既存の関数の結果は変えない
- [X] T183 [P] [US1] `Sources/MediaViewerCore/Model/MediaTypeFilter.swift` の `apply(to:)` で `kind.isMedia == false` の行を常に残し、
  `Sources/MediaViewerCore/Model/Sorting.swift` の `sorted` で `.parent` の行を取り除いてから並べ、先頭に戻す。T171 を通す
- [X] T184 [P] [US1] `Sources/MediaViewerCore/FileSystem/DirectoryLister.swift` の `mediaFiles(in:)` で、ディレクトリでない拡張子 `zip`（大文字小文字を
  区別しない）のファイルを `kind: .archive` の `MediaFile` として返す（`typeDescription` は `localizedTypeDescription`、なければ「ZIP アーカイブ」）。
  プロトコルの説明コメントを contracts/core-api.md の文言に合わせる。T172 の前半を通す
- [X] T185 [P] [US1] `Sources/MediaViewerCore/Imaging/ImageDecoder.swift` に `decode(data:maxPixelSize:)` と `isAnimated(data:)` を追加し、プロトコル
  `ImageDecoding` にも加える。`CGImageSourceCreateWithData` から先は、ファイル URL の `decodeSynchronously` と同じ判定（対応する型・フレーム数・
  サムネイルのオプション・`byteCost`）を共有する関数にまとめる。テスト用のフェイクの `ImageDecoding`（`BrowserModelTests` など）にも実装を足す。T172 の後半を通す
- [X] T186 [US1] `Sources/MediaViewerCore/Model/BrowserState.swift` に `FolderListing.archive: ArchiveLocation?`（イニシャライザの既定引数 nil）と
  `PreviewContent.animatedImageData(URL, Data)` を追加する。網羅的な `switch` を持つ `Sources/MediaViewerApp/Preview/PreviewViewController.swift` には、
  この時点では `.animatedImageData` を `.loading` と同じ表示にする仮の分岐を入れ（T196 で置き換える）、`swift build` を通す
- [X] T187 [US1] `Sources/MediaViewerCore/Browser/BrowserModel.swift` に zip の中の移動を加える（R23・R26、contracts/core-api.md「ブラウザ状態」）:
  - イニシャライザに `archiveReader: any ArchiveReading = ZipArchiveReader()` を追加する。`private var archiveIndex: ArchiveIndex?` を持つ。
    `public var isBrowsingArchive: Bool { listing.archive != nil }`
  - `selectFolder(_:)` の先頭の「読み込み・プレビュー・先読みの取り消し、動画の停止、選択とプレビューを空にする」処理を `private func resetForNavigation()`
    に切り出し、`selectFolder` と zip の移動で共有する。`selectFolder` では `archiveIndex = nil` にする（`FolderListing` の `archive` は既定の nil）
  - `openItem(_ url:)`: `listing.files` から行を探し、`.archive` なら `resetForNavigation()` → `listing = FolderListing(folder: listing.folder, files: [],
    state: .loading, archive: ArchiveLocation(archive: url, directory: ""))` → `archiveReader.open(url)` を待ち、取り消されていない・同じ位置のままなら
    `archiveIndex` に入れて一覧を作る。失敗したら `allFiles = []`・`listing.state = .failed(error.message)`。`.directory` なら索引から（読み直さずに）その階層の
    一覧を作る。`.parent` なら `goToEnclosingLevel()`。`.media` と見つからない URL では何もしない
  - `goToEnclosingLevel()`: zip の外なら何もしない。`listing.archive.parent` があれば、その階層の一覧を作り、直前の階層のディレクトリの URL
    （`ArchiveURL.entry(archive:path: 直前の directory)`）を `select([url], focused: url)` する。最上位なら `archiveIndex = nil`、`listing.folder` を
    ディスクから読み直し（`lastFolder` は書き換えない）、zip のファイル URL の行を同じく選択する（行が消えていれば何も選ばない）
  - `rebuildListing()`: zip の中なら `files = [parent 行] + mediaTypeFilter.apply(to: allFiles)`（`parent` 行は `MediaFile(url: ArchiveURL.parentLink(of:),
    name: "...", kind: .parent, typeDescription: "", creationDate: nil, fileSize: 0)`）。状態は data-model の「FolderListing」の規則で決める:
    メディアも `...` 以外の行もない → `.empty`、絞り込み前にメディアがあり後に0件 → `.noMatches`、それ以外 → `.loaded`（`.failed` のときは呼ばない）
  - `sortOrder` の `didSet` と `reloadCurrentFolder()`: zip の中では `allFiles` を並べ直して `rebuildListing()` するだけにし、`reloadCurrentFolder()` は
    zip の中なら何もしない（フォルダの一覧で zip の中の一覧を上書きしない）
  - `handleFileSystemEvent`: zip の中で、通知に `listing.folder` が含まれていたら `archiveReader.identity(of:)` を `archiveIndex.identity` と比べ、
    nil か違えば `archiveIndex = nil` にしてフォルダの一覧を読み直し、選択とプレビューを空にする。同じなら何もしない。フォルダ自体が消えた場合の既存の
    処理はそのまま
  - T173 のうち、移動・選択・空の判定・FSEvents・`lastFolder` のケースを通す
- [X] T188 [US1] `Sources/MediaViewerCore/Browser/BrowserModel.swift` のプレビューと先読みを zip に対応させる（R24・R26）:
  - `loadPreview(for:)`: `listing.files` の行の `kind` を先に見て、メディアでなければ `.empty`（FR-075）。`MediaKind(fileExtension:)` による判定は
    行が見つからないときだけ使う
  - `ArchiveURL.parse(url) != nil` の画像: 索引の項目の `readability` が `.encrypted` / `.unsupportedMethod` なら `.unavailable(name:, reason: error.message)`。
    それ以外はキャッシュにあれば `.image`、なければ `.loading(url)` にしてから、タスクで `archiveReader.data(for: url, limit: MemoryLimits.archiveImageBytes)`
    → `decoder.isAnimated(data:)` なら `.animatedImageData(url, data)`、静止画なら `decoder.decode(data:maxPixelSize:)` → キャッシュに入れて `.image`。
    失敗は `.unavailable(name:, reason: ArchiveError.message または既存の理由)`。世代番号の確認は既存のとおり
  - `ArchiveURL.parse(url) != nil` の動画: 既存どおり `.video(url)`（再生は Phase 21）
  - `schedulePrefetch(around:)`: zip の中の画像では同期の `decoder.isAnimated(url)` を呼ばずに、タスクの中で `Data` を読み、アニメーションでなければデコードして
    キャッシュに入れる。動画とメディア以外の行は先読みしない
  - T173 の残り（`.image`・`.animatedImageData`・暗号化・プレビューの空・動画の停止通知）を通す。`swift test` がすべて通ることを確認する
- [X] T189 [US1] `Sources/MediaViewerCore/Imaging/ThumbnailProvider.swift` を zip の中の画像に対応させる（R24）。イニシャライザに
  `archiveReader: (any ArchiveReading)? = nil` を追加する。`ArchiveURL.parse(url) != nil` のとき QuickLook を使わず、同時 4 件までに制限した
  （`actor` の簡単なセマフォ）タスクで `data(for:limit: MemoryLimits.archiveImageBytes)` → `CGImageSourceCreateWithData` →
  `CGImageSourceCreateThumbnailAtIndex`（`kCGImageSourceThumbnailMaxPixelSize` = 段階に丸めたピクセル数、`CreateThumbnailWithTransform`、`FromImageAlways`）。
  キャッシュのキーは既存のもの。`cancel(for:pointSize:scale:)` は zip の中の要求のタスクも URL + ピクセル数で取り消す。zip の中の動画・暗号化・
  非対応方式・失敗では nil を返す（動画は Phase 21 の T205 で対応する）。`Tests/MediaViewerCoreTests/ThumbnailProviderTests.swift` に、zip の中の PNG で
  画像が返ること・暗号化の項目で nil が返ることを追加する
- [X] T190 [P] [US1] `Sources/MediaViewerApp/Shared/IconCatalog.swift` に `listItemIcon(for kind: ListItemKind, pointSize: CGFloat) -> NSImage?` を追加する。
  `.media` は既存の `fallbackIcon` と同じ名前、`.archive` は `doc.zipper`、`.directory` は `folder`、`.parent` は `arrowshape.turn.up.left`（template）。
  `fallbackIcon(for:)` はこの関数を `pointSize: 16` で呼ぶ形にする
- [X] T191 [US1] 組み立てとメニューを結線する:
  - `Sources/MediaViewerApp/App/MainSplitViewController.swift` の `init()` で `ZipArchiveReader()` を1つ作り、`BrowserModel(... archiveReader:)` と
    `ThumbnailProvider(archiveReader:)` に渡す。インスタンスを保持する
  - `Sources/MediaViewerApp/App/MainMenu.swift`: 「ファイル」メニューの「開く」の直後に
    `NSMenuItem(title: "中を表示", action: #selector(FileListViewController.openFocusedItem(_:)), keyEquivalent: String(UnicodeScalar(NSDownArrowFunctionKey)!))`
    と、`NSUpArrowFunctionKey` の「上の階層へ」（`#selector(FileListViewController.goToEnclosingLevel(_:))`）を追加する。どちらも
    `keyEquivalentModifierMask = [.command]`、`target = nil`
- [X] T192 [US1] `Sources/MediaViewerApp/FileList/FileListViewController.swift` を zip に対応させる（R26、contracts/keyboard-and-menus.md）:
  - `@objc func openFocusedItem(_:)`: テキスト編集中なら何もしない。フォーカス行の URL で `openItem(_ url: URL)` を呼ぶ。`openItem(_:)`（内部公開）は
    `Task { await model.openItem(url); <戻った場合はフォーカス行を見える位置へ> }`。リスト形式とサムネイル形式のダブルクリックからも呼ぶ
  - `@objc func goToEnclosingLevel(_:)`: テキスト編集中なら何もしない。`await model.goToEnclosingLevel()` の後、リスト形式は
    `ListModeView` のフォーカス行を `scrollRowToVisible`、サムネイル形式は `thumbnailModeView.scrollToFocused()` を呼ぶ（FR-070）
  - `validateMenuItem`: `openFocusedItem` はテキスト編集中でなく、フォーカス行の `ListItemCommands.canOpenContainer` が true のとき有効。
    `goToEnclosingLevel` はテキスト編集中でなく `model.isBrowsingArchive` のとき有効。`model.isBrowsingArchive` のときは `copy`・`open`・
    `revealInFinder`・`moveToTrash`・`duplicate`・`rename`・`paste`・`movePaste` を無効にする（FR-073）
  - `copy`・`paste`・`movePaste`・`duplicate`・`rename`・`moveToTrash`・`open`・`revealInFinder` の先頭で、`model.isBrowsingArchive` なら何もせずに戻る
  - `refresh()`・`updateModeVisibility()`: `.empty` / `.noMatches` / `.failed` でも `listing.files` が空でなければ一覧を表示したまま、一覧の下端に
    高さ 24pt のメッセージの帯（`NSTextField` のラベル、`secondaryLabelColor`、帯は一覧のスクロールビューの下端に制約し、下部のサイズバーより上）を出して
    メッセージを入れる。`files` が空のときは従来どおり中央のメッセージ。`.empty` の文言は既存のもの、`.noMatches` は `noMatchesMessage`、`.failed` はその文字列
  - `moveFocusInFullScreen(_:)`: `FocusNavigator.targetIndex(..., isNavigable: { files[$0].kind.isMedia })` を使う（FR-046）
- [X] T193 [US1] `Sources/MediaViewerApp/FileList/ListModeView.swift` を zip に対応させる:
  - `tableView.target = self`・`doubleAction` を設定し、`clickedRow` が有効なら、その行を単一選択にしてから `onOpenItem?(url)` を呼ぶ
    （`var onOpenItem: ((URL) -> Void)?` を追加し、T192 で `FileListViewController.openItem(_:)` に結ぶ）
  - `FileListTableView.keyDown`: Command だけを押した ↓ / ↑（`specialKey == .downArrow / .upArrow`）は `super` に渡さずに消費する（メニュー項目が無効なときの
    既定の動作を止める、R26）
  - `onReturn`: フォーカス行の `ListItemCommands(kind:isBrowsingArchive:)` の `allowsFileOperations` が false なら、名前の変更を始めずに true を返す（FR-073）
  - `pasteboardWriterForRow`: 同じ判定が false の行では nil を返す（ドラッグを始めない）
  - 名前のセル: メディア以外の行は `IconCatalog.listItemIcon(for:pointSize: 16)` を設定し、縮小画像を要求しない（取り消しの対象にもしない）。
    `.parent` の行は名前を `...`、a11y のラベルを「上の階層へ」にする。「作成日」「種類」の列は既存の表示（nil は「--」）
- [X] T194 [US1] `Sources/MediaViewerApp/FileList/ThumbnailModeView.swift` を zip に対応させる:
  - `ThumbnailCollectionView.mouseDown(with:)` を override し、`super` の後に `event.clickCount == 2` なら、その位置の項目を `onDoubleClickItem?(index)` で伝える。
    `ThumbnailModeView` はその行を単一選択にしてから `onOpenItem?(url)` を呼ぶ（T192 で結ぶ）
  - `keyDown`: Command だけの ↓ / ↑ を消費する。`onReturnKey`: T193 と同じ判定で名前の変更を始めない
  - `pasteboardWriterForItemAt`: T193 と同じ判定で nil を返す
  - `ThumbnailItemView.configure(with:)`・`requestThumbnail(for:)`: メディア以外の行は `IconCatalog.listItemIcon(for:pointSize:)`（サムネイルの大きさの半分程度）を
    中央に出し、縮小画像を要求しない。`.parent` の a11y のラベルは「上の階層へ」
- [X] T195 [US1] `Sources/MediaViewerApp/FileList/FileContextMenu.swift`: メニューの先頭に「中を表示（⌘↓）」（`openFocusedItem(_:)`）と「上の階層へ（⌘↑）」
  （`goToEnclosingLevel(_:)`）と区切り線を追加する。どちらも宛先を `host` にし、有効・無効は T192 の `validateMenuItem` に任せる。
  `menuNeedsUpdate(_:)` で、`host` の `model.isBrowsingArchive` が true なら「上の階層へ」を表示し、false なら隠す。zip の中ではペースト・移動ペーストの
  `isEnabled` を false にする（contracts/keyboard-and-menus.md「右クリックメニュー（ファイルリスト）」）
- [X] T196 [US1] アニメーションの `Data` を表示する:
  - `Sources/MediaViewerApp/Preview/ImagePreviewView.swift`: アニメーションの元を `enum AnimatedSource { case url(URL), data(Data) }` にし、
    `showAnimated(source:fileName:fallback:)` で `.url` は既存の `CGAnimateImageAtURLWithBlock`、`.data` は `CGAnimateImageDataWithBlock(data as CFData, nil, …)` を
    使う。停止・「視差効果を減らす」の扱い・フォールバックは既存の処理を共有する。既存の `showAnimated(url:fileName:fallback:)` は `.url` を渡す形にする
  - `Sources/MediaViewerApp/Preview/PreviewViewController.swift`: T186 の仮の分岐を置き換え、`.animatedImageData(url, data)` では
    `decoder.decode(data:maxPixelSize:)` をフォールバックにして `showAnimated(source: .data(data), …)` を呼ぶ。表示前に `model.preview` が同じ URL のままかを
    既存どおり確かめる
- [X] T197 [P] [US1] `Sources/FixtureKit/FixtureSets.swift` に `zip(in:)` を追加し、`makeAll(in:)` に加える。quickstart.md「検証用フォルダの準備」の `zip/` の表の
  ファイルをすべて作る（画像・動画の中身は既存の `ImageFixtures`・`VideoFixtures` の生成物を使う）。`huge.zip` は 10,000 個の小さな JPEG:
  - `Sources/FixtureKit/VideoFixtures.swift` の `mp4(at:…)`・`mov(at:…)` に `fastStart: Bool = false`（true なら `AVAssetWriter.shouldOptimizeForNetworkUse = true`
    で再生用の情報を先頭に置く）と `averageBitRate: Int? = nil`（指定時は `AVVideoCompressionPropertiesKey` の `AVVideoAverageBitRateKey`）を追加する。
    既定値では従来と同じファイルになる（再生用の情報は末尾）
  - `videos-stored.zip`: 無圧縮で、640×360 の mp4・mov と、SC-014 の再生開始の計測用の 1080p の mp4（`width: 1920, height: 1080, seconds: 10`、
    `fastStart: true`）を入れる
  - `videos-deflated.zip`: deflate で、`fastStart: true` の mp4 と、既定（再生用の情報が末尾）の mov を入れる
  - `scripts/make-fixtures.sh ~/MediaViewerFixtures` で `zip/` ができることを確認する
  - 大きな動画（SC-014 のメモリの確認用）: `FixtureSets.bigVideoZips(in:)` を追加し、`zip-big/` に、1080p・`averageBitRate: 60_000_000`・150 秒の
    mp4（フレームは毎フレーム変わる模様にして、実際に約 1.1GB になるようにする）を、無圧縮で格納した `big-video-stored.zip` と deflate で格納した
    `big-video-deflated.zip` を作る。生成に時間とディスク（約 2.3GB）を使うため `makeAll` には含めず、`Sources/make-fixtures/main.swift` の
    `--big` 引数のときだけ作る。`scripts/make-fixtures.sh` は2番目以降の引数を `make-fixtures` へそのまま渡すようにする
    （`scripts/make-fixtures.sh ~/MediaViewerFixtures --big`）
- [X] T198 [P] [US1] `README.md` の「主な機能」と「使い方（主なショートカット）」の表に、zip の中の表示（ダブルクリック・⌘↓ で中を表示、⌘↑ または `...` で
  戻る、ツリーには出ない）、zip の中は読み取り専用であること、日本語のファイル名の自動判定を追記する

### Verification for User Story 1

- [X] T199 [US1] 自動テストと手動確認を行う（T162〜T198 に依存）:
  - `swift build`、`swift test`、`scripts/check-no-network.sh` を通す。`swift test` に含まれる `MediaViewerPerformanceTests` が quickstart.md「性能の検証」の
    基準内であることを確かめ、10,000 項目の zip の索引作成の時間を記録する（憲章 原則 II）
  - SC-015 の操作の継続を確かめる: `huge.zip` をダブルクリックした直後から、ツリーを ↑↓ で移動し続け、ファイルリストのスクロールも行う。
    画面収録または Instruments で、100ms 以上の停止が 0 回で、最初の項目が 1 秒以内に出ることを確認する。計測方法・最大停止時間・最初の項目までの
    時間を記録し、基準を超えた場合は作業を止めて状況を報告する
  - `scripts/make-app.sh` で `.build/MediaViewer.app` を作り、ユーザーに起動と GUI 確認を依頼する。依頼時は
    `scripts/make-fixtures.sh ~/MediaViewerFixtures` の準備コマンドと、quickstart.md「zip ファイル（FR-068〜075）」の確認ポイント 1〜7・10〜16 を
    具体的に示す（8・9 の動画は Phase 21 で確認する）。起動しない場合は AGENTS.md の lldb 手順で例外を止める
  - ⌘↓ / ⌘↑ がアプリに届かない（常駐アプリなどに先取りされる）場合は、作業を止めてユーザーにキーの変更を相談する
  - 回帰確認: 通常のフォルダのリスト形式・サムネイル形式の矢印キー・⇧ + 矢印・⌘A・Return の名前の変更・⌘C / ⌘V / ⌥⌘V / ⌘D / ⌘Delete・ツリーへのドラッグ・
    右クリックメニュー、種類フィルタ（FR-056〜060）、フルスクリーンの矢印移動（FR-046）、行頭アイコン（FR-048）、ツリーの操作が従来どおり動く
  - 結果（実行日、OS、確認項目、合否、性能テストの主な計測値）を `specs/001-three-pane-media-viewer/checklists/validation.md` に記録する

**Checkpoint**: ファイルリストの zip ファイルをダブルクリックか ⌘↓ で開き、ディレクトリを辿り、`...` か ⌘↑ で戻れる。zip の中の画像は通常のフォルダと
同じにプレビュー・サムネイル・フルスクリーンで見られ、zip の中は変更できない。日本語の名前の zip も文字化けしない

---

## Phase 21: zip の中の動画のストリーミング再生（FR-071・072、SC-014 追加、US1）

**Purpose**: zip の中の動画（mp4 / mov）を、一時ファイルにもメモリ全体にも展開せず、AVPlayer の範囲要求に応じて必要な部分だけを zip から読んで
再生する。無圧縮の項目は直接読み、deflate の項目は順方向の展開カーソル 2 本と 32MB のチャンクキャッシュで読む。代表フレーム（サムネイル・
行頭アイコン）も同じ仕組みで作る（[spec.md](./spec.md) FR-071・072・SC-014・US1 の受け入れシナリオ 17・19、[plan.md](./plan.md) の
「変更点（2026-10-21: zip ファイル）」、[research.md](./research.md) R25、[data-model.md](./data-model.md) の `ArchiveEntryStream`、
[contracts/core-api.md](./contracts/core-api.md)「zip」）。

**Independent Test**: `swift test` で `ArchiveEntryStream` と `ArchiveAssetLoader` のテスト、展開後 1GB の項目の読み出しのメモリの計測が通ること。
`.app` で quickstart.md「zip ファイル（FR-068〜075）」の 8・9 を確認し、zip の中の動画がループ再生・シーク・停止でき、一時ファイルが作られないこと。

### Tests for User Story 1

- [X] T200 [P] [US1] `Tests/MediaViewerCoreTests/ArchiveEntryStreamTests.swift`（新規、`@Suite("ArchiveEntryStream")`）を先に書く（T203 の前に
  ビルドエラーになることを確認する）。中身は 0〜255 を繰り返す 5MB のバイト列（位置が分かるもの）を、無圧縮と deflate で格納した zip を使う:
  - `length` が展開後のサイズと一致する
  - `read(offset:maxLength:)` を、先頭・1MB の境界をまたぐ位置・末尾の手前・末尾ちょうど（空の `Data`）・末尾より先（空の `Data`）で呼び、
    元のバイト列の同じ範囲と一致する
  - deflate で、位置 4MB → 1MB → 3MB → 0 の順（後ろ向きを含む）に読んでも一致する。2 か所の離れた位置を交互に 20 回読んでも一致する
  - 複数のタスクから同時に別々の範囲を読んでも、それぞれ一致する（スレッド安全）
  - 暗号化・方式 12 の項目の `ZipArchiveReader.stream(for:)` → `.entryEncrypted` / `.unsupportedMethod(12)`
  - 一時ファイルを作らないこと（FR-072）は、このテストでは判定しない。共有の一時ディレクトリは、並列に動くほかのテストもフィクスチャを
    作るため、中身の増減では判定できない。代わりに `scripts/check-no-archive-writes.sh`（T203 で追加）で、`Sources/MediaViewerCore/Archive/` に
    書き込み系の API（`forWritingAtPath`・`createFile`・`write(to:`・`FileHandle(forWritingTo:`・`O_WRONLY`・`O_RDWR`・`O_CREAT`）が現れないことを確かめる。
    実行時の確認は T207 の `fs_usage` で行う
- [X] T201 [P] [US1] `Tests/MediaViewerCoreTests/ArchiveAssetLoaderTests.swift`（新規、`@Suite("ArchiveAssetLoader")`）を先に書く。`VideoFixtures` の
  mp4 と mov（再生用の情報が末尾）を、無圧縮と deflate で格納した zip を使う:
  - `ArchiveAssetFactory.makeAsset(for:reader:)` の asset で `try await asset.load(.duration)` が、元のファイルの `AVURLAsset` の `duration` と一致する
    （4 通りすべて）。`load(.tracks)` に動画のトラックがある
  - `AVAssetImageGenerator(asset:)` の `image(at: .zero)` が画像を返す
  - asset を作った関数を抜けた後も（読み込み器を外から保持していなくても）読み込みが完了する（asset が読み込み器を保持していること）
  - 暗号化の項目の asset では `load(.duration)` が失敗し、クラッシュしない
- [X] T202 [P] [US1] `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift` に SC-014 の計測を追加する（R25）。`ZipFixtureWriter` で
  `.zeros(count: 1 << 30)` を deflate で格納した `zeros.mp4` の zip を一時ディレクトリに作る（生成は計測に含めない）。`ZipArchiveReader.stream(for:)` で
  先頭から末尾まで 512KB ずつ読み、続けて 900MB・100MB・10MB の位置（後ろ向き）から各 4MB を読む。64 回の読み出しごとに `task_info`（`TASK_VM_INFO`）の
  `phys_footprint` を測り、読み出し前からの最大の増加が 128MB 以下であることを確かめる。最大の増加量と所要時間を出力する

### Implementation for User Story 1

- [X] T203 [US1] `Sources/MediaViewerCore/Archive/ArchiveEntryStream.swift`（新規）を作り、`ArchiveReading` に `stream(for:)` を加えて `ZipArchiveReader` に
  実装し、T200 を通す（R25、data-model の「ArchiveEntryStream」）。T200 の `scripts/check-no-archive-writes.sh`（実行権限付き、`scripts/check-no-network.sh` と
  同じ書き方）を追加し、通ることを確かめる:
  - `final class ArchiveEntryStream: @unchecked Sendable`。`length`（展開後のサイズ）と `read(offset:maxLength:) throws(ArchiveError) -> Data`。
    `ArchiveFile` を保持する（zip を閉じた後も読み出せる）。内部は `NSLock` で1回の `read` ごとに直列化する
  - 無圧縮: 「要求範囲を `pread` で直接読む」。キャッシュしない
  - deflate: 1MB 単位のチャンクで読む。チャンクは LRU キャッシュ（合計 `MemoryLimits.archiveStreamCacheBytes = 32 * 1024 * 1024`、`MemoryLimits.swift` に追加）に置く。
    キャッシュにないチャンクは、`InflateCursor` を最大 2 本の LRU から、位置がチャンクの先頭以下で最も近いものを選んで `skip(to:)` で進めて作る。
    どれも先頭より後ろにいれば、最も古く使ったカーソルを `reset()` する
  - `read` は `offset` から `maxLength` まで（末尾で打ち切る）をチャンクから組み立てて返す
- [X] T204 [US1] `Sources/MediaViewerCore/Archive/ArchiveAssetLoader.swift`（新規）に `ArchiveAssetLoader`（`NSObject`、`AVAssetResourceLoaderDelegate`、
  `@unchecked Sendable`）と `ArchiveAssetFactory` を作り、T201 を通す（R25）:
  - `makeAsset(for:reader:)`: `AVURLAsset(url: entryURL)` を作り、`resourceLoader.setDelegate(loader, queue: <専用の直列キュー>)` を設定し、
    `objc_setAssociatedObject(asset, <static のキー>, loader, .OBJC_ASSOCIATION_RETAIN)` で asset に読み込み器を保持させる
  - `resourceLoader(_:shouldWaitForLoadingOfRequestedResource:)`: true を返し、要求ごとに `Task.detached` を始めて、要求の識別子で覚える。タスクは
    最初に `reader.stream(for:)` を1回だけ作って共有し、`contentInformationRequest` があれば `contentType = UTType(filenameExtension:)?.identifier`、
    `contentLength = Int64(stream.length)`、`isByteRangeAccessSupported = true` を入れる。`dataRequest` があれば、`currentOffset` から
    `requestsAllDataToEndOfResource` なら末尾まで、そうでなければ `requestedOffset + requestedLength` まで、512KB ずつ `read` して `respond(with:)` で返し、
    各チャンクの間で `Task.isCancelled` を確かめる。最後に `finishLoading()`、失敗は `finishLoading(with: NSError)`（説明に `ArchiveError.message`）
  - `resourceLoader(_:didCancel:)`: そのタスクを取り消して、識別子を忘れる
- [X] T205 [US1] `Sources/MediaViewerCore/Imaging/ThumbnailProvider.swift`: zip の中の動画で、`ArchiveAssetFactory.makeAsset(for:reader:)` の asset から
  `AVAssetImageGenerator`（`appliesPreferredTrackTransform = true`、`maximumSize` = 段階に丸めたピクセル数の正方形）の `image(at: .zero)` で代表フレームを作る。
  zip の中の動画の取得は同時 2 件までに制限する（画像の 4 件とは別）。`Tests/MediaViewerCoreTests/ThumbnailProviderTests.swift` に、zip の中の mp4 で
  画像が返ることを追加する
- [X] T206 [US1] zip の中の動画をプレビューで再生する:
  - `Sources/MediaViewerApp/Preview/VideoPreviewView.swift`: `configure(asset: AVAsset, autoplay:loop:fileName:)` を追加し、既存の `configure(url:…)` は
    `AVURLAsset(url:)` を作ってこれを呼ぶ形にする。`AVPlayerItem(asset:)` を使う。ループ・終端の停止・再生状態の扱いは変えない
  - `Sources/MediaViewerApp/Preview/PreviewViewController.swift`: イニシャライザに `archiveReader: any ArchiveReading` を追加する。`.video(url)` で
    `ArchiveURL.parse(url) != nil` なら `ArchiveAssetFactory.makeAsset(for: url, reader: archiveReader)` を渡し、それ以外は従来どおり URL を渡す
  - `Sources/MediaViewerApp/App/MainSplitViewController.swift`: T191 の `ZipArchiveReader` を `PreviewViewController` にも渡す
  - os_signpost の `VideoPlaybackStart` は zip の中の動画でも同じく記録する（変更不要であることを確認する）

### Verification for User Story 1

- [X] T207 [US1] 自動テストと手動確認を行う（T200〜T206 に依存）:
  - `swift build`、`swift test`、`scripts/check-no-network.sh` を通す。T202 の最大のメモリ増加量と所要時間を記録する。128MB を超えた場合は
    作業を止めて状況を報告する（憲章 原則 II）
  - `scripts/make-app.sh` で `.build/MediaViewer.app` を作り、ユーザーに起動と GUI 確認を依頼する。依頼時は quickstart.md「zip ファイル（FR-068〜075）」の
    確認ポイント 8・9 と、Instruments（Points of Interest）での `videos-stored.zip` の 1080p 動画の `VideoPlaybackStart`（1 秒以内）の計測手順、
    `sudo fs_usage -w -f filesys MediaViewer` で zip 以外への書き込みがないことの確認手順を具体的に示す
  - SC-014 のメモリを必ず確かめる: `scripts/make-fixtures.sh ~/MediaViewerFixtures --big` で `zip-big/` を作り、`big-video-stored.zip` と
    `big-video-deflated.zip` の動画をそれぞれ再生し、先頭・中ほど・末尾・先頭へのシークを含めて 1 分以上操作する。動画を選ぶ前と操作中に
    `footprint MediaViewer`（または `footprint -p <pid>`）で `phys_footprint` を測り、増加が 128MB 以下であることを確認する。依頼時はこの手順と
    コマンドを具体的に示す。128MB を超えた場合は作業を止めて状況を報告する
  - 回帰確認: 通常のフォルダの動画の自動再生・ループ・シーク・Space・フルスクリーンの再生の維持（FR-031〜037）と、リスト形式・サムネイル形式の
    動画の代表フレームが従来どおり動く
  - 結果（実行日、OS、確認項目、合否、T202 と `footprint` によるメモリの最大増加量、再生開始の時間）を
    `specs/001-three-pane-media-viewer/checklists/validation.md` に記録する

**Checkpoint**: zip の中の動画を、一時ファイルを作らずに通常のファイルと同じ操作で再生・シークでき、メモリの使用量は動画のサイズに比例しない

---

## Phase 22: ファイルリストのフォルダ・`..` の行・ツリーの同期（FR-008・070・076〜078 追加、US1）

**Purpose**: ファイルリストにサブフォルダを出し、ダブルクリックか ⌘↓ でそのフォルダの一覧へ移れるようにする。通常のフォルダの一覧の先頭行にも
上の階層へ戻る行 `..` を置き（ツリーのルートでは出さない）、`..` か ⌘↑ で親フォルダへ戻る。一覧の中で移動したときは、ツリーの実際の階層で
そのフォルダを選択・展開し、必要最小限スクロールする（キーボードフォーカスはファイルリストのまま）。戻る行の表記は zip の中も含めて
`..` に統一する（旧表記 `...`。Phase 20 の完了済みタスクの記述は履歴として残す）
（[spec.md](./spec.md) FR-008・070・076〜078・US1 の受け入れシナリオ 21・22、[plan.md](./plan.md) の「変更点（2026-10-21: ファイルリストのフォルダ・`..`・
ツリーの同期）」、[research.md](./research.md) R29〜R31、[data-model.md](./data-model.md) の `ListItemKind`・`MediaFile`・`FolderListing`（通常のフォルダの移動）・
`FolderNavigation`・`ParentLink`・`TreeSyncRequest`・`ListItemCommands`、[contracts/core-api.md](./contracts/core-api.md)「形式判定」「ディレクトリ・ボリューム」
「ブラウザ状態」「zip」、[contracts/keyboard-and-menus.md](./contracts/keyboard-and-menus.md)「ファイルリスト」「右クリックメニュー（ファイルリスト）」「メニューバー」）。
フォルダのファイル操作（コピー・名前の変更・ゴミ箱・移動の仕上げ）は Phase 23 で行う。Phase 22 の時点では、フォルダの行は既存の経路で操作できてよいが、
ツリーへの即時反映・拡張子の確認の省略・確認モーダルの文言・自分自身へのドロップの見た目は Phase 23 で揃える。

**Independent Test**: `swift test` で `FolderNavigation`・`ParentLink`・`ListItemCommands`・`DirectoryLister` のフォルダの行・`BrowserModel` のフォルダの移動の
テストが通ること。`.app` で quickstart.md「ファイルリストのフォルダ（FR-076〜078）」の 1〜14 を確認し、フォルダの行・入る・戻る・ツリーの同期・
ルートでの `..` の扱い・種類フィルタ・フルスクリーンの読み飛ばしが期待どおりであること。

### Preparation for User Story 1

- [X] T208 [US1] 行の種類 `.folder` を加え、戻る行の表記を `..` にする（R29・R30）。続けて既存の参照を直し、ビルドとテストを通す:
  - `Sources/MediaViewerCore/Model/MediaKind.swift`: `ListItemKind` に `case folder`（コメント「通常のフォルダのサブフォルダ（ファイル操作の対象）」）を
    `.archive` の後に加える。`opensAsContainer` は `.archive` / `.folder` / `.directory` / `.parent` で true、`sortKey` は `"folder"`。`.parent` のコメントを
    「先頭行 `..`（zip の中と、ツリーのルート以外の通常のフォルダ）」にする
  - `Sources/MediaViewerCore/Browser/BrowserModel.swift` の `parentRow(for:)` の `name` を `".."` にし、コメントの `...` を `..` にする
  - `Sources/MediaViewerApp/FileList/ListModeView.swift` の `cell.nameField.stringValue = "..."` を `".."` にする（a11y ラベル「上の階層へ」は変えない）。
    `ThumbnailModeView.swift` の表示名も同じく `..` にそろえる。両ファイルと `FileListViewController.swift`・`FileContextMenu.swift`・`ListItemCommands.swift` の
    コメントの `...` を `..` にする
  - `Sources/MediaViewerApp/Shared/IconCatalog.swift` の `listItemIcon(for:pointSize:)` で、`.folder` に `.directory` と同じ `folder` を返す
  - `switch` が網羅でなくなった箇所（`BrowserModel.openItem(_:)` など）は、この時点では `.folder` を `.media` と同じく何もしない分岐にしてビルドを通す（T221 で置き換える）
  - `Tests/MediaViewerCoreTests/BrowserModelArchiveTests.swift`・`ArchiveIndexTests.swift` などで `"..."` を期待している箇所を `".."` にする
  - `swift build` と `swift test`（既存のテスト）が通ることを確認する。新しいテスト（T210〜T216）はこのタスクの後に書く
- [X] T209 [P] [US1] `Sources/FixtureKit/FixtureSets.swift` に `folders(in:)` を追加して `makeAll(in:)` に加え、`ops(in:)` に `album/` を加える
  （quickstart.md「検証用フォルダの準備」の `folders/` の表と `ops/` の行のとおり）:
  - `folders/`: `cover.jpg`（`ImageFixtures.jpeg` 320×240）、`trip/day1/` に JPEG 3 枚（`1.jpg`〜`3.jpg`）、`trip/day1/best/` に JPEG 1 枚、`trip/day2/` に
    PNG 1 枚、`only-subfolders/inner/`（空）、`empty-folder/`、`.hidden-folder/`（中に JPEG 1 枚）、`Viewer.app/Contents/`（空。拡張子 .app の
    ディレクトリはパッケージになる）、`dir.zip/`（ディレクトリ。中に JPEG 1 枚）
  - `ops/album/`: JPEG 2 枚（`a.jpg`・`b.jpg`）と空の `inner/`
  - `swift build` が通り、`scripts/make-fixtures.sh` で一時フォルダに作れることを確認する

### Tests for User Story 1

- [X] T210 [P] [US1] `Tests/MediaViewerCoreTests/FolderNavigationTests.swift`（新規、`@Suite("FolderNavigation")`）を先に書く（T217 の前にビルドエラーに
  なることを確認する）。data-model の「FolderNavigation」の表の全行を検証する。ルートは `URL(fileURLWithPath:)` で `/`・`/Users/me`・`/Volumes/Ext`:
  - ルートそのもの（`/Users/me`・`/`・`/Volumes/Ext`、末尾 `/` 付きも）→ nil
  - `/Users/me/a` → `/Users/me`、`/Users/me/a/b` → `/Users/me/a`（ホームが最も深いルート）
  - `/Users/x` → `/Users`、`/Users` → `/`（起動ボリューム `/` の中）。`/Volumes/Ext/p` → `/Volumes/Ext`
  - 「比較は `standardizedFileURL` のパスの要素で行う」: ルートを `/Users/me` だけにしたとき `/Users/me2/a` → nil（ルート外）。`/Users/me/./a/../b` → `/Users/me`
  - 「どのルートにも含まれない、またはルートの一覧が空」→ nil（ルートが空なら `/Users/me/a` も nil）
- [X] T211 [P] [US1] `Tests/MediaViewerCoreTests/ParentLinkTests.swift`（新規、`@Suite("ParentLink")`）を先に書く:
  - `url(for: URL(fileURLWithPath: "/tmp/写真 集/a#b"))` の `scheme == "mvparent"`、`isFileURL == false`、同じフォルダで2回作ると `==`、別のフォルダとは `!=`
  - `isParentLink` は `mvparent` の URL で true、ファイル URL・`mvzip` の URL（`ArchiveURL.parentLink(of:)` を含む）で false
- [X] T212 [P] [US1] `Tests/MediaViewerCoreTests/ListItemCommandsTests.swift` を data-model の新しい「ListItemCommands」の表に合わせる:
  - `allKinds` に `.folder` を加える
  - zip の外の `.folder`: `canOpenContainer == true`・`allowsFileOperations == true`・`allowsPaste == true`
  - zip の外の `.parent`: `canOpenContainer == true`・`allowsFileOperations == false`・`allowsPaste == true`（既存の期待値が true なら false に直す）
  - `hasEnclosingLevel` を省略すると `canGoUp == isBrowsingArchive`（既存のケースが変わらない）。`isBrowsingArchive: false, hasEnclosingLevel: true` で
    どの種類（nil を含む）でも `canGoUp == true`、`hasEnclosingLevel: false` で false
  - zip の中はどの種類でも従来どおり `allowsFileOperations == false`・`allowsPaste == false`
- [X] T213 [P] [US1] `Tests/MediaViewerCoreTests/DirectoryListerTests.swift` にケースを追加する（R29）。一時フォルダに `a.jpg`・`sub/`・`.hidden-dir/`・`Pkg.app/Contents/`・
  `dir.zip/`（ディレクトリ）・`z.zip`（ファイル）・`notes.txt` を作る:
  - `mediaFiles(in:)` が `sub`（`kind == .folder`、`typeDescription == "フォルダ"`、`fileSize == 0`、`creationDate != nil`）と `dir.zip`（`.folder`）を返し、
    `.hidden-dir` と `Pkg.app` は返さない。`z.zip` は `.archive`、`a.jpg` は `.media(.jpeg)`、`notes.txt` は返さない
  - `mediaFiles(in:)` の `.folder` の URL の集合が、`subfolders(of:)` の結果と一致する（`standardizedFileURL` で比べる）
  - 既存の「`x.zip` という名前のディレクトリは返さない」ケースを、「`.archive` としては返さず `.folder` として返す」に直す
- [X] T214 [P] [US1] `Tests/MediaViewerCoreTests/SortingTests.swift`・`MediaTypeFilterTests.swift`・`FocusNavigatorTests.swift` にケースを追加する:
  - 並べ替え: `.parent`・`.folder`（`b`）・`a.jpg`・`c.png`・`.archive`（`d.zip`）を名前・作成日・種類の昇順と降順で並べ、`.parent` は常に先頭、`b` は名前の
    自然順で `a.jpg` と `c.png` の間に入る（フォルダを上にまとめない）
  - `apply(to:)`: `imagesOnly`・`videosOnly` で `.folder` の行が残り、並び順を保つ
  - `isNavigable`（`kind.isMedia`）付きの移動で、`[parent, folder, media, folder, media]` の位置 2 から ↓ → 4、位置 2 から ↑ → nil
- [X] T215 [US1] `Tests/MediaViewerCoreTests/BrowserModelFolderTests.swift`（新規、`@Suite("BrowserModel のフォルダ")`、`@MainActor`）を先に書く。
  `BrowserModelArchiveTests` と同じく `/private/var/...` 表記の一時フォルダに `root/cover.jpg`・`root/trip/day1/1.jpg`・`root/trip/day2/`・`root/empty/`・
  `root/only/inner/` を作り、実際の `DirectoryLister`・`ImageDecoder` で `BrowserModel` を作る。`setNavigationRoots([root])` を呼んでから `selectFolder(root)` する:
  - ルートの一覧: `files` に `.parent` がなく、`cover.jpg`・`empty`・`only`・`trip` が名前の順。`hasEnclosingLevel == false`。`goToEnclosingLevel()` は何もせず、
    `treeSyncRequest` も変わらない
  - `openItem(trip)`: `listing.folder == root/trip`、`files[0].kind == .parent`・`files[0].name == ".."`・`ParentLink.isParentLink(files[0].url)`、続いて `day1`・`day2`、
    選択は空、プレビューは `.empty`、`settings.viewSettings.lastFolder == root/trip`、`treeSyncRequest?.folder == root/trip` で `id` が増える
  - `openItem(day1)` → `goToEnclosingLevel()`: `trip` の一覧に戻り、`selection.selected == [day1 の URL]`・`focused == day1 の URL`、`treeSyncRequest?.folder == root/trip`、
    `lastFolder == root/trip`。`openItem(<.parent の URL>)` でも同じ結果になる。もう一度戻ると `root` の一覧で `trip` が選ばれ、`files` に `.parent` がない
  - `selectFolder(root/trip/day2)`（ツリーからの選択）では `treeSyncRequest` が変わらない。そこでも `..` は出る（`hasEnclosingLevel == true`）
  - ルートが空（`setNavigationRoots([])`）のとき、`root/trip` を `selectFolder` しても `..` を出さず、`hasEnclosingLevel == false`。`setNavigationRoots([root])` を
    呼ぶと、読み直さずに `..` が先頭に入る（`files` の `.parent` 以外の行は同じ）
  - 空の判定（FR-060）: `empty` は `files == [parent]`・`.empty`。`only` は `[parent, inner]`・`.loaded`。`trip` で `videosOnly` にすると `day1`・`day2` が残り `.loaded`
    （メディアが元々ない）。`trip/day1` で `videosOnly` にすると `[parent]`・`.noMatches`
  - 読めないフォルダ（FR-077）: `root/locked/` を作って権限を `0o000` にし（テスト後に戻す）、`openItem(locked)` で `listing.state == .denied`・`files` が `[parent]` だけ。
    `openItem(<.parent の URL>)` で `root` に戻り `locked` が選ばれる。存在しないフォルダを `selectFolder` した `.failed` でも、ルート以外なら `files == [parent]`。
    `reloadCurrentFolder()` 中にフォルダが読めなくなった場合も同じ。ルート（`root`）を `0o000` にした場合は `files` が空
  - フォルダの行を選ぶとプレビューは `.empty`。`.video` のプレビュー中にフォルダの行へ移ると `stopPlaybackSignal` が増える（`BrowserModelVideoTests` のフェイクの
    デコーダを使うか、`.video` になる mp4 を `VideoFixtures` で置く）
  - `operableSelection`: `select([parent, day1, day2], focused: parent)` で `[day1, day2]`（一覧の並び順）。`select([parent], focused: parent)` で `[]`
  - zip の中の移動（`root/a.zip` を `ZipFixtureWriter` で作って `openItem` → `goToEnclosingLevel()`）では `treeSyncRequest` が変わらず、`lastFolder` も変わらない
  - `handleFileSystemEvent` で表示中の `root/trip/day2` を削除して呼ぶと親へ移るが、`treeSyncRequest` は変わらない
- [X] T216 [P] [US1] `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift` に、10,000 個の小さな JPEG と 1,000 個の空のサブフォルダを持つフォルダで
  `DirectoryLister().mediaFiles(in:)` が 1 秒以内（返す件数は 11,000。SC-003 の列挙と同じ基準。実測でフォルダなしの 10,000 件でも約 0.8 秒のため 0.5 秒から変更）であることの計測を追加する（quickstart.md「性能の検証」、R29）。生成は計測に含めない

### Implementation for User Story 1

- [X] T217 [P] [US1] `Sources/MediaViewerCore/Model/FolderNavigation.swift`（新規、`public enum FolderNavigation`）に
  `enclosingFolder(of folder: URL, roots: [URL]) -> URL?` を作り、T210 を通す。`standardizedFileURL.pathComponents` で比べ、`folder` がどれかのルートと同じなら nil、
  `folder` を接頭に含むルートのうち要素数が最も多いものを選んで `deletingLastPathComponent()` を返す。含むルートがなければ nil
- [X] T218 [P] [US1] `Sources/MediaViewerCore/Model/ParentLink.swift`（新規、`public enum ParentLink`）に `scheme = "mvparent"`・`url(for:)`・`isParentLink(_:)` を作り、
  T211 を通す。`URLComponents` の `scheme` と `percentEncodedPath`（フォルダの `standardizedFileURL.path` の各要素を `ArchiveURL` と同じ集合でエンコード）で組み立てる
- [X] T219 [P] [US1] `Sources/MediaViewerCore/Model/ListItemCommands.swift` に `hasEnclosingLevel: Bool` を加え、T212 を通す。`init(kind:isBrowsingArchive:hasEnclosingLevel: Bool? = nil)`
  （nil なら `isBrowsingArchive`）、`canGoUp` は `hasEnclosingLevel`、`allowsFileOperations` は `!isBrowsingArchive && kind != .parent`。`allowsPaste` は変えない。
  型のコメントを data-model の表に合わせる
- [X] T220 [P] [US1] `Sources/MediaViewerCore/FileSystem/DirectoryLister.swift` の `mediaFiles(in:)` を変え、T213 を通す（R29）:
  - `fileKeys` に `.isPackageKey` を加える。`isDirectory == true` の URL は、`isVisibleSubfolder` と同じ条件（パッケージでない）のときだけ
    `MediaFile(url:, name: url.lastPathComponent, kind: .folder, typeDescription: "フォルダ", creationDate: values?.creationDate, fileSize: 0)` にし、それ以外のディレクトリは捨てる
  - ディレクトリでない URL の扱い（`.zip` は `.archive`、メディアは `.media`）は変えない。`contentsOfDirectory` は1回のまま
  - プロトコル `DirectoryListing.mediaFiles(in:)` のドキュメントコメントを contracts/core-api.md のとおりにする
  - `swift test --filter DirectoryLister` に加え、T216 の性能テストを通す
- [X] T221 [US1] `Sources/MediaViewerCore/Model/BrowserState.swift` に `TreeSyncRequest`（`folder: URL`・`id: Int`、`Sendable`・`Equatable`）を追加し、
  `Sources/MediaViewerCore/Browser/BrowserModel.swift` を変えて T215 と既存の `BrowserModelTests`・`BrowserModelArchiveTests`・`BrowserModelVideoTests` を通す（R30・R31）:
  - 非公開の `navigationRoots: [URL] = []` と `public func setNavigationRoots(_ urls: [URL])`。値が変わり、`listing.archive == nil` で状態が `.loaded` / `.empty` / `.noMatches` なら
    `rebuildListing()` を呼ぶ（選択は `restricted(toVisible:)` で整える）
  - `public var hasEnclosingLevel: Bool`（`listing.archive != nil || FolderNavigation.enclosingFolder(of: listing.folder, roots: navigationRoots) != nil`）
  - `public var operableSelection: [URL]`（`listing.files` の並び順で `selection.selected` に含まれ、`kind != .parent` の URL。一覧にない選択の URL は末尾に加える。
    `FileListViewController.selectedFileURLs` の既存の並べ方と同じ）
  - `public private(set) var treeSyncRequest: TreeSyncRequest?` と、非公開の `treeSyncCounter`
  - `rebuildListing()`: zip の外で `FolderNavigation.enclosingFolder` が nil でなければ、`MediaFile(url: ParentLink.url(for: listing.folder), name: "..", kind: .parent,
    typeDescription: "", creationDate: nil, fileSize: 0)` を `filtered` の先頭に加える。空の判定（`hasMedia` / `hasOtherRows`）は `allFiles` で行う既存のまま
  - 読めないフォルダ（FR-077）: `loadFolder` と `reloadCurrentFolder()` の失敗の分岐で `listing.files = []` にしている箇所を、zip の外で `enclosingFolder` が nil でなければ
    同じ `..` の行だけにする（`parentRow` と同じく1か所の関数で作る）。`allFiles` は空のまま、状態は従来どおり `.denied` / `.failed(…)`
  - 非公開の `navigateToFolder(_ url: URL, selecting target: URL?) async`: `selectFolder(_:)` と同じ手順（`resetForNavigation()`・`archiveIndex = nil`・`.loading`・
    `lastFolder` の保存・`loadFolder`）の後、`treeSyncCounter += 1` して `treeSyncRequest = TreeSyncRequest(folder: url, id: treeSyncCounter)` を出す（依頼は読み込みの前に出し、
    ツリーの同期を一覧の完了で待たせない）。読み込み後、世代が同じで `target` の行があれば `select([row.url], focused: row.url)` する
    （`returnToFolder(selecting:)` の `standardizedFileURL` の比べ方を流用する）
  - `openItem(_:)`: `.folder` は `navigateToFolder(file.url, selecting: nil)`。`.parent` は従来どおり `goToEnclosingLevel()`
  - `goToEnclosingLevel()`: `listing.archive == nil` なら、`enclosingFolder` があれば `navigateToFolder(parent, selecting: listing.folder)`、なければ何もしない。zip の中は従来どおり
  - `selectFolder(_:)`・`returnToFolder(selecting:)`・`handleFileSystemEvent` は `treeSyncRequest` を変えない
- [X] T222 [US1] ファイルリストの判定を `hasEnclosingLevel` と `operableSelection` に揃える（R30）:
  - `Sources/MediaViewerApp/FileList/ListItemSupport.swift`: `focusedItemCommands` と `itemCommands(forRowAt:)` で
    `ListItemCommands(kind:, isBrowsingArchive:, hasEnclosingLevel: hasEnclosingLevel)` を作る
  - `Sources/MediaViewerApp/FileList/FileListViewController.swift`: `selectedFileURLs` を `model.operableSelection` を返す形にする。コピー・複製・ゴミ箱・開く・Finder に表示は
    対象が空なら何もしない（既存の `guard !urls.isEmpty`）。`validateMenuItem` で、ファイル操作の項目は `allowsFileOperations` に加えて `!model.operableSelection.isEmpty` のときだけ
    有効にする（`..` だけを選択中は淡色）。`goToEnclosingLevel(_:)` の判定は `canGoUp` のまま（`hasEnclosingLevel` で決まる）。`openFocusedItem(_:)`・`openItem(_:)` は変えない
    （`.folder` は Core が開く。開いた後の `scrollFocusedItemIntoViewAfterModelUpdate()` は既存のまま）
  - `FileListViewController.refresh()`（または `updateModeVisibility()`）: `.denied` も、`.empty` / `.noMatches` / `.failed` と同じく、行が残る場合は一覧を出したまま
    下端にメッセージの帯（「アクセスできません」の既存の文言）を出す。行が1つもないときは従来どおり中央に出す（FR-077、R26）
  - `Sources/MediaViewerApp/FileList/FileContextMenu.swift`: 「上の階層へ」の表示条件を `host?.isBrowsingArchive` から `host?.focusedItemCommands.canGoUp` にする
    （戻る先があるときだけ表示）。コメントも直す
  - `ListModeView.swift`・`ThumbnailModeView.swift`: `.folder` の行は `kind.mediaKind` が nil のため縮小画像を要求せず、`IconCatalog.listItemIcon(for: .folder, …)` の `folder` を出すことを
    確かめる（必要なら分岐を足す）。ドラッグ・Return の判定は `itemCommands(forRowAt:)` / `focusedItemCommands` のままで、`.folder` は可・`.parent` は不可になる
  - `swift build` が通ることを確認する
- [X] T223 [US1] ツリーのルートの受け渡しと同期を結線する（R30・R31）:
  - `Sources/MediaViewerApp/App/MainSplitViewController.swift` の `init()`: `BrowserModel` を作った直後、ツリーを作る前に
    `model.setNavigationRoots(volumes.rootNodes().map(\.url))` を呼ぶ（ツリーの初回の `reveal` → `selectFolder` より前に、ルートを渡しておく）
  - `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift`:
    - `applyRoots(_:)` の最後で `model.setNavigationRoots(roots.map(\.url))` を呼ぶ
    - `observeTreeSyncRequest()` を追加し、`viewDidLoad` の `observeDisplayedFolder()` の隣で呼ぶ。`withObservationTracking { _ = model.treeSyncRequest }` の `onChange` で
      MainActor の `Task` から `syncSelection(to:)` を呼び、監視を張り直す
    - `syncSelection(to request: TreeSyncRequest)`: `revealTask?.cancel()` の後、`revealTask = Task { … }` で `reveal(request.folder, selecting: false)` 相当の
      展開だけを行い、完了後に `Task.isCancelled` でなく `model.treeSyncRequest?.id == request.id` で、かつ `model.listing.folder.standardizedFileURL ==
      request.folder.standardizedFileURL` のときだけ、`isRestoringSelection = true` の間に
      `selectRowIndexes(…, byExtendingSelection: false)` と `scrollRowToVisible(row)` を行って `false` に戻し、`updateWatchSet()` を呼ぶ。`makeFirstResponder` は呼ばない
    - `outlineViewSelectionDidChange`: `isRestoringSelection` でない（ユーザーの操作による）選択の変更では、`selectFolder` を呼ぶ前に、進行中の同期の `revealTask` を
      `cancel()` して nil にする（ツリーからの選択は `treeSyncRequest` を変えないため、遅れて終わった同期がユーザーの選択を上書きしないようにする。R31）
    - `reveal(_:)` のルートの選び方を「`targetComponents` を接頭に含むルートのうち、要素数が最も多いもの」にする（見つからなければ従来どおりホーム）。行の選択を
      呼び出し側で行えるよう、展開だけの関数（例: `expandAncestors(of:) async -> Node?`。辿れた最も深いノードを返す）と、選択とスクロールを分ける。初回の `viewDidAppear` の
      `reveal` は従来どおり選択して `selectFolder` を起こす（`isRestoringSelection` を立てない）
    - お気に入りの項目を選択中でも、同期は実際の階層の行を選択する（`rowForURL` は `roots` だけを見る既存のまま）
  - `swift build` が通ることを確認する
- [X] T224 [P] [US1] `README.md` の「主な機能」と「使い方（主なショートカット）」に、ファイルリストのフォルダの表示、ダブルクリック・⌘↓ で中へ、⌘↑ または先頭行の `..` で親へ戻る
  （ホーム・ボリュームの最上位では `..` は出ない）、ツリーの選択が同期することを追記し、zip の戻る行の記述 `...` を `..` に直す

### Verification for User Story 1

- [X] T225 [US1] 自動テストと手動確認を行う（T208〜T224 に依存）:
  - `swift build`、`swift test`、`scripts/check-no-network.sh` を通す。T216 の計測値を記録する。1 秒を超えた場合は作業を止めて状況を報告する（憲章 原則 II）
  - `scripts/make-app.sh` で `.build/MediaViewer.app` を作り、ユーザーに起動と GUI 確認を依頼する。依頼時は `scripts/make-fixtures.sh ~/MediaViewerFixtures` の準備コマンドと、
    quickstart.md「ファイルリストのフォルダ（FR-076〜078）」の確認ポイント 1〜14、US1 の 3（`mixed/` の `sub` と `..`）、「zip ファイル（FR-068〜075）」の 1・3・5・13（表記が `..`）を
    具体的に示す。起動しない場合は AGENTS.md の lldb 手順で例外を止める
  - 回帰確認: ツリーのクリック・矢印キー・ダブルクリック開閉（FR-053）・お気に入り（FR-061〜067）、zip の中の移動と戻った先の選択（FR-069・070）、
    種類フィルタ（FR-056〜060）、フルスクリーンの矢印移動（FR-046）、行頭アイコン（FR-048）が従来どおり動く
  - 結果（実行日、OS、確認項目、合否、T216 の計測値）を `specs/001-three-pane-media-viewer/checklists/validation.md` に記録する

**Checkpoint**: ファイルリストにフォルダが出て、ダブルクリック・⌘↓ で入り、`..`・⌘↑ で戻れる。ツリーの選択は一覧の移動に追従し、フォーカスはファイルリストに残る

---

## Phase 23: フォルダのファイル操作（FR-018・022・027・076 追加、US4）

**Purpose**: ファイルリストのフォルダを、ファイルと同じくコピー・ペースト・名前の変更・ゴミ箱・移動・複製・ツリーへのドラッグの対象にする。フォルダは中身ごと
操作し、名前の変更では拡張子の確認を出さず、確認モーダルではフォルダは中身ごと操作する旨を示す。操作の結果は FSEvents を待たずにツリーへ反映し、
フォルダを自分自身やその配下へドロップできない見た目にする。フォルダの削除はファイルリストからだけで、ツリーの ⌘⌫ と右クリックメニューは変えない
（2026-10-21 の FR-079 で変更し、ツリーのフォルダのゴミ箱を Phase 24 で加える。この Phase の記述は履歴として残す）
（[spec.md](./spec.md) FR-018・022・027・076・US1 の受け入れシナリオ 23・Edge Cases、[plan.md](./plan.md) の「変更点（2026-10-21: ファイルリストのフォルダ・`..`・ツリーの同期）」、
[research.md](./research.md) R32、[data-model.md](./data-model.md) の `ListItemCommands`、[contracts/core-api.md](./contracts/core-api.md)「ファイル操作」、
[contracts/keyboard-and-menus.md](./contracts/keyboard-and-menus.md)「ファイルリスト」「確認モーダルと衝突ダイアログ」）。

**Independent Test**: `swift test` で `NameValidation` と `FileOperationService` のフォルダのケースが通ること。`.app` で quickstart.md「US4」の 7〜9 を `ops/` で確認し、
フォルダの各操作・確認モーダルの文言・ツリーへの即時反映・自分自身へのドロップの拒否・ツリーの ⌘⌫ が期待どおりであること（US4 の 9 は Phase 24 で
「ツリーのフォルダのゴミ箱」の参照に変わった）。

### Tests for User Story 4

- [X] T226 [P] [US4] `Tests/MediaViewerCoreTests/NameValidationTests.swift` と `Tests/MediaViewerCoreTests/FileOperationServiceTests.swift` にケースを追加する（T227 の前に
  ビルドエラーになることを確認する）:
  - `validateNewName("album.2024", for: <album のフォルダ URL>, existingNames: [], isDirectory: true)` → `.ok`（拡張子の確認なし）。`isDirectory` を省略したファイルの
    `a.jpg` → `a.png` は従来どおり `.needsExtensionChangeConfirmation`。フォルダでも空・`a/b`・`.x`・同名（大文字小文字違いを含む）は `.invalid`
  - `FileOperationService` で、中に `a.jpg` と `inner/b.jpg` を持つ `album/` を: コピー（中身ごと複製され、元も残る）、移動（元が消え、操作先に中身ごとある）、名前の変更
    （`album 2024` になり中身が残る）、ゴミ箱（元が消え、`succeeded` にゴミ箱の URL が入る）。操作先に同名の `album/` があるとき、`conflicts(for:)` がそれを返し、
    `.replace` でフォルダごと置き換わり（古い方の中身が残らない）、`.keepBoth` で `album 2` ができる
  - `album/` を `album/inner/` へ移動・コピーすると失敗し、理由が「フォルダを自分自身またはその配下へ移動・コピーすることはできません」で、何も変わらない（既存の動作の確認）

### Implementation for User Story 4

- [X] T227 [US4] `Sources/MediaViewerCore/Operations/NameValidation.swift` の `validateNewName` に `isDirectory: Bool = false` を足し、true のときは拡張子の比較を飛ばして `.ok` を
  返す（R32）。T226 を通す。`FileOperationService` は変更しない（T226 のフォルダのケースが既存の実装で通ることを確かめる。通らない場合は原因を直し、そのテストを残す）
- [X] T228 [US4] `Sources/MediaViewerApp/Operations/FileOperationCoordinator.swift` と `Sources/MediaViewerApp/Operations/ConfirmationPresenter.swift` を変える（R32）:
  - `FileOperationCoordinator`: `var onFoldersChanged: ((Set<URL>) -> Void)?` を追加し、`transfer`（コピー・移動）・`duplicate`・`trash`・`rename` の `model.reloadCurrentFolder()` の後で、
    対象の親フォルダ（`deletingLastPathComponent()`）と操作先（コピー・移動）の集合を `standardizedFileURL` にして渡す。キャンセルされた操作では呼ばない
  - `rename(_:to:)`: `file.hasDirectoryPath` か `FileManager` の `fileExists(atPath:isDirectory:)` でフォルダかを調べ、`validateNewName(…, isDirectory:)` に渡す
  - `ConfirmationPresenter.informativeText(for:)`: `sources` にディレクトリ（`fileExists(atPath:isDirectory:)`）が1つでもあれば、対象の行の後に
    「フォルダは中身ごと操作します」（ゴミ箱は「フォルダは中身ごとゴミ箱に入ります」）の1行を加える。メッセージの見出しと「今後この確認を表示しない」は変えない
- [X] T229 [US4] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` と `Sources/MediaViewerApp/App/MainSplitViewController.swift` を変える（R32）:
  - ツリーに `func refreshFolders(_ changed: Set<URL>)` を追加し、`eventTask` の `for await changed in self.watcher.events` の本体から `model.handleFileSystemEvent` を除いた処理
    （`reloadExpandedNodes(in:)`・`recheckCollapsedNodes(in:)`・`updateWatchSet()`・`refreshFavoriteAvailabilityIfNeeded(in:)`）を移して共有する。`eventTask` はそれを呼ぶ形にする
  - `validateDrop`: `fileURLs(from:)` の URL のどれかについて、ドロップ先のノードの `url.standardizedFileURL.pathComponents` がその URL の要素を接頭に含む
    （ドロップ先が自分自身か配下）なら `[]` を返す
  - 右クリックメニューと `moveToTrash(_:)` の判定は変えない（お気に入り以外の行で ⌘⌫ は何もしない。FR-064。後に Phase 24 の T238 で FR-079 のゴミ箱を加える）
  - `MainSplitViewController.init()`: ツリーを作った後に `fileOperationCoordinator.onFoldersChanged = { [weak tree] folders in tree?.refreshFolders(folders) }` を設定する
  - `swift build` が通ることを確認する

### Verification for User Story 4

- [X] T230 [US4] 自動テストと手動確認を行う（T226〜T229 に依存）:
  - `swift build`、`swift test`、`scripts/check-no-network.sh` を通す
  - `scripts/make-app.sh` で `.build/MediaViewer.app` を作り、ユーザーに起動と GUI 確認を依頼する。依頼時は `scripts/make-fixtures.sh ~/MediaViewerFixtures`（`ops/` を作り直す）と、
    quickstart.md「US4」の確認ポイント 1〜9（7〜9 がフォルダ）と US1 の受け入れシナリオ 23 を具体的に示す。フォルダをゴミ箱に入れた後、Finder の「戻す」で復元できることも確かめてもらう
  - 回帰確認: ファイルのコピー・名前の変更（拡張子の確認を含む）・ゴミ箱・移動・複製・衝突ダイアログ（FR-018〜027）、お気に入りの削除（FR-064）、zip の中の読み取り専用（FR-073）が
    従来どおり動く
  - 結果（実行日、OS、確認項目、合否）を `specs/001-three-pane-media-viewer/checklists/validation.md` に記録する

**Checkpoint**: ファイルリストのフォルダを、ファイルと同じ操作で中身ごとコピー・名前の変更・ゴミ箱・移動でき、結果はツリーにもすぐ反映される

---

## Phase 24: ツリーのフォルダをゴミ箱に入れる（FR-064・079 追加、US1）

**Purpose**: ツリーの通常のフォルダ（ホーム・ボリュームの最上位を除く）を、右クリックメニューの「ゴミ箱に入れる」と ⌘⌫ で、確認モーダルを経て中身ごとゴミ箱に入れられる
ようにする。表示中のフォルダ（またはその祖先）を入れたときは、親フォルダをツリーで選択してその一覧を表示し、プレビューを空にする。お気に入りの項目の ⌘⌫ は従来どおり
「お気に入りから削除」のまま。Phase 23 の「ツリーの ⌘⌫ と右クリックメニューは変えない」はこの Phase で置き換える
（[spec.md](./spec.md) FR-064・079・US1 の受け入れシナリオ 24・Edge Cases、[plan.md](./plan.md) の「変更点（2026-10-21: ツリーのフォルダをゴミ箱に入れる）」、
[research.md](./research.md) R33、[data-model.md](./data-model.md) の「TreeItemRole と FavoriteCommands」「FolderNavigation」、
[contracts/core-api.md](./contracts/core-api.md)「お気に入り」「ブラウザ状態」、[contracts/keyboard-and-menus.md](./contracts/keyboard-and-menus.md)「ディレクトリツリー」
「右クリックメニュー（ツリー）」「メニューバー」）。

**Independent Test**: `swift test` で `FavoriteCommandsTests`・`FolderNavigationTests`・`BrowserModelFolderTests` の追加ケースが通ること。`.app` で quickstart.md
「ツリーのフォルダのゴミ箱（FR-079）」の 1〜9 を確認し、ツリーから中身ごとゴミ箱に入れられ、表示中のフォルダ（または祖先）を入れたときは親が選択・表示され、
ホーム・ボリュームの最上位・見出しでは何も起きず、お気に入りの項目の ⌘⌫ が従来どおりであること。

### Tests for User Story 1

- [X] T231 [P] [US1] `Tests/MediaViewerCoreTests/FavoriteCommandsTests.swift` にケースを追加する（T234 の前にビルドエラーになることを確認する）。ルートは
  `[URL(fileURLWithPath: "/"), URL(fileURLWithPath: "/Users/me")]` を使う:
  - `trashTarget(.folder(/Users/me/a), roots:)` → `/Users/me/a`。`/Volumes/Ext/a`（ルートに `/` を含むため対象）→ URL
  - `trashTarget` が nil になる: `.folder(/Users/me)`・`.folder(/)`・`.folder(/Users/me/)`（末尾の `/`）、`.favorite(/Users/me/a)`、`.favoritesHeader`、`nil`、
    ルートが空の `.folder(/Users/me/a)`
  - `contextMenu(for: .folder(/Users/me/a), roots:)` が `[.moveToTrash, .separator, .pasteHere, .movePasteHere, .separator, .addToFavorites, .separator, .revealInFinder]`
  - `contextMenu(for: .folder(/Users/me), roots:)`（ルート）と `contextMenu(for: .folder(/Users/me/a))`（`roots` 省略）が従来どおり
    `[.pasteHere, .movePasteHere, .separator, .addToFavorites, .separator, .revealInFinder]`。`.favorite` は `[.removeFromFavorites]`、`.favoritesHeader` は空のまま
    （`roots` を渡しても変わらない）
  - 既存のケース（`canAdd`・`removalTarget`・`folderToShow`・`acceptsFiles`）は変えずに通す
- [X] T232 [P] [US1] `Tests/MediaViewerCoreTests/FolderNavigationTests.swift` に `folderToShow(afterTrashing:showing:roots:)` のケースを追加する（T235 の前にビルドエラーに
  なることを確認する）。ルートは `/` と `/Users/me`:
  - 表示中のフォルダ自身: `trashed [/Users/me/a/b]`、`showing /Users/me/a/b` → `/Users/me/a`
  - 祖先: `trashed [/Users/me/a]`、`showing /Users/me/a/b/c` → `/Users/me`（ルートそのものが親でもよい）
  - 複数（最も浅いものの親）: `trashed [/Users/me/a/b, /Users/me/a]`、`showing /Users/me/a/b/c` → `/Users/me`。配列の順を入れ替えても同じ
  - nil になる: 兄弟（`trashed [/Users/me/a/x]`、`showing /Users/me/a/b`）、`showing` の配下だけ（`trashed [/Users/me/a/b/c]`、`showing /Users/me/a/b`）、
    名前の接頭辞だけが同じ（`trashed [/Users/me/a/b]`、`showing /Users/me/a/b2`）、空の配列、ルート（`trashed [/Users/me]`、`showing /Users/me/a`）、ルートの一覧が空
  - 末尾の `/` や `..` を含む表記（`/Users/me/a/b/`・`/Users/me/a/x/../b`）でも同じ結果になる（`standardizedFileURL` のパスの要素で比べる）
- [X] T233 [P] [US1] `Tests/MediaViewerCoreTests/BrowserModelFolderTests.swift` に `leaveTrashedFolders(_:)` のケースを追加する（T236 の前にビルドエラーになることを確認する）。
  既存の `makeEnv()` の一時フォルダを使い、ゴミ箱には入れずに `FileManager.removeItem` で消してから呼ぶ（ゴミ箱を汚さない）:
  - `trip/day1` を表示中（`openItem` で入る）に `trip/day1` を消して `leaveTrashedFolders([trip/day1])` → `true`。一覧の `folder` が `trip`、`state` が `.loaded`、
    選択とフォーカスが空、プレビューが `.empty`、`lastFolder` が `trip`、`treeSyncRequest` の `folder` が `trip` で `id` が呼ぶ前より増えている。
    一覧に `day1` の行がなく、`day2` は残っている
  - `trip/day1` を表示中に、祖先の `trip` を消して `leaveTrashedFolders([trip])` → `true`。一覧の `folder` が `root`
  - `trip/day1` を表示中に、無関係な `empty` を消して `leaveTrashedFolders([empty])` → `false`。一覧の `folder`・選択・`treeSyncRequest` が呼ぶ前と同じ
  - 空の配列 → `false` で何も変わらない
  - 動画のプレビュー中: `trip/day1` に `VideoFixtures.mp4` で `clip.mp4` を作ってから選択し、プレビューが `.video` になったことを確かめてから `trip/day1` を消して
    `leaveTrashedFolders([trip/day1])` を呼ぶ → `stopPlaybackSignal` が増える
  - zip の中: `root/trip` に `ZipFixtureWriter`（`BrowserModelArchiveTests` と同じ使い方）で JPEG 1 枚の `photos.zip` を作り、`trip` を表示して `photos.zip` を
    `openItem` で開いた後、`trip` を消して `leaveTrashedFolders([trip])` → `true`。`isBrowsingArchive` が false、一覧の `folder` が `root`

### Implementation for User Story 1

- [X] T234 [US1] `Sources/MediaViewerCore/Model/FavoriteCommands.swift` を変える（R33。T231 を通す）:
  - `TreeContextMenuItem` に `case moveToTrash` を足す（コメント「ツリーのフォルダをゴミ箱に入れる（FR-079）」）
  - `public static func trashTarget(_ role: TreeItemRole?, roots: [URL]) -> URL?` を足す。`.folder(url)` で、かつ
    `FolderNavigation.enclosingFolder(of: url, roots: roots) != nil` のときだけ `url` を返し、それ以外は nil
  - `contextMenu(for:)` を `contextMenu(for role: TreeItemRole, roots: [URL] = [])` にする。`trashTarget(role, roots:)` が URL を返すときは、従来の `.folder` の並びの先頭に
    `.moveToTrash, .separator` を足す。ほかの役割の結果は変えない
  - `swift build` が通ることを確認する（App の `makeContextMenuItem` の `switch` が網羅されずエラーになる場合は、T238 の `.moveToTrash` の分岐だけを先に足してよい）
- [X] T235 [P] [US1] `Sources/MediaViewerCore/Model/FolderNavigation.swift` に `public static func folderToShow(afterTrashing trashed: [URL], showing: URL, roots: [URL]) -> URL?` を
  足す（R33、data-model の表。T232 を通す）。`showing` と各 `trashed` を `standardizedFileURL.pathComponents` にし、`showing` の要素が `trashed` の要素を接頭に含む
  （同じ、または配下）ものの中で要素数が最も少ないものを選び、その `enclosingFolder(of:roots:)` を返す。該当がなければ nil。ドキュメントコメントに FR-079 を書く
- [X] T236 [US1] `Sources/MediaViewerCore/Browser/BrowserModel.swift` に `@discardableResult public func leaveTrashedFolders(_ trashed: [URL]) async -> Bool` を足す（R33。T235 の後。
  T233 を通す）。`FolderNavigation.folderToShow(afterTrashing: trashed, showing: listing.folder, roots: navigationRoots)` が親を返したら
  `await navigateToFolder(parent, selecting: nil)` を呼んで true、nil なら何もせず false。`listing.folder` は zip の中でも zip を含むフォルダなので、zip の状態は
  `selectFolder` の中で捨てられる。ドキュメントコメントに「表示中のフォルダ（zip の中なら zip を含むフォルダ）自身か祖先をゴミ箱に入れたときに親へ移る。
  `treeSyncRequest` を出す（FR-079）」と書く。既存の `BrowserModelFolderTests`・`BrowserModelArchiveTests` が通ることを確かめる
- [X] T237 [US1] `Sources/MediaViewerApp/Operations/FileOperationCoordinator.swift` の `trash(_:)` を変える（R33。T236 の後）:
  - 確認でキャンセルしたときは従来どおり何もしない
  - `service.execute` と `presentFailures` の後、まず `notifyFoldersChanged(sources: urls, destination: nil)` を呼んでツリーへ知らせ（親の一覧の読み込みを待たずに、
    ゴミ箱に入れた行をツリーから消すため。FR-027）、続けて `await model.leaveTrashedFolders(trashedSources)`（次の項目）を呼ぶ。false のときだけ従来どおり
    `await model.reloadCurrentFolder()` を呼ぶ（true のときに読み直すと、消えたフォルダの「フォルダが見つかりません」が一瞬出るため）
  - `trashedSources` は、`urls` から `result.failed` の URL を除いた元の場所の配列とする。`result.succeeded` はゴミ箱の中の URL を返すため（T226）渡さない。`FileOperationService` の結果の型は変えない
  - ファイルリストからのゴミ箱は、表示中のフォルダやその祖先を対象にしないため、`leaveTrashedFolders` が false を返して従来どおりの経路になることをコメントに書く
- [X] T238 [US1] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` を変える（R33。T234・T237 の後）:
  - `private var rootURLs: [URL] { roots.map(\.url) }` を足す
  - `menuNeedsUpdate(_:)` を `FavoriteCommands.contextMenu(for: role, roots: rootURLs)` にする
  - `makeContextMenuItem` に `.moveToTrash` を足す: タイトル「ゴミ箱に入れる」、アクション `trashFolderFromMenu(_:)`、`keyEquivalent` は `NSBackspaceCharacter`、
    修飾キー `[.command]`（「お気に入りから削除」と同じ表示）。`target` と `representedObject`（右クリックした行）は既存の項目と同じく設定する
  - `@objc private func trashFolderFromMenu(_ sender: Any?)`: `targetItem(for: sender)` の役割で `FavoriteCommands.trashTarget(_:roots:)` を求め、URL があれば
    `Task { await coordinator.trash([url]) }`。フォーカスは移さない（R33）
  - `moveToTrash(_:)`: 選択中の行がお気に入りの項目なら従来どおり `removeFavorite`。そうでなく `trashTarget(role(for: selectedItem), roots: rootURLs)` が URL を返せば
    `Task { await coordinator.trash([url]) }`。ドキュメントコメントを「⌘⌫。お気に入りの項目ならお気に入りから削除（FR-064）、ルート以外のフォルダならゴミ箱に入れる（FR-079）」にする
  - `validateMenuItem`: `moveToTrash(_:)` は、お気に入りの項目で「お気に入りから削除」・true（従来どおり）、`trashTarget` が URL を返す行で「ゴミ箱に入れる」・true、
    それ以外で「ゴミ箱に入れる」・false。`trashFolderFromMenu(_:)` は `trashTarget(role(for: targetItem(for: menuItem)), roots: rootURLs) != nil`
  - `reloadChildren(of:)`: `applyListing` を `isRestoringSelection = true` の間に行う（`defer` で戻す）。読み直し後に `selectedURL` の行がなければ、`selectedURL` から
    `deletingLastPathComponent()` で祖先を辿り、`rowForURL` で最初に見つかった行を同じく `isRestoringSelection` の間に選ぶ（`selectFolder` を呼び返さず、隣の行へ選択が
    ずれて一覧が切り替わらないようにする。R33）。行があれば従来どおりその行を選び直す。お気に入りの項目を選択中（`selectedNode` が nil）のときは従来どおり何もしない
  - `syncSelection(to:)`・`reveal(_:)`・`removeFavorite`・ペースト・ドロップは変えない
  - `swift build` が通ることを確認する
- [X] T239 [P] [US1] `README.md` のツリーの操作説明に、通常のフォルダを ⌘⌫ または右クリックメニューの「ゴミ箱に入れる」で中身ごとゴミ箱に入れられること
  （確認モーダルあり・設定で省略可、ホーム・ボリュームの最上位は不可、表示中のフォルダを入れたときは親フォルダを表示する、お気に入りの項目の ⌘⌫ は
  お気に入りから削除）を追記する。Phase 23 の「ツリーでは削除できない」旨の記述があれば直す

### Verification for User Story 1

- [ ] T240 [US1] 自動テストと手動確認を行う（T231〜T239 に依存）:
  - `swift build`、`swift test`、`scripts/check-no-network.sh` を通す
  - `scripts/make-app.sh` で `.build/MediaViewer.app` を作り、ユーザーに起動と GUI 確認を依頼する。依頼時は `scripts/make-fixtures.sh ~/MediaViewerFixtures`（`ops/` を作り直す）、
    quickstart.md「ツリーのフォルダのゴミ箱（FR-079）」の準備のコマンドと確認ポイント 1〜9、US1 の受け入れシナリオ 24 を具体的に示す。ゴミ箱に入れたフォルダを
    Finder の「戻す」で復元できることも確かめてもらう
  - 回帰確認: quickstart.md「お気に入り」の 7・9・10・16・18（お気に入りの項目の ⌘⌫ と「お気に入りから削除」、ホームの ⌘⌫ が無効）、「US4」の 3・7（ファイルリストからの
    ファイル・フォルダのゴミ箱）、「ファイルリストのフォルダ」の 2・4・14（ツリーの同期）。さらに、アプリを前面にしたままターミナルで表示中のフォルダを `rm -rf` したとき、
    一覧が親フォルダに移り、ツリーの選択が隣の行へずれずに親の行になること（T238 の `reloadChildren` の変更。FR-042）
  - 結果（実行日、OS、確認項目、合否）を `specs/001-three-pane-media-viewer/checklists/validation.md` に記録する

**Checkpoint**: ツリーの通常のフォルダを ⌘⌫ と右クリックメニューからゴミ箱に入れられ、表示中のフォルダを入れたときは親フォルダの表示に移る。お気に入りの削除と
ファイルリストのゴミ箱は従来どおり

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
- **アプリアイコン (Phase 10)**: Setup の T005（`scripts/make-app.sh`）があれば始められる。ストーリーの実装とは
  独立しているが、T084 は T005 のスクリプトを編集するため、T005 完了後に着手する。T085 は T084 に依存する。
  Phase 10 は配布準備として Phase 9 の後に置く（タスク ID の順序を保つため、Phase 9 内へは移動しない）
- **プレビューの拡大フィット (Phase 11)**: US1 の T028・T033 を置き換える追加作業。T086 → T087 → T088 の順に進め、
  T089 は独立して進められる。T088 は T086・T087 と `scripts/make-app.sh` に依存する
- **サムネイルのキーボード追従スクロール (Phase 12)**: FR-017 の追加作業。T090 の後に T091・T092 を並行でき、
  T093 は両方に依存する。T092 は US3 の `ThumbnailModeView` を変更するため、US3 の完了後に着手する
- **フルスクリーン中の矢印移動 (Phase 13)**: FR-046 の追加作業。US5 と US3 の完了後に着手する。
  T094 → T095・T096 の順に進め、T097 は T094・T096 に、T098 は T097 に依存する。
  T099 はファイルが重ならないため T094 と並行できる。T100 は T095〜T099 に依存する
- **ツリーのフォルダアイコン (Phase 14)**: FR-047 の追加作業。US1 の `DirectoryTreeViewController` に依存する。
  T101 → T102 → T103 の順に進める。T103 で US1 単独の手動確認を行い、Phase 15 を待たない
- **リスト形式の行頭アイコン (Phase 15)**: FR-048 の追加作業。US3 の `ThumbnailProvider`・
  `ThumbnailModeView`・`ListModeView`・`FileListViewController` と、Phase 14 の T101（`IconCatalog`）に依存する。
  T104（テスト）→ T105（64px 段階とサイズ単位キャンセル）→ T106（`ThumbnailModeView`）→
  T107（`ListModeView`）→ T108（`FileListViewController`）の順に進め、T109 は T103・T108 に依存する
- **ツールバー (Phase 16)**: FR-049〜052 の追加作業。US3 の `FileListViewController`（表示形式・サイズ・下部バー）と
  US5 の `MainSplitViewController`（フルスクリーン）に依存する。T110・T111（テスト）→ T112・T113（Core）→
  T114（`FileListViewController`）→ T115（`MainToolbarController`）・T116（`MainSplitViewController`）→
  T117（ウィンドウとメニューの結線）の順に進め、T119 は最後に行う。T118（README）はいつでも並行できる
- **ツリーのダブルクリック開閉と開閉の三角 (Phase 17)**: FR-053〜055 の追加作業。US1 の `DirectoryTreeViewController`・
  `DirectoryLister`・`FolderNode` と、Phase 14 のセル構成に依存する。Phase 16 とはファイルが重ならないが、Phase 単位で
  コミットするため、Phase 16 の T119 とコミットを済ませてから着手する。T120〜T122（テスト）→ T123・T124（モデル）・
  T125（`DirectoryLister`）→ T126（`SubfolderProbe`）→ T128 → T129 → T130（同じ `DirectoryTreeViewController.swift`）の順に進め、
  T132 は最後に行う。T127（性能テスト）は T125 の後、T131（README）はいつでも並行できる
- **種類フィルタ (Phase 18)**: FR-056〜060 の追加作業。US3 の `BrowserModel`・`FileListViewController` と、Phase 16 の
  `MainToolbarController` に依存する。Phase 単位でコミットするため、Phase 17 の T132 とコミットを済ませてから着手する。
  T133〜T136（テスト）→ T137（`MediaTypeFilter`）・T138（`BrowserState`）→ T139（`BrowserModel`）→ T140（App の `switch`）→
  T141（`FileListViewController`）→ T142（`MainToolbarController`）の順に進め、T144 は最後に行う。T138 で `.noMatches` を
  加えると App がビルドできなくなるため、T138〜T140 は続けて行う。T136（性能テスト）は T133〜T135 と同じく先に書き、T137 の後に通す。T143（README）はいつでも並行できる
- **お気に入り (Phase 19)**: FR-061〜067 の追加作業。US1 の `DirectoryTreeViewController`（Phase 14 のセル・Phase 17 の開閉と確認）、
  US4 の `ConfirmationPresenter`、Phase 16 の `SettingsStore` に依存する。Phase 単位でコミットするため、Phase 18 の T144 とコミットを
  済ませてから着手する。T145〜T148（テスト）→ T149（`FavoriteFolders`）→ T150（`FavoriteCommands`）・T151（`FavoriteProbe`）・
  T152（`SettingsStore`）→ T156 → T157 → T158（同じ `DirectoryTreeViewController.swift`）→ T159（メニューの結線）の順に進め、
  T161 は最後に行う。T153〜T155 は T156 の前ならいつでもよい。T160（README）はいつでも並行できる
- **zip の中の閲覧 (Phase 20)**: FR-068〜071・073〜075 の追加作業。US1 の `BrowserModel`・`DirectoryLister`、US3 の `ListModeView`・`ThumbnailModeView`・
  `ThumbnailProvider`・`FileListViewController`、Phase 13 の `FocusNavigator`、Phase 18 の `MediaTypeFilter` と `.noMatches` に依存する。Phase 単位で
  コミットするため、Phase 19 の T161 とコミットを済ませてから着手する。T162（フィクスチャの書き出し）→ T163（`ListItemKind` と既存の参照の修正。
  既存のテストを通してから次へ進む）→ T164〜T174（テスト）→ T175〜T185（Core の部品）→ T186（`BrowserState`）→ T187 → T188（同じ `BrowserModel.swift`）→ T189 → App の T190〜T196 の順に進め、
  T199 は最後に行う。T177 → T178 → T179 → T180 は順に依存する（構造の解析 → 索引 → 展開 → 読み取り器）。T197（`FixtureSets`）は T162 の後、
  T198（README）はいつでも並行できる
- **zip の中の動画 (Phase 21)**: FR-072・SC-014 の追加作業。Phase 20 の `ZipArchiveReader`・`InflateCursor`・`ThumbnailProvider`・`PreviewViewController` に依存する。
  Phase 20 の T199 とコミットを済ませてから着手する。T200〜T202（テスト）→ T203（`ArchiveEntryStream`）→ T204（`ArchiveAssetLoader`）→ T205・T206 の順に
  進め、T207 は最後に行う
- **ファイルリストのフォルダ (Phase 22)**: FR-008・070・076〜078 の追加作業。Phase 20 の `ListItemKind`・`ListItemCommands`・`BrowserModel` の zip の移動、Phase 19 の
  ツリーの `isRestoringSelection`・`reveal`、Phase 17 のサブフォルダの判定に依存する。Phase 21 と `MainSplitViewController.swift` を共有するため、Phase 21 の T207 と
  コミットを済ませてから着手する。T208（`.folder` と `..` の表記。既存のテストを通してから次へ進む）→ T210〜T216（テスト）→ T217〜T220（Core の部品）→
  T221（`BrowserModel`）→ T222（ファイルリスト）→ T223（ツリーと結線）の順に進め、T225 は最後に行う。T209（`FixtureSets`）と T224（README）はいつでも並行できる
- **フォルダのファイル操作 (Phase 23)**: FR-018・022・027・076 の追加作業。Phase 22 の `.folder` の行と `operableSelection`、US4 の `FileOperationCoordinator`・
  `ConfirmationPresenter` に依存する。Phase 22 の T225 とコミットを済ませてから着手する。T226（テスト）→ T227（`NameValidation`）→ T228（App の操作）→
  T229（ツリーと結線）の順に進め、T230 は最後に行う
- **ツリーのフォルダのゴミ箱 (Phase 24)**: FR-064・079 の追加作業。Phase 19 の `FavoriteCommands` とツリーのメニューの振り分け、Phase 22 の `FolderNavigation`・
  `navigateToFolder`・`treeSyncRequest`、Phase 23 の `FileOperationCoordinator.onFoldersChanged` とツリーの `refreshFolders` に依存する。Phase 23 の T230 とコミットを
  済ませてから着手する。T231〜T233（テスト）→ T234（`FavoriteCommands`）・T235（`FolderNavigation`）→ T236（`BrowserModel`）→ T237（`FileOperationCoordinator`）→
  T238（ツリー）の順に進め、T240 は最後に行う。T239（README）はいつでも並行できる

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
- アイコン: T081 → T082 → T083 → T084 → T085 の順に進める。
  T082 は T081 のターゲット追加後にビルド確認する
- プレビューの拡大フィット: T086・T089 はファイルが重ならないため並行できる。T087 は T086 の実装に依存し、
  T088 は T087 に依存する
- サムネイルのキーボード追従スクロール: T091（テスト）と T092（UI）はファイルが重ならないため、
  T090 の完了後に並行できる。T093 は T091・T092 に依存する
- フルスクリーン中の矢印移動: T094（Core）の完了後、T095（テスト）と T096（サムネイル UI）は
  ファイルが重ならないため並行できる。T097（FileListViewController）は T096 に、T098（MainSplitViewController）は
  T097 に依存する。T099（動画シーク）は T094 とファイルが重ならないため最初から並行できる。
  T100 は T095〜T099 の完了後に行う
- 行頭アイコン: T101（`IconCatalog`）の完了後、T102（ツリー）と T104（64px 段階のテスト）は
  ファイルが重ならないため並行できる。T103（ツリー手動確認）は T102 の後に行う。T105 は T104 に、
  T106 は T105 に、T107 は T101・T105 に、T108 は T107 に依存し、同じ
  `ListModeView` / `ThumbnailModeView` の初期化・要求を共有するため並行しない。T109 は最後に行う
- ツールバー: T110 と T111 はファイルが重ならないため並行できる。T112（`Settings.swift`・`SettingsStore.swift`）と
  T113（`FileListChrome.swift`）もそれぞれのテストの後に並行できる。T115（新規ファイル）と T116
  （`MainSplitViewController.swift`）は T114 の後に並行できる。T117 は `MainWindowController.swift` と
  `MainMenu.swift` を編集するため T115・T116 の後に行う。T118（`README.md`）は他と重ならない
- ツリーの開閉: T120・T121・T122 はファイルが重ならないため並行できる。T123（`FolderNode.swift`）と T124
  （`FolderDisclosure.swift`）は並行できるが、T120 は両方が揃うまでビルドできない。T125 は T121 の後、T126 は T122・T125 の後に行う。
  T127（`PerformanceBaselineTests.swift`）は T125 の後に T126 と並行できる。T128〜T130 は同じ
  `DirectoryTreeViewController.swift` を編集するため並行せず、この順に進める。T131（`README.md`）は他と重ならないため、いつでも並行できる
- 種類フィルタ: T133・T134・T135・T136 はファイルが重ならないため並行できる。T137（`MediaTypeFilter.swift`）と T138
  （`BrowserState.swift`）は並行できるが、T133 は両方が揃うまでビルドできない。T139 は T134〜T138 の後に行う。
  T140 と T141 は同じ `FileListViewController.swift` を編集するため並行せず、この順に進める。T142 は T141 の後に行う。
  T136（`PerformanceBaselineTests.swift`）も T133〜T135 と並行して先に書ける。T143（`README.md`）は他と重ならない
- お気に入り: T145・T146・T147・T148 はファイルが重ならないため並行できる。T149（`FavoriteFolders.swift`）と T151（`FavoriteProbe.swift`）は
  並行できる。T150 と T152 は T149 の後に並行できる。T153（`ConfirmationPresenter.swift`）・T154（`IconCatalog.swift`）・
  T155（`SettingsWindowController.swift`）は互いに、また Core のタスクとも並行できる。T156〜T158 は同じ
  `DirectoryTreeViewController.swift` を編集するため並行せず、この順に進める。T156 は `MainSplitViewController.swift` の `init()` も、
  T159 は同じファイルのメニュー検証も編集するため、T156 と T159 は並行しない。T160（`README.md`）は他と重ならない
- zip の中の閲覧: T164〜T172 と T174 はファイルが重ならないため並行できる（T173 は T172 と同じく先に書けるが、`BrowserModel` の多くの API を
  参照するため最後に書くとよい）。T175（`ArchiveURL`・`ArchiveLocation`）・T176（`ArchiveNameDecoder`）・T181（`ListItemCommands`）・
  T182（`FocusNavigator`）・T183（`MediaTypeFilter`・`Sorting`）・T184（`DirectoryLister`）・T185（`ImageDecoder`）は T163 の後に互いに並行できる。
  T177〜T180 は順に進める。T187・T188 は同じ `BrowserModel.swift`、T192 と T193・T194・T195 は `FileListViewController` の結線を共有するため、この順に
  進める。T190（`IconCatalog.swift`）は T193・T194 の前に行う。T196 は T186 の後なら App のほかのタスクと並行できる
- zip の中の動画: T200・T201・T202 はファイルが重ならないため並行できる。T205（`ThumbnailProvider.swift`）と T206（App）は T204 の後に並行できる
- ファイルリストのフォルダ: T210〜T214 と T216 はファイルが重ならないため並行できる（T215 も先に書けるが、`BrowserModel` の新しい API を参照するため最後に書くとよい）。
  T217（`FolderNavigation.swift`）・T218（`ParentLink.swift`）・T219（`ListItemCommands.swift`）・T220（`DirectoryLister.swift`）は T208 の後に互いに並行できる。
  T221 は T217〜T220 の後、T222 は T219・T221 の後、T223 は T221 の後に行う。T222 と T223 はファイルが重ならないが、どちらも `swift build` を確かめるため順に進めるとよい。
  T209（`FixtureSets.swift`）と T224（`README.md`）は他と重ならない
- フォルダのファイル操作: T226 の後、T227（Core）と T228（`FileOperationCoordinator.swift`・`ConfirmationPresenter.swift`）は T228 が T227 の `isDirectory` を使うため順に進める。
  T229 は `DirectoryTreeViewController.swift` と `MainSplitViewController.swift` を編集し、T228 の `onFoldersChanged` に依存する
- ツリーのフォルダのゴミ箱: T231・T232・T233 はファイルが重ならないため並行できる。T234（`FavoriteCommands.swift`）と T235（`FolderNavigation.swift`）は並行できるが、
  T234 は T235 の `enclosingFolder` を使うだけなので順序の制約はない。T236 は T235 の後、T237 は T236 の後、T238 は T234・T237 の後に行う。T239（`README.md`）は他と重ならない
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
8. アプリアイコン → `.app` に固有アイコンを同梱（FR-043〜045、SC-011）
9. プレビューの拡大フィット → 小さい画像もペインとフルスクリーンに合わせて拡大（FR-028 改定）
10. サムネイルのキーボード追従スクロール → 矢印キーで一覧を辿るときもフォーカス項目が見え続ける（FR-017 改定）
11. フルスクリーン中の矢印移動 → 全画面のまま前後のファイルへ移動でき、動画のシークは `<` / `>` で行える（FR-046）
12. 行頭アイコン → ツリーでフォルダ種別が分かり、リスト形式で内容の縮小画像が見える（FR-047・048）
13. ツールバー → ⇧⌘T で表示し、表示形式とサムネイルサイズをツールバーから操作できる（FR-049〜052）
14. ツリーの開閉 → 行のダブルクリックで開閉でき、三角はサブフォルダがあるフォルダにだけ出る（FR-053〜055）
15. 種類フィルタ → ツールバー・メニュー・⇧⌘I / ⇧⌘M で画像だけ・動画だけに絞り込める（FR-056〜060）
16. お気に入り → ツリー最上部の「お気に入り」から登録したフォルダをすぐに開け、⌃⌘T / ⌘⌫ / ⇧⌘F で操作できる（FR-061〜067）
17. zip の中の閲覧 → ファイルリストで zip を開いて中の画像を見られ、⌘↓ / ⌘↑ と `...` で辿れる。zip の中は読み取り専用（FR-068〜071・073〜075）
18. zip の中の動画 → zip の中の動画を、一時ファイルを作らずにストリーミングで再生できる（FR-072、SC-014）
19. ファイルリストのフォルダ → 一覧にフォルダが出て、ダブルクリック・⌘↓ で入り、`..`・⌘↑ で戻れる。ツリーの選択が追従する（FR-076〜078）
20. フォルダのファイル操作 → フォルダもファイルと同じくコピー・名前の変更・ゴミ箱・移動でき、ツリーにすぐ反映される（FR-018・076）
21. ツリーのフォルダのゴミ箱 → ツリーの通常のフォルダを ⌘⌫ と右クリックメニューからゴミ箱に入れられ、表示中なら親フォルダへ移る（FR-079）

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- 性能に影響する変更の PR には、T076・T077 の計測結果を記載する（憲章 原則 II）
- 新しい操作を追加したら、contracts/keyboard-and-menus.md の表も更新する（憲章 原則 III）
- アイコンはビルド時のみ生成し、外部素材・追加依存・ネットワークを使わない。
  `.build/AppIcon.icns` はコミットしない（research.md R14、原則 I・V）
- FR-028 の改定（2026-10-20）により、完了済みの T028・T033 の「原寸を超えて拡大しない」は
  Phase 11 の T086・T087 が置き換える。履歴として元の記述は残す
- 小さい画像の拡大はレイヤーのフレーム変更だけで行い、デコードや再描画を増やさない（計画書「変更点」）
- FR-017 の改定（2026-10-20）により、サムネイル形式の矢印移動ではフォーカス項目全体が見える最小限の
  スクロールを行う。対象はサムネイル形式のみで、リスト形式は OS 標準の追従を維持する。
  サムネイルサイズ・ペイン幅・ウィンドウサイズの変更では追従しない（spec Clarifications、R15）
- FR-046（2026-10-20）により、フルスクリーン中もファイルリストと同じ規則で矢印移動できる。
  移動規則は `FocusNavigator` に集約し、表示形式ごとに二重実装しない。端では循環せず停止する。
  動画のフルスクリーンでは矢印をファイル移動に使い、シークは `<` / `>`（5 秒）で行う。
  Shift+矢印の範囲選択はフルスクリーンでは対象外（spec の Outstanding）とし、イベントを横取りしない
- FR-047・048（2026-10-20）により、ツリーはホーム・ボリューム・通常フォルダを SF Symbols で区別し、
  リスト形式は内容の縮小画像を 64px 段階で遅延取得する。取得中・失敗時は形式別の SF Symbol を残し、
  a11y 要素にはしない。新しい設定・永続化・外部素材・外部依存を追加しない（research.md R17）
- サムネイルのキャンセルは FR-048 の追加に伴い、T047・T052 の URL だけの `cancel(for:)` から
  URL + 要求サイズ（`cancel(for:pointSize:scale:)`）へ置き換える。リストの 64px 要求が
  サムネイル形式の 128px 以上の要求を巻き込まないようにする（T105・T106）
- FR-049〜052（2026-10-20）により、メインウィンドウに `NSToolbar` を追加する。既定は非表示で、表示状態は
  `view.showsToolbar` だけに保存し、`NSToolbar` の自動保存は使わない。表示形式・サイズの状態は
  `FileListViewController` を唯一の正とし、メニュー・下部バー・ツールバーで同じ経路を通す。
  フルスクリーン中はツールバーを自動で隠し、保存値は変えない（research.md R18）
- FR-053〜055（2026-10-20）により、ツリーの行のダブルクリックで開閉をトグルし、開閉の三角はサブフォルダの有無が
  `.present` または `.failed` のフォルダにだけ出す。確認は表示中のフォルダの直下1階層だけを、最初の1件で打ち切り、
  同時 4 件までで行う。展開時の読み込み失敗は「アクセスできません」の表示にそろえ、権限なし（`.denied`）は三角を消し、
  それ以外（`.unavailable`）は三角を残して再展開で読み直す。確認結果は
  永続化しない（research.md R19）
- FR-056〜060（2026-10-20）により、ファイルリストを「画像のみ表示」「動画のみ表示」の独立した2つのオン・オフで絞り込む。
  状態は `BrowserModel.mediaTypeFilter` の1か所だけに持ち、保存しない。`listing.files` を絞り込み後の配列にするため、
  一覧・選択・先読み・フルスクリーン移動・ファイル操作は表示中の一覧だけを対象にする。対象はあるが0件のときは `.noMatches` とし、
  `.empty` と文言を分ける。隠れた選択は外し、戻しても復元しない（research.md R20）
- FR-061〜067（2026-10-20）により、ツリーの最上部に仮想的な「お気に入り」の見出しを置く。登録はパスの配列 `favorites.paths` だけに保存し、
  ブックマークによる追従・見つかるかどうか・見出しの開閉状態は保存しない。操作の可否は `FavoriteCommands` に集め、メニュー・
  ショートカット・右クリックで同じ判断を使う。⌘⌫ は新しいメニュー項目を作らず、既存の「ゴミ箱に入れる」をレスポンダーチェーンで
  ツリーに振り分け、項目名を「お気に入りから削除」に変える。削除は確認モーダル（ファイル操作と同じ省略設定）を通し、実際のフォルダは
  変えない（research.md R21）
- FR-068〜075（2026-10-21）により、ファイルリストに zip ファイルを出し、zip の中をファイルリストの中だけで辿る。zip はツリーに出さない。
  zip の読み取りは外部依存を使わず Core に自前で持ち（Complexity Tracking）、zip の中の項目は `mvzip:` の URL で表して既存の選択・キャッシュを使う。
  zip の中は読み取り専用で、判断は `ListItemCommands` に集める。zip の中身は一時ファイルにもユーザーのフォルダにも書き出さない。動画は
  `AVAssetResourceLoaderDelegate` で必要な範囲だけを読み、メモリは 32MB のチャンクキャッシュと展開カーソル 2 本で頭打ちにする（research.md R22〜R28）
- FR-076〜078（2026-10-21）により、ファイルリストにサブフォルダ（`ListItemKind.folder`）を出し、通常のフォルダの先頭行にも `..` を置く（ツリーのルートでは出さない）。
  戻る行の表記は zip の中も含めて `..` に統一した。Phase 20 の完了済みタスクの `...` は履歴として残し、T208 で実装を `..` に置き換える。ツリーの同期は
  `BrowserModel.treeSyncRequest` を介して行い、ツリーからの選択を送り返さない。フォルダはファイルと同じ全操作の対象にし、`..` の行は操作の対象から除く。
  フォルダの削除はファイルリストからだけで、ツリーの ⌘⌫ は変えない（research.md R29〜R32）。この最後の点は FR-079 で変更した（次の項目）
- FR-079（2026-10-21）により、ツリーのルート以外の通常のフォルダを ⌘⌫ と右クリックメニューの「ゴミ箱に入れる」でゴミ箱に入れられるようにする。新しいメニュー項目・キーは
  作らず、既存の「ゴミ箱に入れる」の検証で振り分ける（お気に入りの項目は「お気に入りから削除」のまま）。ルートの判定は `..` と同じ `FolderNavigation.enclosingFolder` を使い、
  `TreeItemRole` に種類を足さない。実行はファイルリストと同じ `FileOperationCoordinator.trash(_:)` を通し、表示中のフォルダかその祖先を入れたときは
  `BrowserModel.leaveTrashedFolders` が `navigateToFolder` で親へ移り、`treeSyncRequest` でツリーの親を選ぶ（research.md R33）
- Commit after each task or logical group
