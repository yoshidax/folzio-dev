import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "scripts/dev/strip-readme-dev-note.sh"

START = "<!-- dev-repo-note:start -->"
END = "<!-- dev-repo-note:end -->"

ORIGINAL = """# Folzio

English | [日本語](README.ja.md)

**Browse and organize your images.**

## Features
"""

WITH_NOTE = """# Folzio

English | [日本語](README.ja.md)

<!-- dev-repo-note:start -->
> [!NOTE]
> This is the development repository. Visit [yoshidax/folzio](https://github.com/yoshidax/folzio).
<!-- dev-repo-note:end -->

**Browse and organize your images.**

## Features
"""


class StripReadmeDevNoteTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)

    def tearDown(self):
        self.directory.cleanup()

    def write(self, name, text):
        path = self.root / name
        path.write_text(text)
        return path

    def run_script(self, *paths):
        return subprocess.run(["bash", str(SCRIPT), *map(str, paths)],
                              capture_output=True, text=True)

    def assert_rejected(self, text, reason=None):
        path = self.write("README.md", text)
        result = self.run_script(path)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(str(path), result.stderr)
        if reason is not None:
            self.assertIn(reason, result.stderr)
        self.assertEqual(path.read_text(), text)

    def test_removes_note_and_following_blank_line(self):
        path = self.write("README.md", WITH_NOTE)
        result = self.run_script(path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(path.read_text(), ORIGINAL)

    def test_keeps_following_line_when_it_is_not_blank(self):
        path = self.write("README.md", f"# Folzio\n\n{START}\n> note\n{END}\ntext\n")
        result = self.run_script(path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(path.read_text(), "# Folzio\n\ntext\n")

    def test_removes_note_at_end_of_file(self):
        path = self.write("README.md", f"# Folzio\n\n{START}\n> note\n{END}\n")
        result = self.run_script(path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(path.read_text(), "# Folzio\n\n")

    def test_leaves_file_without_markers_unchanged(self):
        path = self.write("README.md", ORIGINAL)
        result = self.run_script(path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(path.read_text(), ORIGINAL)

    def test_leaves_file_without_markers_or_final_newline_unchanged(self):
        path = self.write("README.md", "# Folzio\n\nNo final newline")
        result = self.run_script(path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(path.read_text(), "# Folzio\n\nNo final newline")

    def test_keeps_missing_final_newline_when_removing_note(self):
        path = self.write("README.md", f"# A\n\n{START}\n> n\n{END}\n\nB")
        result = self.run_script(path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(path.read_text(), "# A\n\nB")

    def test_reports_crlf_marker_lines(self):
        text = f"# A\r\n\r\n{START}\r\n> n\r\n{END}\r\n\r\nB\r\n"
        path = self.root / "README.md"
        path.write_bytes(text.encode())
        result = self.run_script(path)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("CRLF", result.stderr)
        self.assertEqual(path.read_bytes(), text.encode())

    def test_reports_file_name_with_backslash_verbatim(self):
        path = self.write("x\\ty.md", f"{START}\n> note\n")
        result = self.run_script(path)
        self.assertEqual(result.returncode, 1)
        self.assertIn(str(path), result.stderr)

    def test_reads_file_whose_name_contains_equals_sign(self):
        path = self.write("x=y.md", WITH_NOTE)
        result = self.run_script(path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(path.read_text(), ORIGINAL)

    def test_processes_each_file(self):
        english = self.write("README.md", WITH_NOTE)
        japanese = self.write("README.ja.md", WITH_NOTE.replace("English", "日本語"))
        result = self.run_script(english, japanese)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(english.read_text(), ORIGINAL)
        self.assertEqual(japanese.read_text(), ORIGINAL.replace("English", "日本語"))

    def test_rejects_start_without_end(self):
        self.assert_rejected(f"# Folzio\n\n{START}\n> note\n")

    def test_rejects_end_without_start(self):
        self.assert_rejected(f"# Folzio\n\n> note\n{END}\n")

    def test_rejects_end_before_start(self):
        self.assert_rejected(f"# Folzio\n\n{END}\n> note\n{START}\n")

    def test_rejects_nested_start(self):
        self.assert_rejected(f"{START}\n{START}\n> note\n{END}\n{END}\n")

    def test_rejects_two_ranges(self):
        self.assert_rejected(f"{START}\n> one\n{END}\n\n{START}\n> two\n{END}\n")

    def test_rejects_marker_inside_a_line(self):
        self.assert_rejected(f"# Folzio\n\nText {START}\n> note\n{END}\n")

    def test_rejects_indented_marker(self):
        self.assert_rejected(f"# Folzio\n\n  {START}\n> note\n{END}\n")

    def test_rejects_missing_file(self):
        result = self.run_script(self.root / "missing.md")
        self.assertEqual(result.returncode, 1)
        self.assertIn("missing.md", result.stderr)

    def test_rejected_file_leaves_every_file_unchanged(self):
        valid = self.write("README.md", WITH_NOTE)
        broken = self.write("README.ja.md", f"{START}\n> note\n")
        result = self.run_script(valid, broken)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(valid.read_text(), WITH_NOTE)
        self.assertEqual(broken.read_text(), f"{START}\n> note\n")


if __name__ == "__main__":
    unittest.main()
