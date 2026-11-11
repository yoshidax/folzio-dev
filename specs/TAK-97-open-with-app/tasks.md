# Tasks: 関連アプリケーションで開く

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[research.md](research.md)、[menu.md](contracts/menu.md)

**Tests**: Core の対象判定と異常条件は憲章 IV に従い自動検証する。GUI は保守者が確認する。

## Phase 0: 設計レビュー

- [x] T000 [MANUAL] 保守者が `specs/TAK-97-open-with-app/spec.md`、`plan.md`、`tasks.md` の対象条件と構成を確認し、実装開始を承認する（2026-11-11、このチャット）

## Phase 1: Setup

- [x] T001 macOS SDK の `NSWorkspace.urlsForApplications(toOpen:)` と `open(_:withApplicationAt:configuration:completionHandler:)` の Swift 6 シグネチャを CI 対応版で確認し、`specs/TAK-97-open-with-app/research.md` の決定を確定する（CI 42977395629 の build 成功）

## Phase 2: Foundational

- [x] T002 `Sources/FolzioCore/Model/ListItemCommands.swift` に1件の通常ファイルだけを対象にする判定を追加する
- [x] T003 `Tests/FolzioCoreTests/ListItemCommandsTests.swift` にメディア・zip・フォルダ・`..`・zip 内・複数選択の判定テストを追加する（実行は T012）

## Phase 3: User Story 1 - 関連アプリを選んで開く (Priority: P1)

**Goal**: 1件のファイルを OS が示す関連アプリで開く。

**Independent Test**: 画像1件の右クリックから既定以外のアプリを選ぶと、そのアプリで開く。

- [x] T004 [US1] `Sources/FolzioApp/FileList/FileContextMenu.swift` に「開く」の直後のサブメニューと候補更新を実装する
- [x] T005 [US1] `Sources/FolzioApp/FileList/FileListViewController.swift` に対象 URL を固定した候補取得と指定アプリでの起動を実装する（実行確認は T012・T013）
- [x] T006 [US1] `Sources/FolzioApp/App/MainMenu.swift` にキーボードで到達できる同名サブメニューを追加する（実行確認は T012・T013）
- [x] T007 [US1] `Sources/FolzioLocalization/TextKey.swift` と `Sources/FolzioLocalization/Resources/en.lproj/Localizable.strings`、`Sources/FolzioLocalization/Resources/ja.lproj/Localizable.strings` にメニュー名を追加する

## Phase 4: User Story 2 - 無効条件と失敗を扱う (Priority: P2)

**Goal**: 対象外で起動せず、起動失敗を利用者に知らせる。

**Independent Test**: フォルダ・zip 内・複数選択で選べず、アプリ削除時には失敗を通知する。

- [x] T008 [US2] `Sources/FolzioApp/FileList/FileContextMenu.swift` と `Sources/FolzioApp/App/MainMenu.swift` で対象外・候補ゼロの淡色表示と同名アプリの識別を実装する（実行確認は T013）
- [x] T009 [US2] `Sources/FolzioApp/FileList/FileListViewController.swift` で選択変更後の誤起動を防ぎ、起動失敗を通知する（実行確認は T013）
- [x] T010 [US2] `Sources/FolzioLocalization/TextKey.swift` と `Sources/FolzioLocalization/Resources/en.lproj/Localizable.strings`、`Sources/FolzioLocalization/Resources/ja.lproj/Localizable.strings` に失敗通知の文言を追加する

## Phase 5: Verification

- [x] T011 `scripts/dev/check-all.sh` を実行し、`specs/TAK-97-open-with-app/quickstart.md` に結果を記録する
- [x] T015 [MANUAL] 保守者が Cloud 指定の `work` から `feature/tak-97-open-with-app` に変えることを承認する（2026-11-11、このチャット）
- [x] T012 作業ブランチを push して macOS CI の `swift build` と `swift test` を確認し、`specs/TAK-97-open-with-app/quickstart.md` に結果を記録する（CI 42977395629 の build と通常テスト 1172 件は成功。性能 27 件中 3 件は失敗を許容する工程で閾値超過）
- [x] T016 `docs/usage.md` と `docs/usage.ja.md` に対象条件・右クリックと「ファイル」メニューの操作・キーボード経路を同じ内容で追加する（0a8202c）
- [x] T017 ショートカット照合時の Open With 更新を一時ログで調査し、結果確認後にログを削除する（754d0f0 で調査。⌘C・⌘↓ と「ファイル」メニュー表示でログを確認）
- [x] T018 同じコードで macOS CI の性能テストを再実行し、`quickstart.md` に結果を追記する（CI 42978586843）
- [x] T019 [MANUAL] ショートカット照合時の関連アプリ問い合わせを避ける設計を保守者が承認する（2026-11-11、このチャット）
- [x] T020 既定アプリの「（デフォルト）」表示・区切り線と各アプリの 16pt アイコンを追加する（保守者が 2026-11-11 に両方追加を承認。検証は T022・T013）
- [x] T022 既定アプリ表示とアイコン追加後の macOS CI で build と通常テストを確認し、`quickstart.md` に記録する（CI 42986412381）
- [x] T021 承認された設計でショートカット照合時の関連アプリ問い合わせを避ける（d297e14 で実装、T024 で撤回）
- [x] T023 更新抑制の追加後に macOS CI の build と通常テストを確認し、`quickstart.md` に記録する（CI 43003841866）
- [x] T024 保守者の体感評価とショートカットのカスタマイズ条件を踏まえ、⌘ キーに限った更新抑制を撤回する（2026-11-11、このチャット）
- [x] T013 [MANUAL] 保守者が `scripts/make-app.sh` と `open .build/Folzio.app` で3ペインと `specs/TAK-97-open-with-app/quickstart.md` の操作を確認する（2026-11-11、このチャットで確認完了と報告）
- [x] T014 `specs/product/file-list.md` と `specs/product/contracts/keyboard-and-menus.md` に決定した要件を反映し、仕様検査を実行する（保守者が 2026-11-11 に差分を承認）

## Dependencies & Execution Order

- T000 の承認までは実装を始めない。T001 は macOS SDK で T012 の CI の一部として確かめる。T002 は T003 の前提。
- US1（T004〜T007）を完成させ、US2（T008〜T010）で例外を仕上げる。
- T011〜T012 は実装後。T013 は保守者の macOS で行い、結果が届くまで未チェックにする。
- T012 の前に T015 を終え、Cloud 指定の `work` が `docs_private/cloud-agent-workflow.md` の push 許可名に含まれない問題を解決する。
- T014 は実装と検証が済んだ後、最新の master を取り込んで行う。

## Implementation Strategy

US1 の1件オープンを最小単位として確認し、US2 の無効条件とエラーを追加する。実装を複数エージェントに分けない。
