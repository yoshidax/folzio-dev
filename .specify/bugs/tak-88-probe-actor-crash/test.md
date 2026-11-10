# Bug Verification: TAK-88 確認スクリプトの reader

- **Slug**: tak-88-probe-actor-crash（fix の文脈から継続）
- **Tested**: 2026-11-09
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: partial

## Summary

修正後のスクリプトは通常モードと Swift 6 で警告なしに型検査でき、実際に使う reader のバックグラウンド実行の回帰確認も成功した。
保守者の実際の JPEG ドラッグによる再現確認はまだ行っていない。T006・T007 と Phase 2 以降は未完了のまま。

## Checks Performed

| Check | Command / Action | Result | Notes |
|---|---|---|---|
| 型検査 | `swiftc [-swift-version 6] -warnings-as-errors -typecheck` | pass | 両モード。修正案で実行し、同じ内容を適用 |
| reader の回帰確認 | `--self-test` の reader 部分のみを両モードで実行 | pass | 実際に使う makePromiseReader を OperationQueue から3回呼ぶ |
| 全自己検査 | `swift -swift-version 6 -module-cache-path /tmp/folzio-tak88-swift-cache scripts/dev/pasteboard-probe.swift --self-test` | pass | 適用後。画像2種、非圧縮 TIFF、reader の成功・受け取りエラー・情報取得エラー、MainActor 通知 |
| SIL の隔離 | `swiftc -swift-version 6 -emit-silgen` | pass | 元の reader は MainActor で入口に実行チェック。修正後は nonisolated / Sendable |
| ビルド | `swift build` | pass | 通常の sandbox 内ではキャッシュ等の権限で失敗。許可を得た再実行は成功 |
| 全体テスト | `swift test` | fail | PerformanceBaseline 27件成功、FolzioAppTests 28件成功。FolzioCoreTests の BrowserModel search が3 issues、BrowserModel が2 issues。全体成功とは扱わない |
| 失敗スイートの個別確認 | `swift test --skip-build --filter 'BrowserModel(Search)?Tests'` | pass | 97件成功。ログ `/tmp/folzio-tak88-probe-fix/model-tests.log`。全体実行時の失敗原因は未調査 |
| 規約検査 | `scripts/dev/check-all.sh` | pass | 176件の Python 検査を含め全件成功 |
| 差分 | `git diff --check` | pass | コード適用後に実行 |
| 元の GUI 再現 | JPEG をスクリプトへドロップ | not-run | 保守者へ再実行を依頼。未確認 |
| Folzio の起動スモーク | `scripts/make-app.sh` → `open .build/Folzio.app` | not-run | T006 quickstart はこの段階で確認スクリプトだけを起動すると定める。製品ソースは未変更 |

## Output Excerpts

```
OK: cat.png（中身は JPEG）, declared=public.png
OK: logo.svg（中身は PNG）, declared=public.png
OK: 非圧縮 TIFF の生成。file promise の実際の受け渡しは macOS で手動確認してください。
OK: バックグラウンド reader の成功・受け取りエラー・情報取得エラー。通知は MainActor。
```

## Residual Risks

- 回帰確認は実際の NSFilePromiseReceiver のドラッグを代替しない。
- 全体テストの失敗は、個別実行で再現しなかったが原因や変更前との比較は未調査。今回のスクリプトは製品テストから読み込まれず、製品ソース・テストは変更していない。
- GUI が確認されるまで修正完了や T006 の完了を宣言しない。

## Recommendation

保守者に同じ JPEG のドロップを再確認してもらい、readerCount・書き出された名前と容量・秒数・fileNames(after) のログを取得する。
その後、T006 の残りのアプリと形式を確認する。Phase 2 へは進まない。

## 追確認（2026-11-09 16:36 JST）

- 保守者が Safari の JPEG をドロップし、「落ちませんでした」と報告。
- ログで `readerCount=1`、`readerMainThread=false`、約束の `fileTypes=[public.jpeg]` を確認。元の actor 隔離違反のクラッシュはこの操作では再現しなかった。
- JPEG データは872744 bytes、UI スレッドの読み出し0.001321秒。マスクは1（copy）。
- 約束の書き出しは0.038413秒で `NSCocoaErrorDomain Code=3072`（キャンセル）。fileNames は空で、ファイル名・容量は取得できていない。
- 判定は引き続き partial。コールバックまで落ちずに進むことは確認したが、受け渡しの成功は未確認。自己ドラッグの約束と Safari の再試行で切り分ける。
- ログの複製: `/tmp/folzio-tak88-probe-fix/safari-jpeg-drag-20261109-1636.log`。
