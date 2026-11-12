"""scripts/dev/find-spec-id.sh の回帰テスト。"""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = "scripts/dev/find-spec-id.sh"


class FindSpecIdTests(unittest.TestCase):
    def run_find(self, files, *ids, cwd=None):
        """files（パス → 内容）を置いた一時リポジトリで、スクリプトを実行する。"""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts/dev").mkdir(parents=True)
            shutil.copy2(ROOT / SCRIPT, root / SCRIPT)
            for name, text in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding="utf-8")
            return subprocess.run(
                [str(root / SCRIPT), *ids],
                capture_output=True,
                text=True,
                cwd=cwd or directory,
            )

    def test_prints_path_and_line_of_bullet_definition(self):
        result = self.run_find(
            {"specs/product/search.md": "# 検索\n\n- **FR-080**: 検索できる。\n"},
            "FR-080",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "FR-080 specs/product/search.md:3\n")

    def test_finds_all_id_kinds_including_numbered_scenarios(self):
        text = "\n".join(
            [
                "- **SC-001**: 成功の基準。",
                "  - **EC-002**: 子項目の定義。",
                "- **A-003**: 前提。",
                "2. **US30-AS2**: **Given** 番号付きリストのシナリオ,",
            ]
        )
        result = self.run_find({"specs/product/overview.md": text + "\n"}, "SC-001", "EC-002", "A-003", "US30-AS2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.splitlines(),
            [
                "SC-001 specs/product/overview.md:1",
                "EC-002 specs/product/overview.md:2",
                "A-003 specs/product/overview.md:3",
                "US30-AS2 specs/product/overview.md:4",
            ],
        )

    def test_finds_definitions_in_subdirectories(self):
        result = self.run_find(
            {"specs/product/contracts/localization.md": "- **FR-500**: 契約。\n"},
            "FR-500",
        )
        self.assertEqual(result.stdout, "FR-500 specs/product/contracts/localization.md:1\n")

    def test_ignores_mentions_outside_definitions(self):
        files = {
            "specs/product/a.md": "FR-080 を参照する。\n- 詳細は **FR-080** にある。\n- **FR-0800**: 別の ID。\n",
            "specs/001-old/spec.md": "- **FR-080**: 凍結した feature の定義。\n",
        }
        result = self.run_find(files, "FR-080")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertIn("FR-080", result.stderr)

    def test_reports_missing_id_after_printing_the_others(self):
        result = self.run_find({"specs/product/a.md": "- **FR-001**: あり。\n"}, "FR-999", "FR-001")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "FR-001 specs/product/a.md:1\n")
        self.assertIn("FR-999", result.stderr)

    def test_prints_every_location_of_a_duplicated_id(self):
        files = {"specs/product/a.md": "- **FR-001**: 1つ目。\n", "specs/product/b.md": "\n- **FR-001**: 2つ目。\n"}
        result = self.run_find(files, "FR-001")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["FR-001 specs/product/a.md:1", "FR-001 specs/product/b.md:2"])

    def test_works_from_another_directory(self):
        result = self.run_find({"specs/product/a.md": "- **FR-001**: あり。\n"}, "FR-001", cwd="/")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "FR-001 specs/product/a.md:1\n")

    def test_rejects_missing_or_malformed_arguments(self):
        for ids in ((), ("FR080",), ("TAK-82",), ("FR-.*",)):
            with self.subTest(ids=ids):
                result = self.run_find({"specs/product/a.md": "- **FR-001**: あり。\n"}, *ids)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(result.stdout, "")

    def test_sampled_definitions_in_the_repository_are_found_once(self):
        """実際の specs/product/ から等間隔に選んだ定義が、それぞれ 1 か所に見つかる。

        全件（約 1,600 個）では 5 秒ほどかかり check-all.sh が遅くなるため、約 50 個を選ぶ。
        """
        pattern = r"^[[:space:]]*(-|[0-9]+\.) \*\*((FR|SC|EC|A)-[0-9]+|US[0-9]+-AS[0-9]+)\*\*"
        ids = subprocess.run(
            ["grep", "-rhoE", "--include=*.md", pattern, "specs/product"],
            capture_output=True, text=True, cwd=ROOT, check=True,
        ).stdout
        all_ids = sorted({line.split("**")[1] for line in ids.splitlines()})
        sample = all_ids[:: max(1, len(all_ids) // 50)]
        self.assertTrue(any(i.startswith("US") for i in sample))
        result = subprocess.run([str(ROOT / SCRIPT), *sample], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(result.stdout.splitlines()), len(sample))


if __name__ == "__main__":
    unittest.main()
