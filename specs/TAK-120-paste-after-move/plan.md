# Implementation Plan: コピー元を移動した後もペーストできるようにする

**Branch**: `claude/tender-carson-4e5op3` | **Date**: 2026-11-20 | **Spec**: [spec.md](spec.md)

**Input**: [TAK-120](https://linear.app/takyoshida/issue/TAK-120/) と現行の file-operations.md・directory-tree.md

## Summary

Folzio がクリップボードに書いた、またはペーストで読んだファイルの並びと、そのときのクリップボードの版（`changeCount`）を
メモリに覚える。Folzio が移動・名前の変更を終えたら、クリップボードの版が覚えたときのままなら、覚えたファイルの並びを
移動後の場所へ付け替えて書き直す。付け替えと判断は `FolzioCore` の `ClipboardFileRecord` に置き、既存の
`RenamedFolder`（フォルダの名前の変更で URL を付け替える型）を使う。クリップボードの中身は、従来どおりペーストの実行時だけ読む。

## Technical Context

**Language/Version**: Swift 6（CI は Xcode 16.0）

**Primary Dependencies**: AppKit（`NSPasteboard`）、FolzioCore。追加依存なし

**Storage**: なし（メモリだけ。A-249）

**Testing**: Swift Testing（FolzioCoreTests の `ClipboardFileRecordTests`、FolzioAppTests の `ClipboardRelocationTests`）、
保守者の GUI 起動確認（Finder でのペーストを含む）

**Target Platform**: macOS 15 以降の既存ターゲット

**Project Type**: デスクトップアプリ

**Performance Goals**: 移動・名前の変更の後に、覚えた URL の数だけパスを比べる（ファイルシステムにアクセスしない）

**Constraints**: オフライン。判断ロジックは AppKit を import しない `FolzioCore` に置く。UI スレッドでファイル操作をしない。
クリップボードの中身はペーストの実行時だけ読む（FR-354）

**Scale/Scope**: 書き換えの契機は、移動（`transfer` の `.move`）と名前の変更（`rename`）の2か所。記録の契機は、
コピー（ファイルリスト・ツリー）とペースト・移動ペースト

## Constitution Check

| 原則 | 設計上の確認 |
|---|---|
| I ローカル完結 | 外部通信を追加しない。ファイルは変更せず、クリップボードの file URL だけを書き換える。 |
| II 体感パフォーマンス | 書き換えはパスの比較だけで、UI スレッドでファイルシステムにアクセスしない（R3）。 |
| III キーボードとアクセシビリティ | ショートカットとメニューは変えない。⌘C → ⌥⌘V → ⌘V のキーボードの流れが続けられるようになる。 |
| IV テスト | 付け替えと版の判断を `FolzioCore` に置いて単体テストで全分岐を確かめ、移動・名前の変更・ペーストからの書き換えを App のテストで確かめる。 |
| V シンプルさ | 新しい設定を足さない。既存の `RenamedFolder` を再利用し、記録は `PasteboardFileURLs` の1か所に置く。 |

**Post-design**: 上記を満たす。Complexity Tracking に記録する違反はない。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-120-paste-after-move/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/requirements.md
└── tasks.md
```

設定のキー・文言・ショートカットの変更はないため、contracts/ は作らない。

### Source Code (repository root)

```text
Sources/FolzioCore/
└── Model/ClipboardFileRecord.swift          # 新規。覚えたファイルの並びと版、移動後の並びの計算
Sources/FolzioApp/
├── Shared/PasteboardFileURLs.swift          # 書いたとき・ペーストで読んだときに記録し、移動の後に書き直す
└── Operations/FileOperationCoordinator.swift # ペーストで記録する。移動・名前の変更の後に書き直す。transferItems が移動の対応を返す
Tests/FolzioCoreTests/
└── ClipboardFileRecordTests.swift           # 新規
Tests/FolzioAppTests/
├── ClipboardRelocationTests.swift           # 新規。移動ペースト・ドロップ・名前の変更・中止・別のアプリの変更
└── FileTransferCancellationTests.swift      # transferItems の戻り値の変更に追従
docs/usage.md・docs/usage.ja.md               # 移動の後もペーストできることを書く
```

**Structure Decision**: 既存の2ターゲット（FolzioCore・FolzioApp）の構成のまま、上記のファイルだけを変える。

## Complexity Tracking

なし。
