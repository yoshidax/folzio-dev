# Tasks: フォルダの右クリックメニューの整理

**Input**: `specs/024-list-folder-favorites/` の spec・plan・research・data-model・contracts・quickstart。
**Tests**: 憲章 IV により、対象計算と実操作のテストを含める。
**Organization**: 共通方針に依存する3ストーリーを1つの実装 Phase 内で順次仕上げる。

## Format

`- [ ] Tnnn [MANUAL?] [USn?] 説明（対象パス）`

手動確認は ID 直後の `[MANUAL]` で分類する。文書作成・実装・自動検証・コミットと混在させない。
実装中は分類を変えず、報告前の代行チェックをしない。

## Phase 1: Setup — 目的変更後の設計承認

- [X] T001 [MANUAL] `specs/024-list-folder-favorites/spec.md`・`plan.md`・`tasks.md` と分析結果をレビューし、共通操作・新規フォルダの配置・複数対象・検索結果のペースト・手動分類を承認する。
- [X] T002 T001 の承認を `specs/024-list-folder-favorites/quickstart.md` 末尾へ記録し、設計文書だけをコミットして `.specify/feature.json` の選択先を確認する。

今回の設計レビューの承認を T001 に使い、同じ承認を再度求めない。設計コミットは workflow の実装前ゲート。

## Phase 2: Foundational — 既存基盤を再利用

新しい依存・保存形式・プロジェクト初期化はない。
Core の共通方針と対象計算は次の実装 Phase の最初に作成する。
個別には動作しない基盤だけを別の実装 Phase に分けず、1つの共通メニューとして検証・コミットする。

## Phase 3: User Stories 87・88・89 — フォルダの共通操作 (P1)

### US88: 同じファイル操作を同じメニューで使う

**Independent Test**: ツリー・リスト・サムネイルの単一／複数フォルダで操作列と有効条件を比較し、コピー・複製の実結果を検証する。

- [X] T003 [US88] `Tests/FolzioCoreTests/FolderContextMenuTests.swift` と `Tests/FolzioCoreTests/TreeBatchTargetsTests.swift` に共通順序・単一／複数・混在・ルート・仮想項目・`..` を除く前の件数のテストを追加する（FR-018・019・076・208・213・218・401・402・404、SC-225・227）。
- [X] T004 [US88] `Tests/FolzioAppTests/FolderContextMenuTests.swift` に両ビューの実メニュー・外部で開く項目の非表示・対象切替後のメニュー再計算・ツリーのコピー URL と複製 action の接続テストを追加する（FR-397・401・402・404）。テストは一時フォルダと隔離した pasteboard／defaults を使う。
- [X] T005 [US88] `Sources/FolzioCore/Model/FolderContextMenu.swift` に通常フォルダの共通操作列と対象役割・件数の方針を追加する。「対象全体が実フォルダ1件」を単一先の条件とし、`..` や不明な URL を除いてから件数を判定しない。入力元・対象・表示フォルダ・検索／zip 状態から貼り付け先 URL? を返す純粋関数も置く（FR-401・403）。
- [X] T006 [US88] `Sources/FolzioCore/Model/TreeBatchTargets.swift`・`FavoriteCommands.swift` を共通操作列へ接続し、通常フォルダ全体のコピー・複製・Finder 対象を返す。既存のゴミ箱・ドラッグ・ルート保護とお気に入りの別メニューを維持する（FR-218・401・402）。
- [X] T007 [US88] `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` に copy・duplicate と可否検証を加え、右クリックはその対象、⌘C・⌘D・メニューバーは現在の選択を使う。既存 coordinator.duplicate と Pasteboard file URL、翻訳の名前／件数表示を共用する（FR-018・019・402、SC-228）。
- [X] T008 [US88] `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` の通常フォルダのメニューを共通順序にそろえ、複数フォルダの Finder に表示を接続し、通常フォルダの「新規フォルダ」を外す。お気に入りの仮想項目のメニュー・背景とキーの新規作成は保つ（FR-208・213・218・401）。
- [X] T009 [US88] `Sources/FolzioApp/FileList/FileContextMenu.swift` を対象別に構成し、実フォルダだけなら共通操作と既存ナビゲーションを出す。実フォルダを含むときは open・openWith を隠し、メディア／zip ファイル・背景の既存構成を保つ。ルートを含む混在対象でも共通の保護を適用し、翻訳・キー割り当てを共用する（FR-076・397・401・404）。

### US89: 項目メニューのペースト先を対象フォルダにする

**Independent Test**: P を表示し B を選択したまま A にペーストするケースと、背景・キーから P にペーストするケースを比較する。

- [X] T010 [US89] `Tests/FolzioCoreTests/FolderContextMenuTests.swift` と `Tests/FolzioAppTests/FolderContextMenuTests.swift` に入力経路・対象全体・検索／zip・消失／混在による行先と無効条件のテストを追加する。実コピー・移動の先が A と P で分かれ、B や古い対象に書き込まれないことを一時フォルダで検証する（FR-087・397・403、EC-272〜274、SC-226）。
- [X] T011 [US89] `Sources/FolzioApp/FileList/FileListViewController.swift` に項目メニューの貼り付け先を決める経路を追加し、単一実フォルダならその URL を既存 coordinator.paste へ渡す。検索結果でも許可し、複数・混在・消失時は他の先へ戻さない。背景・メニューバー・メニューを閉じた状態のキーは表示中のフォルダ、検索／zip は無効という既存条件を保つ（FR-087・403）。
- [X] T012 [US89] `Sources/FolzioApp/FileList/FileContextMenu.swift` と `FileListViewController.swift` の検証と action を同じ先の計算にそろえ、既存のファイル／画像 clipboard 条件・移動条件・確認・衝突・失敗表示を共用する（FR-403、EC-273）。

### US87: お気に入り登録の拡張

**Independent Test**: 一覧の選択中／選択外・検索・絞り込み・一覧のみ表示で1件だけを登録し、重複と復元を検証する。

- [X] T013 [US87] `Tests/FolzioCoreTests/FavoriteCommandsTests.swift`・`PaneLayoutTests.swift` と `Tests/FolzioAppTests/FolderContextMenuTests.swift` に登録対象・重複・保存・ペイン・文字入力のテストを追加し、`FavoriteCommands.swift`・`PaneLayout.swift` に単一実フォルダと対象ペインの判断を実装する（FR-062・092・399、EC-268〜271）。
- [X] T014 [US87] `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` に URL による登録可否と共通登録入口を設け、`FileListViewController.swift`・`App/MainSplitViewController.swift` から接続する。既存保存・再描画・重複判定を共用し、一覧フォーカスで候補なしでもツリーへ戻さず、登録時に閲覧状態を保つ（FR-062・217・399・400、SC-221〜224）。

### 自動検証・手動確認・Phase コミット

- [X] T015 `Tests/FolzioCoreTests/`・`Tests/FolzioAppTests/` の関連テストと、既存の FileListContextClickTests・ペースト・画像受信・新規フォルダの回帰を検証し、`swift build` → `swift test` → `scripts/dev/check-all.sh` → `scripts/make-app.sh` を実行して `specs/024-list-folder-favorites/quickstart.md` 末尾へ結果とビルドを記録する。
- [X] T016 [MANUAL] 保守者が `open .build/Folzio.app` で起動し、`specs/024-list-folder-favorites/quickstart.md` の項目1〜10（3ペイン・両表示形式・コピー／複製・入力別の貼り付け先・複数／混在／検索／zip／失敗・登録／復元／回帰）を確認し、ビルド・macOS・各結果を報告する。
- [X] T017 [MANUAL] 同じビルドで `specs/024-list-folder-favorites/quickstart.md` の項目11（日本語・英語・キー変更・VoiceOver）を確認して各結果を報告する。
- [X] T018 T016・T017 の報告を `specs/024-list-folder-favorites/quickstart.md` 末尾へ記録し、該当する tasks.md のチェックを更新して実装 Phase をコミットする。

## Phase 4: Polish & Cross-Cutting — 最終確認と製品仕様

- [X] T019 T015 と同じ順で最終の自動検証を行い、`.build/Folzio.app` のビルド識別情報と結果を `specs/024-list-folder-favorites/quickstart.md` 末尾へ追記する。
- [ ] T020 [MANUAL] 保守者が T019 のビルドを `open .build/Folzio.app` で起動し、3ペインが表示されることを確認してビルドと結果を報告する（`specs/024-list-folder-favorites/quickstart.md`）。
- [ ] T021 T020 の報告を `specs/024-list-folder-favorites/quickstart.md` 末尾へ記録し、speckit-converge で実装・仕様・計画・タスクを照合する。同じファイルへ結果を追記し、追加タスクがあれば最大3反復まで実装・自動検証・手動確認を行う。
- [ ] T022 `specs/product/README.md` を再読し、`scripts/dev/check-spec-ids.sh` を実行してから spec の反映先と feature の `contracts/keyboard-and-menus.md` を製品仕様へ反映する。旧来の「複製は一覧だけ」「ツリーの複数はゴミ箱だけ」「一覧ペーストは常に表示中」「検索で一律ペースト禁止」等の説明・シナリオを更新し、feature spec に凍結注記を加える。反映後に ID と形式の検査を実行し、まだコミットしない。
- [ ] T023 [MANUAL] 保守者が `git diff -- specs` で `specs/product/` の変更・ID・反映先と feature の凍結注記を確認して承認する。
- [ ] T024 T023 の承認を `specs/024-list-folder-favorites/quickstart.md` 末尾へ記録し、製品仕様・契約と feature をコミットして作業ブランチ・検証結果・残課題を報告する。

## Dependencies & Execution Order

T001 → T002 → T003・T004 → T005 → T006〜T009 → T010 → T011・T012 → T013・T014 → T015 → T016・T017 → T018 → T019 → T020 → T021 → T022 → T023 → T024。
テストは対象コードより先に追加する。各実装の後にその関連テストを確認し、全接続後に T015 の Phase ゲートを行う。
US89 は共通の対象方針に依存。US87 はその共通メニューへの接続後に完了する。
個々のストーリーは対応する検証で判定できるが、共通コードを1つの実装 Phase で統合する。

## Parallel Opportunities

今回は採用せず、同じセッションで順次作業する。

## Implementation Strategy

共通対象方針 → ツリーの操作拡張と一覧の構成 → 行先の区別 → 登録 → 自動検証 → 手動確認の順。
GUI 報告前に実装 Phase をコミットせず、製品仕様の承認前に反映をコミットしない。
実装中に更新できる feature 文書は tasks.md のチェックと、明示した quickstart.md 末尾の記録だけ。
製品反映時の spec の凍結注記は T022 で明示している。
PR 作成・マージ・Linear Done は今回の手順に含めない。

## Phase 5: Convergence

- [ ] T025 アプリ内のショートカット一覧の文言（`Sources/FolzioLocalization/Resources/ja.lproj/Localizable.strings` と `en.lproj` の `shortcuts.entry.copy`・`shortcuts.condition.copy`・`shortcuts.condition.duplicate`・`shortcuts.condition.addFavorite`）を、ツリーのコピー・複製、複製のルートの制限、ファイルリストのみ表示を含む一覧からの登録に合わせて更新し、両言語で確認する。FR-019・FR-062・FR-399・FR-402 とショートカット一覧の契約に従う（partial）
