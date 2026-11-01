# Tasks: 同一パスのファイルの内容更新をサムネイルとプレビューに反映する

**Input**: `specs/TAK-14-image-content-refresh/` の spec.md・plan.md・research.md・data-model.md・contracts/core-api.md・quickstart.md

**Status**: 2026-11-01 保守者が設計を承認し、T004〜T017 を実装した。Cloud では Swift を実行できないため、ビルドとテストは CI（T020）で確認する。

**Tests**: 憲章 IV によりコアロジックのテストは必須。Cloud では実行できないため、macOS CI で確認する。

## Phase 1: Setup

- [x] T001 origin/master（4ec25c0）が作業ブランチの祖先であることを確かめ、TAK-14 を In Progress にし、spec.md に Issue の URL と保守者の回答（Clarifications）を記録する
- [x] T002 plan.md・research.md・data-model.md・contracts/core-api.md・quickstart.md を作る
- [x] T003 設計レビューの承認を保守者から受ける。承認前にソースを実装しない

## Phase 2: Foundational（全ストーリーの前提）

- [x] T004 Sources/FolzioCore/Model/FileContentVersion.swift を作る（`init(resourceValues:)`・`init(archiveIdentity:)`）。Tests/FolzioCoreTests/FileContentVersionTests.swift で、大きさ・更新日時・識別子のどれかが違えば等しくないこと、値が得られないときの `nil` の扱いを確かめる（R1、A-141）
- [x] T005 Sources/FolzioCore/Model/MediaFile.swift に `contentVersion` を追加する（既定値 `nil`、`==`・`hash` は URL のまま）
- [x] T006 Sources/FolzioCore/FileSystem/DirectoryLister.swift の `fileKeys`・`mediaKeys` に `.contentModificationDateKey`・`.fileIdentifierKey` を加え、メディアの行に版を設定する。Tests/FolzioCoreTests/DirectoryListerTests.swift に、同じパスを寸法の違う画像で上書きすると版が変わり、別のファイルの版は変わらないテストを足す（FR-228）
- [x] T007 Sources/FolzioCore/Imaging/DecodedImageCache.swift の `get`・`put` に `version` を加え、版の違う項目を返さず捨てる。`nil` は保持しない。Tests/FolzioCoreTests/DecodedImageCacheTests.swift を更新し、版の不一致・後からの古い版の `put`（EC-161）・上限の維持を確かめる（R2、FR-230）
- [x] T008 Sources/FolzioCore/Imaging/ThumbnailProvider.swift の `ThumbnailProviding` と実装に `version` を加え、キャッシュのキーと実行中の要求の照合に使う。Tests/FolzioCoreTests/ThumbnailProviderTests.swift でキーが版で区別されることを確かめる（QuickLook に頼らない。TAK-7）（R3）

**Checkpoint**: Core がビルドでき、既存のテストが新しい API で通る（App の呼び出しは T013 で直すため、T008 と同じコミットで最小限の引数追加を行う）

## Phase 3: User Story 1（US41）- 上書きした画像をそのまま見直す (P1 / MVP)

**Goal**: FR-228〜230、EC-159〜162。**Independent Test**: quickstart.md の Q1〜Q5、Q9

- [x] T009 [US1] Sources/FolzioCore/Browser/BrowserModel.swift の `decodedImage(for:)` と先読みが、`listing.files` の行の `contentVersion` でキャッシュを引くようにする（FR-230）
- [x] T010 [US1] Sources/FolzioCore/Browser/BrowserModel.swift の `reloadCurrentFolder()` で新旧の版を突き合わせ、`changedContentURLs`・`contentChangeGeneration` を更新し、該当する先読みを取り消す（R4、FR-228、SC-116）
- [x] T011 [US1] Sources/FolzioCore/Browser/BrowserModel.swift に、フォーカス中のファイルの版が変わったときのプレビューの読み込み直しを実装する。静止画は表示を保ったまま差し替え、アニメーション画像は設定し直し、種類の変化・失敗は通常の規則に従う。動画は対象外通知のたびに版を比べるため、書き込み途中の内容は後の通知で置き換わる（R5、FR-229、EC-159、EC-160、EC-162、EC-163、A-142）
- [x] T012 [US1] Tests/FolzioCoreTests/BrowserModelContentRefreshTests.swift（新規）で、US41-AS1（上書き → `handleFileSystemEvent` → 選択を保ったままプレビューの寸法が変わる）、US41-AS3（非選択中に上書き → 選択で新しい寸法）、変わっていない行が `changedContentURLs` に入らないこと、壊れたファイルでの失敗表示（EC-159）、置き換え前に始めた読み込みが表示されないこと（EC-161）を確かめる
- [x] T013 [US1] Sources/FolzioApp/FileList/ListModeView.swift と ThumbnailModeView.swift で、縮小画像の要求と取り消しに `file.contentVersion` を渡し、`contentChangeGeneration` を観察して、URL の並びが同じなら変わった行だけを読み込み直し、縮小画像を要求し直す。`ThumbnailCell.configure` は版が変わったときも代替アイコンに戻す（R8、FR-228）

## Phase 4: User Story 2（US42）- zip を置き換えた後に開き直す (P2)

**Goal**: FR-231。**Independent Test**: quickstart.md の Q6・Q7

- [x] T014 [US2] Sources/FolzioCore/Archive/ArchiveIndex.swift が作るメディアの行に `identity` から作った版を設定し、Sources/FolzioCore/Browser/BrowserModel.swift の `archiveImage(for:maxPixelSize:)` がその版でキャッシュを引く（R7）
- [x] T015 [US2] Tests/FolzioCoreTests/BrowserModelContentRefreshTests.swift に、zip の中の画像を表示 → 一覧に戻る → 同じ名前で中の画像の寸法が違う zip に置き換え → 開き直して選択すると新しい寸法になるテストを足す。表示中の zip の置き換えで一覧に戻る既存の挙動（EC-26）は既存の BrowserModelArchiveTests が確かめる（US42-AS1・AS2）

## Phase 5: User Story 3（US43）- 検索結果でも置き換え後の内容を見る (P3)

**Goal**: FR-232。**Independent Test**: quickstart.md の Q8

- [x] T016 [US3] Sources/FolzioCore/Browser/BrowserModel.swift の `pruneMissingResults(under:)` で、通知のあったフォルダの下の結果の版をバックグラウンドで取り直し、変わった結果を `allFiles` で差し替え、T010・T011 と同じ通知と読み込み直しを行う。検索結果の表示中の `reloadCurrentFolder()`（アプリのファイル操作の後に呼ばれ、`pruneMissingResults(under: nil)` になる）も同じ経路で対応する（R6）
- [x] T017 [US3] Tests/FolzioCoreTests/BrowserModelContentRefreshTests.swift に、検索結果の画像を上書き → `handleFileSystemEvent` → 並びと選択を保ったまま版とプレビューの寸法が変わるテストを足す（US43-AS1）

## Phase 6: Polish & Delivery

- [x] T018 Cloud の検査を実行する: scripts/check-no-network.sh、scripts/check-readme-sync.sh master、scripts/dev/check-english-comments.sh、scripts/dev/check-skill-sync.sh、`python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py"`。結果を quickstart.md に記録する
- [x] T019 作業ブランチに push し、PR の作成を保守者の依頼まで待つ。PR を作ったら Linear に PR のリンクを追加して In Review にする
- [x] T020 macOS CI の結果（通常のテストと性能テストのログの末尾）を確認し、quickstart.md に記録する。失敗したらログを読んでまとめて直す
- [ ] T021 [MANUAL] 保守者に、ローカルの最新 Swift での build/test、起動スモーク、quickstart.md の Q1〜Q9 を依頼し、結果を quickstart.md に記録する。報告があるまで未チェックのままにする（SC-115・116）
- [x] T022 実装と検証の後、PR の最後に最新の master を取り込み、ID の衝突を確かめてから、spec.md の「反映先」の項目を specs/product/ へ反映する。差分を保守者が承認した後にコミットし、spec.md を凍結する
- [ ] T023 TAK-43 の再現手順（quickstart.md の Q4）の結果を TAK-43 の判断材料として保守者に報告する（TAK-43 の作業はこの feature では行わない）

## Dependencies & Execution Order

T003 → T004〜T008（T004 → T005 → T006。T007・T008 は T004 の後）→ US1（T009 → T010 → T011 → T012、T013 は T010 の後）→ US2（T014 → T015）→ US3（T016 → T017）→ T018 → T019 → T020 → T021 → T022。
US2・US3 は US1 の T009〜T011 に依存する（同じ BrowserModel のため直列にする）。

## Parallel Opportunities

Cloud ではサブエージェントによる並列実装を行わない（AGENTS.md）。同じ `BrowserModel.swift` を触るタスクが多いため、すべて順に行う。

## Implementation Strategy

US1 が MVP（報告された症状と TAK-43 の症状を対象にする）。Core の API の変更（T004〜T008）を先に入れ、App の呼び出しを同じ段階で
コンパイルできる状態にする。CI は PR の作成時にしか動かないため、まとめて実装し、Cloud の検査を通してから push する。

## GUI 確認の結果への対応（2026-11-01）

- [x] T024 [US3] Q8 の NG（検索結果で何も更新されない）を調べ、URL オブジェクトが資源値を保持するため置き換え前の版が返ることを特定した。Sources/FolzioCore/Model/FileContentVersion.swift の `current(of:)` を新しい URL で読むように直し、Tests/FolzioCoreTests/FileContentVersionTests.swift に回帰テストを足す（FR-232、research.md R6）
- [x] T025 [MANUAL] 修正後の CI の成功と、保守者による Q8 の再確認を記録する
