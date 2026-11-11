# Implementation Plan: TAK-97

**Branch**: `feature/tak-97-open-with-application` | **Date**: 2026-11-11 | **Spec**: [spec.md](spec.md)

## Summary

単一の実ファイルかどうかは `ListItemCommands` で判定する。選択された行の種類と実 URL は
`FileListViewController` が確認する。サブメニューの候補は開く直前に
`NSWorkspace.urlsForApplications(toOpen:)` から取得し、選んだアプリケーションには
`NSWorkspace.open(_:withApplicationAt:configuration:completionHandler:)` でファイルを渡す。

候補はファイルの拡張子に対する macOS の関連付けに従う。選択が変わった後の古いメニュー項目は
実行時に対象 URL を再確認して拒否する。失敗は対象ウインドウのシートで示す。

## Verification

- Core の判定テストで、メディア、zip ファイル、複数選択、フォルダ、zip 内を確認する。
- `scripts/dev/check-all.sh` で静的検査を実行する。
- macOS の CI で `swift build` と `swift test` を確認する。
- 保守者の macOS で実際の関連アプリの一覧と起動、候補なし、失敗時の表示を確認する。
