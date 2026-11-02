# Implementation Plan: リスト形式の列の表示・非表示

**Branch**: `claude/jolly-ptolemy-1b91ys` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: [TAK-47](https://linear.app/takyoshida/issue/TAK-47/)

## Summary

列見出しの右クリックで、ファイル名・作成日・種類・サイズ・変更日の表示・非表示を選べるようにし、結果を `SettingsStore` に保存する。
サイズ・変更日の列を足し、並べ替え（列見出しのクリックと「表示 > 並べ替え」メニュー）を対応させる。
判断ロジック（列の集合・保存形式・並べ替えの比較）は `FolzioCore`、描画とメニューは `FolzioApp`、文言は `FolzioLocalization` に置く。

## Technical Context

**Language/Version**: Swift 6 / AppKit のみ / 外部依存なし（Swift Package）
**Storage**: `UserDefaults`（`SettingsStore`）
**Testing**: Swift Testing（`Tests/FolzioCoreTests`）。Cloud では CI で実行する
**Target Platform**: macOS 15 以降
**Performance Goals**: 列の切り替えは再読み込みなしで即時。`DirectoryLister` の読み取りキーを 1 つ足すだけで、10,000 ファイルの一覧の応答を損なわない
**Constraints**: ネットワーク API なし。UI スレッドで列挙しない。`NSSplitViewDelegate` の禁止メソッドに触れない

## Constitution Check

| 原則 | 判定 |
|---|---|
| I ローカル完結 | 通信なし。ファイルを変更しない — OK |
| II 体感パフォーマンス | 取得は既存の列挙で 1 キー追加のみ — OK |
| III キーボード/アクセシビリティ | ポップアップは `NSMenu` で、項目に名前を持つ。列の表示・非表示は設定でも到達可能にはしない（右クリックのみ、Finder と同じ）。Ctrl+クリックも `NSTableHeaderView.menu` で同じメニューになる — OK（A-158） |
| IV テスト | Core に列の設定・並べ替え・書式のテストを付ける — OK |
| V YAGNI | 列幅・列順の保存は範囲外 — OK |

設計後の再評価: 違反なし。

## Project Structure

```text
specs/TAK-47-list-column-visibility/
├── spec.md / plan.md / research.md / data-model.md / quickstart.md / tasks.md
Sources/
├── FolzioCore/
│   ├── Model/MediaFile.swift            # modificationDate を追加
│   ├── Model/Settings.swift             # SortColumn に size / modificationDate、ListColumn と ListColumnVisibility を追加
│   ├── Model/Sorting.swift              # サイズ・変更日の比較（値なしは末尾）
│   ├── FileSystem/DirectoryLister.swift # contentModificationDateKey を読む
│   ├── Archive/ArchiveIndex.swift       # entry の更新日時を modificationDate に渡す
│   └── Settings/SettingsStore.swift     # 列の表示状態の保存・復元
├── FolzioLocalization/TextKey.swift     # 列名（サイズ・変更日）と、ポップアップ・並べ替えの文言
└── FolzioApp/FileList/ListModeView.swift# 列の追加、ヘッダーのメニュー、セルの表示、並べ替えメニュー
Tests/FolzioCoreTests/                   # 並べ替え・設定・Lister・ArchiveIndex
```

**Structure Decision**: 既存の 3 モジュール構成のまま。新しいファイルは、列の集合の型だけ `Model/` に 1 つ足してもよい（`ListColumn.swift`）。

## 設計の要点

1. `ListColumn`（name / creationDate / kind / size / modificationDate）と、表示集合 `ListColumnVisibility`（name は常に含む）を Core に置く。既定は name・creationDate・kind。
2. `ViewSettings` に `visibleColumns` を持たせ、`SettingsStore` が `view.list.visibleColumns`（列名の文字列配列）で保存する。壊れた値・未知の名前は無視し、空や欠落は既定へ（name は常に補う）。
3. `MediaFile` に `modificationDate: Date?` を追加（既定 nil）。`DirectoryLister` は `contentModificationDateKey` を読む。zip の項目は既存の `creationDate` と同じ entry の更新日時を渡す。フォルダ行の更新日時も取得する。
4. `SortColumn` に `size` / `modificationDate` を追加。比較は、値なしを昇順・降順とも末尾に置き（作成日と同じ規則を日付とサイズに一般化）、同値は名前の自然順。フォルダと `fileSize` が意味を持たない行は「サイズなし」とする。
5. `ListModeView`: 5 列を作り、`visibleColumns` と検索中の場所列で `isHidden` を設定する。`NSTableHeaderView.menu` に「ファイル名/作成日/種類/サイズ/変更日」のチェック付き項目を持つ `NSMenu` を付け、`menuNeedsUpdate` でチェックを更新する。ファイル名は `isEnabled = false`。
6. サイズは `ByteCountFormatter`（file style）で表示。フォルダ・取得不能は `--`。表示言語の切り替え時に列名とセルを更新する（既存の `displayLanguageDidChange` に追加）。
7. 設定は `BrowserModel` 経由の既存の保存経路（表示設定の変更時に保存）に乗せる。実装時に保存経路を確認する。
