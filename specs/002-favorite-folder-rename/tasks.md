---

description: "Task list for お気に入りの名前の変更"
---

# Tasks: お気に入りの名前の変更

**Input**: Design documents from `/specs/002-favorite-folder-rename/`

**Prerequisites**: plan.md, spec.md, research.md（R48〜R56）, data-model.md, contracts/, quickstart.md

**Tests**: 憲章 原則 IV（テスト必須）により、`MediaViewerCore` の判断ロジックと異常系には自動テストを付ける
（data-model.md の「テスト」の表）。各テストタスクは対応する実装タスクの前に書き、ビルドエラーまたは失敗になることを確かめてから実装する。
行内編集・メニューの検証・確認モーダル・VoiceOver・名前の変更中の無効化は、quickstart.md の手動確認で検証する（R56）。

**Organization**: spec.md のユーザーストーリーは US1（既存 US1 への追加）の1つだけのため、Phase 3 に Core とアプリの実装をまとめる。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1)
- Include exact file paths in descriptions

## Path Conventions

- Core（AppKit 非依存）: `Sources/MediaViewerCore/`
- UI（AppKit）: `Sources/MediaViewerApp/`
- テスト: `Tests/MediaViewerCoreTests/`
- 共通ルール: Swift 6 strict concurrency。Core から `import AppKit` しない。ネットワーク API は使わない。
  実際のフォルダ（ファイルシステム）は一切変更しない（FR-099、SC-019）
- 変更しないファイル: `Sources/MediaViewerApp/App/MainMenu.swift`・`FileListViewController`・`PaneCommands`・`MainToolbarController`（plan.md、R52・R53）
- コードのコメントでは判断の根拠を `R48` のように research.md の番号で参照する

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 変更前の状態が健全であることを確かめる。新しいターゲットや依存は追加しない

- [ ] T001 ブランチ `002-favorite-folder-rename` で、変更前に `swift build` と `swift test` が通ることを確かめる。失敗があれば
  この feature の変更に入る前にユーザーへ報告する（既存の失敗をこの feature で直さない）

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: なし。ユーザーストーリーが US1 の1つだけで、追加する型（`FavoriteName` など）はすべて US1 のためのものなので Phase 3 に置く

---

## Phase 3: User Story 1 - お気に入りの項目に表示名を付ける (Priority: P1) 🎯 MVP

**Goal**: 「お気に入り」の下の項目を、Return・右クリックの「名前を変更」・「編集 > 名前を変更」で行の中で名前を変えられるようにする。
表示名は `favorites.displayNames` に保存して次回起動時に復元し、実際のフォルダには触れない（FR-099〜102、FR-064 の変更）

**Independent Test**: `swift test` で `FavoriteNameTests`・`FavoriteFoldersTests`・`FavoriteCommandsTests`・`SettingsStoreTests` が通ること。
`.app` で quickstart.md の「3. 手動確認」1〜24 を行い、場所の違う同じ名前のフォルダを2つ登録して片方の名前を変えると、ツリー上で見分けられ、
Finder で実際のフォルダの名前が変わっておらず、再起動後も名前が残ること

### Tests for User Story 1

> **NOTE: 先に書き、ビルドエラーまたは失敗になることを確かめてから T006〜T009 を実装する**

- [ ] T002 [P] [US1] `Tests/MediaViewerCoreTests/FavoriteNameTests.swift` を新規作成する（`@Suite("FavoriteName")`、Swift Testing）。T006 の前にビルドエラーになることを確かめる:
  - `normalized`: `"  2025 "` → `"2025"`、`"\n2025\n"` → `"2025"`、`""`・`"   "`・`" \n\t "` → nil
  - `normalized` と `sanitizedForEditing` が、中の改行 `"\n"`・`"\r\n"`・U+2028（`"\u{2028}"`）を取り除く（`"a\nb"` → `"ab"`）
  - `sanitizedForEditing` は前後の空白を残す（`" a "` → `" a "`）
  - `maximumLength == 255`。255 文字ちょうどの入力はそのまま、256 文字・300 文字の入力は先頭 255 文字に切れる
  - 長さは `String.count`（書記素クラスタ）で数える: 絵文字（`"👨‍👩‍👧"`）や結合文字（`"e\u{301}"`）を 255 個並べた入力は切れず、256 個で 255 個に切れる。切った結果の末尾が書記素の途中で切れていない
  - `/`・`:` を含む名前（`"a/b:c"`）をそのまま受け付ける
- [ ] T003 [P] [US1] `Tests/MediaViewerCoreTests/FavoriteFoldersTests.swift` にケースを追加する（T007 の前にビルドエラーになることを確かめる）。URL は既存のケースと同じく `/tmp/fav/...` を使う:
  - `commitDisplayName("2025（バックアップ）", for: b, defaultName: "2025")` → true、`customName(for: b) == "2025（バックアップ）"`、`displayName(for: b, defaultName: "2025")` が同じ値
  - 別の名前へ変更 → true。空・空白だけで確定 → true で `customName(for:) == nil`、`displayName` が `defaultName`
  - 現在の表示名と同じ名前（前後の空白だけ違うものを含む）で確定 → false で変わらない。表示名なしの項目で `defaultName` と同じ名前を確定 → false（Return を2回押しても表示名が付かない。R50）
  - 表示名ありの項目で `defaultName` と同じ名前を確定 → true で、表示名として残る（解除しない。EC-41）
  - 2つの項目に同じ表示名を付けられる（EC-41）。`"a/b:c"` も受け付ける
  - 未登録の場所への `commitDisplayName` → false、`customNamesByPath` は空のまま
  - `remove` で表示名も消え、同じ場所を `add` し直すと `customName(for:) == nil`（EC-44）
  - 表記の違い（末尾の `/`、`..` を含む）でも同じ登録の表示名を引ける・設定できる
  - `init(urls:customNames:)` が、未登録のパスのキーと、正規化して空になる値（`"  "`）を捨て、256 文字の値を 255 文字に丸める。改行を含む値は改行を除く
  - `customNamesByPath` のキーが `standardizedFileURL.path` であること
  - 等価比較が表示名を含む（`urls` が同じで表示名だけ違えば `!=`）
  - 既存のケース（`init(urls:)` の重複除去など）は変えずに通す
- [ ] T004 [P] [US1] `Tests/MediaViewerCoreTests/FavoriteCommandsTests.swift` を変える（T008 の前にビルドエラーになることを確かめる）:
  - `renameTarget(.favorite(a))` → `a`。`renameTarget(.favoritesHeader)`・`renameTarget(.folder(a))`・`renameTarget(.folder(/Users/me))`（ルート）・`renameTarget(nil)` → nil（US1-AS35）
  - 既存の34行目と92行目の `contextMenu(for: .favorite(...)) == [.removeFromFavorites]` を `[.renameFavorite, .removeFromFavorites]` に改める（`roots` を渡す場合も同じ）
  - `.folder`（ルートとルート以外）・`.favoritesHeader` のメニューに `.renameFavorite` が含まれない
  - ほかの既存のケースは変えずに通す
- [ ] T005 [P] [US1] `Tests/MediaViewerCoreTests/SettingsStoreTests.swift` の `// MARK: - favorites` にケースを追加する（T009 の前に失敗することを確かめる）。既存のケースと同じ一時ドメインの `UserDefaults` を使う:
  - 表示名の往復: `FavoriteFolders(urls: [a, b], customNames: [b.path: "2025（バックアップ）"])` を書いて読むと等しい。`defaults.dictionary(forKey: "favorites.displayNames")` が `[b.path: "2025（バックアップ）"]`
  - 旧形式: `favorites.paths` だけを書いた状態で読むと、登録順のまま全件 `customName(for:) == nil`（EC-45）
  - `favorites.displayNames` が辞書でない（文字列・配列）→ 表示名なしで、登録は失われない
  - 値が文字列でない項目（数値）、`favorites.paths` にないパスの項目、空白だけの値の項目を捨てる。改行を含む値は改行を除いて読む
  - 300 文字の保存値を 255 文字に丸めて読む
  - 表示名が1つもない `FavoriteFolders` を書くと `favorites.displayNames` のキーが消える（`defaults.object(forKey:) == nil`）
  - 表示名を付けた登録を `remove` してから書くと、そのパスが `favorites.displayNames` に残らない
  - `favorites.paths` の書き込み内容は従来どおり（既存の `favoritesRoundTrip` が通る）

### Implementation for User Story 1（Core）

- [ ] T006 [P] [US1] `Sources/MediaViewerCore/Model/FavoriteName.swift` を新規作成する（R50、data-model の「FavoriteName」、contracts/core-api.md。T002 を通す）:
  - `public enum FavoriteName`。`public static let maximumLength = 255`（「`String.count`（書記素クラスタ）で数える」）
  - `public static func sanitizedForEditing(_ text: String) -> String`: 「改行（`CharacterSet.newlines` に含まれる文字）を取り除き、先頭から 255 文字で打ち切る。
    前後の空白は残す（入力中のため）」。改行の判定は Unicode scalar 単位で行い、`\r\n` のような1書記素の改行も除く。打ち切りは `String(text.prefix(maximumLength))`
  - `public static func normalized(_ text: String) -> String?`: 「`sanitizedForEditing` の後に前後の空白と改行を取り除く。空なら nil」
  - `/`・`:` を拒否せず、重複の検査もしない（EC-41）。各メンバーのドキュメントコメントに FR-100 を書く
- [ ] T007 [US1] `Sources/MediaViewerCore/Model/FavoriteFolders.swift` を変える（R48、data-model の「FavoriteFolders」。T006 の後。T003 を通す）:
  - `private var customNames: [String: String]`（キーは既存の `key(_:)` ＝ `standardizedFileURL.path`）を足す。不変条件をコメントに書く:
    「キーは、すべて `urls` に登録されている場所のキー」「値は `FavoriteName.normalized(_:)` を通した値で、1〜255 文字・改行なし・前後に空白なし」
  - `init(urls:)` を `public init(urls: [URL] = [], customNames: [String: String] = [:])` にする。重複除去は既存どおり。`customNames` は各キーを
    `URL(fileURLWithPath:)` の `key` に揃え、「未登録のキーと、正規化して空になる値を捨てる」
  - `public func customName(for url: URL) -> String?`、`public func displayName(for url: URL, defaultName: String) -> String`（`customName(for:) ?? defaultName`。FR-101）
  - `@discardableResult public mutating func commitDisplayName(_ input: String, for url: URL, defaultName: String) -> Bool`: 未登録なら false。
    `FavoriteName.normalized(input)` が現在の表示名（`displayName(for:defaultName:)`）と同じなら何もせず false。nil なら表示名を解除、それ以外は表示名にして true
    （`defaultName` と同じ名前でも表示名ありの項目では表示名として残す。EC-41、R50）
  - `remove(_:)` は登録と一緒に `customNames` のキーも消す（EC-44）。`add(_:)` は表示名を付けない
  - `public var customNamesByPath: [String: String] { customNames }`（保存用）
  - `Equatable` は合成のまま（`urls` と `customNames` の両方で比べる）。ファイルシステムには触れない
  - 既存の呼び出し側（`FavoriteFolders(urls:)`・`FavoriteFolders()`）がそのままビルドできることを確かめる
- [ ] T008 [P] [US1] `Sources/MediaViewerCore/Model/FavoriteCommands.swift` を変える（R52、data-model の「FavoriteCommands・TreeContextMenuItem」。T004 を通す）:
  - `TreeContextMenuItem` に `case renameFavorite` を足す（コメント「お気に入りの項目の「名前を変更」（FR-099）」）
  - `public static func renameTarget(_ role: TreeItemRole?) -> URL?`: `.favorite(url)` のときだけ url、`.favoritesHeader`・`.folder`・nil は nil（FR-099、US1-AS35）。
    ドキュメントコメント「Return・「編集 > 名前を変更」・右クリックの「名前を変更」の対象」
  - `contextMenu(for:roots:)` の `.favorite` を `[.renameFavorite, .removeFromFavorites]` にする。`.folder`・`.favoritesHeader` は変えない
  - `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` の `makeContextMenuItem` の `switch` は `default` がなく網羅的なので、
    ケースを足すと必ずビルドエラーになる。このタスクで `.renameFavorite` の分岐を必ず足す。この時点ではタイトル「名前を変更」・アクションなし
    （`action: nil`。メニューでは淡色）の仮の項目にし、T012 で本来のアクションとキー等価に置き換える。`swift build` が通ることを確かめる
  - App のファイルを触るため、T011〜T016（同じ `DirectoryTreeViewController.swift`）より前に終える。[P] は T006・T007・T009・T010 との並行を指す
- [ ] T009 [US1] `Sources/MediaViewerCore/Settings/SettingsStore.swift` の `favorites` を変える（R49、contracts/settings.md。T007 の後。T005 を通す）:
  - `Keys` に `static let favoriteDisplayNames = "favorites.displayNames"` を足す
  - get: `favorites.paths` の読み方は変えない。`defaults.object(forKey: Keys.favoriteDisplayNames) as? [String: Any]` が取れなければ表示名なし。取れたら
    `compactMapValues { $0 as? String }` で文字列でない値を捨て、`FavoriteFolders(urls: urls, customNames: names)` に渡す（未登録のパス・空になる値の破棄と
    正規化・255 文字への丸めは `init` が行う）
  - set: `favorites.paths` は従来どおり `newValue.urls.map(\.path)`。`newValue.customNamesByPath` が空なら `removeObject(forKey: Keys.favoriteDisplayNames)`、
    空でなければ `set` する
  - プロパティのドキュメントコメントに「表示名は `favorites.displayNames`（標準化した絶対パス → 表示名）に、付けた分だけ保存する。旧形式（`favorites.paths` だけ）は
    全件表示名なしとして読む。移行処理は持たない（R49）」を足す
  - `swift test --filter MediaViewerCoreTests` が通ることを確かめる

### Implementation for User Story 1（App）

- [ ] T010 [P] [US1] `Sources/MediaViewerApp/Tree/FavoriteNameFormatter.swift` を新規作成する（R50。T006 の後）:
  - `final class FavoriteNameFormatter: Formatter`。判定は `FavoriteName` に任せ、このクラスに規則を書かない
  - `string(for obj: Any?) -> String?` は `obj as? String`、`getObjectValue(_:for:errorDescription:)` は文字列をそのまま `obj` に入れて true（`stringValue` の読み書きを変えない）
  - `isPartialStringValid(_ partialStringPtr: AutoreleasingUnsafeMutablePointer<NSString>, proposedSelectedRange:originalString:originalSelectedRange:errorDescription:) -> Bool`:
    `FavoriteName.sanitizedForEditing(partial)` が入力と同じなら true。違えば `partialStringPtr` を整形後の文字列に置き換え、選択位置を整形後の末尾
    （または元の位置を超えない範囲）に直して false を返す（ペーストを含めて改行と 256 文字目以降が入らない。FR-100）
  - クラスに分離の注釈（`@MainActor` など）は付けない。`Formatter` の override するメソッドは nonisolated のため、
    クラスを `@MainActor` にすると Swift 6 で override の分離が合わずビルドエラーになる。判定は純粋関数の `FavoriteName` に任せ、
    状態を持たないため分離は要らない
  - `override init()`（`super.init()` を呼ぶ）と `required init?(coder: NSCoder)`（`super.init(coder:)` を呼ぶ）を置く
- [ ] T011 [US1] `Sources/MediaViewerApp/Operations/ConfirmationPresenter.swift` の `confirmRemovingFavorite(named:)` を `confirmRemovingFavorite(named name: String, path: String)` に置き換える（R55、FR-064 の変更）:
  - `informativeText` を `"対象: \(name)\n場所: \(path)\n実際のフォルダは変更されません"` にする。メッセージ・ボタン・省略設定（FR-023）の扱いは変えない
  - 唯一の呼び出し側 `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` の `removeFavorite(_:)` を `confirmRemovingFavorite(named: entry.name, path: entry.url.path)` に直す
  - `swift build` が通ることを確かめる（T012〜T016 と同じファイルを触るため、それらより先に行う）
- [ ] T012 [US1] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` で表示名を表示に使う（R48・R52・R54、data-model の「App 側の状態」。T007・T008・T011 の後）:
  - `FavoriteEntry` に `var defaultName: String` を足す（登録したフォルダの名前。ルートならボリューム名）。`name` の意味を「表示名」に変え、コメントを直す
  - `rebuildFavoriteEntries()`: `defaultName = root?.folder.name ?? url.lastPathComponent`（既存の名前の決め方）、`name = favorites.displayName(for: url, defaultName: defaultName)`。
    既存の項目を使い回すときも `name`・`defaultName`・`kind` を更新する
  - `outlineView(_:viewFor:item:)` の `FavoriteEntry` の行は従来どおり `cell.textField?.stringValue = entry.name`（VoiceOver はこれを項目名として読む。FR-101）
  - `makeContextMenuItem` の `.renameFavorite`（T008 で足した仮の分岐）を本来の項目に置き換える: タイトル「名前を変更」、アクション `renameFavoriteFromMenu(_:)`（T014）、`keyEquivalent` は `"\r"`、修飾キーなし（Return を表示）。
    `target`・`representedObject` は既存の項目と同じく設定する
  - `swift build` が通ることを確かめる（`renameFavoriteFromMenu(_:)` は T014 までは何もしない空の実装を置いてよい）
- [ ] T013 [US1] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` に行内編集の開始・終了を実装する（R51・R54。T010・T012 の後。`ListModeView.beginRenaming` / `finishRenaming` と同じ型にする）:
  - 状態: `private var editingFavorite: FavoriteEntry?`（nil 以外の間は「名前の変更中」）、`private var editingOriginalName: String?`、`private var isFinishingEdit = false`、
    `private var needsReloadAfterEdit = false`、`private let favoriteNameFormatter = FavoriteNameFormatter()`
  - `private func beginEditingFavorite(_ entry: FavoriteEntry) -> Bool`: 編集中なら false。`outlineView.row(forItem: entry)` の行を `scrollRowToVisible` し、
    `layoutSubtreeIfNeeded()` の後 `view(atColumn: 0, row:, makeIfNecessary: true)` のセルの `textField` を取る。`stringValue = entry.name`、
    `formatter = favoriteNameFormatter`、`delegate = self`、`setAccessibilityLabel("お気に入りの名前")`、編集の見た目（`isEditable`・`isSelectable`・
    背景・`focusRingType`。`ListModeView.setEditingAppearance` と同じ）にして `window.makeFirstResponder(field)`。失敗したら元に戻して false。
    成功したらフィールドエディタ（`field.currentEditor() as? NSTextView`）の選択を全体にする（FR-099「現在の表示名を全選択」）。
    ツリーの選択・`model`（ファイルリスト・プレビュー・最後に選択していたフォルダ）には触れない（FR-102）
  - `private func finishEditingFavorite(commit: Bool, restoresFocus: Bool)`: `isFinishingEdit` で再入を防ぎ（`defer` で戻す）、`editingFavorite` と元の名前を nil に戻す。
    そのあと次の順で行う（`ListModeView.finishRenaming` と同じく、編集を終えてから行を更新する。編集中のセルを `reloadItem` すると、
    フィールドエディタが切り離されたセルに残るおそれがあるため）:
    1. 入力値を取る: セルがあれば `field.stringValue` を取る
    2. 見た目を戻す: 非編集の見た目にし、`formatter = nil`・`delegate = nil`・`setAccessibilityLabel(nil)` にする
    3. 編集を終える: `restoresFocus` なら `window.makeFirstResponder(outlineView)`。そうでなければ、フィールドエディタがまだこのフィールドに付いているとき
       （`field.currentEditor() != nil`）だけ `window.endEditing(for: field)` を呼ぶ（クリック先のフォーカスは変えない。A-31）。
       ここで `controlTextDidEndEditing(_:)` が来ても `isFinishingEdit` で何もしない
    4. commit: `commit` なら `favorites.commitDisplayName(input, for: entry.url, defaultName: entry.defaultName)` が true のときだけ `settings.favorites = favorites` と
       `rebuildFavoriteEntries()`
    5. `reloadItem`: 最後に必ず `outlineView.reloadItem(entry)` で表示名と淡色（編集中に届いた availability）を反映し、`needsReloadAfterEdit = false`
    確認モーダルは出さない（FR-099、A-29）。ファイルシステムには触れない
  - `NSTextFieldDelegate` に準拠する extension を足す:
    `control(_:textView:doCommandBy:)` で `#selector(NSResponder.insertNewline(_:))` → `finishEditingFavorite(commit: true, restoresFocus: true)`、
    `#selector(NSResponder.cancelOperation(_:))` → `finishEditingFavorite(commit: false, restoresFocus: true)`（Esc で編集前に戻す。US1-AS32）。どちらも true を返す。
    `controlTextDidEndEditing(_:)` → `finishEditingFavorite(commit: true, restoresFocus: false)`（ほかの場所のクリックで確定し、クリック先のフォーカスを変えない。A-31）
  - `outlineView(_:viewFor:item:)` で、どの行（`Node`・見出し・`FavoriteEntry`）のセルも毎回非編集の見た目・`formatter = nil`・`delegate = nil`・
    `setAccessibilityLabel(nil)` に戻す（セルは共有のため。R51・R54）。見た目を戻す処理は `beginEditingFavorite` と共有の `setEditingAppearance(_:editing:)` にまとめる
- [ ] T014 [US1] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` に開始の経路を実装する（R52、FR-099。T013 の後）:
  - `@objc func rename(_ sender: Any?)`: 「編集 > 名前を変更」と Return（既存のメニュー項目 `#selector(FileListViewController.rename(_:))`、`target = nil`）を応答チェーンで受ける。
    `FavoriteCommands.renameTarget(role(for: selectedItem))` が URL を返し、`selectedItem` が `FavoriteEntry` のときだけ `beginEditingFavorite` を呼ぶ。
    ドキュメントコメント「ツリーにフォーカスがあるときの Return・「編集 > 名前を変更」。お気に入りの項目だけ表示名の編集を始める（FR-099）。
    zip の中・検索結果の表示中も `BrowserModel` の状態は見ない（EC-46）」
  - `@objc private func renameFavoriteFromMenu(_ sender: Any?)`: `(sender as? NSMenuItem)?.representedObject`（右クリックした行。A-21）に `renameTarget` を当て、
    `FavoriteEntry` なら `beginEditingFavorite`。ツリーの選択は変えない。メニューの追跡中で `makeFirstResponder` に失敗する場合は、
    `Task { @MainActor in ... }` で次のターンに回して始める
  - `MainMenu.swift` は変えない（R52）
- [ ] T015 [US1] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` の `validateMenuItem(_:)` を変える（R52・R53、FR-099・102。T014 の後）:
  - 先頭で `editingFavorite != nil` なら、自分のアクション（`rename(_:)`・`renameFavoriteFromMenu(_:)`・`moveToTrash(_:)`・`trashFolderFromMenu(_:)`・`paste(_:)`・
    `movePaste(_:)`・`revealInFinder(_:)`・`addToFavorites(_:)`・`removeFavoriteFromMenu(_:)`）にはすべて false を返す（並びは契約 keyboard-and-menus.md の 2・R53 と同じ）。コメントに「Return と ⌘⌫ はメニューの
    キー等価がフィールドエディタより先に処理されるため、無効にしないと編集中の Return が確定にならず、⌘⌫ でお気に入りが削除される（R53）」と書く。
    ここで無効になるのは、`paste(_:)` は右クリックの「ここにペースト」、`movePaste(_:)` は右クリックの「ここに移動ペースト」と「編集 > 移動ペースト」（⌥⌘V）。
    「編集 > ペースト」（⌘V）は名前の変更中はフィールドエディタが先に受けて編集欄へのテキストのペーストになり、この検証には来ない（無効にしない。R53）
  - 編集中でないとき: `rename(_:)` は `FavoriteCommands.renameTarget(role(for: selectedItem)) != nil`（お気に入りの項目以外・未選択では無効。US1-AS35）、
    `renameFavoriteFromMenu(_:)` は `renameTarget(role(for: menuItem.representedObject)) != nil`
  - ほかの項目の既存の判定は変えない。`PaneCommands`・ツールバー・`FileListViewController` の無効化は、既存の `isEditingText`（first responder が `NSTextView`）で効くため変えない（R53）
- [ ] T016 [US1] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` で、編集中に起こるツリーの再読み込みを扱う（R51「編集中に起こるツリーの再読み込み」、EC-42・43。T013 の後）:
  - `applyFavoriteProbe(_:)`: 対象が `editingFavorite` と同じ項目なら `availability` だけ更新し、`reloadItem` せずに `needsReloadAfterEdit = true` にする（編集を続けられる。EC-43）
  - フォーカスの扱い（R51「フォーカス」）: 下の `applyRoots`・`menuNeedsUpdate` では、確定の直前にツリーにフォーカスがあったか
    （編集中のフィールドにフィールドエディタがまだ付いているか。`field.currentEditor() != nil`）を見て、その値を `restoresFocus` に渡す。
    付いていれば `restoresFocus: true` でツリーに戻す（`window.endEditing(for:)` だけで終えるとウインドウが first responder になり、
    クリックし直すまで Return・⌘⌫・矢印キーが効かなくなるため）。付いていなければ `restoresFocus: false` でほかのフォーカスを奪わない。
    判定は小さなヘルパー（例: `private var editingFieldHasFocus: Bool`）にまとめる
  - `applyRoots(_:)`: `reloadData()` の前に、編集中なら `finishEditingFavorite(commit: true, restoresFocus: editingFieldHasFocus)` で確定する（入力した名前を失わない。quickstart 24）
  - `menuNeedsUpdate(_:)`: 項目を作る前に、編集中なら `finishEditingFavorite(commit: true, restoresFocus: editingFieldHasFocus)` で確定する（契約 keyboard-and-menus.md の 3。quickstart 23）
  - `outlineViewItemWillCollapse(_:)` を足す: 編集中で、折りたたむ項目（`notification.userInfo?["NSObject"]`）が「お気に入り」の見出しのとき、
    `finishEditingFavorite(commit: true, restoresFocus: true)` で確定する（開閉ボタンのクリックでは first responder が変わらないことがあり、
    行が消えると編集中のフィールドが切り離されたまま残るため。クリック先はツリーなのでフォーカスはツリーに戻す。R51）。
    既存の `outlineViewItemDidCollapse(_:)` は変えない
  - `applyListing` の `reloadItem(node, reloadChildren:)` は編集を止めないため変えない。`reloadFavorites()` は編集中はメニューの検証で起こらない（T015）
- [ ] T017 [P] [US1] `README.md` のお気に入りの説明（15行目付近）とショートカットの表（153〜156行目付近）に、お気に入りの項目の名前を Return・右クリックの「名前を変更」・
  「編集 > 名前を変更」で変えられること（行の中で編集、Return で確定・Esc で取り消し、空にすると元のフォルダ名に戻る、実際のフォルダの名前は変わらない、
  確認モーダルなし）と、お気に入りの削除の確認に表示名と絶対パスが出ることを追記する

### Verification for User Story 1

- [ ] T018 [US1] 「Phase の検証ゲート」の 1〜4 を行う（T002〜T017 に依存）:
  - `swift build`、`swift test`、`scripts/check-no-network.sh` を通す。新しいテストが data-model.md の「テスト」の表の項目を含むことを確かめる
  - quickstart.md「2. 準備」のコマンドは `.app` のドメイン（`local.my-img-viewer.MediaViewer`）にあるユーザーの実際のお気に入りを上書きする。
    **実行する前に、上書きすることと退避先（`~/MediaViewer-defaults-backup.plist`）をユーザーに伝えて了承を得る**。了承がなければ準備のコマンドを実行せず、
    ユーザーに準備を任せるか、どう進めるかを相談する
  - 了承を得たら、quickstart.md「2. 準備」のコマンド（`pgrep -fl MediaViewer`、`defaults export` による退避、テスト用フォルダとディスクイメージ（quickstart 24 用）の作成、旧形式の `favorites.paths` の書き込み、
    `favorites.displayNames` の削除）をこの順で実行し、`scripts/make-app.sh` で `.build/MediaViewer.app` を作る。`defaults export` が失敗したら、
    書き込みの前に止めて理由を確かめる（「ドメインがない」以外の失敗では先へ進まない）
  - ユーザーに `open .build/MediaViewer.app` での起動と GUI 確認を依頼する。依頼時は、起動スモーク（3ペインが表示されること）と quickstart.md「3. 手動確認」1〜24 の
    操作・期待・対応 ID を具体的に示す。任意で「4. 保存内容の確認」の `defaults read` も示す
  - 起動しない・例外が出るときは AGENTS.md の「起動しないときの初動」に従い lldb で例外を止める
  - GUI で確かめていない項目があれば、このタスクの下にその番号と理由を追記する（quickstart.md「5. 完了の条件」）
  - GUI 確認の結果を受け取ったら、アプリが終了していることを `pgrep -fl MediaViewer` で確かめ、ユーザーに確認してから quickstart.md「2. 準備」の
    「元に戻すとき」の手順で元のお気に入りに戻す。戻した後の `defaults read … favorites.paths` の結果をユーザーに示す

**Checkpoint**: お気に入りの項目の名前を3つの手段で変えられ、再起動後も残り、実際のフォルダは変わらない。名前の変更中は契約の操作が無効になり、
ファイルリストの名前の変更・お気に入りの削除・ツリーのゴミ箱は従来どおり

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: 変更範囲の確認とコミット

- [ ] T019 変更範囲を確かめる（T018 の後）:
  - `grep -rn "import AppKit" Sources/MediaViewerCore` が何も返さない
  - `git diff --stat` で、plan.md の「変更しない」ファイル（`Sources/MediaViewerApp/App/MainMenu.swift`・`FileListViewController`・`PaneCommands`・`MainToolbarController`）と
    `specs/product/` に変更がない（`specs/product/` への反映は実装と検証の後に、sdd-increment の反映の手順で別に行う）
  - 実装中に変えた仕様文書が、この tasks.md のチェックと T018 の追記だけであること（AGENTS.md）
- [ ] T020 ソースの変更・テスト・`README.md`・`specs/002-favorite-folder-rename/` を1つのコミットにする（例: `feat: rename favorite display names (002-favorite-folder-rename)`）。
  コミット前に `swift build` と `swift test` が通っていることを確かめる

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 依存なし
- **Foundational (Phase 2)**: タスクなし
- **User Story 1 (Phase 3)**: Phase 1 の後
- **Polish (Phase 4)**: Phase 3 の T018 の後

### User Story Dependencies

- **User Story 1 (P1)**: ほかのストーリーへの依存なし（ストーリーは1つだけ）

### Within User Story 1

- テスト（T002〜T005）→ Core の実装（T006〜T009）→ App の実装（T010〜T017）→ 検証（T018）
- T006 → T007 → T009（`FavoriteFolders` が `FavoriteName` を、`SettingsStore` が `FavoriteFolders(urls:customNames:)` を使う）
- T008 は T006・T007 と独立。ただし `DirectoryTreeViewController.swift` の `makeContextMenuItem` に仮の分岐を足すため、T011 より前に終える
- T010 は T006 の後
- `DirectoryTreeViewController.swift` を触る T008 → T011 → T012 → T013 → T014 → T015 → T016 は同じファイルのため直列
  （T008 は `makeContextMenuItem` の仮の分岐だけ。T011 は `ConfirmationPresenter.swift` と呼び出し側の1行。T012 は T007・T008 の後、T013 は T010 の後）
- T017（README）はほかと独立

### Parallel Opportunities

- T002・T003・T004・T005（別々のテストファイル）
- T006 と T008（別ファイル。T008 は `DirectoryTreeViewController.swift` も触るため、T011〜T016 とは並行しない）。T007 の後に T009 と T010 も並行できる
- T017 は Phase 3 のどの時点でも並行できる
- worktree で並列化する場合も、`DirectoryTreeViewController.swift` を触る T008・T011〜T016 は1つの worktree で直列に行う（AGENTS.md「並列実装」）

---

## Parallel Example: User Story 1

```bash
# テストをまとめて書く:
Task: "FavoriteNameTests.swift を新規作成（T002）"
Task: "FavoriteFoldersTests.swift にケースを追加（T003）"
Task: "FavoriteCommandsTests.swift を変更（T004）"
Task: "SettingsStoreTests.swift にケースを追加（T005）"

# Core の独立した2ファイル:
Task: "FavoriteName.swift を新規作成（T006）"
Task: "FavoriteCommands.swift に renameFavorite と renameTarget を追加（T008）"

# T007 の後:
Task: "SettingsStore.swift に favorites.displayNames の読み書きを追加（T009）"
Task: "FavoriteNameFormatter.swift を新規作成（T010）"
Task: "README.md に名前の変更を追記（T017）"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: 変更前の build / test を確かめる
2. Phase 3 の Core（T002〜T009）: `swift test --filter MediaViewerCoreTests` で表示名の規則と保存を確かめる
3. Phase 3 の App（T010〜T017）: 行内編集と3つの開始手段、名前の変更中の無効化
4. **STOP and VALIDATE**: T018 で検証ゲートと quickstart.md の手動確認 1〜24
5. Phase 4: 変更範囲を確かめてコミット

### Incremental Delivery

1. Core（T002〜T009）だけで一度 `swift test` を通す。App は表示名を使っていないため挙動は変わらない（保存形式の互換も保たれる）。
   ただし T008 の仮の分岐により、お気に入りの項目の右クリックメニューに淡色の「名前を変更」が出る（T012 で有効になる）
2. T011〜T012 で表示名の表示と削除の確認モーダルのパスを入れる
3. T013〜T016 で行内編集を入れ、T018 で GUI を確認する

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- テストの失敗を3回直しても解決しない場合は、作業を止めて状況を報告する（AGENTS.md）
- GUI の起動はユーザーに依頼する。UI の起動スモークは同時に複数 worktree で行わない
- `specs/product/` への反映（spec.md の「反映先」の表）は、このタスク一覧の範囲外。実装と検証が終わってから sdd-increment の反映の手順で行う
