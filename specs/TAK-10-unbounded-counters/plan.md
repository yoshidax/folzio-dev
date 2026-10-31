# Implementation Plan: 大きな連番のファイル操作

**Branch**: `work` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)

## Summary

`uniqueName` の連番を整数ではなく半角十進文字列として正規化・加算し、末尾の数と衝突検索の双方で上限をなくす。既存の拡張子と大文字小文字を無視した衝突判定は維持する。

## Technical Context

- Swift 6 / macOS 15、外部依存なし。Core の命名ロジックと Swift Testing を使用。
- ファイル操作は既存の `FileOperationService`。変更はオフラインで、UI 操作・保存形式を増やさない。
- 計算量は連番の桁数と衝突候補数に比例し、既存のディレクトリ内候補検索の枠内で行う。

## Constitution Check

- I: 既存ファイルを変更せず、通信を追加しない。
- II: 既存の非 UI スレッドのファイル操作内で命名する。
- III: 既存の ⌘D と衝突ダイアログを維持する。
- IV: 上限と衝突、異常系に回帰テストを追加し、macOS CI で実行する。
- V: 独立した多倍長数ライブラリを導入せず、必要な加算のみを実装する。設計後も適合。

## Project Structure

- `Sources/FolzioCore/Operations/NameValidation.swift`: 文字列連番の解析と加算。
- `Tests/FolzioCoreTests/NameValidationTests.swift`: 境界と通常の命名。
- `Tests/FolzioCoreTests/FileOperationServiceTests.swift`: 既存データを保全する実操作。
- [research.md](research.md)、[data-model.md](data-model.md)、[quickstart.md](quickstart.md)、[tasks.md](tasks.md)。
