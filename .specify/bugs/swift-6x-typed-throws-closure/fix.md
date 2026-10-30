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
| `Sources/FolzioApp/Preview/VideoPreviewView.swift` | modified | `[AVAssetTrack]` が Swift 6.0 の SDK で `Sendable` でないため、トラックの有無を `Bool?` にする処理を `nonisolated` の補助関数 `loadHasVideoTrack(of:)` に出した（PR の CI で見つかった） |
| `Sources/FolzioApp/App/MainToolbarController.swift` | modified | `NSToolbar.isVisible` が Swift 6.0 の SDK で `@MainActor` のため、KVO の通知の `change.newValue` を使うようにした（PR の CI で見つかった） |
| `Sources/FixtureKit/ZipFixtureWriter.swift` | modified | `dosDateTime` の長い式が Swift 6.0 のコンパイラで「型の検査に時間がかかりすぎる」エラーになったため、型を付けた部分式に分けた（値は同じ。2 回目の CI で見つかった） |
| `Tests/FolzioPerformanceTests/PerformanceBaselineTests.swift` | modified | `mach_task_self_`（グローバルの変数）が Swift 6.0 の並行性の検査で拒否されるため、`task_self_trap()` に置き換えた（3 回目の CI で見つかった。`swift build` は通り、`swift test` のコンパイルで出た）。最初に試した `mach_task_self()` は C のマクロで Swift から使えず、4 回目の CI で失敗した |
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

- この環境（クラウド）には Swift がなく、`swift build`・`swift test` は手元では実行できない。確認は PR #3 の CI（macOS 15 / Xcode 16.0 / Swift 6.0）で行った
- CI の結果（run 41102143791、コミット `867c0e6`）:
  - `swift build` → 成功
  - `swift test --no-parallel --skip FolzioPerformanceTests` → 成功
  - `swift test --filter FolzioPerformanceTests` → 27 件すべて成功（91 秒）
- Swift 6.1・6.2・6.4 でのビルドは、CI では確認していない。ローカル（Swift 6.4）での `swift build`・`swift test` は、ユーザーの確認が必要
- 実行した検査:
  - `scripts/check-no-network.sh` → 通過
  - `scripts/dev/check-english-comments.sh` → 通過
  - `scripts/check-readme-sync.sh master` → 通過
- 手動の確認: なし（GUI は未起動）

## Deviations from Assessment

- 追加のテストは 2 件。assessment では「既存のテストの確認、なければ足す」としていた。既存のテストに、読み込み中の切り詰めを扱うものがなかった
- 変更したファイルに `.github/workflows/macos-swift-ci.yml` を加えた。assessment の「Files likely to change」にはなかったが、
  最小の版で確認するという、ユーザーの判断（CI は Xcode 16.0 のみ）を反映するために必要
- PR #3 の最初の CI（Xcode 16.0 / Swift 6.0.0）で、`FolzioCore` は通り、`FolzioApp` の 2 か所で別の互換性のエラーが見つかった
  （assessment の Risks で想定していたもの）。同じ「宣言している最小の版でビルドできない」不具合の範囲として、このコミットで直した。
  どちらも挙動を変えない書き換え（`MainToolbarController` の値の取り方は、`.new` の通知の値を使う形になる）
- ワークフローの `synchronize`（一時的な trigger）は、このコミットでは外していない。CI での確認が通るまで、修正のたびに再実行する必要があるため

## Follow-ups

- テストを並列で実行すると、3 コアのランナーで 10 分以上進まなくなった（CI の `swift test --skip FolzioPerformanceTests`。ログに
  `IOServiceMatching failed for: AppleM2ScalerParavirtDriver` が出ていた）。CI は `--no-parallel` で通るようにした。
  並列で止まる原因は未調査で、別の Issue として扱う
- ワークフローに、テストのステップごとの `timeout-minutes: 10` を足した（止まったテストがランナーを占有しないようにするため）
- 一時的な `synchronize` の trigger は外した。以後の push では CI が自動で動かないので、再確認は `workflow_dispatch` で行う
- `docs/development.md` ほかの「6.0 以上」は、Xcode 16.0（Swift 6.0）でのビルドとテストが通ったので、正しいと確認できた
- Swift 6.4 のローカル環境での確認（`swift build`・`swift test`・起動スモーク）は未実施。特に、ツールバーの表示・非表示の切り替え
  （`MainToolbarController`）と、動画プレビューのトラック判定（`VideoPreviewView`）に触れている
