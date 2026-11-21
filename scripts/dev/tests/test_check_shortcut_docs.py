"""ショートカットの表と既定のキーの照合検査の回帰テスト。"""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "scripts/dev/check-shortcut-docs.py"
SWIFT = "Sources/FolzioCore/Shortcuts/ShortcutCommand.swift"
DOCUMENTS = ("docs/usage.md", "docs/usage.ja.md", "README.md", "README.ja.md")


class CheckShortcutDocsTests(unittest.TestCase):
    def run_check(self, replacements=None):
        """実際の定義と文書を一時ディレクトリへ写し、(ファイル, 置換前, 置換後) を適用して検査する。"""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in (SWIFT, *DOCUMENTS):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text((ROOT / name).read_text(encoding="utf-8"), encoding="utf-8")
            for name, old, new in replacements or []:
                path = root / name
                text = path.read_text(encoding="utf-8")
                self.assertEqual(text.count(old), 1, f"{name} に置換対象がちょうど 1 つない: {old}")
                path.write_text(text.replace(old, new), encoding="utf-8")
            return subprocess.run(
                [sys.executable, "-I", str(SCRIPT), "--root", str(root)], capture_output=True, text=True
            )

    def test_accepts_the_current_repository(self):
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_reports_both_the_stale_key_and_the_missing_key_when_a_default_changes(self):
        result = self.run_check([
            (SWIFT, 'id: .duplicate, defaultCombination: key("d", [.command])',
             'id: .duplicate, defaultCombination: key("e", [.command])'),
        ])
        self.assertEqual(result.returncode, 1)
        for name in ("docs/usage.md", "docs/usage.ja.md"):
            self.assertIn(f"{name}: duplicate の既定のキー ⌘E が", result.stderr)
            self.assertRegex(result.stderr, rf"{name}:\d+: ⌘D は既定のキー")
        # README の表は部分集合なので、載っていないキーは食い違いにしない。
        self.assertNotIn("README", result.stderr)

    def test_reports_a_stale_key_in_the_readme(self):
        result = self.run_check([
            ("README.md", "| Create a new folder | ⇧⌘N |", "| Create a new folder | ⇧⌘K |"),
        ])
        self.assertEqual(result.returncode, 1)
        self.assertRegex(result.stderr, r"README\.md:\d+: ⇧⌘K は既定のキー")

    def test_requires_every_default_key_in_the_guide_tables(self):
        # 表の外（箇条書き）にキーがあっても、表にあるとは扱わない。
        result = self.run_check([
            ("docs/usage.ja.md", "| 履歴を戻る／進む | ⌘[ / ⌘]、移動メニュー、ツールバー |\n", ""),
        ])
        self.assertEqual(result.returncode, 1)
        self.assertIn("docs/usage.ja.md: back の既定のキー ⌘[ が「ショートカット一覧」の表にない", result.stderr)
        self.assertIn("docs/usage.ja.md: forward の既定のキー ⌘] が", result.stderr)
        self.assertNotIn("docs/usage.md", result.stderr)

    def test_accepts_alternates_reserved_and_fixed_keys_and_the_minus_sign(self):
        result = self.run_check([
            ("README.md", "| Create a new folder | ⇧⌘N |",
             "| Create a new folder | ⇧⌘N, ⌘=, ⌘Q, ⇧Tab, ⌥→, ⌘−, ⌘-click |"),
        ])
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_a_modifier_order_other_than_the_menu_order(self):
        result = self.run_check([
            ("README.md", "| Create a new folder | ⇧⌘N |", "| Create a new folder | ⌘⇧N |"),
        ])
        self.assertEqual(result.returncode, 1)
        self.assertIn("⌘⇧N は既定のキー", result.stderr)

    def test_fails_when_a_command_cannot_be_read_from_the_definition(self):
        result = self.run_check([
            (SWIFT, "    case shortcuts\n", "    case shortcuts\n    case unread\n"),
        ])
        self.assertEqual(result.returncode, 1)
        self.assertIn("ShortcutCommandID と一致しない（読めない: ['unread']", result.stderr)

    def test_fails_when_the_heading_of_a_table_is_missing(self):
        result = self.run_check([
            ("README.ja.md", "## よく使うショートカット\n", "## ショートカット\n"),
        ])
        self.assertEqual(result.returncode, 1)
        self.assertIn("README.ja.md: 見出し「## よく使うショートカット」が見つからない", result.stderr)


if __name__ == "__main__":
    unittest.main()
