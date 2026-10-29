#!/bin/bash
# spec-kit ワークフロー sdd-increment-kilo を、Kilo CLI (kilo run) をバックエンドに
# 進捗ログと終了通知付きで実行する
#
#   scripts/dev/sdd-run-kilo.sh run "<追加要件>" [-i key=value ...]   新しく実行する
#   scripts/dev/sdd-run-kilo.sh resume <run_id>                      一時停止・失敗した実行を再開する
#   scripts/dev/sdd-run-kilo.sh status [<run_id>]                    実行の状態を表示する
#
# 進捗は別のターミナルで `tail -f .specify/workflows/runs/progress.log` で見られる。
# 承認待ちに答えるため、ターミナルから直接実行すること（パイプやリダイレクトを付けない）
set -uo pipefail

cd "$(dirname "$0")/../.."
root="$PWD"
runs_dir="$root/.specify/workflows/runs"

if ! command -v specify >/dev/null 2>&1; then
    PATH="$HOME/.local/bin:$PATH"
fi

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

if ! command -v kilo >/dev/null 2>&1; then
    echo "kilo が見つかりません。Kilo CLI をインストールしてください" >&2
    exit 1
fi

mkdir -p "$runs_dir"
# 進捗ログ。.kilo/plugin/sdd-progress.js と scripts/dev/sdd-notify.sh が追記する
export SDD_PROGRESS_LOG="$runs_dir/progress.log"

# spec-kit の opencode アダプタを Kilo CLI に向ける。Kilo は opencode のフォークで、
# `run --command <name>`, `-m <provider/model>`, `--format` の意味が同じ
export SPECKIT_INTEGRATION_OPENCODE_EXECUTABLE=kilo
# 非対話実行では permission が自動拒否されるため --auto を渡す（明示的に deny した操作は拒否される）
if [[ -z "${SPECKIT_INTEGRATION_OPENCODE_EXTRA_ARGS:-}" ]]; then
    export SPECKIT_INTEGRATION_OPENCODE_EXTRA_ARGS="--auto"
fi

started=$(date +%s)

case "$command" in
    run)
        change="${1:-}"
        [[ -n "$change" ]] || usage
        shift
        printf '\n%s ===== run (kilo): %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${change%%$'\n'*}" >> "$SDD_PROGRESS_LOG"
        echo "進捗: tail -f ${SDD_PROGRESS_LOG#$root/}"
        specify workflow run sdd-increment-kilo -i change="$change" "$@"
        ;;
    resume)
        run_id="${1:-}"
        [[ -n "$run_id" ]] || usage
        shift
        printf '\n%s ===== resume (kilo): %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$run_id" >> "$SDD_PROGRESS_LOG"
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

scripts/dev/sdd-notify.sh "$message" "SDD workflow (kilo) $run_id"
exit "$exit_code"
