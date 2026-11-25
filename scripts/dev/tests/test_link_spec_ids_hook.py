"""scripts/dev/link-spec-ids-hook.py（MessageDisplay の hook）の回帰テスト。"""

import json
import os
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = "scripts/dev/link-spec-ids-hook.py"
SCRIPTS = (SCRIPT, "scripts/dev/spec_id_definitions.py", "scripts/dev/base-ref.sh")
PRODUCT = {
    "specs/product/search.md": "# 検索\n\n- **FR-080**: 検索できる。\n- **SC-022**: 速い。\n2. **US1-AS1**: **Given** シナリオ\n",
}
LINEAR = "https://linear.app/takyoshida/issue/"


class LinkSpecIdsHookTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name) / "repo"
        self.temp = Path(directory.name) / "tmp"
        self.temp.mkdir()
        (self.root / "scripts/dev").mkdir(parents=True)
        for script in SCRIPTS:
            shutil.copy2(ROOT / script, self.root / script)

    def write_files(self, files):
        for name, text in files.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")

    def commit_base(self, files):
        self.write_files(files)

        def git(*args):
            subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True)
        git("init", "-q", "-b", "master")
        git("add", "-A")
        git("-c", "user.name=test", "-c", "user.email=test@example.com", "commit", "-q", "-m", "base")

    def run_hook(self, delta, message_id="m1", final=True, raw=None, env=None):
        event = raw if raw is not None else {"delta": delta, "message_id": message_id, "index": 0, "final": final}
        result = subprocess.run(
            ["python3", "-I", str(self.root / SCRIPT)],
            input=event if isinstance(event, str) else json.dumps(event),
            capture_output=True,
            text=True,
            env={**os.environ, "TMPDIR": str(self.temp), **(env or {})},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def displayed(self, delta, **kwargs):
        """表示される文を返す。hook が何も出力しなければ、元の delta が表示される。"""
        output = self.run_hook(delta, **kwargs)
        if not output:
            return delta
        payload = json.loads(output)["hookSpecificOutput"]
        self.assertEqual(payload["hookEventName"], "MessageDisplay")
        return payload["displayContent"]

    def test_prints_nothing_without_ids(self):
        self.write_files(PRODUCT)
        self.assertEqual(self.run_hook("ID のない文\n"), "")

    def test_links_spec_ids_to_definition_lines(self):
        self.write_files(PRODUCT)
        self.assertEqual(
            self.displayed("- **SC-022** とFR-080の定義、US1-AS1\n"),
            "- **[SC-022](specs/product/search.md#L4)** と[FR-080](specs/product/search.md#L3)の定義、"
            "[US1-AS1](specs/product/search.md#L5)\n",
        )

    def test_links_linear_issue_ids(self):
        self.write_files(PRODUCT)
        self.assertEqual(self.displayed("TAK-82 の続き\n"), f"[TAK-82]({LINEAR}TAK-82) の続き\n")

    def test_keeps_ids_without_definition(self):
        self.write_files(PRODUCT)
        self.assertEqual(self.run_hook("FR-999 は未定義\n"), "")
        self.assertEqual(self.displayed("FR-999 と FR-080\n"), "FR-999 と [FR-080](specs/product/search.md#L3)\n")

    def test_ignores_mentions_outside_definitions(self):
        self.write_files({"specs/product/search.md": "# 検索\n\nFR-080 を参照する文。\n\n- **FR-080**: 定義。\n"})
        self.assertEqual(self.displayed("FR-080\n"), "[FR-080](specs/product/search.md#L5)\n")

    def test_keeps_existing_links_urls_and_inline_code(self):
        self.write_files(PRODUCT)
        delta = (
            "[FR-080](specs/product/search.md#L3) と `SC-022` と ``US1-AS1``\n"
            f"{LINEAR}TAK-82 と specs/TAK-82-foo/spec.md\n"
        )
        self.assertEqual(self.run_hook(delta), "")

    def test_keeps_ids_in_code_fence_across_deltas(self):
        self.write_files(PRODUCT)
        self.assertEqual(self.displayed("```text\nFR-080\n", final=False), "```text\nFR-080\n")
        self.assertEqual(self.displayed("SC-022 はまだ中\n", final=False), "SC-022 はまだ中\n")
        self.assertEqual(
            self.displayed("```\nFR-080 は外\n", final=True),
            "```\n[FR-080](specs/product/search.md#L3) は外\n",
        )
        self.assertEqual(list(self.temp.glob("folzio-link-spec-ids-*")), [])

    def test_tracks_fence_per_message(self):
        self.write_files(PRODUCT)
        self.displayed("~~~\n", message_id="a", final=False)
        self.assertEqual(self.displayed("FR-080\n", message_id="b"), "[FR-080](specs/product/search.md#L3)\n")
        self.assertEqual(self.displayed("FR-080\n", message_id="a"), "FR-080\n")

    def test_prefers_feature_in_progress_over_product(self):
        self.commit_base({**PRODUCT, "specs/TAK-1-done/spec.md": "- **FR-080**: 凍結した定義。\n"})
        self.write_files({"specs/TAK-2-new/spec.md": "# 新\n\n- **FR-080**: 変更後。\n- **FR-900**: 新規。\n"})
        self.assertEqual(
            self.displayed("FR-080 と FR-900 と SC-022\n"),
            "[FR-080](specs/TAK-2-new/spec.md#L3) と [FR-900](specs/TAK-2-new/spec.md#L4) と "
            "[SC-022](specs/product/search.md#L4)\n",
        )

    def test_ignores_frozen_features(self):
        self.commit_base({**PRODUCT, "specs/003-old/spec.md": "- **SC-022**: 凍結した定義。\n"})
        self.assertEqual(self.displayed("SC-022\n"), "[SC-022](specs/product/search.md#L4)\n")

    def test_wraps_path_with_spaces_in_angle_brackets(self):
        self.write_files({"specs/product/two words.md": "- **FR-080**: 定義。\n"})
        self.assertEqual(self.displayed("FR-080\n"), "[FR-080](<specs/product/two words.md#L1>)\n")

    def test_prints_nothing_on_bad_input_or_spec_errors(self):
        self.write_files({"specs/product/broken.md": "```\n- **FR-080**: 閉じていないフェンス\n"})
        self.assertEqual(self.run_hook("FR-080\n"), "")
        self.assertEqual(self.run_hook(None, raw="not json"), "")
        self.assertEqual(self.run_hook(None, raw={"message_id": "m1"}), "")

    def test_message_with_ids_is_fast_enough(self):
        self.write_files(PRODUCT)
        start = time.monotonic()
        self.run_hook("SC-022 FR-080 US1-AS1 TAK-82\n")
        self.assertLess(time.monotonic() - start, 2.0)

    def test_repository_ids_are_linked(self):
        """実際のリポジトリで、find-spec-id.sh と同じ定義を指すこと（SC-022 は凍結した feature にもある）。"""
        expected = subprocess.run(
            [str(ROOT / "scripts/dev/find-spec-id.sh"), "SC-022"], capture_output=True, text=True, check=True,
        ).stdout.splitlines()[0]
        result = subprocess.run(
            ["python3", "-I", str(ROOT / SCRIPT)],
            input=json.dumps({"delta": "SC-022\n", "message_id": "repo", "final": True}),
            capture_output=True,
            text=True,
            env={**os.environ, "TMPDIR": str(self.temp)},
        )
        content = json.loads(result.stdout)["hookSpecificOutput"]["displayContent"]
        self.assertEqual(content, expected + "\n")


if __name__ == "__main__":
    unittest.main()
