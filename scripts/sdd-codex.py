#!/usr/bin/env python3
"""Spec Kit Codex runner and JSONL-to-text execution bridge (stdlib only)."""

from datetime import datetime, timezone
import hashlib
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
MANUAL_WAIT = 75


def attempt_directory(root):
    configured = os.environ.get("SDD_CODEX_ATTEMPT_DIR")
    directory = Path(configured) if configured else root / ".specify/workflows/runs/attempts" / uuid.uuid4().hex
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def task_path(root):
    feature = json.loads((root / ".specify/feature.json").read_text())["feature_directory"]
    path = (root / feature / "tasks.md").resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError("feature の tasks.md がリポジトリの外を指しています")
    return path


def read_tasks(root):
    path = task_path(root)
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
    if not isinstance(result, dict) or set(result) not in (required, required | {"manual_requests"}):
        raise ValueError("実装結果のフィールドが不正です")
    if result["status"] not in ("ready_for_verification", "waiting_for_manual", "blocked", "failed") or not isinstance(result["summary"], str):
        raise ValueError("実装結果の status／summary が不正です")
    for field in ("completed_task_ids", "remaining_manual_task_ids", "blockers"):
        values = result[field]
        if not isinstance(values, list) or not all(isinstance(value, str) for value in values) or len(set(values)) != len(values):
            raise ValueError(f"実装結果の {field} が不正です")
    requests = result.get("manual_requests", [])
    if not isinstance(requests, list):
        raise ValueError("manual_requests は配列で指定してください")
    ids = []
    for request in requests:
        if (not isinstance(request, dict) or set(request) != {"task_id", "kind", "instructions"}
                or not isinstance(request["task_id"], str)
                or request["kind"] not in ("design_review", "gui", "other")
                or not isinstance(request["instructions"], str) or not request["instructions"].strip()):
            raise ValueError("手動確認要求の ID・種別・手順が不正です")
        ids.append(request["task_id"])
    if len(ids) != len(set(ids)) or bool(requests) != (result["status"] == "waiting_for_manual"):
        raise ValueError("waiting_for_manual のときだけ、重複のない手動確認要求が必要です")
    return result


def validate_delivery(text, before, after):
    result = parse_delivery_result(text)
    if result["status"] not in ("ready_for_verification", "waiting_for_manual") or result["blockers"]:
        raise ValueError(f"実装未完了 ({result['status']}): {result['summary']} / {result['blockers']}")
    if {key: task["description"] for key, task in before.items()} != {key: task["description"] for key, task in after.items()}:
        raise ValueError("実装中にタスクの定義・手動確認の分類が変更されました。設計レビューから確認してください")
    pending_code = [key for key, task in after.items() if not task["checked"] and not task["manual"]]
    if pending_code and result["status"] != "waiting_for_manual":
        raise ValueError("未完了の実装タスクがあります: " + ", ".join(pending_code))
    checked = {key for key, task in after.items() if task["checked"]}
    pending_manual = {key for key, task in after.items() if not task["checked"] and task["manual"]}
    if set(result["completed_task_ids"]) != checked or set(result["remaining_manual_task_ids"]) != pending_manual:
        raise ValueError("実装結果のタスク ID と tasks.md のチェック状態が一致しません")
    # A manual task unchecked at entry must await the human gate.
    if any(task["manual"] and not task["checked"] and after[key]["checked"] for key, task in before.items()):
        raise ValueError("未確認の手動タスクが実装中に完了扱いにされました")
    if any(request["task_id"] not in pending_manual for request in result.get("manual_requests", [])):
        raise ValueError("手動確認要求は既定の未チェック [MANUAL] タスクだけに指定してください")
    if any(task["checked"] and not after[key]["checked"] for key, task in before.items()):
        raise ValueError("完了済みタスクが未完了へ戻されました")
    return result


def workflow_state(root, env):
    if env.get("SDD_CODEX_WORKFLOW") != WORKFLOW:
        return None
    run_id = env.get("SDD_CODEX_RUN_ID")
    if run_id:
        return load_state(root, run_id)
    return find_new_state(root, set(json.loads(env.get("SDD_CODEX_PREVIOUS_RUN_IDS", "[]"))))


def manual_path(root, state):
    return root / ".specify/workflows/runs" / state["run_id"] / "manual-pending.json"


def task_digest(root):
    return hashlib.sha256(task_path(root).read_bytes()).hexdigest()


def app_digest(root):
    binary = root / ".build/MediaViewer.app/Contents/MacOS/MediaViewer"
    return hashlib.sha256(binary.read_bytes()).hexdigest() if binary.exists() else None


def pending_manual(root, state):
    path = manual_path(root, state)
    if not path.exists():
        return None
    pending = json.loads(path.read_text())
    step = state.get("step_results", {}).get("implement", {})
    if (state.get("current_step_id") != "implement" or step.get("status") != "failed"
            or step.get("output", {}).get("exit_code") != MANUAL_WAIT):
        raise ValueError("手動確認要求と workflow の停止位置が一致しません")
    if (pending["run_id"] != state["run_id"] or pending["tasks_path"] != str(task_path(root))
            or pending["tasks_sha256"] != task_digest(root)):
        raise ValueError("手動確認要求の作成後に tasks.md が変更されました。resume <run_id> --refresh-manual で再生成してください")
    if pending["app_sha256"] != app_digest(root):
        raise ValueError("手動確認要求の作成後に対象アプリが変更されました。resume <run_id> --refresh-manual で再生成してください")
    tasks = read_tasks(root)
    validate_delivery(json.dumps(pending["result"]), tasks, tasks)
    return pending


def save_manual(root, state, result):
    pending = {"run_id": state["run_id"], "tasks_path": str(task_path(root)),
               "tasks_sha256": task_digest(root), "app_sha256": app_digest(root), "result": result}
    manual_path(root, state).write_text(json.dumps(pending, ensure_ascii=False, indent=2) + "\n")


def review_approved(state, root):
    gate = state.get("step_results", {}).get("review_gate", {})
    return (gate.get("status") == "completed" and gate.get("output", {}).get("choice") == "approve"
            and not manual_path(root, state).with_name("review-invalidated.json").exists())


def show_manual(state, pending):
    print(f"Status: waiting_for_manual（run: {state['run_id']}）", flush=True)
    print(pending["result"]["summary"], flush=True)
    for request in pending["result"]["manual_requests"]:
        print(f"\n{request['task_id']} [{request['kind']}]\n{request['instructions']}", flush=True)


def confirm_manual(root, state, pending, input_stream=None):
    """Only the runner, after receiving evidence, may check manual tasks."""
    pending_manual(root, state)  # Refuse approval of a stale request.
    tasks = read_tasks(root)
    requests = pending["result"]["manual_requests"]
    # A review gate approves the design; it cannot stand in for running the app.
    design_only = all(request["kind"] == "design_review"
                      and re.search(r"設計レビュー|design review", tasks[request["task_id"]]["description"], re.I)
                      and not re.search(r"open\s|起動して|起動し、", tasks[request["task_id"]]["description"], re.I)
                      for request in requests)
    automatic = design_only and review_approved(state, root)
    if automatic:
        print("保存済み review_gate の approve を設計レビューの確認報告として引き継ぎます。", flush=True)
        response = "review_gate: approve"
    else:
        show_manual(state, pending)
        stream = input_stream if input_stream is not None else sys.stdin
        if not stream.isatty():
            return False
        print("上記すべてを実施して成功を確認したら、確認結果（対象ビルド・OS・端末等）を記入してください。", flush=True)
        print("未実施・問題ありは空行で停止します。確認結果: ", end="", flush=True)
        response = stream.readline().strip()
        if not response:
            return False
        print("この報告で上記タスクを完了として記録しますか？ [approve / その他は停止]: ", end="", flush=True)
        if stream.readline().strip() != "approve":
            return False
    pending_manual(root, state)  # Re-check after the human has worked in another terminal.
    receipt = {"run_id": state["run_id"], "received_at": datetime.now(timezone.utc).isoformat(),
               "tasks_sha256": pending["tasks_sha256"], "manual_requests": requests,
               "app_sha256": pending["app_sha256"],
               "source": "review_gate" if automatic else "terminal", "report": response}
    receipt_path = manual_path(root, state).with_name("manual-receipts.jsonl")
    with receipt_path.open("a") as stream:
        stream.write(json.dumps(receipt, ensure_ascii=False) + "\n")
    ids = {request["task_id"] for request in requests}
    path = task_path(root)
    text = re.sub(r"^(\s*- \[) (\]\s+(T\d+)\b)",
                  lambda match: match[1] + ("X" if match[3] in ids else " ") + match[2],
                  path.read_text(), flags=re.M)
    path.write_text(text)
    manual_path(root, state).unlink()
    progress(f"[manual confirmed] {', '.join(sorted(ids))} / {receipt_path}")
    print(f"確認報告を記録しました: {receipt_path}", flush=True)
    return True


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
    state = workflow_state(ROOT, os.environ) if implementation else None
    if implementation:
        args[0] += ("\n最終回答は指定された JSON schema のみで返してください。権限不足・未決判断・失敗は status=blocked/failed、"
                    "依存順で次にユーザーが実施できる既定の [MANUAL] がある場合は waiting_for_manual とします。"
                    "後続の非手動タスクがその確認に依存して残っていても waiting_for_manual で停止してください。"
                    "manual_requests に現在実施可能な手動タスクだけを task_id・kind（design_review/gui/other）・"
                    "具体的な instructions（コマンド、確認点、報告に必要な情報）付きで列挙してください。"
                    "前提未完了の別Phaseの手動タスクは要求しないでください。"
                    "全非手動タスク完了の場合だけ ready_for_verification とします。"
                    "waiting_for_manual/ready_for_verification の blockers は空、他の status の manual_requests は空配列です。"
                    "completed_task_ids は tasks.md のチェック済み ID 全件、remaining_manual_task_ids は"
                    "事前に [MANUAL] と分類された未チェック ID 全件です。未分類タスクを手動扱いにしたり、"
                    "タスク定義を変更したり、未確認の手動タスクをチェックしてはいけません。")
        if state:
            receipt_path = manual_path(ROOT, state).with_name("manual-receipts.jsonl")
            args[0] += (f"\nこの run は {state['run_id']} です。設計レビュー review_gate の承認状態: "
                        f"{'approve 済み' if review_approved(state, ROOT) else '承認の証拠なし'}。"
                        "設計レビューだけの既定手動タスクが未チェックなら、確認の重複を避けるため"
                        "kind=design_review の waiting_for_manual を返してください。ランナーが承認証拠を照合して記録します。"
                        "承認済みでも手動タスクを自分でチェックしてはいけません。"
                        "GUI確認を設計レビューの承認で代替しないでください。"
                        f"\n受領済みの手動確認報告: {receipt_path}（存在するときだけ読む）。"
                        "報告転記タスクではこの記録を根拠にし、指定された記録先へ転記してください。")
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
        result = validate_delivery(last_message, before, read_tasks(ROOT))
        if result["status"] == "waiting_for_manual":
            if state:
                save_manual(ROOT, state, result)
            print(last_message, flush=True)
            return MANUAL_WAIT
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
    refresh = command == "resume" and len(arguments) == 3 and arguments[2] == "--refresh-manual"
    if (command == "resume" and len(arguments) != 2 and not refresh) or (command == "status" and len(arguments) > 2):
        raise ValueError("resume <run_id> [--refresh-manual] / status [<run_id>] を指定してください")
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
        if len(arguments) > 1:
            pending = pending_manual(root, state)
            if pending:
                show_manual(state, pending)
                return 0
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
        env["SDD_CODEX_PREVIOUS_RUN_IDS"] = json.dumps(sorted(previous_ids))
        env.pop("SDD_CODEX_RUN_ID", None)
        if command == "resume":
            (attempt / "state-before.json").write_bytes((runs / arguments[1] / "state.json").read_bytes())
            env["SDD_CODEX_RUN_ID"] = arguments[1]
            if refresh:
                path = manual_path(root, state)
                if not path.exists():
                    raise ValueError("再生成する手動確認要求がありません")
                path.rename(attempt / "manual-pending-before-refresh.json")
                path.with_name("review-invalidated.json").write_text(json.dumps({"attempt": str(attempt)}) + "\n")
                print("古い確認要求をログへ退避しました。設計レビューの承認は再利用せず、実装で確認要求を再生成します。", flush=True)
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
        code = 1
        try:
            # Resume a validated manual suspension before paying for another Codex turn.
            pending = pending_manual(root, state) if command == "resume" else None
            rounds = 0
            while True:
                if pending:
                    if not confirm_manual(root, state, pending):
                        code = MANUAL_WAIT
                        break
                    argv = [specify, "workflow", "resume", state["run_id"]]
                code = subprocess.call(argv, cwd=root, env=env)
                state = (load_state(root, env["SDD_CODEX_RUN_ID"]) if env.get("SDD_CODEX_RUN_ID")
                         else find_new_state(root, previous_ids))
                env["SDD_CODEX_RUN_ID"] = state["run_id"]
                pending = pending_manual(root, state)
                if not pending:
                    break
                rounds += 1
                if rounds > 100:
                    raise ValueError("手動確認の中断・再開が100回を超えました。進捗ログを確認してください")
            (attempt / "state-after.json").write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n")
            message = (f"手動確認待ち。resume {state['run_id']} で報告して再開できます" if pending
                       else outcome_message(state))
            if state.get("status") == "failed" and not pending:
                step = state.get("step_results", {}).get(state.get("current_step_id"), {})
                detail = step.get("output", {}).get("stderr", "").strip()
                if detail:
                    print(detail[-3000:], file=sys.stderr, flush=True)
            if code == 0 and state.get("status") != "completed":
                code = 1
        except KeyboardInterrupt:
            message = "中断しました。status で停止位置を確認してから resume してください"
            code = 130
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
