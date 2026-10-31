# Implementation Plan: TAK-21 ツリーでのフォルダの複数選択と一括操作

**Branch**: `claude/youthful-brahmagupta-ocjb0d` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-21-tree-multi-select/spec.md`

## Summary

ツリーの `NSOutlineView` を複数選択可能にし、操作の対象（選択全体か、右クリック・ドラッグを始めた1行か）と、その対象での各操作の可否を Core の
`TreeBatchTargets` で決める。一括のゴミ箱は既存の `FileOperationCoordinator.trash(_:origin: .tree)` に URL の配列を渡し、確認モーダルの場所の表示だけを複数に対応させる。
移動・コピーは既存のアプリ内ドラッグ（`InternalDrag`・`InternalDropValidation`）がそのまま URL の配列を扱う。主の行（FR-209）はツリーのサブクラスで追跡し、
操作後の選択は表示中のフォルダの単一選択に揃える（FR-212）。

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: Foundation / AppKit。外部依存なし

**Storage**: なし（新しい設定・永続データを追加しない）

**Testing**: Swift Testing（`Tests/FolzioCoreTests`）、macOS CI、保守者の GUI 確認

**Target Platform**: macOS 15 以降

**Project Type**: Swift Package のデスクトップアプリ

**Performance Goals**: 選択・メニューの有効化の判定はディスクを読まず、行数に比例する計算だけにする（R2）。ツリーの表示の停止は SC-004 と同じく 100ms 未満

**Constraints**: ネットワーク API を使わない。ファイル操作と移動・コピーの検証は UI スレッドで行わない（既存の detached task を使う）。
AppKit UI の不変条件（AGENTS.md）を守る

**Scale/Scope**: ツリーの通常のフォルダの複数選択からの移動・コピー・ゴミ箱。お気に入りの一括削除・⌘A・アプリ外へのドラッグは対象外（A-119・A-122・A-123）

## Constitution Check

| 原則 | Phase 0 / Phase 1 の確認 |
|---|---|
| I ローカル完結・破壊的操作の確認 | 適合。通信なし。一括のゴミ箱は省略不可の確認モーダルを経て、ゴミ箱経由（FR-021）。移動は既存の常時確認（FR-024） |
| II 性能・UI スレッド | 適合。可否の判定は I/O なし（R2）。ファイル操作・ドロップの検証は既存の detached task |
| III キーボード操作 | 適合。Shift+↑↓ で複数選択でき、⌘⌫・メニューで一括削除できる。単一の対象の操作は複数選択中に無効化して誤操作を防ぐ |
| IV テスト | 適合する計画。Core の対象・可否・重なりの判定を Swift Testing で網羅する。GUI の確認を quickstart に定める。まだ実行していない |
| V YAGNI | 適合。新しい依存・設定・確認モーダルの種類を追加しない。⌘A・お気に入りの一括削除は追加しない |
| 仕様の管理 | 適合。変更はこの feature に記録し、検証後に `specs/product/` へ反映する |

設計の前後で違反はない。設計レビューの承認前に実装しない（docs_private/cloud-agent-workflow.md の「全体の流れ」）。

## Project Structure

### Documentation (this feature)

`spec.md`、`plan.md`、`research.md`、`data-model.md`、`contracts/tree-selection.md`、`quickstart.md`、`tasks.md`、`checklists/requirements.md`

### Source Code (repository root)

- `Sources/FolzioCore/Model/TreeBatchTargets.swift`（新規）: 対象の決定（FR-210）、ゴミ箱・ドラッグの URL と可否（FR-211）、親子の重なり（EC-141）。R1・R2
- `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift`: `allowsMultipleSelection = true`。`DragAwareOutlineView` で主の行とアンカーを追跡し、Shift+↑↓ を処理（R4）。
  ドラッグ前の選択全体の復元と、通常のフォルダ以外を含むドラッグの抑止（R5）。`moveToTrash`・`trashFolderFromMenu`・`validateMenuItem`・`menuNeedsUpdate`・
  `rename`・`paste`・`movePaste`・`copyPathname`・`addToFavorites` を `TreeBatchTargets` 経由に変える（R7）。`selectAll(_:)` の無効化（R8）。折りたたみの扱い（R9）。
  操作後の選択（FR-212、R6）
- `Sources/FolzioApp/App/MainSplitViewController.swift`: `canAddSelectedFolderToFavorites` を複数選択で false にする（R7）
- `Sources/FolzioApp/Operations/FileOperationCoordinator.swift`: ツリーからのゴミ箱の確認モーダルに各フォルダのパスを渡す（R3）。ツリーからの移動・ゴミ箱の完了をツリーへ通知（FR-212）
- `Sources/FolzioApp/Operations/ConfirmationPresenter.swift`: 複数の場所の表示（先頭5件と残りの件数）
- `Sources/FolzioLocalization/TextKey.swift`、`Resources/{ja,en}.lproj/Localizable.strings`: EC-141 のエラーの見出しと説明、複数の場所の行の文言
- `Tests/FolzioCoreTests/TreeBatchTargetsTests.swift`（新規）: FR-210・FR-211・EC-141 の全分岐と、単一の対象で `FavoriteCommands` と一致すること
- `Tests/FolzioCoreTests/Localization/`: 追加したキーの ja・en の存在（既存のキー網羅テストがあればそれに従う）

**Structure Decision**: 既存の Core/App 分離を維持する。判断は Core の新しい値型に置き、AppKit 側は入力の収集と結果の適用だけを行う。

## Phase 0: Research

[research.md](research.md) の R1〜R9。AppKit の挙動に依存する R4（Shift クリックのアンカー）・R5（nil を返したときのドラッグ）・R9（折りたたみの選択）は
静的調査では確定できないため、GUI 確認（quickstart の S3・S5・S7）を実装のゲートにする。想定と違えば、該当の箇所だけを調整し、仕様の振る舞いは変えない。

## Phase 1: Design

[data-model.md](data-model.md) の `TreeBatchTargets` と、[contracts/tree-selection.md](contracts/tree-selection.md) のキー・マウスの契約に従う。

- 単一選択のときの振る舞いは変えない（既存の FR-079・FR-103・FR-064・FR-182 の経路を通す）。`TreeBatchTargets` は1件のとき既存の `FavoriteCommands` の結果を返す
- `outlineViewSelectionDidChange` は、主の行が変わったときだけ `model.selectFolder` を呼ぶ。複数選択中にファイルリストの表示をほかの経路で変えない
- 一括のゴミ箱の失敗（一部の失敗・外部で消えた項目）は既存の `presentFailures` に任せる（EC-142）

## Complexity Tracking

憲章の例外なし。

## Delivery Gate

設計レビューの承認後に実装する。Cloud の静的検査、macOS CI の build/test、保守者のローカルでの起動スモークと quickstart の S1〜S12 を終えてから `specs/product/` に反映する。
PR は保守者の依頼があったときだけ作る。
