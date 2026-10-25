#!/usr/bin/env python3
"""Spec Kit Codex runner and JSONL-to-text execution bridge (stdlib only)."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time


WORKFLOW = "sdd-increment-codex"
ROOT = Path(__file__).resolve().parent.parent


def progress(message):
    """Logging must never change an agent's exit status."""
    target = os.environ.get("SDD_PROGRESS_LOG")
    if target:
        try:
            with open(target, "a", encoding="utf-8") as stream:
                stream.write(time.strftime("%H:%M:%S ") + message.replace("\n", " ")[:500] + "\n")
        except OSError:
            pass


def event_summary(event):
    kind = event.get("type", "?")
    item = event.get("item") or {}
    if kind.startswith("item."):
        detail = item.get("command") or item.get("text") or item.get("changes") or ""
        return f"[{kind} {item.get('type', '?')}] {detail}"
    return f"[{kind}] {event.get('error') or event.get('message') or ''}"


def execute_codex(arguments):
    """Always collect JSONL; Spec Kit capture receives only the last agent message."""
    binary = shutil.which(os.environ.get("SDD_CODEX_BIN", "codex"))
    if not binary or Path(binary).resolve() == Path(__file__).resolve():
        raise ValueError("codex が見つからないか、実行ブリッジ自身を指しています")
    # The official adapter appends --json only for streaming command steps.
    # Normalize both captured and streamed calls without installing global hooks.
    args = [arg for arg in arguments if arg != "--json"]
    # --approve-for-me selects workspace-write itself and conflicts with --sandbox.
    args += ["--json", "--approve-for-me"]
    model = os.environ.get("SDD_CODEX_MODEL")
    if model:
        args += ["--model", model]
    proc = subprocess.Popen([binary, "exec", *args], stdout=subprocess.PIPE, text=True, encoding="utf-8")
    last_message = ""
    completed = False
    failed = False
    try:
        for line in proc.stdout:
            try:
                event = json.loads(line)
                if not isinstance(event, dict):
                    raise ValueError("event is not an object")
            except (ValueError, TypeError):
                print(line.rstrip(), file=sys.stderr, flush=True)
                continue
            summary = event_summary(event)
            progress(summary)
            # Keep live progress out of captured stdout (review reports).
            print(summary[:500], file=sys.stderr, flush=True)
            if event.get("type") == "item.completed":
                item = event.get("item") or {}
                if item.get("type") == "agent_message":
                    last_message = item.get("text", "")
            if event.get("type") == "turn.completed":
                completed = True
            if event.get("type") in ("turn.failed", "error"):
                failed = True
        code = proc.wait()
    except (KeyboardInterrupt, SystemExit):
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        return 130
    finally:
        proc.stdout.close()
    if code:
        return code if code > 0 else 128 - code
    if failed or not completed or not last_message.strip():
        print("Codex の成功した最終回答を取得できませんでした。進捗ログを確認してください", file=sys.stderr)
        return 1
    print(last_message, flush=True)
    return 0


def load_state(root, run_id):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", run_id):
        raise ValueError("run_id の形式が不正です")
    path = root / ".specify/workflows/runs" / run_id / "state.json"
    state = json.loads(path.read_text())
    if state.get("workflow_id") != WORKFLOW or state.get("run_id") != run_id:
        raise ValueError(f"{run_id} は {WORKFLOW} の実行ではありません")
    return state


def find_new_state(root, previous_ids):
    """Do not mistake a newer Claude/Kilo run for our own result."""
    states = []
    for path in (root / ".specify/workflows/runs").glob("*/state.json"):
        if path.parent.name in previous_ids:
            continue
        try:
            states.append(load_state(root, path.parent.name))
        except (ValueError, OSError):
            continue
    if len(states) != 1:
        raise ValueError("今回の Codex run を一意に特定できません。workflow status で確認してください")
    return states[0]


def outcome_message(state):
    status = state.get("status", "unknown")
    run_id = state["run_id"]
    if status == "completed":
        return f"完了しました（run: {run_id}）"
    if status in ("paused", "failed"):
        return f"{status}。status {run_id} で確認し、resume {run_id} で再開できます"
    return f"終了しました（状態: {status}、run: {run_id}）"


def run_workflow(arguments, root=ROOT):
    command = arguments[0] if arguments else ""
    if command not in ("run", "resume", "status"):
        raise ValueError('使い方: scripts/sdd-run-codex.sh run "<追加要件>" [-i key=value ...] | resume <run_id> | status [<run_id>]')
    if command in ("run", "resume") and (len(arguments) < 2 or not arguments[1].strip()):
        raise ValueError("追加要件または run_id を指定してください")
    if (command == "resume" and len(arguments) != 2) or (command == "status" and len(arguments) > 2):
        raise ValueError("resume／status の引数は run_id だけを指定してください")
    env = os.environ.copy()
    env["PATH"] = str(Path.home() / ".local/bin") + os.pathsep + env.get("PATH", "")
    specify = shutil.which("specify", path=env["PATH"])
    if not specify:
        raise ValueError("specify が見つかりません。Spec Kit 1.2.2 以降をインストールしてください")
    if command != "run" and len(arguments) > 1:
        load_state(root, arguments[1])
    if command == "status":
        return subprocess.call([specify, "workflow", *arguments], cwd=root, env=env)
    if not shutil.which(env.get("SDD_CODEX_BIN", "codex"), path=env["PATH"]):
        raise ValueError("codex が見つかりません。Codex CLI をインストールしてください")
    state_config = json.loads((root / ".specify/integration.json").read_text())
    if "codex" not in state_config.get("installed_integrations", []):
        raise ValueError("specify integration install codex で Codex integration を追加してください")
    runs = root / ".specify/workflows/runs"
    runs.mkdir(parents=True, exist_ok=True)
    lock = runs / ".sdd-codex.lock"
    try:
        lock.mkdir()
    except FileExistsError:
        raise ValueError(f"別の Codex workflow が実行中です。実行がない場合だけ rmdir {lock} でロックを解除してください") from None
    started = time.monotonic()
    try:
        previous_ids = {p.parent.name for p in runs.glob("*/state.json")}
        env["SDD_PROGRESS_LOG"] = str(runs / "progress.log")
        env["SPECKIT_INTEGRATION_CODEX_EXECUTABLE"] = str(root / "scripts/sdd-codex.py")
        # Used by the workflow preflight to reject execution without this runner.
        env["SDD_CODEX_WORKFLOW"] = WORKFLOW
        argv = [specify, "workflow", command]
        if command == "run":
            argv += [WORKFLOW, "-i", "change=" + arguments[1], *arguments[2:]]
        else:
            argv += [arguments[1]]
        print("進捗: tail -f .specify/workflows/runs/progress.log", flush=True)
        with open(env["SDD_PROGRESS_LOG"], "a", encoding="utf-8") as log:
            log.write(time.strftime("\n%Y-%m-%d %H:%M:%S ") + f"===== {command} (codex)\n")
        try:
            code = subprocess.call(argv, cwd=root, env=env)
        except KeyboardInterrupt:
            code = 130
        try:
            state = load_state(root, arguments[1]) if command == "resume" else find_new_state(root, previous_ids)
            message = outcome_message(state)
            if code == 0 and state.get("status") != "completed":
                code = 1
        except (ValueError, OSError) as exc:
            message = str(exc)
            code = code or 1
        minutes = int((time.monotonic() - started) / 60)
        message += f"（{minutes}分、終了コード: {code}）"
        print(message, flush=True)
        with open(env["SDD_PROGRESS_LOG"], "a", encoding="utf-8") as log:
            log.write(time.strftime("%H:%M:%S ") + "[終了] " + message + "\n")
        if env.get("SDD_CODEX_NOTIFY") != "0":
            subprocess.call([str(root / "scripts/sdd-notify.sh"), message, "SDD workflow (Codex)"], cwd=root, env=env)
        return code if code >= 0 else 128 - code
    finally:
        lock.rmdir()


if __name__ == "__main__":
    try:
        args = sys.argv[1:]
        sys.exit(execute_codex(args[1:]) if args and args[0] == "exec" else run_workflow(args))
    except (ValueError, OSError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
