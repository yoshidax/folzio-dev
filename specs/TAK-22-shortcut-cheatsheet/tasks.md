# Tasks: 目的別ショートカットチートシート

**Input**: `specs/TAK-22-shortcut-cheatsheet/` の spec.md、plan.md、research.md、data-model.md、contracts/、quickstart.md。

**Prerequisites**: 設計レビューの承認前には実装しない。設計承認済み。実装はPR #10でマージ済み。検証記録はquickstart.mdを参照。

**Tests**: spec.md の検証方針に従いカタログ・翻訳の自動テストを追加。AppKit の確認は実機で記録する。

**Organization**: US1=US32、US2=US33、US3=US34。Cloud はIssue単位のため全タスクを順次実行する。[P] は使用しない。

## Phase 1: Setup

- [x] T001 `specs/TAK-22-shortcut-cheatsheet/plan.md` の設計レビュー承認を受け、実装開始の根拠を `specs/TAK-22-shortcut-cheatsheet/quickstart.md` の結果欄へ記録する。
- [x] T002 `specs/TAK-22-shortcut-cheatsheet/contracts/shortcut-cheatsheet.md` の44項目を既存 `specs/product/contracts/keyboard-and-menus.md` と各入力ハンドラーへ照合し、既存条件を変えないことを確認する（FR-203）。実装に必要な新規AppKit APIは公式ヘッダー・文書で利用前に確認する。

## Phase 2: Foundational

- [x] T003 `Sources/FolzioCore/Shortcuts/ShortcutCatalog.swift` に固定カタログを追加する。「7区分」「空区分は禁止」「IDは空でなく全体で一意」「keysは空でなく言語で変形しない」「各entryは1区分だけ」を満たし、契約の44項目を固定順で持たせる（FR-202〜203）。
- [x] T004 `Tests/FolzioCoreTests/ShortcutCatalogTests.swift` で区分の順序・空でないこと、44項目のIDとキーと所属、ID一意性を検証する。期待一覧は契約から照合し、実装の値をそのまま期待値にしない（FR-202〜203、SC-096）。

## Phase 3: US1 一覧を開いて目的から探す (P1 / MVP)

**Goal**: メニュー・⌘/から読める一覧を開き、親を操作できる。

**Independent Test**: quickstart Q1〜2。既存の入力条件はQ7〜8で確認する。

- [x] T005 [US1] `Sources/FolzioLocalization/ShortcutText.swift` と `Sources/FolzioLocalization/TextKey.swift`、`Sources/FolzioLocalization/Resources/{en,ja}.lproj/Localizable.strings` にタイトル、7見出し、44操作の説明と条件、起動・閉じるラベルを追加する。全IDを網羅して英語と日本語の完全な文を提供し、各翻訳キーの用途を英語コメントで説明する（FR-202・206）。
- [x] T006 [US1] `Sources/FolzioApp/Shortcuts/ShortcutCheatSheetWindowController.swift` に通常レベルの独立NSWindowと一覧を実装する。初期内容640×680pt、最小480×360pt、画面が小さい場合はvisibleFrame優先。キー列を区別し説明を折り返し、横スクロールなしの縦一覧とする。sheet/modal/child windowは使わず、既定言語でも全項目を表示する（FR-201〜202）。
- [x] T007 [US1] `Sources/FolzioApp/App/MainWindowController.swift` で一覧を遅延作成し、親の右→左→表示領域内の順で初期配置する。初回だけ配置し親のフレームは変えない（FR-201、EC-139）。
- [x] T008 [US1] `Sources/FolzioApp/App/AppDelegate.swift`、`Sources/FolzioApp/App/MainMenu.swift`、`Sources/FolzioApp/App/MainSplitViewController.swift` に起動入口と表示可否を追加する。⌘/とメニューを同じ明示targetへ送り、親終了・編集中・親sheet/app modal・全画面・slideshowを拒否する。既存の単独/を変えず、起動条件の参照を既存状態から得る（FR-200、EC-136〜138）。

**Checkpoint**: US32-AS1〜3 が実演可能。ただし終了・翻訳・全検証前は提出完了にしない。

## Phase 4: US2 対応ウィンドウだけ閉じる (P1)

**Goal**: 親あたり1枚、再利用、入力先だけ閉じる、親の終了と連動。

**Independent Test**: quickstart Q3〜6・Q14。

- [x] T009 [US2] `Sources/FolzioApp/App/MainWindowController.swift` と `Sources/FolzioApp/Shortcuts/ShortcutCheatSheetWindowController.swift` で既存controllerを再利用し、一覧を閉じても位置・サイズ・スクロールを親の生存中だけ保持する。親限定willClose通知で一覧を閉じ親終了済みにし、通知の寿命を管理する。既存window.delegateは置換しない（FR-204〜205、EC-136）。
- [x] T010 [US2] `Sources/FolzioApp/App/MainMenu.swift` に nil target の `NSWindow.performClose(_:)` と⌘Wを追加し、Closeの翻訳バインドを付ける。親を明示targetにしない。アプリ再起動への一覧復元は加えない（FR-204〜205）。
- [ ] T011 [US2] `specs/TAK-22-shortcut-cheatsheet/quickstart.md` にQ3〜6・Q14の実機結果を保守者から受けて記録する。開く10回で1枚、一枚だけ閉じる、親終了連動、閉じた親への再表示拒否を確認する。実機確認前は未チェックのままにする（SC-097・099）。

## Phase 5: US3 言語・キーボード・読み上げ (P2)

**Goal**: 両言語、参照位置維持、キーボードで全項目、読み上げ。

**Independent Test**: quickstart Q10〜12。

- [x] T012 [US3] `Sources/FolzioApp/Shortcuts/ShortcutCheatSheetWindowController.swift` にLanguageChangeObserverを追加し、タイトル・見出し・説明・条件を即時更新する。先頭可視entry IDと行内offsetをレイアウト後に復元・clampし、位置・サイズ・キー表記を保つ（FR-206）。
- [x] T013 [US3] `Sources/FolzioApp/Shortcuts/ShortcutCheatSheetWindowController.swift` でscroll viewを初期入力先にし、↑↓・Page Up/Down・Home/Endで全項目へ到達させる。不足分のみ専用ビューで処理し、Escを親へ流さない。見出しと行のキー・説明・条件に読み上げ用の意味を付け、system colorsを使う（FR-207、EC-140）。
- [x] T014 [US3] `Tests/FolzioCoreTests/Localization/ShortcutTextTests.swift` で全区分と44項目の両言語取得、空欄・欠落・内部キー表示がないこと、キー表記不変を検証する。既存の `Tests/FolzioCoreTests/Localization/CatalogConsistencyTests.swift` の整合性検査にも全TextKeyを含める（FR-206、SC-098）。
- [ ] T015 [US3] `specs/TAK-22-shortcut-cheatsheet/quickstart.md` に保守者によるQ10〜12の実機結果を記録する。両言語最小幅、参照項目維持、キーボード、VoiceOver、明暗モード、親への非伝播を確認する（SC-098〜099）。

## Phase 6: Polish & Verification

- [x] T016 `README.md` と `README.ja.md` に一覧の開き方・閉じ方・非モーダル表示を同内容で追記する（FR-200・205）。
- [x] T017 `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`python3 -I -m unittest discover -s scripts/dev/tests -p 'test_check_git_push.py'`、`git diff --check` を実行し、結果を `specs/TAK-22-shortcut-cheatsheet/quickstart.md` に追記する。
- [x] T018 許可された作業ブランチへの変更・pushが必要な場合は保守者に確認してから提出し、依頼時のみPRを作る。`.github/workflows/macos-swift-ci.yml` のbuild・全テスト・性能テスト結果を確認し、CI URLと結果を `specs/TAK-22-shortcut-cheatsheet/quickstart.md` に記録する。CIがない間は未確認とする。
- [ ] T019 保守者のローカルbuild/testと3ペイン起動スモーク、Q1〜2・Q7〜9・Q13および44項目の契約と実動作の照合を `specs/TAK-22-shortcut-cheatsheet/quickstart.md` に記録する。US/JIS配列、通常表示・zip・検索結果・全画面・slideshowの条件を確認し、未確認事項を明記する（SC-096・099）。
- [x] T020 実装と検証後に最新masterを取り込み、`specs/product/window-layout.md`、`specs/product/overview.md`、`specs/product/contracts/keyboard-and-menus.md`、`specs/product/contracts/localization.md` へspecの反映表に従って追記する。ID衝突は未マージの本feature側で振り直す。差分を示し承認後コミットし、`specs/TAK-22-shortcut-cheatsheet/spec.md` に凍結注記を付ける。

## Dependencies & Execution Order

T001の承認 → T002照合 → T003〜004基盤 → US1 T005〜008 → US2 T009〜011 → US3 T012〜015 → T016〜020。
US2とUS3はUS1の画面を前提とするが、各独立テストは他ストーリーの受け入れ結果と分けて確認できる。
保守者の確認待ち中はGUI記録タスクを未チェックにし、依存しない実装・静的検査まで進められる。T020は全検証後。

## Parallel Opportunities

Cloudでのタスク分割による並列実装は行わない。US1の翻訳と画面、US2の所有とメニュー、US3の更新と読み上げは同じファイルを変更するため直列。
研究段階のみ読み取り専用の調査担当が所有・入力監視を確認した。

## Implementation Strategy

US1を最小の実演可能範囲とし、US2の所有・終了、US3の翻訳・入力を順に追加する。各ストーリーで契約・テストを確認して小さくコミットする。
最終提出は全ストーリー・CI・保守者確認後。進捗の正本はこのtasks.mdとし、Linearに全タスクを複製しない。
