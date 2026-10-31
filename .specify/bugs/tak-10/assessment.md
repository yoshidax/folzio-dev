# Bug Assessment: 連番の整数オーバーフロー

- **Slug**: tak-10
- **Created**: 2026-11-01
- **Source**: [TAK-10](https://linear.app/takyoshida/issue/TAK-10/連番が-intmax-のファイルを複製すると整数オーバーフローでクラッシュする)
- **Verdict**: likely valid, needs reproduction
- **Severity**: medium

## Report

`photo 9223372036854775807.jpg` の複製が整数オーバーフローで終了するというレビュー報告。コピー・移動の「両方残す」も同じ命名関数を使う。

## Symptom

末尾の連番が `Int.max` のファイルを複製するとクラッシュする可能性がある。クラッシュせず、既存ファイルを変更しないことが期待される。

## 仕様との照合

- FR-018 は複製に空いている連番を使い、既存ファイルを変更しないことを要求する。クラッシュにより複製できないことはこの要求に反する。
- FR-025 の「両方残す」も関連する。ただし、整数上限を超えるときの具体的な命名規則は定めていない。上限時の規則は仕様変更として決めてから実装する。

## Reproduction

1. `photo 9223372036854775807.jpg` を用意する（64-bit 環境）。
2. ファイルを選んで ⌘D で複製する。
3. クラッシュの有無と既存ファイルを確認する。

このセッションでは実行再現していない。元の報告では検証プログラムの異常終了が確認された。

## Suspected Code Paths

- `Sources/FolzioCore/Operations/NameValidation.swift:53` — `uniqueName` は末尾の数値に 1 を加え、衝突時も加算する。
- `Sources/FolzioCore/Operations/NameValidation.swift:77` — `trailingCounter` は `Int.max` を `Int` として受理する。
- `Sources/FolzioApp/Operations/FileOperationCoordinator.swift:42`、`Sources/FolzioCore/Operations/FileOperationService.swift:198` — 複製と衝突解決から命名処理へ到達する。

## Root Cause Hypothesis

確信度: 高。`match.number + 1` は `Int.max` でオーバーフローする。また、初期値が `Int.max - 1` で `Int.max` の候補が既に存在する場合も、ループ内の `counter += 1` がオーバーフローする。

## Proposed Remediation

**Preferred**: 上限を持たない十進文字列として連番を進める規則を仕様として定め、両方の加算箇所でオーバーフローを避ける。たとえば `photo 9223372036854775807.jpg` の次を `photo 9223372036854775808.jpg` とする。既存の衝突回避と拡張子の扱いを保つ。

**Files likely to change**: `Sources/FolzioCore/Operations/NameValidation.swift`、`Tests/FolzioCoreTests/NameValidationTests.swift`、必要に応じて操作サービスのテスト。

**Tests to add**: `Int.max` の入力、`Int.max - 1` から衝突して上限を越える場合、上限を超える既存の連番、衝突時の既存ファイル保全と通常の命名。

## Risks & Considerations

- 上限を超える数字を連番として扱うと、現行の `Int` に変換できない末尾数字の扱いが変わる。仕様で明確化する。
- ファイルシステムの名前の長さ制限に達した場合は別途操作エラーになり得る。
- macOS GUI と Swift の実行検証はこの環境では未実施。

## Open Questions

- 上限を超えた連番を十進文字列として続ける案を採用するか。
