# Implementation Plan: TAK-16 大文字小文字だけの改名

**Branch**: `work` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-16-case-only-rename/spec.md`

## Summary

同じ親の兄弟を列挙し、元の名前と完全一致するエントリだけを除外して競合判定する。別エントリがなければ、大文字小文字だけの変更では改名先の存在を元項目自身として扱い、既存の移動処理へ進む。返す URL は入力表記にする。事前検証と実行時の両方で別項目の競合を拒否する。

## Technical Context

**Language/Version**: Swift 6
**Primary Dependencies**: Foundation / AppKit。外部依存なし。
**Storage**: ローカルのファイルシステム。新しい永続データなし。
**Testing**: Swift Testing / FixtureKit、macOS CI と保守者の実機。
**Target Platform**: macOS 15 以降、Apple silicon。
**Project Type**: Swift Package のデスクトップアプリ。
**Performance Goals**: 既存の改名と同程度の応答。兄弟の確認は O(n)、子孫走査なし。画像のデコード・キャッシュは変更しない。
**Constraints**: ネットワーク API を追加せず、列挙と操作は UI スレッドで実行しない。
**Scale/Scope**: 一覧・検索結果のファイル/フォルダとツリーの通常フォルダ。大文字小文字だけの改名と競合防止。

## Constitution Check

| 原則 | Phase 0 / Phase 1 の確認 |
|---|---|
| I ローカル完結 | 適合。通信なし。改名は既存の常時確認を経由。別エントリの上書き・ゴミ箱移動を行わない。 |
| II 性能 | 適合。FileOperationService の detached task と既存 siblingNames を使う。列挙は親のみ。 |
| III キーボード | 適合。Return・既存メニュー・ラベルを維持。 |
| IV テスト | 適合する計画。Core の成功・競合・失敗をテストし、CI とローカル検証をマージ条件にする。まだ実行していない。 |
| V YAGNI | 適合。新しい依存・設定・抽象化・一時ファイル方式は追加しない。 |
| 仕様管理 | 適合。変更はこの feature に記録。product 反映は検証後、最新 master と照合して承認を得る。 |

設計前後で違反なし。承認前の実装はしない（docs_private/cloud-agent-workflow.md §全体の流れ）。

## Project Structure

### Documentation (this feature)

`spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/rename.md`, `quickstart.md`, `tasks.md`, `checklists/requirements.md`。

### Source Code (repository root)

- `Sources/FolzioCore/Operations/FileOperationService.swift`: 実行直前の兄弟列挙と自己エントリ除外。rename の競合は resolution に関わらず拒否し、コピー・移動の resolution は変更しない。
- `Sources/FolzioCore/Operations/NameValidation.swift`: existingNames が「元項目以外」を表す契約を英語で明記。比較規則は維持する。
- `Sources/FolzioApp/Operations/FileOperationCoordinator.swift`: 現在の完全一致名の除外・確認・結果通知を維持。必要があれば契約コメントだけを調整。
- `Tests/FolzioCoreTests/NameValidationTests.swift`: 元項目を除いた入力で自己の case-only を許可し、別項目を含めた入力で拒否することを分離。
- `Tests/FolzioCoreTests/FileOperationServiceTests.swift`: ファイル/フォルダ、拡張子の表記、別エントリ競合、全 resolution、実際の保存名と内容保存。
- `Tests/FolzioCoreTests/RenamedFolderTests.swift`, `SearchRenameLedgerTests.swift`: 大文字小文字だけの URL 置換を追加。UI の既存の反映経路も実機で確認。

**Structure Decision**: 既存の Core/App 分離を維持し、小さな変更を既存ファイル内で行う。

## Phase 0: Research

[research.md](research.md) に静的調査と代替案を記載。一般的な同一実体判定を改名の自己判定に流用しない。

## Phase 1: Design

[data-model.md](data-model.md) の入力・結果と [contracts/rename.md](contracts/rename.md) に従う。通常の FileManager.moveItem を使う最小変更を採る。macOS の大文字小文字を区別しないボリュームでこの経路が指定表記を保存することは未検証で、最初の成功テストを実装ゲートにする。失敗時は成功扱いや一時ファイルへの迂回を追加せず、原因を調べ設計を見直す。

親の列挙が失敗したときは空集合と見なさず systemFailure とする。改名先が別エントリなら sameNameExists を返す。大文字小文字以外が違う通常の改名では、実在する target を自己扱いしない。同じ表記は現状の no-op を維持。

## Complexity Tracking

憲章の例外なし。完全な外部競合のトランザクション制御・一時名の予約/復旧・コピー/移動の挙動変更は含めない。

## Delivery Gate

設計レビュー後に実装。Cloud の静的検査、macOS CI の build/test、両ボリュームでの実際の改名と GUI 確認を終えてから product に反映する。PR は依頼時のみ。現在の `work` は許可された push 用接頭辞に一致しないため push しない。push 段階では保守者の許可で `feature/` 等のブランチへ移す。
