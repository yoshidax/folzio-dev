# Bug Fix: Swift 6.0〜6.2 のツールチェーンで FolzioCore がビルドできない

- **Slug**: swift-6x-typed-throws-closure
- **Fixed**: 2026-10-30
- **Assessment**: ./assessment.md
- **Status**: applied（ビルドとテストの確認は CI が必要。「Local Verification」を参照）
- **Issue**: [TAK-28](https://linear.app/takyoshida/issue/TAK-28)

## Summary

`ArchiveEntryStream` の 2 か所で、`Data.withUnsafeMutableBytes` に型付き throws のクロージャを直接渡していた。
クロージャの外へエラーを取り出して投げ直す補助関数 `withMutableBytes(of:_:)` を足し、2 か所をそれに置き換えた。
クロージャの本体（読み込みのループ）は変えていない。あわせて、CI の Xcode を、宣言している最小の版（Xcode 16.0 / Swift 6.0）に固定した。

## Changes

| File | Change | Notes |
|------|--------|-------|
| `Sources/FolzioCore/Archive/ArchiveEntryStream.swift` | modified | `private static func withMutableBytes(of:_:)` を追加。`readStored` と `chunk(at:)` の `withUnsafeMutableBytes` の呼び出しを置き換えた |
| `Tests/FolzioCoreTests/ArchiveEntryStreamTests.swift` | added tests | zip を開いた後に切り詰めたときの `ArchiveError` の伝播を固定する 2 件 |
| `.github/workflows/macos-swift-ci.yml` | modified | `XCODE_VERSION` を `"26.3"` から `"16.0"` へ（最小の版でのビルドを確認するため） |

## Diff Highlights (optional)

```swift
private static func withMutableBytes(
    of data: inout Data,
    _ body: (UnsafeMutableRawBufferPointer) throws(ArchiveError) -> Void
) throws(ArchiveError) {
    var failure: ArchiveError?
    data.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) -> Void in
        do throws(ArchiveError) {
            try body(buffer)
        } catch {
            failure = error
        }
    }
    if let failure { throw failure }
}
```

## Tests Added or Updated

- `ArchiveEntryStreamTests.swift::truncatedZipThrows` — stored と deflated の両方で、zip を開いた後に 1000 バイトへ切り詰めると、
  `read` が `ArchiveError` を投げる
- `ArchiveEntryStreamTests.swift::truncatedStoredEntry` — stored の項目では、エラーが `.corrupted(.dataTruncated)` になる
  （補助関数がエラーを取りこぼさず、同じ値で投げ直すことを固定する）

不具合そのもの（特定のツールチェーンでコンパイルできない）の回帰は、CI のビルドで固定する。

## Local Verification

- この環境（クラウド）には Swift がなく、`swift build`・`swift test` は**実行できていない**。コンパイルの確認は CI で行う
- 実行した検査:
  - `scripts/check-no-network.sh` → 通過
  - `scripts/dev/check-english-comments.sh` → 通過
  - `scripts/check-readme-sync.sh master` → 通過
- 手動の確認: なし（GUI は未起動）

## Deviations from Assessment

- 追加のテストは 2 件。assessment では「既存のテストの確認、なければ足す」としていた。既存のテストに、読み込み中の切り詰めを扱うものがなかった
- 変更したファイルに `.github/workflows/macos-swift-ci.yml` を加えた。assessment の「Files likely to change」にはなかったが、
  最小の版で確認するという、ユーザーの判断（CI は Xcode 16.0 のみ）を反映するために必要
- ワークフローの `synchronize`（一時的な trigger）は、このコミットでは外していない。CI での確認が通るまで、修正のたびに再実行する必要があるため

## Follow-ups

- CI が通ったら、`synchronize` を外す（TAK-25 の取り決め）
- CI で別のモジュールの互換性のエラーが見つかった場合は、同じ bug の範囲で直すか、assessment をやり直す
- `docs/development.md` ほかの「6.0 以上」は、Xcode 16.0 でのビルドが通ってから、正しいと確認できる
