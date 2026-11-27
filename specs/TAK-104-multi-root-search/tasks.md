# Tasks: 複数の検索起点

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[research.md](research.md)、[data-model.md](data-model.md)、
[search-sheet.md](contracts/search-sheet.md)、[quickstart.md](quickstart.md)

**Tests**: 憲章 IV に従い、次を自動テストで確かめる。Swift のビルドとテストは CI で、GUI は保守者が確認する。
- Core: 行の検証と起点の整理（異常系を含む）、シートの入力の状態、場所と検索バーの材料、順の列挙、起点ごとの名前の変更・削除
- App: 起点の行の追加・削除・フォーカス・Tab の順・アクセシビリティのラベル
- 性能: 3つの起点に分けた 10,000 ファイルの検索（SC-249）

## Phase 0: 設計レビュー

- [X] T000 [MANUAL] 保守者が `specs/TAK-104-multi-root-search/` の spec・plan・tasks と analyze の結果を確認し、実装の開始を承認する（2026-11-27、このチャット。2回目のレビューで FR-394 の英語の変更を加えた設計を承認）

## Phase 1: Foundational（Core の判断）

- [X] T001 [P] `Tests/FolzioCoreTests/SearchRootListTests.swift` に `SearchRootList.validate` のテストを足す（FR-436・EC-303・EC-304）
  - すべて有効、2行目が無効（各 `SearchRootError`）、上の無効な行を優先、空白だけの行を無視、すべて空で `.empty`
  - `Failure.row` が元の行の添字で、`rowCount` が行の数。`.picked` は空白を除かない
- [X] T002 `Tests/FolzioCoreTests/SearchRootListTests.swift` に `SearchRootList.organize` のテストを足す（FR-437・EC-300〜EC-302・EC-307）
  - 同じパス・末尾の `/`・`.` を含む表記で1つにまとめ、最初の位置を保つ
  - 配下の起点を除く。間に隠しフォルダ（名前が `.` で始まる・隠し属性）またはパッケージがあれば残す。起点自身が隠しフォルダなら残す
  - `/` と他の起点。入力の順を保つ
- [X] T003 `Sources/FolzioCore/Search/SearchRootList.swift` に `SearchRootList`（data-model.md 3）を実装し、T001・T002 を通す
- [X] T004 [P] `Tests/FolzioCoreTests/SearchRootInputTests.swift`（既存の `SearchPanelInputState` のテストのファイル）に行の操作のテストを足す（FR-435）
  - 追加: 末尾に空の `.typed`、10 行で `nil`、パネル表示中・保留中の操作があるとき `nil`
  - 削除: 1 行で `nil`、フォーカスの添字（中ほど・末尾）、ほかの行の由来（`.picked`）を保つ
  - 行ごとの編集・GUI 選択の反映がその行だけを変える。追加・削除で古い検証の完了を捨てる
- [X] T005 `Sources/FolzioCore/Search/SearchRootInput.swift` の `SearchPanelInputState` と `SearchPanelOperationTicket` を行の並びに広げる
  （data-model.md 2）。既存のテストを新しい API に合わせ、T004 を通す
- [X] T006 [P] `Tests/FolzioCoreTests/SearchListingTests.swift` に、含む起点・場所・検索バーの材料のテストを足す（FR-084（変更）・FR-439・EC-305）
  - 起点1つ（従来と同じ文字列。ルート `/`）、2つの起点の場所、入れ子（EC-302）で内側の起点、同じフォルダ名の起点で絶対パス
  - `rootSummary` の `.single`・`.multiple`、`rootPaths` の順
- [X] T007 `Sources/FolzioCore/Search/SearchListing.swift` の `root` を `roots` に替え、`root(containing:)`・`location(of:)`・`rootSummary`・
  `rootPaths` を実装する。コンパイルの通る範囲で `BrowserModel` の参照を `roots` に合わせ、T006 を通す
- [X] T008 [P] `Tests/FolzioCoreTests/SearchRemovalScopeTests.swift` に、起点が複数のとき項目を含む起点で止まるテストを足す（FR-440・EC-306）
- [X] T009 `Sources/FolzioCore/Search/SearchRemovalScope.swift` と `BrowserModel.pruneMissingResults` で、結果を含む起点を渡す。T008 を通す

**Checkpoint**: Core の判断が揃い、既存のテストが通る（CI）

## Phase 2: User Story 99 - 複数の場所をまとめて検索する（P1）

**Goal**: 起点の行を追加・削除して複数の起点で検索でき、結果が1つの一覧になる

**Independent Test**: quickstart.md の 2〜6・10

- [X] T010 [P] [US99] `Tests/FolzioCoreTests/SearchRootPlanTests.swift` に `SearchRootPlan`（data-model.md 5）のテストを足す（FR-438・FR-440）
  - `next` の順、`rebase`（起点そのもの・祖先・無関係）、`contains`、`removeAll`
- [X] T011 [US99] `Sources/FolzioCore/Search/SearchRootPlan.swift` を実装し、T010 を通す
- [X] T012 [US99] `Tests/FolzioCoreTests/BrowserModelSearchTests.swift` に、複数の起点の検索のテストを足す（FR-438・FR-440・US99-AS3・AS10・AS11）
  - 2つの起点の結果が1つの一覧になり、件数が合計、すべての起点を辿り終えて `.finished`
  - 2つ目の起点は1つ目を辿り終えてから始まる（仮の searcher で開始の順を記録）
  - 検索の解除・新しい検索で、待ち行列の起点も始まらない
  - 1つ目の検索中に、待ち行列の起点の名前を変えたとき、追加の列挙をせず、新しい名前で辿り、結果が重複しない
  - 起点の1つの名前の変更で、その起点の `roots` と配下の結果の URL が変わる。起点の1つが消えたとき、その起点の結果だけが外れる
  - すべての起点が消えたとき、結果が0件になり、検索を終えていれば該当する項目がない旨の状態になる（EC-306）
- [X] T013 [US99] `Sources/FolzioCore/Browser/BrowserModel.swift` に `startSearch(_:roots:)` と順の列挙を実装し、`didRenameFolder` を
  起点ごとの判定と待ち行列の追随に改める（research.md R3・R4）。T012 と既存の検索のテストを通す
- [X] T014 [P] [US99] `Sources/FolzioLocalization/TextKey.swift` と日英の文言に、contracts/search-sheet.md の文言を追加する
  - 既存の文言の表（contracts/localization.md の検索）と同じ書き方。日英の両方を同じコミットで足す
  - 補足説明（`searchDescription`）の英語を複数形の文に改める（FR-394（変更）・contracts/search-sheet.md の「文言の変更」）
    - 今の英文を確かめている `Tests/FolzioCoreTests/Localization/SearchSheetTextTests.swift` の期待値も新しい文に改める
- [X] T015 [US99] `Sources/FolzioApp/Search/SearchRootRowView.swift` を新規に作り、`Sources/FolzioApp/Search/SearchPanelController.swift`
  を起点の行の一覧・「起点を追加」・行ごとの「削除」と「選択…」・行の番号付きの理由・フォーカスの移動・Tab の順に改める
  （FR-081（変更）・FR-435・FR-436・contracts/search-sheet.md）
  - 検証は `SearchRootList.validate` と `organize` を `Task.detached` の中で呼ぶ。完了は `SearchPanelInputState.complete` で判定する
  - 制約は行のビューを `addArrangedSubview` した後に有効化する（AGENTS.md の AppKit UI の不変条件）
  - 表示言語の切り替えで、行の番号付きのラベルも更新する
- [X] T016 [US99] `Sources/FolzioApp/App/MainSplitViewController.swift` の `onSearch` を `[URL]` にし、`model.startSearch(_:roots:)` を呼ぶ
- [X] T017 [P] [US99] `Sources/FolzioApp/FileList/FileListViewController.swift` の検索バーを `rootSummary` と `rootPaths` で表示する（FR-439）
- [X] T018 [P] [US99] `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` の監視と観察を、すべての起点に改める（FR-440）
- [X] T019 [US99] `Tests/FolzioAppTests/SearchPanelRowsTests.swift` に、シートの行のテストを足す（FR-081（変更）・FR-435）
  - 開いたときに1行で「削除」が無効。追加で末尾に空の行とフォーカス、10 行で「起点を追加」が無効
  - 削除でほかの行の値を保ち、フォーカスが繰り上がった行へ移る
  - Tab の順（`nextKeyView` の連鎖）が contracts/search-sheet.md のとおりで、無効なボタンを飛ばす
  - 行が2つ以上のときのアクセシビリティのラベルに行の番号が入る

**Checkpoint**: US99 が単独で動く（CI のテスト）

## Phase 3: User Story 100 - 重なった起点を指定しても同じ項目が重複しない（P1）

**Goal**: 起点の整理がシートの検索で使われ、重複が出ない

**Independent Test**: quickstart.md の 7

- [X] T020 [US100] `Tests/FolzioCoreTests/FolderSearchFixtureTests.swift` に、実際のフォルダで重なった起点を整理して検索するテストを足す（SC-250・US100-AS1〜AS4）
  - 同じフォルダの2回、表記の違い、シンボリックリンク、親と配下、親と隠しフォルダの中の配下
  - 整理した起点で `BrowserModel` の検索をし、行の URL に重複がなく、前の4通りが外側の起点1つの結果と一致する
  - `SearchRootList.isSkippedByEnumeration` を実際のファイルシステムで使う
- [X] T021 [US100] T020 で見つかった不足を `SearchRootList`・`SearchPanelController` で直す（不足がなければ確認の結果を記録して閉じる）
  - 2026-11-27: T020 のテストは CI（`b9751e9`）で通り、不足は見つからなかった

## Phase 4: User Story 101 - ワイルドカードを使えることを知る（P2）

**Goal**: キーワード欄の直下にワイルドカードの説明が出て、読み上げられる

**Independent Test**: quickstart.md の 2・8

- [X] T022 [US101] `Sources/FolzioApp/Search/SearchPanelController.swift` に、キーワード欄の直下のワイルドカードの説明のラベルを足し、キーワード欄の
  アクセシビリティの説明を「補足説明 + 空白 + ワイルドカードの説明」にする（FR-441・research.md R6）。表示言語の切り替えに追従する
- [X] T023 [US101] `Tests/FolzioAppTests/SearchPanelRowsTests.swift` に、説明のラベルの文言・英語の補足説明が複数形の文であること・選択できないこと・Tab の移動先でないこと・
  キーワード欄のヘルプの文を確かめるテストを足す（FR-441）

## Phase 5: Polish & 横断

- [X] T024 [P] `Tests/FolzioPerformanceTests/PerformanceBaselineTests.swift` に、3つの起点に分けた 10,000 ファイルの検索が 3 秒以内に終わるテストを足す（SC-249）
- [X] T025 [P] 公開文書の確認: `docs/usage.md`・`docs/usage.ja.md` の検索の説明を、複数の起点とワイルドカードの説明に合わせて日英同じ内容で更新する
  （該当の記述がなければ、PR の「公開文書への影響」に理由を書く）
- [X] T026 `scripts/dev/check-all.sh` を実行して通す（Cloud の検証ゲート）。コメントは英語（`docs_private/comment-translation-glossary.md`）
- [X] T027 PR の CI（`swift build`・`swift test`・性能テスト）の成功を確かめる。性能テストはログの末尾の件数で確かめ、計測結果を PR に記載する
  - 2026-11-27: `b9751e9` で build・通常のテスト（1441 件）・性能テスト（29 件）が成功。SC-249 は 0.595 秒
- [ ] T028 [MANUAL] 保守者が quickstart.md の「保守者のローカルでの確認」1〜10 を行い、結果を報告する（起動スモーク、SC-251・SC-252 を含む）
- [ ] T029 保守者の報告を `checklists/validation.md` に記録する（実行日・OS・確認項目・合否）
- [ ] T030 `speckit-converge` を実行し、追記されたタスクがあれば実装と検証を繰り返す
- [ ] T031 `git merge origin/master` の後、`scripts/dev/check-spec-ids.sh` を実行し、spec.md の「反映先」の項目を `specs/product/search.md`・
  `contracts/localization.md`・`contracts/keyboard-and-menus.md` へ反映する。`python3 scripts/dev/check-spec-format.py` と
  `scripts/dev/check-spec-ids.sh` を通し、spec.md の冒頭に移行済み・凍結の注記を入れる
- [ ] T032 [MANUAL] 保守者が `specs/product/` への反映の差分を承認する

## Dependencies & Execution Order

- Phase 0（T000）の承認の前に実装しない
- Phase 1（T001〜T009）が Phase 2 以降をブロックする。T001・T002 → T003、T004 → T005、T006 → T007、T008 → T009
- Phase 2 の中: T010 → T011 → T012 → T013。T014 → T015 → T016・T019。T017・T018 は T007 の後
- Phase 3（T020・T021）は T013・T015 の後。Phase 4（T022・T023）は T015 の後
- Phase 5: T024・T025 は Phase 2 の後。T026 → T027 → T028 → T029 → T030 → T031 → T032

## Parallel Example

```text
Phase 1: T001（T002 は同じファイルなので続けて書く）、T004、T006、T008 は互いに独立
Phase 2: T014・T017・T018 は T013 と独立に進められる
```

（Cloud ではサブエージェントで並列に実装しない。`[P]` は依存がないことの印として使う）

## Implementation Strategy

1. Phase 1 で Core の判断を揃え、既存の検索（1つの起点）のテストが通ることを CI で確かめる
2. Phase 2 で US99 を完成させる（MVP。起点が1つの操作は従来と同じに動く）
3. Phase 3・4 を足す
4. Phase 5 で性能・公開文書・保守者の確認・product への反映を行う
