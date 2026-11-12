"""scripts/dev/find-spec-id.sh の回帰テスト。"""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = "scripts/dev/find-spec-id.sh"


class FindSpecIdTests(unittest.TestCase):
    def run_find(self, files, *ids, base_files=None, cwd=None):
        """files（パス → 内容）を置いた一時リポジトリで、スクリプトを実行する。

        base_files を渡すと git のリポジトリにし、その内容を比べる基準（master）としてコミットしてから、
        files を作業ツリーに置く。渡さないときは git のリポジトリにしない。
        """
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts/dev").mkdir(parents=True)
            for script in (SCRIPT, "scripts/dev/base-ref.sh"):
                shutil.copy2(ROOT / script, root / script)
            if base_files is not None:
                self.write_files(root, base_files)
                self.commit_base(root)
            self.write_files(root, files)
            return subprocess.run(
                [str(root / SCRIPT), *ids],
                capture_output=True,
                text=True,
                cwd=cwd or directory,
            )

    def write_files(self, root, files):
        for name, text in files.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")

    def commit_base(self, root):
        def git(*args):
            subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True)
        git("init", "-q", "-b", "master")
        git("add", "-A")
        git("-c", "user.name=test", "-c", "user.email=test@example.com", "commit", "-q", "-m", "base")

    def test_prints_markdown_link_to_bullet_definition(self):
        result = self.run_find(
            {"specs/product/search.md": "# 検索\n\n- **FR-080**: 検索できる。\n"},
            "FR-080",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "[FR-080](specs/product/search.md#L3)\n")

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
                "[SC-001](specs/product/overview.md#L1)",
                "[EC-002](specs/product/overview.md#L2)",
                "[A-003](specs/product/overview.md#L3)",
                "[US30-AS2](specs/product/overview.md#L4)",
            ],
        )

    def test_finds_definitions_in_subdirectories(self):
        result = self.run_find(
            {"specs/product/contracts/localization.md": "- **FR-500**: 契約。\n"},
            "FR-500",
        )
        self.assertEqual(result.stdout, "[FR-500](specs/product/contracts/localization.md#L1)\n")

    def test_ignores_mentions_outside_definitions(self):
        files = {
            "specs/product/a.md": "FR-080 を参照する。\n- 詳細は **FR-080** にある。\n- **FR-0800**: 別の ID。\n",
            ".specify/bugs/x/assessment.md": "- **FR-080**（a.md）: bug の記録での引用。\n",
        }
        result = self.run_find(files, "FR-080")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertIn("FR-080", result.stderr)

    def test_finds_new_id_in_feature_in_progress(self):
        base = {"specs/product/a.md": "- **FR-001**: 製品。\n"}
        files = {"specs/TAK-99-new/spec.md": "# spec\n\n- **FR-002**: 作業中の feature で足した。\n"}
        result = self.run_find(files, "FR-002", "FR-001", base_files=base)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.splitlines(),
            ["[FR-002](specs/TAK-99-new/spec.md#L3)", "[FR-001](specs/product/a.md#L1)"],
        )

    def test_prefers_feature_in_progress_over_product(self):
        base = {"specs/product/a.md": "- **FR-001**: 変更前。\n"}
        files = {"specs/TAK-99-new/spec.md": "- **FR-001**: 変更後。\n"}
        result = self.run_find(files, "FR-001", base_files=base)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "[FR-001](specs/TAK-99-new/spec.md#L1)\n")

    def test_ignores_feature_already_in_base(self):
        base = {
            "specs/product/a.md": "- **FR-001**: 反映済み。\n",
            "specs/TAK-98-done/spec.md": "- **FR-001**: 凍結した記録。\n",
        }
        result = self.run_find({}, "FR-001", base_files=base)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "[FR-001](specs/product/a.md#L1)\n")

    def test_ignores_features_without_base_ref(self):
        files = {"specs/product/a.md": "- **FR-001**: 製品。\n", "specs/TAK-99-new/spec.md": "- **FR-001**: 判定できない。\n"}
        result = self.run_find(files, "FR-001")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "[FR-001](specs/product/a.md#L1)\n")

    def test_searches_only_spec_md_of_feature_in_progress(self):
        base = {"specs/product/a.md": "- **FR-001**: 製品。\n"}
        files = {
            "specs/TAK-99-new/spec.md": "# spec\n",
            "specs/TAK-99-new/plan.md": "- **FR-002**: plan での引用。\n",
            "specs/TAK-99-new/tasks.md": "- **FR-002**: tasks での引用。\n",
        }
        result = self.run_find(files, "FR-002", base_files=base)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")

    def test_reports_missing_id_after_printing_the_others(self):
        result = self.run_find({"specs/product/a.md": "- **FR-001**: あり。\n"}, "FR-999", "FR-001")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "[FR-001](specs/product/a.md#L1)\n")
        self.assertIn("FR-999", result.stderr)

    def test_prints_every_location_of_a_duplicated_id(self):
        files = {"specs/product/a.md": "- **FR-001**: 1つ目。\n", "specs/product/b.md": "\n- **FR-001**: 2つ目。\n"}
        result = self.run_find(files, "FR-001")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["[FR-001](specs/product/a.md#L1)", "[FR-001](specs/product/b.md#L2)"])

    def test_works_from_another_directory(self):
        result = self.run_find({"specs/product/a.md": "- **FR-001**: あり。\n"}, "FR-001", cwd="/")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "[FR-001](specs/product/a.md#L1)\n")

    def test_absolute_option_prefixes_the_repository_root(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve() / "repo"
            for name in (SCRIPT, "specs/product/a.md"):
                (root / name).parent.mkdir(parents=True, exist_ok=True)
            for script in (SCRIPT, "scripts/dev/base-ref.sh"):
                shutil.copy2(ROOT / script, root / script)
            (root / "specs/product/a.md").write_text("- **FR-001**: あり。\n", encoding="utf-8")
            for args in (("--absolute", "FR-001"), ("FR-001", "--absolute")):
                with self.subTest(args=args):
                    result = subprocess.run([str(root / SCRIPT), *args], capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, f"[FR-001]({root}/specs/product/a.md#L1)\n")

    def test_wraps_absolute_path_with_spaces_in_angle_brackets(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve() / "my repo"
            (root / "scripts/dev").mkdir(parents=True)
            (root / "specs/product").mkdir(parents=True)
            for script in (SCRIPT, "scripts/dev/base-ref.sh"):
                shutil.copy2(ROOT / script, root / script)
            (root / "specs/product/a.md").write_text("- **FR-001**: あり。\n", encoding="utf-8")
            result = subprocess.run([str(root / SCRIPT), "--absolute", "FR-001"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, f"[FR-001](<{root}/specs/product/a.md#L1>)\n")

    def test_rejects_missing_or_malformed_arguments(self):
        for ids in ((), ("--absolute",), ("FR080",), ("TAK-82",), ("FR-.*",), ("--abs", "FR-001")):
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
