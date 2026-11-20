"""scripts/dev/check-spec-ids.sh の回帰テスト。"""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = ("check-spec-ids.sh", "check-spec-ids.py", "spec_id_definitions.py")


class CheckSpecIdsTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.root = self.directory / "test repo"
        dev = self.root / "scripts/dev"
        dev.mkdir(parents=True)
        for name in SCRIPTS:
            shutil.copy2(ROOT / "scripts/dev" / name, dev / name)

    def write_file(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path

    def run_check(self):
        return subprocess.run(
            ["bash", str(self.root / "scripts/dev/check-spec-ids.sh")],
            cwd=self.directory,
            capture_output=True,
            text=True,
        )

    def test_reports_all_duplicate_ids_and_locations(self):
        labels = ["FR-001", "SC-002", "EC-03", "A-04", "US87-AS1"]
        self.write_file("specs/product/area.md", "".join(f"  - **{label}**: 項目。\n" for label in labels))
        self.write_file(
            "specs/product/contracts/another area.md",
            "\n" + "".join(f"- **{label}**: 再定義。\n" for label in labels[:-1]) + "  2. **US87-AS1**: 再定義。\n",
        )
        result = self.run_check()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertEqual(result.stdout, "")
        for number, label in enumerate(labels, start=1):
            self.assertIn(
                f"\n{label}\n  specs/product/area.md:{number}\n"
                f"  specs/product/contracts/another area.md:{number + 1}\n",
                result.stderr,
            )

    def test_reports_every_occurrence_in_the_same_file(self):
        self.write_file("specs/product/area.md", "1. **US2-AS3**\n\n2. **US2-AS3**\n\n- **US2-AS3**\n")
        result = self.run_check()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(
            "US2-AS3\n  specs/product/area.md:1\n  specs/product/area.md:3\n  specs/product/area.md:5\n",
            result.stderr,
        )

    def test_allows_different_headings_for_the_same_story_with_distinct_scenarios(self):
        self.write_file("specs/product/area.md", "### US34 選んだ言語で一覧を参照する（P2）\n- **US34-AS1**\n")
        self.write_file("specs/product/other.md", "### US34 キーボードと読み上げで一覧を参照する\n2. **US34-AS2**\n")
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "No duplicated spec IDs.\n")

    def test_ignores_references_examples_and_files_outside_the_product_specs(self):
        self.write_file(
            "specs/product/area.md",
            "- **FR-001**: 定義。\n"
            "- 詳細は **FR-001** を参照。\n"
            "````markdown\n```\n- **FR-001**: 使用例。\n````\n"
            "~~~\n2. **FR-001**: 使用例。\n~~~\n",
        )
        self.write_file("specs/product/notes.txt", "- **FR-001**: 参考。\n")
        self.write_file("specs/001-example/spec.md", "- **FR-001**: 元の定義。\n")
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_fails_if_product_directory_is_missing(self):
        result = self.run_check()
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("specs/product", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_fails_if_product_directory_is_unreadable(self):
        product = self.write_file("specs/product/area.md", "- **FR-001**\n").parent
        self.addCleanup(product.chmod, 0o755)
        product.chmod(0)
        try:
            list(product.iterdir())
        except PermissionError:
            pass
        else:
            self.skipTest("ディレクトリのアクセス権が適用されない環境")
        result = self.run_check()
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("specs/product", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_fails_if_a_markdown_file_cannot_be_read(self):
        area = self.write_file("specs/product/area.md", "- **FR-001**\n")
        area.with_name("broken.md").symlink_to("missing.md")
        result = self.run_check()
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("specs/product/broken.md", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_fails_if_a_markdown_file_cannot_be_decoded(self):
        area = self.write_file("specs/product/area.md", "")
        area.write_bytes(b"\xff")
        result = self.run_check()
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("specs/product/area.md", result.stderr)
        self.assertEqual(result.stdout, "")
