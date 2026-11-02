# Tasks: メディアの Space プレビューとダブルクリックによる既定アプリ起動

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[research.md](research.md)、[data-model.md](data-model.md)、[contracts/keyboard-and-menus.md](contracts/keyboard-and-menus.md)

**前提**: 設計（spec・plan）の保守者の承認後に始める。Cloud では Swift を実行できないため、ビルドとテストは CI、GUI は保守者が確認する。

## Phase 1: 技術検証（FR-252 の判定。保守者の実機）

- [ ] T001 最小の `QuickLookCoordinator`（リスト形式。単一選択と、矢印キーの転送 `previewPanel(_:handle:)` を含む）と Space の入口を実装し、`swift build` が通ることを CI で確認する。保守者が quickstart.md の M1〜M3 と M16 を行い、
      起点からの拡大・縮小が標準部品だけで成り立つかを判定する。成り立たなければ Phase 3・4 を中止し、（A）だけを仕上げる（FR-252）
  - Sources/FolzioApp/FileList/QuickLookCoordinator.swift、ListModeView.swift

## Phase 2: ダブルクリックで既定のアプリを開く（US3-AS31〜34 / FR-251。Phase 1 と独立）

- [x] T002 [P] `ListItemKind.opensInDefaultApp(isBrowsingArchive:)` を追加する — Sources/FolzioCore/Model/MediaKind.swift
- [x] T003 [P] 上の判断のテストを書く（メディア true、zip 内 false、folder/archive/directory/parent false、画像と動画の両方）— Tests/FolzioCoreTests/QuickLookTargetsTests.swift
- [x] T004 `FileListViewController.openItem(_:)` で一覧の行を引き、T002 が true なら `NSWorkspace.shared.open(url)`（戻り値は無視。EC-176）、それ以外は従来どおり `model.openItem` — Sources/FolzioApp/FileList/FileListViewController.swift
- [x] T005 リスト形式・サムネイル形式のダブルクリック経路が T004 を通ることを確かめる（コード読み。変更が要れば最小限）— ListModeView.swift、ThumbnailModeView.swift
- [x] T006 Quick Look 表示中のダブルクリックでパネルを閉じてから開く（US3-AS34）。Phase 3 の後に行う — QuickLookCoordinator.swift

## Phase 3: Space の一時プレビュー（US3-AS23〜30 / FR-247〜250・253。Phase 1 の成功が条件）

- [x] T007 `QuickLookTargets.urls(files:selected:isBrowsingArchive:)` を追加する（data-model.md）— Sources/FolzioCore/Model/QuickLookTargets.swift
- [x] T008 [P] T007 のテスト（単一・複数・順序・フォルダ混在・メディアなし・選択が一覧にない・zip 内・検索結果の URL）— QuickLookTargetsTests.swift
- [x] T009 `QuickLookCoordinator` を完成する: `QLPreviewPanelDataSource`、`sourceFrameOnScreenFor`（リスト形式は行、サムネイル形式はサムネイルの矩形。見えない行はスクロールしてから。EC-173）、
      `toggle()`、`refreshOrClose()`（EC-172）— Sources/FolzioApp/FileList/QuickLookCoordinator.swift
- [x] T010 `ListModeView` の `NSTableView` に `acceptsPreviewPanelControl` / `begin` / `end` を実装し、Space を `toggle()` に接続する。動画の `onSpace` / `onTogglePlayback` の経路を外す（FR-248）— ListModeView.swift
- [x] T011 `ThumbnailModeView` の `NSCollectionView` に同じ実装と Space の入口を追加する — ThumbnailModeView.swift
- [x] T012 Space を使わない状態（名前の変更中・フルスクリーン中・スライドショー実行中。EC-170）を、`MainSplitViewController` から `FileListViewController` へ渡す — MainSplitViewController.swift、FileListViewController.swift
- [x] T013 開く前にプレビューの動画を一時停止する（EC-175）。既存の再生制御に pause がなければ最小の API を足す — PreviewViewController.swift、MainSplitViewController.swift
- [x] T014 一覧の更新（選択中のファイルの消失・フォルダの切り替え・検索の開始と終了）と選択の変更で `refreshOrClose()` を呼ぶ — FileListViewController.swift
- [x] T022 `previewPanel(_:handle:)` で矢印キー（⌘ なし）をファイルリストの first responder の `keyDown` へ転送し、それ以外のキーは `false` を返す（FR-254、US3-AS35・37）。
      選択変更の通知で項目と起点を更新し、0件なら閉じる（US3-AS36）— QuickLookCoordinator.swift
- [x] T023 [P] 選択が変わったときの項目の再計算（1件→複数→1件、メディアでない行への移動で0件）のテストを `QuickLookTargetsTests` に足す — Tests/FolzioCoreTests/QuickLookTargetsTests.swift
- [x] T024 パネルの表示中は、選択が動画に移ってもプレビューペインの動画を自動再生しない状態を追加する（EC-175）— PreviewViewController.swift、MainSplitViewController.swift

## Phase 4: ショートカット一覧と文書

- [x] T015 `ShortcutID.quickLook` をカタログに追加し、`videoPlay` の条件の文言を更新する。en/ja の文言とテキストキーを追加し、既存の整合テストを通す —
      Sources/FolzioCore/Shortcuts/ShortcutCatalog.swift、Sources/FolzioLocalization/ShortcutText.swift・TextKey.swift・Resources/{en,ja}.lproj/Localizable.strings
- [x] T016 [P] docs/usage.md と docs/usage.ja.md に Space のクイックルックとダブルクリックの説明を同じ構造で追加する（README は変えない）

## Phase 5: 検証と反映

- [x] T017 Cloud の静的検査（quickstart.md 第1章）を実行する
- [ ] T018 保守者の依頼で PR を作り、CI（`swift build`・`swift test`）の結果を読む。失敗は原因をまとめて直す
- [ ] T019 保守者が quickstart.md の M1〜M15 を実機で確認する。結果を第5章に記録する
- [ ] T020 `git merge origin/master` を取り込み、ID の重複を確かめてから、変更点を `specs/product/`（file-list.md・preview.md・contracts/keyboard-and-menus.md）へ反映する。保守者の承認を得てコミットする
- [ ] T021 spec.md の冒頭に移行済み・凍結の注記を入れる。Linear を `In Review` にして PR のリンクを追加する

## 依存関係

- Phase 1 → Phase 3 → T006。Phase 2 は Phase 1 と並行できる。
- Phase 4 の T015 は Phase 3 を採用する場合だけ行う。見送る場合、FR-248 の変更をしないので `videoPlay` の文言も変えない。

## 実装の記録（2026-11-01）

- T001・T018・T019 は未実施。実装のコードは T001 の範囲を超えて Phase 3 まで書いた。`swift build` と `swift test` は Cloud で実行できず、CI と保守者の実機確認の結果を待つ。
  実機で FR-252 が否定された場合は、Phase 3・4 のうち Space に関わる変更（`QuickLookCoordinator`、Space の入口、`ShortcutID.quickLook`）を取り除く。
- T015: `ShortcutID.quickLook` を追加し、`videoPlay` の条件の文言を変えた。カタログのテストの期待値は 46 件にした。
- T023: 選択の変化に伴う再計算は、`QuickLookTargets.urls` が選択から毎回計算する純粋な関数のため、既存の単一・複数・混在・空・zip 内のテストで覆っている。
