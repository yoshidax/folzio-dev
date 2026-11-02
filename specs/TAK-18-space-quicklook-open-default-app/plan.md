# Implementation Plan: メディアの Space プレビューとダブルクリックによる既定アプリ起動

**Branch**: `claude/inspiring-johnson-vf3781` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-18-space-quicklook-open-default-app/spec.md` / [TAK-18](https://linear.app/takyoshida/issue/TAK-18)

## Summary

2つの独立した変更に分ける。（A）ダブルクリック: メディアの行のダブルクリックで `NSWorkspace.open` を呼ぶ。対象の判断は Core の純粋な関数に置く。
（B）Space: ファイルリストにフォーカスがあるとき、Quick Look の標準パネル（`QLPreviewPanel`）を開閉する。パネルの項目と起点の矩形は
App の `QuickLookCoordinator` が持ち、対象の選び方は Core の純粋な関数に置く。（B）は Cloud で実行して確かめられない公開 API の挙動
（起点からのズーム）に依存するため、最初のタスクを実機の技術検証にし、成り立たなければ（B）を見送って（A）だけを出す（FR-252）。

本資料は設計レビュー用。`docs_private/cloud-agent-workflow.md` の「承認の前に実装しない」に従い、設計の承認後に tasks.md の実装を始める。

## Technical Context

**Language/Version**: Swift 6（言語モード v6）

**Primary Dependencies**: Foundation、AppKit、QuickLookUI（macOS SDK 標準。`import Quartz` 経由、または `import QuickLookUI`）。外部パッケージなし。
Package.swift の変更は不要の想定（SDK のフレームワークは import だけでリンクされる）。CI のビルドで確認する（research.md R6）。

**Storage**: なし。

**Testing**: Swift Testing（`Tests/FolzioCoreTests`）。Quick Look のパネルと既定のアプリの起動は quickstart.md の M1〜M8 で保守者が確認する。

**Target Platform**: macOS 15 以降。Cloud（Linux）では Swift と GUI を実行しない。

**Project Type**: Swift Package のデスクトップアプリ。

**Performance Goals**: Space とダブルクリックのときだけ処理する。パネルへ渡すのは URL の並びだけで、デコード・列挙はしない（Quick Look が自前で行う）。既存の性能基準は変えない。

**Constraints**: Core は AppKit を import しない。パネルの操作は MainActor。ネットワーク API を使わない。AppKit UI の不変条件（制約・split view の delegate に触れない）を守る。

**Scale/Scope**: Core 2（新規 1、変更 1）、App 5、Localization 3（strings 2・テキスト定義 1）、テスト 3、docs 4。

## Constitution Check

| 原則 | Phase 0 前 / Phase 1 後の判断 |
|---|---|
| I ローカル完結 | PASS / PASS。Quick Look と `NSWorkspace.open` は端末内で完結する。ネットワーク API は使わない。`scripts/check-no-network.sh` で確認する。 |
| II 体感性能 | PASS / PASS。UI スレッドで重い処理をしない（読み込みは Quick Look 側）。既存の経路は変えない。 |
| III キーボード・アクセシビリティ | PASS / PASS。Space はキーボードの入口、ダブルクリックの代替は既存の ⌘O。パネルは OS 標準でアクセシビリティ対応済み。 |
| IV テスト必須 | PASS / PASS。対象の選び方と開く対象の判断を Core に置いて自動テストを付ける（異常系: 空・混在・zip 内）。GUI は quickstart.md。 |
| V YAGNI | PASS / PASS。設定・メニュー項目・Folzio 独自のプレビュー UI は追加しない。 |
| 仕様管理 | PASS / PASS。新しい feature ディレクトリだけを作る。ID は master（e7c8413）時点の最大値 FR-232 / SC-116 / EC-163 / A-143 の次から採った。product への反映は実装と検証の後。 |

## Project Structure

### Documentation (this feature)

`specs/TAK-18-space-quicklook-open-default-app/` に spec.md、plan.md、research.md、data-model.md、contracts/keyboard-and-menus.md、quickstart.md、checklists/requirements.md、tasks.md を置く。

### Source Code (repository root)

```text
Sources/FolzioCore/Model/QuickLookTargets.swift            # 新規: Space の対象の選び方 / ダブルクリックで既定のアプリを開く判断
Sources/FolzioCore/Shortcuts/ShortcutCatalog.swift         # 変更: quickLook の項目を追加、videoPlay の条件を変更
Sources/FolzioLocalization/ShortcutText.swift / TextKey.swift / Resources/{en,ja}.lproj/Localizable.strings  # 変更: 文言
Tests/FolzioCoreTests/QuickLookTargetsTests.swift          # 新規
Tests/FolzioCoreTests/ShortcutCatalogTests 相当             # 変更: 既存の整合テストが新しい項目を満たすこと
Sources/FolzioApp/FileList/QuickLookCoordinator.swift      # 新規: QLPreviewPanel の dataSource / delegate、起点の矩形、矢印キーの転送、選択変更での更新、閉じる条件
Sources/FolzioApp/FileList/ListModeView.swift              # 変更: Space で toggle、レスポンダチェーンに Quick Look の制御を追加
Sources/FolzioApp/FileList/ThumbnailModeView.swift         # 変更: 同上（サムネイルの Space と起点）
Sources/FolzioApp/FileList/FileListViewController.swift    # 変更: openItem でメディアを既定のアプリで開く、Coordinator の保持、一覧変更で閉じる
Sources/FolzioApp/App/MainSplitViewController.swift        # 変更: Space を無効にする状態（フルスクリーン・スライドショー）の提供、onTogglePlayback の Space 経路を外す、再生の一時停止
docs/usage.md / docs/usage.ja.md                           # 変更: Space とダブルクリックの説明
```

**Structure Decision**: 判断は Core、パネルの制御と矩形の計算は App。`BrowserModel.openItem` は「メディアでは何もしない」まま変えず（FR-69・76 の契約）、
既定のアプリを開くのは `FileListViewController.openItem` が Core の判断で呼ぶ。`NSWorkspace` は Core に入れない。

## Phase 0: Research

[research.md](research.md) の R1〜R7 に記録した。核心は R1（Quick Look パネルが公開 API だけで起点のズームを実現する方法）で、
実機でしか確かめられないため、tasks.md の T001 を技術検証にして、成否で（B）を続けるか見送るかを決める。

## Phase 1: Design

1. Core に `QuickLookTargets.urls(files:selected:isBrowsingArchive:)`（一覧の並び順のメディアだけ・zip の中は空）と
   `ListItemKind.opensInDefaultApp(isBrowsingArchive:)` 相当の判断を追加する（[data-model.md](data-model.md)）。
2. `QuickLookCoordinator`（MainActor）を作り、`QLPreviewPanelDataSource` / `QLPreviewPanelDelegate` を実装する。
   項目は `NSURL`（`QLPreviewItem` に準拠）。起点は `previewPanel(_:sourceFrameOnScreenFor:)` で、項目の URL から表示中の行／サムネイルの画面座標の矩形を返す
   （見えない場合は `.zero`）。
3. `ListModeView` の `NSTableView` と `ThumbnailModeView` の `NSCollectionView` のサブクラスで `acceptsPreviewPanelControl` / `beginPreviewPanelControl` / `endPreviewPanelControl`
   を実装し、Coordinator を dataSource / delegate に設定する。`keyDown` の Space で Coordinator の `toggle()` を呼ぶ（開いている間はパネルが first responder になり、パネル自身の Space で閉じる）。
4. `toggle()` は Core の判断で対象が空なら何もしない。開く前にプレビューペインの動画を一時停止し（EC-175）、起点の行が見えなければスクロールする（EC-173）。
5. 一覧の更新（選択中のファイルの消失・フォルダの切り替え）と選択の変更で、Coordinator が項目を再計算して `reloadData()` するか、0件なら閉じる（EC-172、FR-254）。
   矢印キー（⌘ なし）は `previewPanel(_:handle:)` でファイルリストの `keyDown` へ転送する（research.md R8）。パネルの表示中は、プレビューペインの動画の自動再生を抑える（EC-175）。
6. `FileListViewController.openItem(_:)` で、一覧から URL の行を引き、Core の判断が「既定のアプリで開く」なら `NSWorkspace.shared.open(url)` を呼ぶ。それ以外は従来の `model.openItem`。
7. `onTogglePlayback` の Space 経路（`ListModeView` の `onSpace`）を外す。プレビューの動画へのフォーカス時の Space はプレビュー側のコントロールが処理する（変更なし）。
8. ショートカット一覧（Core のカタログ・文言）を更新する。

## Complexity Tracking

違反なし。`QuickLookCoordinator` は新しい型だが、パネルの dataSource/delegate はリストの View に載せるとリスト形式とサムネイル形式で重複するため、1つにまとめる（より単純な代替は重複）。
