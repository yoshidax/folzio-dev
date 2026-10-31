# Bug Verification: Swift 6.0〜6.2 のツールチェーンで FolzioCore がビルドできない

- **Slug**: swift-6x-typed-throws-closure
- **Tested**: 2026-10-30
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified（Swift 6.0 は CI で、Swift 6.4 はユーザーの報告で確認。Swift 6.1・6.2 は未確認）
- **Issue**: [TAK-28](https://linear.app/takyoshida/issue/TAK-28)

## Summary

宣言している最小の版（Swift 6.0、Xcode 16.0）で、`swift build`・`swift test`（性能テストを含む）が CI で成功した。
ローカル（Swift 6.4）での `swift build`・`swift test`・起動スモークは、ユーザーが「確認は全て終了」と報告した。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | CI（macOS 15 / Xcode 16.0 / Swift 6.0）の `swift build` | pass | 元のエラー（`ArchiveEntryStream.swift:51`・`:97`）は出ない。ただし、元の失敗を確認した Swift 6.1.2・6.2.4 では、修正後に実行していない |
| 同じ版でのビルドの全体 | 同上 | pass | 修正の途中で見つかった別の互換性のエラー（`FolzioApp` 2 か所、`FixtureKit` 1 か所、テストターゲット 1 か所）も解消した |
| New / updated tests | CI の `swift test --no-parallel --skip FolzioPerformanceTests` | pass | 追加した 2 件（`truncatedZipThrows`、`truncatedStoredEntry`）を含む |
| Regression suite | CI の `swift test --filter FolzioPerformanceTests`（失敗を許容するステップ） | pass | 27 件すべて成功（91 秒）。許容に頼らずに通った |
| 並列でのテスト実行 | CI の `swift test --skip FolzioPerformanceTests`（`--no-parallel` なし） | fail | 3 コアのランナーで 10 分以上進まず、タイムアウトした。`--no-parallel` で通る。原因は未調査（`fix.md` の Follow-ups） |
| ネットワーク API の確認 | `scripts/check-no-network.sh` | pass | クラウド環境で実行 |
| コメントの英語 | `scripts/dev/check-english-comments.sh` | pass | クラウド環境で実行 |
| README の同期 | `scripts/check-readme-sync.sh master` | pass | クラウド環境で実行 |
| ローカル（Swift 6.4）のビルドとテスト | ユーザーが `swift build`・`swift test` を実行 | pass（ユーザーの報告） | 結果の詳細（件数など）の報告はない |
| 起動スモーク | ユーザーが `scripts/make-app.sh`・`open .build/Folzio.app` を実行 | pass（ユーザーの報告） | ツールバーの表示・非表示と動画のプレビューを確認するよう依頼した。個々の項目の報告はない |

## Output Excerpts

```text
# CI（run 41102143791、コミット 867c0e6、Xcode 16.0 / Swift 6.0.0）
Apple Swift version 6.0 (swiftlang-6.0.0.9.10 clang-1600.0.26.2)
Build complete! (13.58s)
✔ Test run with 27 tests passed after 91.363 seconds.   # 性能テスト
```

## Residual Risks

- Swift 6.1.2・6.2.4 では、修正後のビルドを確認していない。元の失敗を確認した版なので、念のため確認したい。
  CI の `XCODE_VERSION` を変えて `workflow_dispatch` で実行すれば確認できる
- テストの並列実行は、3 コアのランナーでは進まなくなる。CI では直列にしているだけで、並列で止まる原因は未調査
- ローカルの確認は、ユーザーの報告に詳細がない。ツールバーの表示・非表示と動画のプレビューを、どの操作で確認したかの記録はない
- CI は PR の作成時と Ready にしたときだけ自動で動く。以後の push の確認には、手動の実行が要る

## Recommendation

マージしてよい。Swift 6.1.2・6.2.4 での確認は、必要なら、マージ後でも `workflow_dispatch` で行える。
並列テストが止まる問題は、別の Issue として追う。

## 訂正（2026-10-31）

この記録は、最新の版（Swift 6.4）での確認を、保守者の「確認は全て終了」という報告に基づいて「pass（ユーザーの報告）」とし、Result を `verified` としていた。
その後、保守者の `swift build`（macOS SDK 27.2）が `VideoPreviewView.swift` で失敗することが分かった。TAK-28 で足した補助関数 `loadHasVideoTrack(of:)` が原因の回帰で、
[TAK-31](https://linear.app/takyoshida/issue/TAK-31) で直した（`.specify/bugs/video-track-sendable-regression/`）。

この記録の Swift 6.0（CI）の結果は正しい。一方、最新の版については、**実行したコマンドと出力の報告を受け取らずに**、「確認は全て終了」という一言を根拠に `verified` とした。これが、回帰を見逃した原因である（保守者の確認の内容は、この記録からは分からない）。
以後、保守者のローカルでの確認は、実行したコマンドと結果（成功、またはエラーの行）の報告を受けてから、記録する。
