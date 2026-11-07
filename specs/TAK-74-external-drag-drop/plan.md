# Implementation Plan: TAK-74 他のアプリとのドラッグ&ドロップ

**Branch**: `claude/affectionate-carson-yaiayj` | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-74-external-drag-drop/spec.md`

## Summary

ドラッグが Folzio のビューから始まったかを既存の `InternalDrag` で見分け、アプリ外のドラッグだけを新しい `ExternalDrag` で扱う。
アプリ外へのドラッグは、3つのビューのアプリ外向けのマスクを `[.copy, .move, .generic]` にそろえ（`.delete` は T005 の確認の結果で外し、Dock のゴミ箱には対応しない）、操作は Finder などのドロップ先に任せる（R2）。
アプリ外から受け取る file URL は、Core の `ExternalDropPolicy` が修飾キー・ボリューム・ドラッグ元のマスクから移動かコピーかを決め（R3・R4）、
既存の `FileOperationCoordinator` のドロップの経路（確認・衝突・失敗・再検証）で実行する（R5）。
ホバー中の検証のキャッシュは、アプリ内の `InternalDrag` の仕組みを `DropOperationCache` にまとめて共有し、操作の決め方だけを差し替える（R4）。
マスクの変更だけで Finder・Dock が期待どおりに動くかは、実装の最初に保守者の macOS で確かめ、その結果で仕様を確定する（R2、tasks.md の Phase 2）。
受け付けるのは file URL だけで、ブラウザの画像の取り込みは憲章 原則 III のため別の Issue で扱う（spec の A-204）。

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: Foundation / AppKit。外部依存なし

**Storage**: なし（新しい設定・永続データを追加しない）

**Testing**: Swift Testing（`Tests/FolzioCoreTests`、`Tests/FolzioAppTests`）、macOS CI、保守者の GUI 確認（quickstart.md）

**Target Platform**: macOS 15 以降

**Project Type**: Swift Package のデスクトップアプリ

**Performance Goals**: ホバー中の検証は UI スレッドでファイルシステムを読まず、ドラッグの通し番号ごとにキャッシュする（R4）。
大きな一覧でのドラッグの反応は、014 の確認と同じ水準を保つ

**Constraints**: ネットワーク API を使わない（FR-348、憲章 原則 I）。ファイル操作とボリュームの判定を UI スレッドで行わない。
アプリ内のドラッグの規則（FR-020・FR-162〜FR-165）を変えない。AppKit UI の不変条件（AGENTS.md）を守る

**Scale/Scope**: ツリー・リスト形式・サムネイル形式・検索結果の、アプリ外へのドラッグとアプリ外からの file URL のドロップ。
ブラウザの画像の取り込み、エイリアスの作成、Folzio から画像データを渡すことは対象外（A-204〜A-206）

## Constitution Check

| 原則 | Phase 0 / Phase 1 の確認 |
|---|---|
| I ローカル完結・破壊的操作の確認 | 適合。通信なし（FR-348）。アプリ外から受け取る移動は常に確認する（FR-024）。アプリ外への移動は、ユーザーが明示的にドロップ先を選ぶ操作で、Finder の取り消しで取り消せる（A-202）。確認の規則（FR-024）は、この例外を明記して変更する。Folzio はドラッグ元として削除せず、Dock のゴミ箱には対応しない（FR-344。T005） |
| II 性能・UI スレッド | 適合。ボリュームと宛先の検証は detached task で、通し番号ごとにキャッシュする（R4） |
| III キーボード操作 | 適合。Folzio と Finder の間の受け渡しは、ファイルリストの既存の ⌘C（file URL を一般のペーストボードに置く。`FileListViewController.swift:929-935`）と ⌘V・⌥⌘V（表示中のフォルダへ貼る。`FileListViewController.swift:950-966`）で行える。ツリーには ⌘C がなく、お気に入りはペースト先にならないため、どちらもファイルリストに表示して同じキーで行う（A-204、contracts の「キーボードの手段」）。キーボードの手段のないブラウザの画像の取り込みは範囲外にした（A-204） |
| IV テスト | 適合する計画。Core の操作の決定を Swift Testing で網羅し、App のマスク・file URL の判定をテストする。GUI は quickstart.md で保守者が確かめる。まだ実行していない |
| V YAGNI | 適合。新しい依存・設定・確認モーダルの種類を追加しない。受け取りは既存のドロップの経路を使う |
| 仕様の管理 | 適合。変更はこの feature に記録し、検証後に `specs/product/` へ反映する |

設計の前後で違反はない。設計レビューの承認前に実装しない（docs_private/cloud-agent-workflow.md の「全体の流れ」）。

## Project Structure

### Documentation (this feature)

`spec.md`、`plan.md`、`research.md`、`data-model.md`、`contracts/external-drag-drop.md`、`quickstart.md`、`tasks.md`、`checklists/requirements.md`

### Source Code (repository root)

- `Sources/FolzioCore/Operations/ExternalDropPolicy.swift`（新規）: 操作の決定とボリュームの判定（R3・R4）
- `Sources/FolzioApp/Shared/DropOperationCache.swift`（新規）: `InternalDrag` から移す、通し番号ごとの操作・URL のキャッシュ（R4）
- `Sources/FolzioApp/Shared/PasteboardFileURLs.swift`（新規）: file URL の読み出しを1つにまとめる（R4・R6）
- `Sources/FolzioApp/Shared/ExternalDrag.swift`（新規）: アプリ外の file URL の判定、アプリ外の操作の決め方、アプリ外向けのマスクの定数（R1・R2・R6）
- `Sources/FolzioApp/Shared/InternalDrag.swift`: キャッシュを `DropOperationCache` へ移す。Folzio のビューで受け取った印（R7）
- `Sources/FolzioApp/Operations/FileOperationCoordinator.swift`: `internalDrop` を `drop` に改名（R5）。`pasteboardFileURLs` を共通の関数に置き換える
- `Sources/FolzioCore/Browser/BrowserModel.swift`: `pruneMissingResults(under:)` で、消えた結果の一番上の消えた祖先（検索のルートまで）を `movedSearchPaths` に記録する（R8）
- `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift`: アプリ外向けのマスク（R2）。`validateDrop`・`acceptDrop` のアプリ外の経路を `ExternalDrag` に置き換え、
  利用可能なお気に入りも宛先にする（FR-345）。ドラッグの終了で、Folzio で受け取らなかったときは `pendingOperationSources` を消す（R7）
- `Sources/FolzioApp/FileList/ListModeView.swift`・`ThumbnailModeView.swift`: マスク（R2）、アプリ外の `validateDrop`・`acceptDrop` を追加（FR-345）、受け取った印（R7）
- `Sources/FolzioApp/FileList/FileListViewController.swift`: リスト形式・サムネイル形式からのドロップを coordinator へつなぐ
- `Tests/FolzioCoreTests/ExternalDropPolicyTests.swift`（新規）
- `Tests/FolzioCoreTests/BrowserModelSearchTests.swift`: FSEvents の経路で、アプリ外で消えたフォルダの配下の遅れた結果が表示されないことのテスト（R8）
- `Tests/FolzioAppTests/ExternalDragTests.swift`（新規）: マスク、登録した型、file URL の判定（名前付きの `NSPasteboard` を使う）、受け取った印
- `README.md`・`README.ja.md`・`docs/usage.md`・`docs/usage.ja.md`: Finder・ブラウザとのドラッグ&ドロップの説明（2 言語を同じコミットで）

**Structure Decision**: 判断（操作の決定）は `FolzioCore`、ペーストボード・ドラッグは `FolzioApp`（AGENTS.md の設計の制約）。
受け取りは新しい実行の経路を作らず、既存の `FileOperationCoordinator.transfer` を使う。

## 実装の順序

1. 先に行う確認: アプリ外向けのマスクだけを変えた版を push し、保守者が macOS で確かめ、結果で仕様を確定する（R2）
2. Core: `ExternalDropPolicy` とテスト
3. App: キャッシュの共通化（`DropOperationCache`・`PasteboardFileURLs`）。アプリ内のドラッグの動作は変えない
4. Core・App: 検索結果の記録（Core）と受け取った印（App）（US75）
5. App: `ExternalDrag`・3つのビューの file URL の受け取り（US76）
6. 文書（README・usage）と、検証の後の `specs/product/` への反映（PR の最後）

## 未検証の点（保守者の macOS で確かめる）

- Finder の移動・コピー、Dock のゴミ箱、Option と ⌘ の同時は T005 で確かめた（R2）。残りは、`.delete` を外した後に Dock のゴミ箱が受け付けないこと（T024）
- 別のボリュームと混在の場合のボリュームの判定（R4。CI では確かめられない）
- ブラウザの画像のドラッグが file URL を含まないか（R6）
- 検索結果からアプリ外へ移動した行が外れ、検索中に遅れて届く古い結果が出ないか（R8）

## Complexity Tracking

違反なし。
