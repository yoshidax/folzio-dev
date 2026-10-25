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
import uuid


WORKFLOW = "sdd-increment-codex"
ROOT = Path(__file__).resolve().parent.parent


def attempt_directory(root):
    configured = os.environ.get("SDD_CODEX_ATTEMPT_DIR")
    directory = Path(configured) if configured else root / ".specify/workflows/runs/attempts" / uuid.uuid4().hex
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def read_tasks(root):
    feature = json.loads((root / ".specify/feature.json").read_text())["feature_directory"]
    path = (root / feature / "tasks.md").resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError("feature の tasks.md がリポジトリの外を指しています")
    tasks = {}
    for line in path.read_text().splitlines():
        match = re.match(r"^\s*- \[([ xX])\]\s+(T\d+)\b(.*)$", line)
        if match:
            checked, task_id, description = match.groups()
            if task_id in tasks:
                raise ValueError(f"タスク ID が重複しています: {task_id}")
            tasks[task_id] = {"checked": checked.lower() == "x", "description": description,
                              "manual": "[MANUAL]" in description}
    if not tasks:
        raise ValueError("tasks.md にタスクがありません")
    return tasks


def parse_delivery_result(text):
    result = json.loads(text)
    required = {"status", "completed_task_ids", "remaining_manual_task_ids", "blockers", "summary"}
    if not isinstance(result, dict) or set(result) != required:
        raise ValueError("実装結果のフィールドが不正です")
    if result["status"] not in ("ready_for_verification", "blocked", "failed") or not isinstance(result["summary"], str):
        raise ValueError("実装結果の status／summary が不正です")
    for field in ("completed_task_ids", "remaining_manual_task_ids", "blockers"):
        values = result[field]
        if not isinstance(values, list) or not all(isinstance(value, str) for value in values) or len(set(values)) != len(values):
            raise ValueError(f"実装結果の {field} が不正です")
    return result


def validate_delivery(text, before, after):
    result = parse_delivery_result(text)
    if result["status"] != "ready_for_verification" or result["blockers"]:
        raise ValueError(f"実装未完了 ({result['status']}): {result['summary']} / {result['blockers']}")
    if {key: task["description"] for key, task in before.items()} != {key: task["description"] for key, task in after.items()}:
        raise ValueError("実装中にタスクの定義・手動確認の分類が変更されました。設計レビューから確認してください")
    pending_code = [key for key, task in after.items() if not task["checked"] and not task["manual"]]
    if pending_code:
        raise ValueError("未完了の実装タスクがあります: " + ", ".join(pending_code))
    checked = {key for key, task in after.items() if task["checked"]}
    pending_manual = {key for key, task in after.items() if not task["checked"] and task["manual"]}
    if set(result["completed_task_ids"]) != checked or set(result["remaining_manual_task_ids"]) != pending_manual:
        raise ValueError("実装結果のタスク ID と tasks.md のチェック状態が一致しません")
    # A manual task unchecked at entry must await the human gate.
    if any(task["manual"] and not task["checked"] and after[key]["checked"] for key, task in before.items()):
        raise ValueError("未確認の手動タスクが実装中に完了扱いにされました")


def guard_resume(state, root):
    implement = state.get("step_results", {}).get("implement", {})
    if implement.get("status") != "completed":
        return
    try:
        result = parse_delivery_result(implement.get("output", {}).get("stdout", ""))
    except (ValueError, TypeError):
        raise ValueError("旧方式または不正な実装完了記録のため resume を停止しました。状態は変更しません。docs/codex-speckit.md の既存 run の扱いを確認してください") from None
    if result["status"] != "ready_for_verification" or result["blockers"]:
        raise ValueError("保存された実装結果が完了ではありません。resume を停止しました")
    if state.get("current_step_id") in ("verify", "notify_gui", "gui_smoke", "record"):
        pending = [key for key, task in read_tasks(root).items() if not task["checked"] and not task["manual"]]
        if pending:
            raise ValueError("実装後に未完了タスクが残っています。resume を停止しました: " + ", ".join(pending))


def verify_workspace(root=ROOT, commands=None):
    commands = commands if commands is not None else [
        ("build", ["swift", "build"]), ("test", ["swift", "test"]),
        ("no-network", ["scripts/check-no-network.sh"]), ("make-app", ["scripts/make-app.sh"]),
    ]
    directory = attempt_directory(root) / ("verify-" + uuid.uuid4().hex)
    directory.mkdir()
    results = []
    for label, argv in commands:
        stdout = directory / f"{label}.stdout.log"
        stderr = directory / f"{label}.stderr.log"
        progress(f"[verify {label}] 開始 / {directory}")
        code = 1
        with stdout.open("x") as out, stderr.open("x") as err:
            try:
                code = subprocess.call(argv, cwd=root, stdout=out, stderr=err)
                code = code if code >= 0 else 128 - code
            except KeyboardInterrupt:
                code = 130
            except OSError as exc:
                err.write(str(exc) + "\n")
        results.append({"stage": label, "command": argv, "exit_code": code,
                        "stdout": str(stdout), "stderr": str(stderr)})
        (directory / "result.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
        detail = f"verify {label}: exit {code}, ログ: {directory}"
        progress(detail)
        print(detail, file=sys.stderr if code else sys.stdout, flush=True)
        if code:
            return code
    return 0


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
    # Collect JSONL regardless of whether the adapter asked for text or JSON,
    # because this bridge needs the final agent message and turn events.
    args = [arg for arg in arguments if arg != "--json"]
    implementation = bool(args and re.match(r"^\s*\$speckit-implement(?:\s|$)", args[0]))
    before = read_tasks(ROOT) if implementation else None
    if implementation:
        args[0] += ("\n最終回答は指定された JSON schema のみで返してください。判断待ちは status=blocked、"
                    "実装・自動検証タスクが完了し手動確認だけ残る場合に限り ready_for_verification とします。"
                    "completed_task_ids は tasks.md のチェック済み ID 全件、remaining_manual_task_ids は"
                    "事前に [MANUAL] と分類された未チェック ID 全件です。未分類タスクを手動扱いにしたり、"
                    "タスク定義を変更したり、未確認の手動タスクをチェックしてはいけません。")
        args += ["--output-schema", str(ROOT / "scripts/sdd-codex-implementation.schema.json")]
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
    if implementation:
        report = attempt_directory(ROOT) / ("implementation-" + uuid.uuid4().hex + ".json")
        report.write_text(last_message + "\n")
        progress(f"[implementation result] {report}")
        validate_delivery(last_message, before, read_tasks(ROOT))
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
        state = load_state(root, arguments[1])
        if command == "resume":
            guard_resume(state, root)
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
        attempt = runs / "attempts" / uuid.uuid4().hex
        attempt.mkdir(parents=True)
        env["SDD_CODEX_ATTEMPT_DIR"] = str(attempt)
        if command == "resume":
            (attempt / "state-before.json").write_bytes((runs / arguments[1] / "state.json").read_bytes())
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
            (attempt / "state-after.json").write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n")
            message = outcome_message(state)
            if state.get("status") == "failed":
                step = state.get("step_results", {}).get(state.get("current_step_id"), {})
                detail = step.get("output", {}).get("stderr", "").strip()
                if detail:
                    print(detail[-3000:], file=sys.stderr, flush=True)
            if code == 0 and state.get("status") != "completed":
                code = 1
        except (ValueError, OSError) as exc:
            message = str(exc)
            code = code or 1
        minutes = int((time.monotonic() - started) / 60)
        message += f"（{minutes}分、終了コード: {code}）"
        print(message, flush=True)
        print(f"今回の実行ログ: {attempt}", flush=True)
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
        if args and args[0] == "exec":
            sys.exit(execute_codex(args[1:]))
        if args == ["verify"]:
            sys.exit(verify_workspace())
        sys.exit(run_workflow(args))
    except (ValueError, OSError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
