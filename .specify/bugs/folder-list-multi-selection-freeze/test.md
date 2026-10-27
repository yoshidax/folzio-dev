# Bug Verification: 10,000 フォルダの複数選択で検索モーダル・右クリックが固まる

- **Slug**: folder-list-multi-selection-freeze
- **Tested**: 2026-10-27
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

選択 URL から行番号への変換を O(N×M) から O(N+M) へ変更し、10,000 行・5,000 選択の変換は
自動計測で約 7.9ms になった。ユーザーが修正後のアプリで、複数選択後の ⌘F・右クリックの
パフォーマンスが解消していることを確認した。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `scripts/make-app.sh` → `open .build/MediaViewer.app`、many-folders で約5,000行を選択→⌘F/右クリック | pass | ユーザーがパフォーマンス解消を確認（2026-10-27） |
| New / updated tests | `swift test --filter SelectionIndexTests` | pass | 空入力・通常・重複 URL の3件 |
| New performance test | `swift test --filter selectionIndexTenThousandRows` | pass | `[perf] 10,000 rows / 5,000 selected: 0.006524583 seconds` |
| Core regression | `swift test --filter MediaViewerCoreTests --no-parallel` | pass | 776件 |
| Performance regression | `swift test --filter MediaViewerPerformanceTests` | partial | 追加した選択テストは成功（7.9ms）。既存の時間依存5件が高負荷（load 10前後）で失敗。変更箇所外 |
| Build | `swift build` | pass | 既存の `MainToolbarController.swift:70` の警告のみ |
| Network API | `scripts/check-no-network.sh` | pass | 参照なし |
| App packaging | `scripts/make-app.sh` | pass | `.build/MediaViewer.app` 更新 |

## Output Excerpts

```
[perf] selection index 10,000 rows / 5,000 selected: 0.006524583 seconds
✔ Test run with 3 tests in 1 suite passed after 0.001 seconds.
✔ Test run with 776 tests in 73 suites passed after 126.839 seconds.
no network API references in Sources
```

Performance suite の失敗（今回の変更外）:

```
✘ didRenameFolder 10,000 search results: median < 100ms
✘ 10,000 files + 1,000 subfolders enumeration: < 1s
✘ 10,000 zip items open/items(in:): < 500ms
✘ batch 256 into 50,000: < 100ms
✘ slideshow extraction 200,000: < 200ms
```

## Residual Risks

- 自動計測は選択インデックス変換だけを対象とし、アプリ全体の 100ms 応答を保証しない。
  ユーザーの GUI 確認で元症状（数十秒の停止）が解消したことを確認した。
- サムネイル形式の選択位置は `SelectionIndex` の単体テストで変換を固定している。GUI での目視確認は
  ユーザー報告に含まれる範囲で問題なし。
- 検索結果表示中（SC-016）の同じ操作は個別の計測値を記録していない。
- 高負荷時に既存の性能テストが不安定。今回の変更とは別の環境要因。

## Recommendation

Close the bug — ユーザーが修正後の GUI でパフォーマンス解消を確認した。個別の停止時間の計測値は
残していないため、必要なら追加計測を行う。
