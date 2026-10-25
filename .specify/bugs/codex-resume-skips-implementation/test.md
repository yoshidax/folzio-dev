# Bug Verification: Codex の判断待ちを実装完了として保存しない

- **Slug**: codex-resume-skips-implementation
- **Tested**: 2026-10-26T01:09:12+09:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

assessment の再現（判断待ちの最終回答が completed になり、resume が implement を飛ばす）は
修正後には再現しない。実装未完了は implement の失敗になり、resume は実装からやり直す。
旧方式で記録された実 run `f1cf656f` も、読み取り専用の確認で resume が停止した。
検証の失敗ログは再実行後も残る。アプリのコードは変更していない。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `python3 -m unittest discover -s scripts/tests -p test_sdd_codex.py -k blocked_implement -v` | pass | blocked 回答で implement が失敗し、resume が implement を再実行してから verify へ進む |
| Reproduction (legacy run) | 実 `f1cf656f` の state を読み取り専用で `guard_resume` に渡す | pass | 「旧方式または不正な実装完了記録」で停止。state の SHA-256 は前後で一致 |
| New / updated tests | `python3 -m unittest discover -s scripts/tests -v` | pass | 18 tests OK |
| Log retention | `python3 -m unittest ... -k failed_output -v` | pass | 失敗した verify の stderr が、成功した再試行後も別 attempt に残る |
| Regression suite | `python3 scripts/sdd-codex.py verify` | pass | 2 回目は build／test／no-network／make-app すべて exit 0 |
| Timing regression | `swift test --filter FileSystemWatcher` | pass | 12 tests OK。全体並列実行時の初回失敗は再現せず |
| Compile | `python3 -m py_compile scripts/sdd-codex.py` | pass | 構文エラーなし |
| Workflow parse | `~/.local/bin/specify workflow info sdd-increment-codex` | pass | version 0.2.0、20 steps として表示 |
| Lint / type-check | （Python の lint 設定なし） | not-run | 専用の lint／型チェックは未設定 |
| GUI smoke | （アプリ起動なし） | skipped | アプリコードを変更していないため。verify の make-app は成功 |

## Output Excerpts

```text
test_blocked_implementation_is_not_success ... ok
test_blocked_implement_retries_on_resume_before_verification ... ok
Ran 2 tests in 2.099s
OK
```

```text
test_legacy_completed_implementation_cannot_resume_to_gui ... ok
Ran 1 test in 0.241s
OK
```

```text
GUARD BLOCKED: ValueError 旧方式または不正な実装完了記録のため resume を停止しました。状態は変更しません。
state unchanged: True
```

```text
verify build: exit 0
verify test: exit 0
verify no-network: exit 0
verify make-app: exit 0
```

初回 verify の失敗（全体並列実行時の FileSystemWatcher の 2 秒タイムアウト）は
`.specify/workflows/runs/attempts/3658649601d9450a983dc8f55fabb19e/` に残り、
成功した再実行は別の attempt に保存されている。

## Residual Risks

- 実際の Codex モデルを使った implement の end-to-end 実行は、ユーザーの利用制限と
  006 の未決事項 I1 のため行っていない。`--output-schema` の受理は `codex exec --help` と
  ブリッジの単体テストで確認したが、モデルが常に schema どおり返すことまでは未検証。
- `[MANUAL]` は新しい規約である。既存の 006 の tasks.md は分類前なので、I1 を決めて
  新しい run を開始する必要がある。既存 run の state や tasks.md を手で書き換えない。
- FileSystemWatcher のタイミングテストは全体並列実行の負荷で揺れることがある。
  今回の変更とは独立の既存テストである。
- verify はビルド成果物を作るが、GUI の目視確認は行っていない。

## Recommendation

修正を close してよい。報告された症状（判断待ちを実装完了として保存し、resume が
GUI 確認へ進む）は自動再現で解消を確認した。既存 run `f1cf656f` は resume せず、
006 の I1 を決めたうえで修正版の workflow から新しい run を開始する。
