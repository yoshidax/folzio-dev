import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]

BASE = """# 検索

## 機能要件

- **FR-001**: ユーザーは、「ファイル」メニューの「検索…」で検索を始められなければならない。前後の空白は除き、空のときは何もしない。
- **FR-002**: 検索結果は一覧に表示しなければならない。

| キー | 内容 | 要件 |
|---|---|---|
| ⌘F | 検索を開く。どのペインにフォーカスがあっても使える | FR-001 |
| ⌘G | 次を検索する | FR-002 |
"""

REFLOWED = """# 検索

## 機能要件

- **FR-001**: ユーザーは、「ファイル」メニューの「検索…」で
  検索を始められなければならない。
  - 前後の空白は除き、空のときは何もしない
- **FR-002**: 検索結果は一覧に表示しなければならない。

| キー | 内容 | 要件 |
|-----|------|------|
| ⌘F | 検索を開く。どのペインにフォーカスがあっても使える | FR-001 |
| ⌘G | 次を検索する | FR-002 |
"""

MOVED_TO_DETAILS = """# 検索

## 機能要件

- **FR-001**: ユーザーは、「ファイル」メニューの「検索…」で検索を始められなければならない。前後の空白は除き、空のときは何もしない。
- **FR-002**: 検索結果は一覧に表示しなければならない。

| キー | 内容 | 要件 |
|---|---|---|
| ⌘F | 下記 | FR-001 |
| ⌘G | 次を検索する | FR-002 |

**表の詳細**

- **⌘F**（内容）: 検索を開く。
  - どのペインにフォーカスがあっても使える
"""


class CheckSpecEquivalenceTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        dev = self.root / "scripts/dev"
        dev.mkdir(parents=True)
        shutil.copy2(ROOT / "scripts/dev/check-spec-equivalence.py", dev / "check-spec-equivalence.py")
        self.git("init", "-q", "-b", "master")
        self.git("config", "user.email", "test@example.com")
        self.git("config", "user.name", "Test")

    def tearDown(self):
        self.directory.cleanup()

    def git(self, *args):
        subprocess.run(["git", *args], cwd=str(self.root), check=True, capture_output=True)

    def write(self, name, text):
        path = self.root / "specs/product" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def commit_base(self, files):
        for name, text in files.items():
            self.write(name, text)
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "base")

    def run_check(self, base="master"):
        script = self.root / "scripts/dev/check-spec-equivalence.py"
        return subprocess.run([sys.executable, str(script), base], capture_output=True, text=True)

    def test_reflow_and_nesting_only_pass(self):
        self.commit_base({"search.md": BASE})
        self.write("search.md", REFLOWED)
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("No differences other than formatting.", result.stdout)

    def test_move_to_table_details_passes_and_is_listed(self):
        self.commit_base({"search.md": BASE})
        self.write("search.md", MOVED_TO_DETAILS)
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        # Which side the diff keeps in place is up to the alignment; either way, one move is listed.
        self.assertIn("moved   search.md:10 -> search.md:", result.stdout)
        self.assertIn("Moved: 1, added: 0, removed: 0", result.stdout)

    def test_moved_table_row_with_label_passes(self):
        self.commit_base({"search.md": BASE})
        text = BASE.replace("| ⌘G | 次を検索する | FR-002 |\n", "") + "\n**表の詳細**\n\n- **⌘G**（FR-002）: 次を検索する\n"
        self.write("search.md", text)
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("moved", result.stdout)

    def test_reordered_sentences_pass_as_moves(self):
        self.commit_base({"search.md": BASE})
        text = BASE.replace("- **FR-002**: 検索結果は一覧に表示しなければならない。\n", "")
        text = text.replace("## 機能要件\n\n", "## 機能要件\n\n- **FR-002**: 検索結果は一覧に表示しなければならない。\n")
        self.write("search.md", text)
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("moved", result.stdout)

    def test_changed_word_fails(self):
        self.commit_base({"search.md": BASE})
        self.write("search.md", BASE.replace("空のときは何もしない", "空のときは警告する"))
        result = self.run_check()
        self.assertEqual(result.returncode, 1)
        self.assertIn("added   search.md:5", result.stdout)
        self.assertIn("removed search.md:5", result.stdout)

    def test_added_sentence_fails(self):
        self.commit_base({"search.md": BASE})
        self.write("search.md", BASE + "\n- **FR-003**: 新しい要件を追加する。\n")
        result = self.run_check()
        self.assertEqual(result.returncode, 1)
        self.assertIn("added   search.md:13  FR-003:新しい要件を追加する", result.stdout)

    def test_removed_sentence_fails(self):
        self.commit_base({"search.md": BASE})
        self.write("search.md", BASE.replace("前後の空白は除き、空のときは何もしない。", ""))
        result = self.run_check()
        self.assertEqual(result.returncode, 1)
        # The boundary of the fragment may shift by the characters it shares with its neighbors.
        self.assertIn("removed search.md:5  ", result.stdout)
        self.assertIn("前後の空白は除き空のときは何もし", result.stdout)
        self.assertIn("Moved: 0, added: 0, removed: 1", result.stdout)

    def test_uncommitted_and_untracked_files_are_compared(self):
        self.commit_base({"search.md": BASE})
        self.write("new.md", "# 新しい領域\n")
        result = self.run_check()
        self.assertEqual(result.returncode, 1)
        self.assertIn("added   new.md:1  新しい領域", result.stdout)

    def test_move_between_files_passes(self):
        self.commit_base({"search.md": BASE, "other.md": "# 他\n"})
        self.write("search.md", BASE.replace("- **FR-002**: 検索結果は一覧に表示しなければならない。\n", ""))
        self.write("other.md", "# 他\n\n- **FR-002**: 検索結果は一覧に表示しなければならない。\n")
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("moved   search.md:6 -> other.md:3", result.stdout)

    def test_deleted_file_fails(self):
        self.commit_base({"search.md": BASE, "other.md": "# 他の領域\n"})
        (self.root / "specs/product/other.md").unlink()
        result = self.run_check()
        self.assertEqual(result.returncode, 1)
        self.assertIn("removed other.md:1  他の領域", result.stdout)

    def test_compares_with_merge_base(self):
        self.commit_base({"search.md": BASE})
        self.git("checkout", "-q", "-b", "work")
        self.git("checkout", "-q", "master")
        self.write("search.md", BASE + "\n- **FR-009**: master だけの変更。\n")
        self.git("commit", "-q", "-am", "master change")
        self.git("checkout", "-q", "work")
        result = self.run_check("master")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_unknown_revision_is_an_error(self):
        self.commit_base({"search.md": BASE})
        result = self.run_check("no-such-revision")
        self.assertEqual(result.returncode, 2)
        self.assertIn("unknown revision", result.stderr)

    def test_unrelated_history_is_an_error(self):
        self.commit_base({"search.md": BASE})
        self.git("checkout", "-q", "--orphan", "other")
        self.git("commit", "-q", "--allow-empty", "-m", "unrelated")
        self.git("checkout", "-q", "master")
        result = self.run_check("other")
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
