# Bug Verification: Codex workflow の手動確認による停止

- **Slug**: codex-manual-gates（fix の文脈から継承）
- **Tested**: 2026-10-27
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

実 Spec Kit 1.2.2・偽 Codex・PTY による自動再現で、レビュー承認の引継ぎと、Phase途中の2回の手動確認を経た同一runの完了を確認した。自動検証はすべて成功し、2026-10-27にユーザーから3ペイン表示成功と macOS 26.6.2（25G83）の報告を受領した。AGENTS.md の起動スモークも通過。実run 356c45b4 の実装は進めていない。

## Checks Performed

| Check | Command / Action | Result | Notes |
|---|---|---|---|
| 元の停止の自動再現 | 実Spec Kit・偽Codex・PTY | pass | do-while 内で手動要求→報告→同じimplement再開を2回実施。確認前に後続を進めない |
| レビュー承認 | review_gate の端末approve→design_review要求 | pass | 保存済みapproveで設計レビューだけを記録。GUIは空行で未確認のまま停止 |
| 異常系 | 不明ID、分類変更、自己承認、失敗プロセス、stale要求、旧run等 | pass | 実失敗は75へ置換しない。タスク/アプリ変更後の要求を拒否、再生成可能 |
| workflow回帰 | `python3 -m unittest discover -s scripts/tests -v` | pass | 28 tests / 15.704s |
| workflow登録 | `specify workflow add --dev .specify/workflow-src/sdd-increment-codex.yml` | pass | v0.3.0、生成物とソースは一致 |
| Phase gate 1 | `swift build` | pass | 初回は標準Clangキャッシュへのsandbox書込み拒否。正規の承認付き再実行で成功 |
| Phase gate 2 | `swift test` | pass | 753 tests / 69 suites / 35.196s |
| Phase gate 3 | `scripts/check-no-network.sh` | pass | exit 0 |
| Phase gate 4a | `scripts/make-app.sh` | pass | exit 0 |
| Phase gate 4b | ユーザーによるapp起動・3ペイン目視 | pass | 2026-10-27受領、macOS 26.6.2（25G83）で3ペイン表示成功 |
| 差分 | `git diff --check` / 作業ツリーとのバイト比較 | pass | 8変更ファイル一致。spec 010進捗・実runの状態は保持 |

## Environment / Evidence

- macOS 26.6.2 / arm64 / Apple Swift 6.4。
- worktree: `/private/tmp/my-img-viewer-codex-manual-gates`、clean master `a0b6232` 基点の `bugfix/codex-manual-gates`。
- 成功ログ（元worktreeから現在のリポジトリへ退避）: `.specify/workflows/runs/attempts/7a08d2c47f2f463a9eb1bb8bb3edddc4/verify-ae3e7f8e56294bda8b2399e4ec0f9d28/`。result.jsonの元パス表記は保存した。
- 初回sandbox失敗ログも `.specify/workflows/runs/attempts/2cd5d049d3ef49b6836084bad7a5f55b/` に退避。
- GUI依頼の対象: `/private/tmp/my-img-viewer-codex-manual-gates/.build/MediaViewer.app`。
- 実行ファイル SHA-256: `731a45fbb919e5f74a688f80beea4fe92d9ecc5d63667de86794ac2bb1b84132`。
- 実run 356c45b4: implement / failed / updated_at `2026-10-27T08:15:10.657819+00:00` のまま。statusの読み取りだけを実行。

## GUI Report

2026-10-27、ユーザーから次の報告を受領した。

> 表示されました。
> macos versionは26.6.2（25G83）

依頼した対象アプリのツリー・ファイルリスト・プレビューの3ペイン表示成功として記録する。

## Output Excerpts

```text
Ran 28 tests in 15.704s
OK
Test run with 753 tests in 69 suites passed after 35.196 seconds.
verify build: exit 0
verify test: exit 0
verify no-network: exit 0
verify make-app: exit 0
```

## Residual Risks

- 実際のCodexモデルによる再開は未実施（spec 010の実装を試験目的で勝手に進めないため）。構造化結果の妥当性はブリッジで検査する。
- GUI起動スモークの報告を受領済み。検証用アプリの確認であり、spec 010 の設計レビューや機能確認の完了には流用しない。
- Spec Kit内部の75中断はfailedと保存される。ランナーのstatusは有効な要求がある場合waiting_for_manualを表示する。

## Recommendation

修正は現在の作業ツリーに反映済み。下記アプリの起動と3ペイン表示の成功報告を受領し、全検証ゲートを通過した。ソース変更とbug記録を1つのコミットにする。新しい実装runは不要で、ユーザーは `./scripts/sdd-run-codex.sh resume 356c45b4` から再開できる。

```bash
open /private/tmp/my-img-viewer-codex-manual-gates/.build/MediaViewer.app
```
