# Tasks: Folzio について（About）ダイアログ

**Input**: `specs/TAK-45-about-dialog/` の spec.md、plan.md、research.md、data-model.md、contracts/about-dialog.md、quickstart.md。

**Prerequisites**: 設計レビューの承認前には実装しない（`docs_private/cloud-agent-workflow.md`）。

**Tests**: spec.md の検証方針に従い、Core のバージョン整形・固定 URL、両言語の文言の揃い、ウィンドウの体裁とリンク動作の自動テストを追加する。GUI は quickstart.md で保守者が確認する。

**Organization**: US1=US44、US2=US45、US3=US46。Cloud は Issue 単位のため全タスクを順次実行し、[P] は使用しない。Cloud では `swift` を実行できないため、ビルドとテストは macOS CI で確認する。

## Phase 1: Setup

- [ ] T001 `specs/TAK-45-about-dialog/plan.md` の設計レビューの承認を保守者から受け、実装開始の根拠を `specs/TAK-45-about-dialog/quickstart.md` の第 5 章に記録する。
- [ ] T002 使う AppKit の API を公式ヘッダー・文書で利用前に確認し、結果を `specs/TAK-45-about-dialog/research.md` の末尾に追記する。対象: `NSWindow.titleVisibility`、`standardWindowButton(_:)` の `isHidden`、`NSApp.applicationIconImage`、`NSButton` の `canBecomeKeyView`、`setAccessibilityRole(.link)`、`NSWorkspace.shared.open(_:)` の戻り値。

## Phase 2: Foundational

- [ ] T003 `Sources/FolzioCore/About/AboutInfo.swift` を追加する。AppKit を import せず、`public static let repositoryURL = URL(string: "https://github.com/yoshidax/folzio")!` と `public static func displayVersion(from value: Any?) -> String?` を持つ。`displayVersion` は「`String` で、前後の空白と改行を除いて空でなければその値、それ以外（nil・文字列以外・空）は nil」とする（data-model.md、FR-236・EC-166）。
- [ ] T004 `Tests/FolzioCoreTests/AboutInfoTests.swift` で `displayVersion` を検証する。`"0.1.0"`、前後に空白のある値、`""`、空白だけ、`nil`、`Int`、`NSNull`。`repositoryURL.absoluteString == "https://github.com/yoshidax/folzio"` も確認する。期待値はテスト内に書き、実装の値を流用しない（SC-117）。
- [ ] T005 `Sources/FolzioLocalization/TextKey.swift` と `Sources/FolzioLocalization/Resources/{en,ja}.lproj/Localizable.strings` に `menu.app.about`、`about.window`、`about.version`（引数 1 つ、`%@`）、`about.icon`、`about.link` を追加する。値は data-model.md の表に従い、各キーの用途を英語コメントで説明する。アプリ名「Folzio」と URL は文言にしない。`about.version` の引数の数と種類を `TextKey.arguments` に登録する（FR-239、FR-147）。
- [ ] T006 `Tests/FolzioCoreTests/Localization/` の既存の整合性検査（`CatalogConsistencyTests.swift` など）が新しい 5 キーを両言語で網羅し、引数の数が一致することを確認する。足りなければ検査を拡張し、`about.version` の英語・日本語の出力（`Version 0.1.0`、`バージョン 0.1.0`）を検証するテストを追加する。

## Phase 3: US1 アプリの版を確認する (P1 / MVP)

**Goal**: アプリメニューの「Folzio について」から、アイコン・アプリ名・バージョンを表示するダイアログを開ける。

**Independent Test**: quickstart シナリオ 1〜3・13。

- [ ] T007 [US1] `Sources/FolzioApp/About/AboutWindowController.swift` を追加する。`init(version: String?, openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) })`。`NSWindow(styleMask: [.titled, .closable])`、`isReleasedWhenClosed = false`、`titleVisibility = .hidden`、最小化・ズームのボタンを `isHidden = true`、リサイズ不可、`tabbingMode = .disallowed`、`window.title = l10n.text(.aboutWindow)`、初期位置は画面中央（FR-234）。内容は中央揃えの縦 `NSStackView`（制約は `addSubview` 後に有効化）で、`NSApp.applicationIconImage` のアイコン（アクセシビリティ説明 `about.icon`）、「Folzio」（太字）、バージョン行（`version` が nil なら行を作らず、余白も空けない）の順に並べる（FR-235・236）。
- [ ] T008 [US1] `Sources/FolzioApp/App/AppDelegate.swift` に `aboutWindowController` を保持する `showAbout(_:)` を追加する。`Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")` を `AboutInfo.displayVersion(from:)` に渡して初期化し、`showWindow`・`makeKeyAndOrderFront`・`NSApp.activate` で前面へ出す。有効条件は設けない（FR-233、US46-AS5）。
- [ ] T009 [US1] `Sources/FolzioApp/App/MainMenu.swift` の `install` で、アプリメニューの先頭に「Folzio について」（`action: #selector(AppDelegate.showAbout(_:))`、`keyEquivalent: ""`、`target = nil`）と区切り線を追加し、「設定…」の前に並べる。`bindings` に `(aboutItem, .menuAppAbout)` を加える（FR-233、US44-AS3）。

**Checkpoint**: US44-AS1〜AS4 が実演可能。

## Phase 4: US2 公開リポジトリを開く (P2)

**Goal**: URL リンクから既定のブラウザで公開リポジトリを開ける。操作要素はリンクだけ。

**Independent Test**: quickstart シナリオ 4〜6・12。

- [ ] T010 [US2] `Sources/FolzioApp/About/AboutWindowController.swift` に、`AboutInfo.repositoryURL.absoluteString` を `.linkColor`・下線の属性文字列で表示する枠なしの `NSButton` を追加する。ポインターのカーソル（`resetCursorRects`）、`canBecomeKeyView = true`、`setAccessibilityRole(.link)`、アクセシビリティ help `about.link`。アクションは `openURL(AboutInfo.repositoryURL)` を呼び、戻り値は無視する（失敗してもエラーを出さず閉じない）。ダイアログに置く操作要素はこのボタンだけにする（FR-237・240、EC-164）。
- [ ] T011 [US2] `Tests/FolzioAppTests/AboutWindowTests.swift` を追加する（`@MainActor`、`.serialized`）。リンクのボタンを実行すると注入した `openURL` が `https://github.com/yoshidax/folzio` で 1 回呼ばれること、`openURL` が false を返してもウィンドウが開いたままで例外が起きないこと、ウィンドウ内の `NSControl` が（リンクのボタンだけで）他に存在しないこと、リンクが `canBecomeKeyView` であること（US45-AS2〜AS4）。

**Checkpoint**: US45-AS1〜AS4 が実演可能。

## Phase 5: US3 独立したウィンドウとして扱い、言語に追随する (P2)

**Goal**: 1 枚だけ・⌘W で閉じる・メインを閉じると閉じる・言語に追随する。

**Independent Test**: quickstart シナリオ 7〜11・14。

- [ ] T012 [US3] `Sources/FolzioApp/App/AppDelegate.swift` の `mainWindowWillClose` で、設定ウインドウと同じく `aboutWindowController?.close()` を呼ぶ。`showAbout` は既存の controller を再利用し、再選択でウィンドウを作り直さず位置も変えない。閉じた後の再表示も同じ controller で行う（FR-238、US46-AS1〜AS3）。
- [ ] T013 [US3] `Sources/FolzioApp/About/AboutWindowController.swift` に `LanguageChangeObserver` を追加し、表示言語の変更時に `window.title`、バージョン行の文言、アイコンとリンクのアクセシビリティ文言を更新して、内容サイズを再計算する（位置は保つ）。アプリ名・URL・バージョンの数値は変えない（FR-239、US46-AS4）。
- [ ] T014 [US3] `Tests/FolzioAppTests/AboutWindowTests.swift` に、スタイル（`.closable` を含み `.miniaturizable`・`.resizable` を含まない）、最小化・ズームのボタンが非表示であること、`titleVisibility == .hidden` かつ `title` が空でないこと、バージョンが nil のときバージョン行がなく、非 nil のとき行があること（EC-166、US44-AS4）を検証するテストを追加する。両言語の切り替え後に行の文字列とウィンドウ名が更新されること（LocalizationState を使う既存のテスト支援を用いる）も検証する。

**Checkpoint**: US46-AS1〜AS5 が実演可能。

## Phase 6: Polish & Cross-Cutting

- [ ] T015 `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`、`python3 -I -m unittest discover -s scripts/dev/tests -p 'test_check_git_push.py'`、`git diff --check` を実行し、結果を `specs/TAK-45-about-dialog/quickstart.md` の第 5 章に記録する。新しいソースコードのコメントはすべて英語で書く。
- [ ] T016 作業ブランチを push し、保守者へ PR を作成できる状態であることと、確認していないこと（`swift build`・`swift test`・GUI）を報告する。PR は依頼されたときだけ作る。PR の作成後に Linear の TAK-45 へ PR のリンクを追加して `In Review` に更新し、macOS CI の結果を読む（失敗は原因をまとめてから直す）。
- [ ] T017 保守者のローカルでの起動スモークと quickstart の GUI シナリオ（1〜14）の確認を依頼し、結果を `specs/TAK-45-about-dialog/quickstart.md` の第 5 章に記録する。省略して「CI が通ったから完了」にしない。
- [ ] T018 実装と検証の完了後、最新の `master` を取り込み（`git merge origin/master`）、ID（FR-233〜240、SC-117〜119、EC-164〜167、A-144〜146、US44〜46）が他の feature と衝突していないことを確認してから、`specs/TAK-45-about-dialog/spec.md` の「反映先」の表に従って `specs/product/overview.md`・`window-layout.md`・`contracts/keyboard-and-menus.md`・`contracts/app-bundle.md`・`contracts/localization.md` へ反映する。重複 ID の検査（`docs_private/cloud-agent-workflow.md` 7 章）を実行し、反映した項目と差分を保守者へ示して承認を得てからコミットする。spec.md の冒頭に移行済み・凍結の注記を入れる。

## Dependencies

- T001 → T002 → すべての実装タスク。
- T003・T005 は T007 以降の前提（T004・T006 はそれぞれの検証）。
- US1（T007〜T009）→ US2（T010〜T011、T007 のウィンドウに追加）→ US3（T012〜T014）。
- T015 は実装の完了後、T016 は T015 の後、T017 は CI 成功後、T018 は T017 の確認後。

## Implementation Strategy

MVP は US1（版の確認）。設計承認後に Phase 2 → 3 の順で進め、各 Phase の終わりにコミットする。Cloud では Swift を実行できないため、記述した API は T002 で存在を確認し、ビルドとテストは CI に委ねる。
