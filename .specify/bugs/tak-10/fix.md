# Bug Fix: 連番の整数オーバーフロー

- **Slug**: tak-10
- **Assessment**: ./assessment.md
- **Status**: applied; review changes awaiting verification

## Summary

末尾の半角十進連番を文字列として扱い、整数の上限を越えても次の空き番号を探す。先頭ゼロは解析時に正規化する。

## Changes

| File | Change |
|---|---|
| `Sources/FolzioCore/Operations/NameValidation.swift` | 十進文字列の加算と衝突検索を実装。 |
| `Tests/FolzioCoreTests/NameValidationTests.swift` | 上限・衝突・桁上がり・先頭ゼロの回帰テストを追加。 |
| `Tests/FolzioCoreTests/FileOperationServiceTests.swift` | 複製・衝突時の保全と名前長制限の失敗を確認。 |

## Verification and deviations

検証結果は [test.md](test.md) を参照。上限時の命名が未規定だったため、`specs/TAK-10-unbounded-counters/` で仕様変更として扱った。名前長の回帰テストとコード整理はレビュー対応で追加し、macOS での実行は未確認。
