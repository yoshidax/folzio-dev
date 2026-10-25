# Bug Fix: Codex の判断待ちを実装完了にせず、resume と検証ログを安全にする

- **Slug**: codex-resume-skips-implementation
- **Fixed**: 2026-10-26T01:08:44+09:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

`$speckit-implement` の最終回答を構造化し、`tasks.md` の状態と照合してから implement を成功に
するようにした。判断待ちは `blocked` として工程自体を失敗させ、resume では実装からやり直す。
旧方式で `completed` と保存された run は resume を停止し、verify の各試行は上書きしない
実行ログとして保存する。

## Changes

| File | Change | Notes |
|------|--------|-------|
| `scripts/sdd-codex.py` | modified | implement の構造化結果を検証。`status=ready_for_verification`、blockers 空、未チェックが `[MANUAL]` のみ、のときだけ成功にする。resume 時に旧記録と未完了タスクを拒否。verify を段階別ログ付きで実行。失敗内容を最後に表示 |
| `scripts/sdd-codex-implementation.schema.json` | added | Codex の `--output-schema` に渡す最終回答の契約 |
| `scripts/tests/test_sdd_codex.py` | modified | blocked／自然文完了／未完了タスク／手動分類の変更／resume 再実行／旧 run 停止／検証ログ保持の回帰テストを追加 |
| `.specify/workflow-src/sdd-increment-codex.yml` | modified | version 0.2.0。tasks で `[MANUAL]` を分類。implement を capture＋6時間 timeout にし、blocked を明示。verify をブリッジ経由に変更 |
| `.specify/workflows/sdd-increment-codex/workflow.yml` | modified | `specify workflow add --dev` で source と同期 |
| `.specify/workflows/workflow-registry.json` | modified | 登録バージョンを 0.2.0 に更新 |
| `docs/codex-speckit.md` | modified | 実装完了の契約、`[MANUAL]`、旧 run の扱い、attempt ログの場所を追記 |

## Diff Highlights

implement の成功条件を command step の中に置いたため、resume が保存済みの誤った成功を
飛ばして後続へ進むことがない。

```python
if implementation:
    validate_delivery(last_message, before, read_tasks(ROOT))
```

resume 時は、旧方式の記録と実装後に残った実装タスクを拒否する。

```python
def guard_resume(state, root):
    implement = state.get("step_results", {}).get("implement", {})
    if implement.get("status") != "completed":
        return
    result = parse_delivery_result(implement.get("output", {}).get("stdout", ""))
    ...
```

verify は試行ごとに別ディレクトリへ stdout／stderr／result.json を残す。

```text
.specify/workflows/runs/attempts/<attempt>/verify-<id>/
  build.stdout.log / build.stderr.log
  test.stdout.log  / test.stderr.log
  ...
  result.json
```

## Tests Added or Updated

- `scripts/tests/test_sdd_codex.py::CodexBridgeTests::test_blocked_implementation_is_not_success` — `blocked` を成功にしない
- `scripts/tests/test_sdd_codex.py::CodexBridgeTests::test_plain_text_completion_is_not_success_for_implement` — 自然文の「判断待ち」を成功にしない
- `scripts/tests/test_sdd_codex.py::CodexBridgeTests::test_ready_result_with_unfinished_code_task_is_rejected` — 実装タスクが未チェックなら拒否
- `scripts/tests/test_sdd_codex.py::CodexBridgeTests::test_only_predeclared_manual_tasks_may_remain` — 事前に `[MANUAL]` のタスクだけ残せる
- `scripts/tests/test_sdd_codex.py::CodexBridgeTests::test_implementation_cannot_reclassify_code_as_manual` — 実装中の手動分類変更を拒否
- `scripts/tests/test_sdd_codex.py::WorkflowTests::test_blocked_implement_retries_on_resume_before_verification` — resume が implement を再実行し、verify へ進まないことを確認
- `scripts/tests/test_sdd_codex.py::WorkflowTests::test_legacy_completed_implementation_cannot_resume_to_gui` — 旧方式の completed 記録で resume できない
- `scripts/tests/test_sdd_codex.py::VerificationLogTests::test_failed_output_survives_a_successful_retry` — 再試行後も失敗ログが残る

## Local Verification

- Commands run: `python3 -m unittest discover -s scripts/tests -v` → 18 tests OK
- Commands run: `python3 scripts/sdd-codex.py verify` → 初回は FileSystemWatcher のタイミングテストが全体並列実行で失敗（test exit 1）。単独実行 `swift test --filter FileSystemWatcher` → 12 tests OK。再実行の verify は build／test／no-network／make-app すべて exit 0
- Commands run: `~/.local/bin/specify workflow info sdd-increment-codex` → 0.2.0 として解析・表示できる
- Manual checks: 実 run `f1cf656f` の state を読み取り専用で `guard_resume` に通し、
  「旧方式または不正な実装完了記録」で停止することと、state が変化しないことを確認した
- Manual checks: 2 回の verify の attempt ディレクトリが残り、初回失敗の stderr が再実行後も参照できることを確認した
- GUI: アプリコードを変更していないため起動確認は行っていない

## Deviations from Assessment

なし。assessment の Preferred remediation のうち、構造化結果、tasks.md 照合、implement 自体の
成功条件、上書きしない verify ログをすべて実装した。`[MANUAL]` の分類指示は、手動確認タスクと
実装タスクを区別するために tasks 工程へ追加した。

## Follow-ups

- 既存 run `f1cf656f` は resume しない。006 の I1（スライドショー中の並べ替え操作）を決め、
  修正版で新しい run を開始する。state ファイルを手で書き換えない。
- このブランチを master へ取り込み、その後 006 の作業ブランチへ反映する。
- FileSystemWatcher の 2 秒タイムアウトは全体並列実行で揺れる既存のテストである。
  今回の修正とは別に、必要なら負荷時の安定性を別 bug として扱う。
