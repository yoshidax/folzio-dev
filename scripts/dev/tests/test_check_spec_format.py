import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]

CONFIG = {
    "line_width_warning": 120,
    "line_width_error": 160,
    "cell_width_warning": 80,
    "exclusions": [],
}

VALID = """# 領域

この領域の仕様。`specs/product/README.md` を参照（「検索」メニュー）。

## 機能要件

- **FR-001**: ユーザーは、「ファイル」メニューの「検索…」で検索を始められなければならない。
  - 条件は子項目に書く（“Find…” と表示する）

| キー | 内容 | 要件 |
|---|---|---|
| ⌘F | 検索を開く | FR-001 |
| ⌃⌘2 | 下記 | FR-002 |
| 設定 | 下記 | — |
| 設定 | 文字列 `a \\| b` を含む | — |

**表の詳細**

- **⌃⌘2 / 表示 > ファイルリストのみ表示**（FR-002）
  - ツリーとプレビューを隠す
- **設定 / 補足説明**（内容）: 説明を表示する

```text
| not a table
「not closed in code
""" + "x" * 200 + """
```
"""


class CheckSpecFormatTests(unittest.TestCase):
    def run_check(self, files, config=None, baseline=None, args=()):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dev = root / "scripts/dev"
            dev.mkdir(parents=True)
            shutil.copy2(ROOT / "scripts/dev/check-spec-format.py", dev / "check-spec-format.py")
            (dev / "spec-format-config.json").write_text(json.dumps(config or CONFIG, ensure_ascii=False))
            if baseline is not None:
                (dev / "spec-format-baseline.json").write_text(json.dumps(baseline, ensure_ascii=False))
            for name, text in files.items():
                path = root / "specs/product" / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text)
            result = subprocess.run([sys.executable, str(dev / "check-spec-format.py"), *args],
                                    capture_output=True, text=True)
            baseline_path = dev / "spec-format-baseline.json"
            saved = json.loads(baseline_path.read_text()) if baseline_path.exists() else None
            return result, saved

    def assert_finding(self, result, location, severity, rule):
        self.assertIn("specs/product/{}: {} {}:".format(location, severity, rule), result.stdout)

    def test_passes_on_valid_document(self):
        result, _ = self.run_check({"a.md": VALID})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Errors: 0", result.stdout)
        self.assertIn("Warnings: 0", result.stdout)

    def test_line_wider_than_error_limit_fails(self):
        result, _ = self.run_check({"a.md": "- " + "あ" * 80 + "\n"})
        self.assertEqual(result.returncode, 1)
        self.assert_finding(result, "a.md:1", "error", "line-width")

    def test_display_width_counts_wide_characters_and_indent(self):
        # 59 wide characters (118 columns) plus a two-space indent is 120 columns: no warning.
        at_limit = "  " + "あ" * 59 + "\n"
        # Ambiguous characters such as → count as one column.
        ambiguous = "→" * 120 + "\n"
        over = "   " + "あ" * 59 + "\n"
        result, _ = self.run_check({"a.md": at_limit + ambiguous}, baseline={"warnings": {}})
        self.assertEqual(result.returncode, 0, result.stdout)
        result, _ = self.run_check({"a.md": over}, baseline={"warnings": {}})
        self.assertEqual(result.returncode, 1)
        self.assert_finding(result, "a.md:1", "warning", "line-width")

    def test_table_row_split_fails(self):
        unterminated = "| a | b |\n|---|---|\n| c | d\n"
        continued = "| a | b |\n|---|---|\n| c | d\n  e |\n"
        result, _ = self.run_check({"a.md": unterminated})
        self.assertEqual(result.returncode, 1)
        self.assert_finding(result, "a.md:3", "error", "table-row-split")
        result, _ = self.run_check({"a.md": continued})
        self.assert_finding(result, "a.md:4", "error", "table-row-split")

    def test_table_columns_separator_and_empty_fail(self):
        result, _ = self.run_check({"a.md": "| a | b |\n|---|---|\n| c | d | e |\n"})
        self.assert_finding(result, "a.md:3", "error", "table-columns")
        result, _ = self.run_check({"a.md": "| a | b |\n| c | d |\n"})
        self.assert_finding(result, "a.md:2", "error", "table-separator")
        result, _ = self.run_check({"a.md": "| a | b |\n|---|---|\n\ntext\n"})
        self.assertEqual(result.returncode, 1)
        self.assert_finding(result, "a.md:1", "error", "table-empty")

    def test_escaped_pipe_is_not_a_column(self):
        result, _ = self.run_check({"a.md": "| a | b |\n|---|---|\n| `x \\| y` | d |\n"})
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_inline_code_split_fails(self):
        result, _ = self.run_check({"a.md": "- `scripts/dev/\n  check.sh` を実行する\n"})
        self.assertEqual(result.returncode, 1)
        self.assert_finding(result, "a.md:1", "error", "code-split")

    def test_quote_split_fails(self):
        result, _ = self.run_check({"a.md": "- 「名前の変更・\n  移動」を選ぶ\n"})
        self.assertEqual(result.returncode, 1)
        self.assert_finding(result, "a.md:1", "error", "quote-split")
        self.assert_finding(result, "a.md:2", "error", "quote-split")
        result, _ = self.run_check({"a.md": "- “Copy\n  Item” を表示する\n"})
        self.assert_finding(result, "a.md:1", "error", "quote-split")

    def test_nested_quotes_and_quotes_in_code_pass(self):
        text = "- 「外側の「内側」の引用」と `「` を書く\n"
        result, _ = self.run_check({"a.md": text})
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_english_split_fails(self):
        result, _ = self.run_check({"a.md": "- 英語は Sentence\n  case にする\n"})
        self.assertEqual(result.returncode, 1)
        self.assert_finding(result, "a.md:2", "error", "english-split")

    def test_english_word_before_child_item_passes(self):
        result, _ = self.run_check({"a.md": "- 対象は zip\n  - zip の中も含める\n- 末尾が English\n  日本語の続き\n"})
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_see_below_without_detail_fails(self):
        text = "| キー | 内容 |\n|---|---|\n| ⌘F | 下記 |\n\n**表の詳細**\n\n- **⌘G**（内容）: 別の項目\n"
        result, _ = self.run_check({"a.md": text})
        self.assertEqual(result.returncode, 1)
        self.assert_finding(result, "a.md:3", "error", "see-below-detail")
        result, _ = self.run_check({"a.md": "| キー | 内容 |\n|---|---|\n| ⌘F | 下記 |\n"})
        self.assert_finding(result, "a.md:3", "error", "see-below-detail")

    def test_cell_width_warning_against_baseline(self):
        text = "| キー | 内容 |\n|---|---|\n| a | " + "あ" * 41 + " |\n"
        result, _ = self.run_check({"a.md": text}, baseline={"warnings": {}})
        self.assertEqual(result.returncode, 1)
        self.assert_finding(result, "a.md:3", "warning", "cell-width")
        self.assertIn("a.md cell-width: 1 > 0", result.stdout)
        result, _ = self.run_check({"a.md": text}, baseline={"warnings": {"a.md": {"cell-width": 1}}})
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_multi_sentence_definition_warning(self):
        text = "- **FR-001**: 一つ目の文。二つ目の\n  文。\n  - 子項目。子項目の二文目。\n- **US1-AS1**: 一文だけ。\n"
        result, _ = self.run_check({"a.md": text}, baseline={"warnings": {}})
        self.assertEqual(result.returncode, 1)
        self.assert_finding(result, "a.md:1", "warning", "multi-sentence")
        self.assertNotIn("a.md:4:", result.stdout)

    def test_decreased_warnings_pass_and_suggest_update(self):
        result, _ = self.run_check({"a.md": "text\n"}, baseline={"warnings": {"a.md": {"line-width": 2}}})
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("--update-baseline", result.stdout)

    def test_update_baseline_records_counts(self):
        text = "- " + "あ" * 60 + "\n" + "- " + "い" * 60 + "\n"
        result, saved = self.run_check({"a.md": text}, baseline={"warnings": {"gone.md": {"line-width": 3}}},
                                       args=["--update-baseline"])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        # Entries of files that were not checked are kept.
        self.assertEqual(saved, {"warnings": {"a.md": {"line-width": 2}, "gone.md": {"line-width": 3}}})

    def test_update_baseline_refused_with_errors(self):
        result, saved = self.run_check({"a.md": "- 「閉じない\n"}, baseline={"warnings": {}},
                                       args=["--update-baseline"])
        self.assertEqual(result.returncode, 1)
        self.assertEqual(saved, {"warnings": {}})

    def test_exclusions_apply_only_to_listed_rules_and_ranges(self):
        text = ("# 領域\n\n## 引用\n\n「長い引用の\n途中」\n\n## 次\n\n「別の\n引用」\n\n"
                "| 日本語 | 英語 |\n|---|---|\n| " + "あ" * 41 + " | b |\n\n"
                "| キー | 内容 |\n|---|---|\n| a | " + "い" * 41 + " |\n")
        config = dict(CONFIG, exclusions=[
            {"file": "a.md", "section": "## 引用", "rules": ["quote-split"], "reason": "test"},
            {"file": "a.md", "table_columns": ["日本語", "英語"], "rules": ["cell-width"], "reason": "test"},
        ])
        result, _ = self.run_check({"a.md": text}, config=config, baseline={"warnings": {}})
        self.assertNotIn("a.md:5:", result.stdout)
        self.assertNotIn("a.md:6:", result.stdout)
        self.assert_finding(result, "a.md:10", "error", "quote-split")
        self.assertNotIn("a.md:15:", result.stdout)
        self.assert_finding(result, "a.md:19", "warning", "cell-width")

    def test_exclusion_that_matches_nothing_is_a_config_error(self):
        config = dict(CONFIG, exclusions=[
            {"file": "a.md", "section": "## ない", "rules": ["quote-split"], "reason": "test"}])
        result, _ = self.run_check({"a.md": VALID}, config=config)
        self.assertEqual(result.returncode, 2)
        config = dict(CONFIG, exclusions=[
            {"file": "missing.md", "rules": ["quote-split"], "reason": "test"}])
        result, _ = self.run_check({"a.md": VALID}, config=config)
        self.assertEqual(result.returncode, 2)

    def test_missing_path_is_an_error(self):
        result, _ = self.run_check({"a.md": VALID}, args=["specs/product/missing.md"])
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
