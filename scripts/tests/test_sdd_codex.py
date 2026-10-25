"""Offline regression tests. Run: python3 -m unittest discover -s scripts/tests -v"""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
BRIDGE = ROOT / "scripts/sdd-codex.py"
spec = importlib.util.spec_from_file_location("sdd_codex", BRIDGE)
sdd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sdd)
SPECIFY = shutil.which("specify") or str(Path.home() / ".local/bin/specify")

FAKE_CODEX = '''#!/usr/bin/env python3
import json, os, pathlib, sys
pathlib.Path(os.environ["FAKE_ARGV"]).write_text(json.dumps(sys.argv[1:]))
if "FAKE_TASKS_TEXT" in os.environ:
    pathlib.Path("specs/test/tasks.md").write_text(os.environ["FAKE_TASKS_TEXT"])
for event in json.loads(os.environ["FAKE_EVENTS"]):
    print(json.dumps(event), flush=True)
sys.exit(int(os.environ.get("FAKE_EXIT", "0")))
'''


def message(text):
    return {"type": "item.completed", "item": {"type": "agent_message", "text": text}}


def delivery_result(status="ready_for_verification", completed=None, manual=None, blockers=None):
    return json.dumps({"status": status, "completed_task_ids": completed or [],
                       "remaining_manual_task_ids": manual or [], "blockers": blockers or [],
                       "summary": "implementation result"})


def make_tasks(root, text="- [ ] T001 Implement\n- [ ] T002 [MANUAL] GUI check\n"):
    (root / ".specify").mkdir(exist_ok=True)
    (root / ".specify/feature.json").write_text(json.dumps({"feature_directory": "specs/test"}))
    (root / "specs/test").mkdir(parents=True, exist_ok=True)
    (root / "specs/test/tasks.md").write_text(text)


class CodexBridgeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="sdd codex ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.fake = self.root / "fake-codex"
        self.fake.write_text(FAKE_CODEX)
        self.fake.chmod(0o755)
        self.env = {
            **os.environ,
            "SDD_CODEX_BIN": str(self.fake),
            "FAKE_ARGV": str(self.root / "argv.json"),
            "SDD_PROGRESS_LOG": str(self.root / "progress.log"),
        }

    def implementation(self, report, tasks_after=None):
        make_tasks(self.root)
        scripts = self.root / "scripts"
        scripts.mkdir(exist_ok=True)
        shutil.copy2(BRIDGE, scripts / BRIDGE.name)
        schema = BRIDGE.with_name("sdd-codex-implementation.schema.json")
        if schema.exists():
            shutil.copy2(schema, scripts / schema.name)
        env = {**self.env, "FAKE_EVENTS": json.dumps([message(report), {"type": "turn.completed"}])}
        if tasks_after is not None:
            env["FAKE_TASKS_TEXT"] = tasks_after
        return subprocess.run([sys.executable, str(scripts / BRIDGE.name), "exec", "$speckit-implement"],
                              cwd=self.root, env=env, text=True, capture_output=True, timeout=10)

    def test_blocked_implementation_is_not_success(self):
        result = self.implementation(delivery_result("blocked", blockers=["I1 unresolved"]))
        self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_plain_text_completion_is_not_success_for_implement(self):
        self.assertNotEqual(self.implementation("判断待ち。全タスク未完了").returncode, 0)

    def test_ready_result_with_unfinished_code_task_is_rejected(self):
        result = self.implementation(delivery_result(manual=["T002"]))
        self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_only_predeclared_manual_tasks_may_remain(self):
        result = self.implementation(delivery_result(completed=["T001"], manual=["T002"]),
                                     "- [X] T001 Implement\n- [ ] T002 [MANUAL] GUI check\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["status"], "ready_for_verification")
        self.assertIn("--output-schema", json.loads((self.root / "argv.json").read_text()))

    def test_implementation_cannot_reclassify_code_as_manual(self):
        result = self.implementation(delivery_result(manual=["T001", "T002"]),
                                     "- [ ] T001 [MANUAL] Implement\n- [ ] T002 [MANUAL] GUI check\n")
        self.assertNotEqual(result.returncode, 0)

    def execute(self, events, code=0, args=None):
        self.env.update(FAKE_EVENTS=json.dumps(events), FAKE_EXIT=str(code))
        return subprocess.run(
            [sys.executable, str(BRIDGE), "exec", *(args or ["test prompt"])],
            env=self.env, text=True, capture_output=True, timeout=10,
        )

    def test_capture_returns_last_message_and_preserves_arguments(self):
        prompt = '$speckit-plan 引数 "引用" $(touch should-not-exist)\n2行目'
        result = self.execute([
            {"type": "thread.started"}, message("途中経過"),
            {"type": "item.completed", "item": {"type": "command_execution", "command": "swift build"}},
            message("設計レビュー\n問題なし"), {"type": "turn.completed"},
        ], args=[prompt, "--json"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "設計レビュー\n問題なし\n")
        argv = json.loads((self.root / "argv.json").read_text())
        self.assertEqual(argv[:2], ["exec", prompt])
        self.assertEqual(argv.count("--json"), 1)
        self.assertNotIn("--sandbox", argv)
        self.assertIn("--approve-for-me", argv)
        self.assertIn("swift build", (self.root / "progress.log").read_text())

    def test_nonzero_exit_propagates(self):
        result = self.execute([message("失敗した回答"), {"type": "turn.completed"}], code=7)
        self.assertEqual(result.returncode, 7)
        self.assertEqual(result.stdout, "")

    def test_failed_or_incomplete_event_stream_is_not_success(self):
        for events in (
            [message("一見成功"), {"type": "turn.failed", "error": "quota"}],
            [message("途中で切断")],
            [{"type": "turn.completed"}],
            [{"type": "error", "message": "接続失敗"}, message("回答"), {"type": "turn.completed"}],
        ):
            with self.subTest(events=events):
                self.assertNotEqual(self.execute(events).returncode, 0)

    def test_logging_failure_does_not_fail_codex(self):
        self.env["SDD_PROGRESS_LOG"] = str(self.root / "missing/log")
        self.assertEqual(self.execute([message("ok"), {"type": "turn.completed"}]).returncode, 0)

    def test_missing_binary_fails(self):
        self.env["SDD_CODEX_BIN"] = str(self.root / "missing-codex")
        self.assertNotEqual(self.execute([]).returncode, 0)


@unittest.skipUnless(Path(SPECIFY).is_file(), "Spec Kit CLI is required for integration tests")
class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="sdd workflow ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        scripts = self.root / "scripts"
        scripts.mkdir()
        shutil.copy2(BRIDGE, scripts / BRIDGE.name)
        schema = BRIDGE.with_name("sdd-codex-implementation.schema.json")
        if schema.exists():
            shutil.copy2(schema, scripts / schema.name)
        (self.root / ".specify").mkdir()
        (self.root / ".specify/integration.json").write_text(json.dumps({
            "installed_integrations": ["codex"], "default_integration": "codex", "integration": "codex",
        }))
        subprocess.run(["git", "init", "-q", str(self.root)], check=True, capture_output=True)
        self.fake = self.root / "fake-codex"
        self.fake.write_text(FAKE_CODEX)
        self.fake.chmod(0o755)
        self.env = {
            **os.environ, "SDD_CODEX_BIN": str(self.fake), "SDD_CODEX_NOTIFY": "0",
            "FAKE_ARGV": str(self.root / "argv.json"),
            "FAKE_EVENTS": json.dumps([message("review report"), {"type": "turn.completed"}]),
            "SPECKIT_INTEGRATION_CODEX_EXTRA_ARGS": "",
        }
        self.install_workflow('''  - id: draft
    type: prompt
    capture: true
    prompt: "$speckit-plan test"
  - id: command
    command: speckit.analyze
    capture: true
  - id: review
    type: gate
    message: "{{ steps.draft.output.stdout }}"
    options: [approve, reject]
    on_reject: retry
  - id: deliver
    type: shell
    run: "printf approved > delivered.txt"
''')

    def install_workflow(self, steps):
        source = self.root / "workflow.yml"
        source.write_text('''schema_version: "1.0"
workflow:
  id: sdd-increment-codex
  name: Codex test
  version: "0.1.0"
  integration: codex
inputs:
  change:
    type: string
    required: true
steps:
''' + steps)
        result = subprocess.run([SPECIFY, "workflow", "add", "--dev", str(source)], cwd=self.root, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)

    def run_runner(self, *args):
        return subprocess.run(
            [sys.executable, str(self.root / "scripts/sdd-codex.py"), *args],
            cwd=self.root, env=self.env, stdin=subprocess.DEVNULL,
            text=True, capture_output=True, timeout=30,
        )

    def state(self):
        paths = list((self.root / ".specify/workflows/runs").glob("*/state.json"))
        self.assertEqual(len(paths), 1)
        return json.loads(paths[0].read_text())

    def test_run_pauses_at_gate_and_status_reports_own_run(self):
        result = self.run_runner("run", "test change")
        state = self.state()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(state["status"], "paused", result.stderr + result.stdout)
        self.assertFalse((self.root / "delivered.txt").exists())
        self.assertIn(state["run_id"], result.stdout)
        self.assertEqual(state["step_results"]["draft"]["output"]["stdout"].strip(), "review report")
        self.assertEqual(state["step_results"]["command"]["output"]["stdout"].strip(), "review report")
        status = self.run_runner("status", state["run_id"])
        self.assertEqual(status.returncode, 0, status.stderr)

    def test_resume_uses_saved_review_then_delivers_after_approval(self):
        self.run_runner("run", "test change")
        state = self.state()
        # A real TTY with one human choice; no gate bypass or fabricated state.
        import pty
        import select
        master, slave = pty.openpty()
        proc = subprocess.Popen(
            [sys.executable, str(self.root / "scripts/sdd-codex.py"), "resume", state["run_id"]],
            cwd=self.root, env=self.env, stdin=slave, stdout=slave, stderr=slave,
        )
        os.close(slave)
        output = b""
        answered = False
        import time
        deadline = time.monotonic() + 20
        try:
            while time.monotonic() < deadline:
                if select.select([master], [], [], 0.1)[0]:
                    try:
                        output += os.read(master, 65536)
                    except OSError:
                        break
                    if b"Choose" in output and not answered:
                        os.write(master, b"1\n")
                        answered = True
                if proc.poll() is not None:
                    break
            self.assertTrue(answered, output.decode(errors="replace"))
            self.assertEqual(proc.wait(timeout=2), 0, output.decode(errors="replace"))
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
            os.close(master)
        self.assertEqual(self.state()["status"], "completed")
        self.assertEqual((self.root / "delivered.txt").read_text(), "approved")

    def test_agent_failure_stops_before_gate_and_delivery(self):
        self.env["FAKE_EXIT"] = "9"
        result = self.run_runner("run", "test failure")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.state()["status"], "failed")
        self.assertFalse((self.root / "delivered.txt").exists())

    def test_resume_rejects_foreign_workflow_and_path_traversal(self):
        runs = self.root / ".specify/workflows/runs/other"
        runs.mkdir(parents=True)
        (runs / "state.json").write_text(json.dumps({"run_id": "other", "workflow_id": "sdd-increment", "status": "paused"}))
        for run_id in ("other", "../other"):
            self.assertNotEqual(self.run_runner("resume", run_id).returncode, 0)

    def test_state_selection_ignores_newer_foreign_workflow(self):
        self.run_runner("run", "test change")
        runs = self.root / ".specify/workflows/runs/foreign"
        runs.mkdir()
        (runs / "state.json").write_text(json.dumps({"run_id": "foreign", "workflow_id": "sdd-increment", "status": "completed"}))
        self.assertEqual(sdd.find_new_state(self.root, set())["workflow_id"], sdd.WORKFLOW)

    def test_blocked_implement_retries_on_resume_before_verification(self):
        make_tasks(self.root)
        self.install_workflow('''  - id: delivery
    type: do-while
    condition: false
    max_iterations: 1
    steps:
      - id: implement
        command: speckit.implement
        capture: true
      - id: verify
        type: shell
        run: "touch verification-ran"
      - id: gui_smoke
        type: gate
        message: GUI review
        options: [approve, reject]
        on_reject: retry
''')
        self.env["FAKE_EVENTS"] = json.dumps([message(delivery_result("blocked", blockers=["I1"])), {"type": "turn.completed"}])
        result = self.run_runner("run", "blocked implementation")
        before = self.state()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(before["step_results"]["implement"]["status"], "failed")
        self.assertFalse((self.root / "verification-ran").exists())
        self.env["FAKE_TASKS_TEXT"] = "- [X] T001 Implement\n- [ ] T002 [MANUAL] GUI check\n"
        self.env["FAKE_EVENTS"] = json.dumps([message(delivery_result(completed=["T001"], manual=["T002"])), {"type": "turn.completed"}])
        self.run_runner("resume", before["run_id"])
        after = self.state()
        self.assertEqual(after["current_step_id"], "gui_smoke")
        self.assertTrue((self.root / "verification-ran").exists())
        log = self.root / ".specify/workflows/runs" / before["run_id"] / "log.jsonl"
        starts = [json.loads(line).get("step_id") for line in log.read_text().splitlines()
                  if json.loads(line).get("event") == "step_started"]
        self.assertEqual(starts.count("implement"), 2)

    def test_legacy_completed_implementation_cannot_resume_to_gui(self):
        run = self.root / ".specify/workflows/runs/legacy"
        run.mkdir(parents=True)
        state = {"run_id": "legacy", "workflow_id": sdd.WORKFLOW, "status": "paused",
                 "current_step_id": "gui_smoke", "step_results": {
                     "implement": {"status": "completed", "output": {"exit_code": 0, "stdout": ""}}}}
        path = run / "state.json"
        path.write_text(json.dumps(state))
        original = path.read_bytes()
        result = self.run_runner("resume", "legacy")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("旧", result.stderr)
        self.assertEqual(path.read_bytes(), original)


class VerificationLogTests(unittest.TestCase):
    def test_failed_output_survives_a_successful_retry(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            commands = [("build", [sys.executable, "-c", "import sys; print('original failure',file=sys.stderr); sys.exit(7)"])]
            self.assertEqual(sdd.verify_workspace(root, commands), 7)
            self.assertEqual(sdd.verify_workspace(root, [("build", [sys.executable, "-c", "print('retry success')"])]), 0)
            outputs = list((root / ".specify/workflows/runs/attempts").rglob("build.stderr.log"))
            self.assertEqual(len(outputs), 2)
            self.assertEqual(sum("original failure" in p.read_text() for p in outputs), 1)


if __name__ == "__main__":
    unittest.main()
