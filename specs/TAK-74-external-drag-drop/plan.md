# Implementation Plan: TAK-74 他のアプリとのドラッグ&ドロップ

**Branch**: `claude/affectionate-carson-yaiayj` | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-74-external-drag-drop/spec.md`

## Summary

ドラッグが Folzio のビューから始まったかを既存の `InternalDrag` で見分け、アプリ外のドラッグだけを新しい `ExternalDrag` で扱う。
アプリ外へのドラッグは、3つのビューのアプリ外向けのマスクを `[.copy, .move, .generic, .delete]` にそろえ、操作は Finder などのドロップ先に任せる（R2）。
アプリ外から受け取る file URL は、Core の `ExternalDropPolicy` が修飾キー・ボリューム・ドラッグ元のマスクから移動かコピーかを決め（R3・R4）、
既存の `FileOperationCoordinator` のドロップの経路（確認・衝突・失敗・再検証）で実行する（R5）。
ブラウザの画像は、file promise を宛先と同じボリュームの一時フォルダへ書き出させるか、画像データを PNG で書き、同じコピーの経路で宛先へ入れて一時フォルダを消す（R6・R7）。
画像データのファイル名は Core の `ImportedImageName` が決める（R8）。

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: Foundation / AppKit / ImageIO（OS 標準）。外部依存なし

**Storage**: なし（新しい設定・永続データを追加しない。受け取りの一時フォルダはその場で消す）

**Testing**: Swift Testing（`Tests/FolzioCoreTests`、`Tests/FolzioAppTests`）、macOS CI、保守者の GUI 確認（quickstart.md）

**Target Platform**: macOS 15 以降

**Project Type**: Swift Package のデスクトップアプリ

**Performance Goals**: ホバー中の検証は UI スレッドでファイルシステムを読まず、ドラッグの通し番号ごとにキャッシュする（R4）。
ブラウザの書き出しを待つ間も UI を止めない（EC-239）。大きな一覧でのドラッグの反応は、014 の確認と同じ水準を保つ

**Constraints**: ネットワーク API を使わない（FR-351、憲章 原則 I）。デコード・変換・ファイル操作を UI スレッドで行わない。
アプリ内のドラッグの規則（FR-020・FR-162〜FR-165）を変えない。AppKit UI の不変条件（AGENTS.md）を守る

**Scale/Scope**: ツリー・リスト形式・サムネイル形式・検索結果の、アプリ外へのドラッグとアプリ外からのドロップ。エイリアスの作成と、
Folzio から画像データ・file promise を渡すことは対象外（A-205・A-206）

## Constitution Check

| 原則 | Phase 0 / Phase 1 の確認 |
|---|---|
| I ローカル完結・破壊的操作の確認 | 適合。Folzio は通信しない（FR-351。URL は文字列として名前に使うだけ）。アプリ外から受け取る移動は常に確認する（FR-024）。アプリ外への移動・ゴミ箱は、ユーザーが明示的にドロップ先を選ぶ操作で、Finder の取り消しとゴミ箱で取り消せる（A-202） |
| II 性能・UI スレッド | 適合。ボリュームと宛先の検証、PNG への変換、一時フォルダの作成・削除は detached task。file promise は専用の `OperationQueue` で待つ |
| III キーボード操作 | 適合。ドラッグ&ドロップは他のアプリとの受け渡しの手段で、Folzio の中の移動・コピーには既存の ⌘C・⌘V・⌥⌘V がある（FR-019）。新しい Folzio の中の操作は追加しない |
| IV テスト | 適合する計画。Core の操作の決定・ファイル名を Swift Testing で網羅し、App の型の登録・マスク・画像の保存と一時フォルダの削除をテストする。GUI は quickstart.md で保守者が確かめる。まだ実行していない |
| V YAGNI | 適合。新しい依存・設定・確認モーダルの種類を追加しない。受け取りは既存のコピー・移動の経路を使う |
| 仕様の管理 | 適合。変更はこの feature に記録し、検証後に `specs/product/` へ反映する |

設計の前後で違反はない。設計レビューの承認前に実装しない（docs_private/cloud-agent-workflow.md の「全体の流れ」）。

## Project Structure

### Documentation (this feature)

`spec.md`、`plan.md`、`research.md`、`data-model.md`、`contracts/external-drag-drop.md`、`quickstart.md`、`tasks.md`、`checklists/requirements.md`

### Source Code (repository root)

- `Sources/FolzioCore/Operations/ExternalDropPolicy.swift`（新規）: 操作の決定とボリュームの判定（R3・R4）
- `Sources/FolzioCore/Operations/ImportedImageName.swift`（新規）: 画像データのファイル名（R8）
- `Sources/FolzioCore/Operations/OperationFailureReason.swift`: `importTimedOut` を追加（R11）
- `Sources/FolzioApp/Shared/ExternalDrag.swift`（新規）: 受け取るデータの判定（`ExternalDragPayload`、R9）、ホバー中の操作の決定とキャッシュ（R4）、登録する型の一覧
- `Sources/FolzioApp/Operations/ExternalImport.swift`（新規）: file promise の受け取りと画像データの保存、一時フォルダの管理（`ImportSession`、R6・R7）
- `Sources/FolzioApp/Operations/FileOperationCoordinator.swift`: `internalDrop` を `drop` に改名（R5）。一時フォルダからのコピーと書き出しの失敗をまとめて表示する入口を追加し、
  一時フォルダを `notifyFoldersChanged` から外す（R6・R10）
- `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift`: アプリ外向けのマスク（R2）、型の登録（R9）。`validateDrop`・`acceptDrop` のアプリ外の経路を `ExternalDrag` に置き換え、
  利用可能なお気に入りも宛先にする（FR-345）
- `Sources/FolzioApp/FileList/ListModeView.swift`・`ThumbnailModeView.swift`: マスク（R2）、型の登録（R9）、アプリ外の `validateDrop`・`acceptDrop` を追加（FR-345）
- `Sources/FolzioApp/FileList/FileListViewController.swift`: リスト形式・サムネイル形式からのアプリ外のドロップを coordinator へつなぐ
- `Sources/FolzioLocalization/TextKey.swift`、`Resources/{ja,en}.lproj/Localizable.strings`: 画像の既定の接頭辞、`importTimedOut` の文言（R11）
- `Tests/FolzioCoreTests/ExternalDropPolicyTests.swift`・`ImportedImageNameTests.swift`（新規）
- `Tests/FolzioAppTests/ExternalDragTests.swift`（新規）: 登録した型、マスク、データの判定（名前付きの `NSPasteboard` を使う）、画像データの保存と一時フォルダの削除
- `README.md`・`README.ja.md`・`docs/usage.md`・`docs/usage.ja.md`: Finder・ブラウザとのドラッグ&ドロップの説明（2 言語を同じコミットで）

**Structure Decision**: 判断（操作の決定・ファイル名）は `FolzioCore`、ペーストボード・ドラッグ・file promise・画像の変換は `FolzioApp`（AGENTS.md の設計の制約）。
受け取りは新しい実行の経路を作らず、既存の `FileOperationCoordinator.transfer` を使う。

## 実装の順序

1. Core: `ExternalDropPolicy`・`ImportedImageName`・`importTimedOut` とテスト
2. App: マスク・型の登録・`ExternalDrag`・3つのビューの file URL の受け取り（US75・US76、P1）
3. App: `ExternalImport`・coordinator の入口・ローカライズ（US77、P2）
4. 文書（README・usage）と、検証の後の `specs/product/` への反映（PR の最後）

## 未検証の点（保守者の macOS で確かめる）

- Finder・Dock のゴミ箱が、追加したマスクで期待どおりに移動・コピー・ゴミ箱を行うか（R2）
- Safari・Chrome が画像のドラッグで何を渡すか（file promise か画像データか、ファイル名）（R6・R7）
- 型の登録を増やしても、アプリ内のドラッグとサムネイルのドロップ先の挙動が変わらないか（R9）

## Complexity Tracking

違反なし。
