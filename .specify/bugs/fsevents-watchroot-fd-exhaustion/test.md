# Bug Verification: フォルダの監視がファイルディスクリプタを使い切り、描画中に落ちる

- **Slug**: fsevents-watchroot-fd-exhaustion
- **Tested**: 2026-10-25
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

修正後の `.app` で、ユーザーが落ちたときと同じ操作（1〜3 個のフォルダを展開し、フォルダの削除と名前の変更を繰り返し、ペインの仕切りと
ウインドウの大きさを変える）を行い、異常終了しなかった。その間のシステムログに `Too many open files` と Metal のエラーは0件で、
新しいクラッシュレポートもない。回帰テストと既存のテストはすべて通った。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | ユーザーが GUI で確認: `scripts/make-app.sh` → `open .build/MediaViewer.app`。1〜3 個のフォルダを展開し、ファイルリストでの名前の変更とツリーでのゴミ箱を繰り返し、途中でペインの仕切りとウインドウの大きさを変える | pass | ユーザーの報告:「問題ありませんでした」。このビルドは master＋修正のため、ツリーでの名前の変更（003）は含まない |
| 修正後のシステムログ | `/usr/bin/log show --last 40m --predicate 'process == "MediaViewer"'` で `Too many open files`・`readFunctionPublicOrPrivateMetadata` を数える | pass | 03:50:26〜04:05:29 の 1,645 行で 0 件 |
| 新しいクラッシュレポート | `ls -t ~/Library/Logs/DiagnosticReports/ \| grep -i mediaviewer` | pass | 修正前の `MediaViewer-2026-10-25-031405.ips` だけ |
| 開いているディスクリプタの数（GUI） | `lsof -p $(pgrep -x MediaViewer) \| wc -l` | not-run | 確認の時点でアプリは終了していた。ユーザーからも数値の報告はない。自動テストの計測で代える |
| New / updated tests | `swift test --filter FileSystemWatcher` | pass | 12 件。追加の2件は修正前に失敗（+2,145、+4,419）、修正後は基準内（増加 100 未満・150 未満） |
| Regression suite | `swift build` / `swift test` | pass | Core 506 件・性能 17 件すべて成功 |
| ネットワーク API の確認 | `scripts/check-no-network.sh` | pass | no network API references in Sources |
| 起動スモーク | `open .build/MediaViewer.app` で3ペインの表示 | pass | ユーザーの GUI の確認に含む |

## Output Excerpts

```text
✔ Test run with 17 tests in 1 suite passed after 29.929 seconds.
✔ Test run with 506 tests in 47 suites passed after 22.738 seconds.
no network API references in Sources
```

```text
# 修正後のログ（MediaViewer、2026-10-25 03:50:26〜04:05:29、1,645 行）
grep -cE "Too many open files|readFunctionPublicOrPrivateMetadata" → 0
```

## Residual Risks

- GUI でのディスクリプタの実数（`lsof`）は測っていない。自動テストの計測（同じ `FileSystemWatcher` を使い、100 フォルダで増加 100 未満）で代えている
- 検索の起点（`subtrees`）は引き続き WatchRoot を使う。起点1つで 20 程度だが、検索の起点を変え続けると、解放の遅れ（約2秒）の間は
  その分が重なる
- 監視する数そのもの（ツリーで見えている行のすべて）は変えていない。WatchRoot なしのストリームはディスクリプタを使わないため上限には
  関わらないが、FSEvents のイベントの量は従来どおり
- ソフト上限を引き上げる保険（`setrlimit`）は入れていない（fix.md の Follow-ups）

## Recommendation

Close the bug — verified end-to-end（GUI での再現の操作、修正後のログ、回帰テスト）。ソースの変更と `.specify/bugs/fsevents-watchroot-fd-exhaustion/` を
1つのコミットにして master にマージし、003 のブランチを rebase して GUI の確認を再開する。
