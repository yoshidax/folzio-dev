import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


class CheckAgentsMdTests(unittest.TestCase):
    def run_check(self, text, files=()):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dev = root / "scripts/dev"
            dev.mkdir(parents=True)
            shutil.copy2(ROOT / "scripts/dev/check-agents-md.sh", dev / "check-agents-md.sh")
            for name in files:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                if name.endswith("/"):
                    path.mkdir(exist_ok=True)
                else:
                    path.write_text("x\n")
            (root / "AGENTS.md").write_text(text)
            return subprocess.run([str(dev / "check-agents-md.sh")], capture_output=True, text=True)

    def lines(self, count):
        return "".join(f"line {i}\n" for i in range(count))

    def test_passes_without_warning_at_45_lines(self):
        result = self.run_check(self.lines(45))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("warning", result.stderr)

    def test_warns_but_passes_between_46_and_50_lines(self):
        for count in (46, 50):
            result = self.run_check(self.lines(count))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("warning: AGENTS.md has", result.stderr)

    def test_fails_above_50_lines(self):
        result = self.run_check(self.lines(51))
        self.assertEqual(result.returncode, 1)
        self.assertIn("AGENTS.md has 51 lines (limit: 50)", result.stderr)
        self.assertIn("docs_private/agents/README.md", result.stderr)

    def test_passes_when_referenced_paths_exist(self):
        text = "Read `docs/guide.md` and `specs/product/`. Run `python3 scripts/dev/check.py`.\n"
        result = self.run_check(text, files=("docs/guide.md", "specs/product/", "scripts/dev/check.py"))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_fails_when_referenced_path_is_missing(self):
        result = self.run_check("Read `docs/guide.md` and `docs/old.md`.\n", files=("docs/guide.md",))
        self.assertEqual(result.returncode, 1)
        self.assertIn("  docs/old.md", result.stderr)
        self.assertNotIn("  docs/guide.md", result.stderr)

    def test_ignores_globs_placeholders_urls_build_output_and_plain_words(self):
        text = ("`specs/TAK-*` `specs/TAK-<nn>-<slug>` `claude/*` `https://example.com/x` "
                "`open .build/Folzio.app` `FolzioCore` `brew install`\n")
        result = self.run_check(text)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_passes_without_any_backticks(self):
        result = self.run_check("Plain text only.\n")
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
