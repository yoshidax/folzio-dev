# Tasks: リスト形式の名前順でフォルダを常に先頭にまとめる

**Input**: `specs/TAK-54-folders-first-name-sort/` の spec.md、plan.md、quickstart.md。

**Prerequisites**: 設計レビューの承認前には実装しない（`docs_private/cloud-agent-workflow.md`）。

**Tests**: Core のロジックにテストを付ける（`Tests/FolzioCoreTests`）。GUI は quickstart.md で保守者が確認する。

**Organization**: 単一のユーザーストーリー（US60）。Cloud は Issue 単位のため全タスクを順次実行する。Cloud では `swift` を実行できないため、ビルドとテストは macOS CI で確認する。

## Phase 1: Setup

- [x] T001 plan.md の設計レビューの承認を保守者から受け、承認を quickstart.md の「記録」に残す。

## Phase 2: US60 名前順でフォルダを先頭にまとめる

**Goal**: 「ファイル名」の並べ替えで、フォルダの行が昇順・降順のどちらでも先頭にまとまる。他の列は変わらない。

**Independent Test**: quickstart シナリオ 1〜4。

- [x] T002 `Sources/FolzioCore/Model/MediaKind.swift` の `ListItemKind` に、`.folder` と `.directory` で true になる計算プロパティ（例: `isFolderRow`）を追加し、`MediaFile` から使えるようにする。doc comment は英語で書く（FR-288）。
- [x] T003 `Sources/FolzioCore/Model/Sorting.swift` の `precedes` で、`order.column == .name` のとき、フォルダの行を方向に関係なく前にする比較を、列の値の比較の前に加える。他の列と `sorted`・`sortedMerge` の本体は変えない。doc comment を英語で更新する（FR-288）。
- [x] T004 `Tests/FolzioCoreTests/SortingTests.swift` に追加する。（1）名前の昇順でフォルダが先頭（2）降順でもフォルダが先頭でグループ内が逆順（3）folder・directory はフォルダ扱い、archive・media はファイル扱い、`..` は常に先頭（4）他の列（作成日・種類・サイズ・変更日・場所）の並びが変わらない（5）`sortedMerge` が、フォルダを混ぜたランダム入力で `sorted(a + b)` と一致する（US60-AS1〜AS5・SC-149・SC-151）。
- [x] T005 `Tests/FolzioCoreTests/SortingTests.swift` の既存テスト `mixesDirectoriesAndMediaByName`・`mixesFoldersWithFiles` の期待値を、新しい順序（フォルダ先頭）に直し、テスト名とコメントを実態に合わせる。
- [x] T006 `Tests/` 全体を `grep` し（`.folder`・`.directory`・`folder(`・`createDirectory` を使うテスト）、名前順でフォルダとファイルが混ざる期待値のあるテスト（`BrowserModel*Tests`・`FileNameSearcherTests`・`FolderSearchFixtureTests` など）を洗い出して、期待値を更新する。更新した箇所を quickstart.md の「記録」に残す。
- [x] T007 `Tests/FolzioPerformanceTests/PerformanceBaselineTests.swift` の並べ替え・`sortedMerge` の測定が、フォルダ先頭の比較でも前提（フォルダを含む入力）を保つことを確認する。基準値は変えない。

**Checkpoint**: 自動テストで US60-AS1〜AS5 を確認できる（CI で実行）。

## Phase 3: 仕様・文書の反映（PR の最後の作業）

- [x] T008 `git merge origin/master` で最新の master を取り込み、競合があれば解消する。
- [x] T009 `specs/product/file-list.md` に FR-288・A-25（変更）・US60-AS1〜AS5・SC-149〜SC-152 を、`specs/product/search.md` に FR-084（変更）を反映する。ID の重複がないことを `docs_private/cloud-agent-workflow.md` 7 章のコマンドで確かめる。
- [x] T010 `specs/product/contracts/keyboard-and-menus.md` の検索結果の並び、`docs/usage.ja.md` と `docs/usage.md` の検索結果の説明（「混ぜて」の記述）を、フォルダ先頭の規則に合わせて直す。`README.md`・`README.ja.md` に並べ替えの記述があれば、同じコミットで両方を直す。
- [ ] T011 反映した項目と差分を保守者へ示し、承認を得てから spec.md の冒頭に移行済み・凍結の注記を入れる。

## Phase 4: 検証

- [x] T012 `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh` を実行する。
- [ ] T013 作業ブランチを push し、保守者の依頼を受けて PR を作り、CI（`swift build`・`swift test`・性能テスト）の結果を確認する。
- [ ] T014 保守者が quickstart.md の手順でローカルの起動スモークを行う（GUI は保守者に依頼する）。結果を quickstart.md の「記録」に残す。
