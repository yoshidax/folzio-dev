# Implementation Plan: コピー元を移動した後もペーストできるようにする

**Branch**: `claude/tender-carson-4e5op3` | **Date**: 2026-11-20 | **Spec**: [spec.md](spec.md)

**Input**: [TAK-120](https://linear.app/takyoshida/issue/TAK-120/) と現行の file-operations.md

## Summary

Finder と同じく、Folzio のコピーで各項目のファイルの参照（`file:///.file/id=…`）とファイル名の文字列をクリップボードに置く。
ペーストのときに参照を今の場所に解決してから、既存のコピー・移動に渡す。クリップボードは後から書き換えない。
参照の作成と解決は Foundation（CoreFoundation の `CFURLCreateFileReferenceURL`・`CFURLCreateFilePathURL`）だけで行えるため、
`FolzioCore` の `ClipboardFileReferences` に置き、UI スレッドの外で呼ぶ。`FolzioApp` の `PasteboardFileURLs` は、
クリップボードの項目の読み書きだけを受け持つ。

## Technical Context

**Language/Version**: Swift 6（CI は Xcode 16.0）

**Primary Dependencies**: Foundation・CoreFoundation（FolzioCore）、AppKit の `NSPasteboard`・`NSPasteboardItem`（FolzioApp）。追加依存なし

**Storage**: なし

**Testing**: Swift Testing（FolzioCoreTests の `ClipboardFileReferencesTests`、FolzioAppTests の `PasteboardFileURLsTests` の追加と
`ClipboardPasteTests`）、保守者の GUI 起動確認（Finder・テキストエディタとの受け渡し、ゴミ箱、別のボリューム）

**Target Platform**: macOS 15 以降の既存ターゲット

**Project Type**: デスクトップアプリ

**Performance Goals**: コピーとペーストで、項目ごとに1回のファイルシステムの問い合わせ（参照の作成・解決）を UI スレッドの外で行う

**Constraints**: オフライン。判断ロジックは AppKit を import しない `FolzioCore` に置く。UI スレッドでファイル操作をしない。
クリップボードの中身はペーストの実行時だけ読む（FR-354）

**Scale/Scope**: コピーの入口2つ（ファイルリスト・ツリー）、ペーストの入口1つ（`FileOperationCoordinator.paste`）

## Constitution Check

| 原則 | 設計上の確認 |
|---|---|
| I ローカル完結 | 外部通信を追加しない。ゴミ箱からの移動ペーストも、利用者の明示的な操作と、既存の移動の確認（FR-024）に従う。 |
| II 体感パフォーマンス | 参照の作成と解決は `Task.detached` で UI スレッドの外で行う（R3）。 |
| III キーボードとアクセシビリティ | ショートカットとメニューは変えない。⌘C → ⌥⌘V → ⌘V のキーボードの流れが続けられるようになる。 |
| IV テスト | 参照の作成・解決（移動・名前の変更・削除・パスの file URL）を `FolzioCore` で単体テストし、クリップボードの読み書きとペーストを App のテストで確かめる。異常系（見つからない項目・解決できない参照）を含む。 |
| V シンプルさ | 新しい設定を足さない。クリップボードの状態を覚えず、書き換えもしない。 |

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
└── Operations/ClipboardFileReferences.swift  # 新規。項目の参照の作成と、今の場所への解決
Sources/FolzioApp/
├── Shared/PasteboardFileURLs.swift          # 参照とファイル名の項目を書く・読む。版が変わっていたら書かない
├── FileList/FileListViewController.swift    # copy(_:) を、参照を UI スレッドの外で用意してから書く形に
├── Tree/DirectoryTreeViewController.swift   # copyFolders(_:to:) を同じ形に
└── Operations/FileOperationCoordinator.swift # paste で項目を読み、解決してからコピー・移動。解決できない項目を失敗に含める
Tests/FolzioCoreTests/
└── ClipboardFileReferencesTests.swift       # 新規
Tests/FolzioAppTests/
├── ExternalDragTests.swift                  # PasteboardFileURLsTests に、参照とファイル名の書き込み・読み取りを追加
└── ClipboardPasteTests.swift                # 新規。コピー → 移動・名前の変更 → ペースト、解決できない参照
docs/usage.md・docs/usage.ja.md               # 移動の後もペーストできることを書く
```

**Structure Decision**: 既存の2ターゲット（FolzioCore・FolzioApp）の構成のまま、上記のファイルだけを変える。
ドラッグ（`InternalDrag`・`ExternalDrag`）の読み取りは変えない（R5）。

## Complexity Tracking

なし。
