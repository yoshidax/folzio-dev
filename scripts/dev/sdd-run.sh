#!/bin/bash
# spec-kit ワークフロー sdd-increment を、進捗ログと終了通知付きで実行する
#
#   scripts/dev/sdd-run.sh run "<追加要件>" [-i key=value ...]   新しく実行する
#   scripts/dev/sdd-run.sh resume <run_id>                     一時停止・失敗した実行を再開する
#   scripts/dev/sdd-run.sh status [<run_id>]                   実行の状態を表示する
#
# 進捗は別のターミナルで `tail -f .specify/workflows/runs/progress.log` で見られる。
# 承認待ちに答えるため、ターミナルから直接実行すること（パイプやリダイレクトを付けない）
set -uo pipefail

cd "$(dirname "$0")/../.."
root="$PWD"
runs_dir="$root/.specify/workflows/runs"

usage() {
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2
}

command="${1:-}"
[[ -n "$command" ]] || usage
shift

if [[ "$command" == "status" ]]; then
    exec specify workflow status "$@"
fi

mkdir -p "$runs_dir"
# 実行中に Claude Code の自動アップデートが走ると、途中の claude -p が起動できなくなるため止める
export DISABLE_AUTOUPDATER=1
# 進捗ログ。scripts/dev/sdd-progress-hook.sh と scripts/dev/sdd-notify.sh が追記する
export SDD_PROGRESS_LOG="$runs_dir/progress.log"
# 各手順の claude -p に、進捗ログ用のフックだけを足す（普段の対話のセッションには入れない）
export SPECKIT_INTEGRATION_CLAUDE_EXTRA_ARGS="${SPECKIT_INTEGRATION_CLAUDE_EXTRA_ARGS:-} --settings $root/.claude/sdd-workflow-settings.json"

started=$(date +%s)

case "$command" in
    run)
        change="${1:-}"
        [[ -n "$change" ]] || usage
        shift
        printf '\n%s ===== run: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${change%%$'\n'*}" >> "$SDD_PROGRESS_LOG"
        echo "進捗: tail -f ${SDD_PROGRESS_LOG#$root/}"
        specify workflow run sdd-increment -i change="$change" "$@"
        ;;
    resume)
        run_id="${1:-}"
        [[ -n "$run_id" ]] || usage
        shift
        printf '\n%s ===== resume: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$run_id" >> "$SDD_PROGRESS_LOG"
        echo "進捗: tail -f ${SDD_PROGRESS_LOG#$root/}"
        specify workflow resume "$run_id" "$@"
        ;;
    *)
        usage
        ;;
esac
exit_code=$?

# 今回の実行の状態は、いちばん新しく更新された state.json から読む
state_file=$(ls -t "$runs_dir"/*/state.json 2>/dev/null | head -1)
status="unknown"
run_id="?"
if [[ -n "$state_file" ]]; then
    status=$(jq -r '.status // "unknown"' "$state_file" 2>/dev/null || echo unknown)
    run_id=$(jq -r '.run_id // "?"' "$state_file" 2>/dev/null || echo "?")
fi

elapsed=$(( $(date +%s) - started ))
duration=$(printf '%d時間%02d分' $((elapsed / 3600)) $((elapsed % 3600 / 60)))

case "$status" in
    completed) message="完了しました（${duration}）" ;;
    paused)    message="一時停止しました。resume ${run_id} で再開できます（${duration}）" ;;
    failed)    message="失敗しました。status ${run_id} で確認してください（${duration}）" ;;
    aborted)   message="中止しました（${duration}）" ;;
    *)         message="終了しました（状態: ${status}、終了コード: ${exit_code}、${duration}）" ;;
esac

scripts/dev/sdd-notify.sh "$message" "SDD workflow $run_id"
exit "$exit_code"
