"""仕様 ID の参照検査と採番の回帰テスト。"""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = "scripts/dev/check-spec-ids.sh"


class CheckSpecReferencesTests(unittest.TestCase):
    def run_check(self, files, *options, base_files=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts/dev").mkdir(parents=True)
            for script in (SCRIPT, "scripts/dev/check-spec-references.py", "scripts/dev/base-ref.sh"):
                shutil.copy2(ROOT / script, root / script)
            if base_files is not None:
                self.write_files(root, base_files)
                self.commit_base(root)
            self.write_files(root, files)
            return subprocess.run([str(root / SCRIPT), *options], capture_output=True, text=True, cwd="/")

    def write_files(self, root, files):
        for name, content in files.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")

    def commit_base(self, root):
        def git(*args):
            subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True)
        git("init", "-q", "-b", "master")
        git("add", "-A")
        git("-c", "user.name=test", "-c", "user.email=test@example.com", "commit", "-q", "-m", "base")

    def test_accepts_normalized_references_and_legacy_story_headings(self):
        result = self.run_check({
            "specs/product/overview.md": (
                "本文は（FR-40・041〜FR-043、SC-002・EC-3・A-001）を参照する。\n"
                "`US017-AS02`・`AS3`〜`4` と US17〜US18・19 を参照する。\n"
                "- **FR-040**: FR-41 を参照する。\n"
                "- **FR-041**\n- **FR-042**\n- **FR-043**\n"
                "- **SC-002**\n- **EC-03**\n- **A-01**\n"
                "### User Story 17 - 旧形式の見出し\n"
                "1. **US17-AS2**\n2. **US17-AS3**\n- **US17-AS4**\n"
                "### US18: 見出し\n"
                "### US19（P1）\n"
            ),
        })
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_reports_missing_endpoints_and_interior_ids_with_locations(self):
        result = self.run_check({
            "specs/product/contracts/settings.md": (
                "（FR-040・\n"
                "  044〜046）と FR-40〜FR-043、US17-AS1〜AS3、US18 を参照する。\n"
                "（SC-1・999、EC-9、A-8）を参照する。\n"
            ),
            "specs/product/overview.md": (
                "- **FR-040**\n- **FR-043**\n- **FR-045**\n- **SC-001**\n"
                "### US17 見出し\n1. **US17-AS1**\n2. **US17-AS3**\n"
            ),
            "specs/TAK-00-active/spec.md": "- **FR-044**\n- **SC-999**\n",
        })
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stderr.splitlines(), [
            f"specs/product/contracts/settings.md:{line}: 定義のない仕様 ID {label}"
            for line, label in (
                (2, "FR-044"), (2, "FR-046"), (2, "FR-041〜FR-042"),
                (2, "US17-AS2"), (2, "US18"), (3, "SC-999"), (3, "EC-09"), (3, "A-08"),
            )
        ])

    def test_ignores_fenced_definitions_and_references(self):
        result = self.run_check({
            "specs/product/overview.md": (
                "- **FR-001**\n"
                "```markdown\n- **FR-001**\n- **FR-999**\nFR-999\n```\n"
                "~~~\nUS999\n~~~\n"
                "本文では FR-999 を参照する。\n"
            ),
        })
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stderr, "specs/product/overview.md:10: 定義のない仕様 ID FR-999\n")

    def test_reports_normalized_duplicate_locations_and_unresolved_references(self):
        result = self.run_check({
            "specs/product/overview.md": (
                "- **FR-040**\n"
                "### US03: 見出し\n"
                "1. **US3-AS01**\n"
            ),
            "specs/product/window-layout.md": (
                "2. **FR-40**\n"
                "### US3（P1）\n"
                "- **US03-AS1**\n"
                "FR-999 を参照する。\n"
            ),
        })
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stderr.splitlines(), [
            "specs/product/overview.md:1: 重複した仕様 ID FR-040",
            "specs/product/window-layout.md:1: 重複した仕様 ID FR-040",
            "specs/product/overview.md:3: 重複した仕様 ID US3-AS1",
            "specs/product/window-layout.md:3: 重複した仕様 ID US3-AS1",
            "specs/product/window-layout.md:4: 定義のない仕様 ID FR-999",
        ])

    def test_checks_ascii_ranges_without_treating_quantities_as_shorthand_ids(self):
        result = self.run_check({
            "specs/product/overview.md": (
                "- **SC-001**\n- **FR-040**\n- **FR-045**\n"
                "SC-001・2 秒以内、SC-001・3件、SC-001〜4.5 秒、SC-001・`5` ms以内。\n"
                "FR-040~FR-045 を参照する。\n"
                "SC-001・SC-002 秒。\n"
            ),
        })
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stderr.splitlines(), [
            "specs/product/overview.md:5: 定義のない仕様 ID FR-041〜FR-044",
            "specs/product/overview.md:6: 定義のない仕様 ID SC-002",
        ])

    def test_rejects_unclosed_fence_with_location_in_both_modes(self):
        for options in ((), ("--next",)):
            with self.subTest(options=options):
                result = self.run_check({
                    "specs/product/overview.md": "# 概要\n```markdown\n本文の FR-999\n",
                }, *options)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(result.stderr, "specs/product/overview.md:2: コードフェンスが閉じていません\n")

    def test_next_uses_definitions_in_all_areas(self):
        result = self.run_check({
            "specs/product/overview.md": (
                "- **FR-090**\n- **SC-009**\n- **EC-99**\n- **A-08**\n"
                "### US105 見出し\n### User Story 109 - 旧形式の見出し\n"
                "採番には参照（FR-999・US999）を使わない。\n"
            ),
            "specs/product/contracts/settings.md": "- **FR-100**\n",
        }, "--next")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["FR-101", "SC-010", "EC-100", "A-09", "US110"])

    def test_next_starts_unused_families_at_one(self):
        result = self.run_check({"specs/product/overview.md": "# 概要\n"}, "--next")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["FR-001", "SC-001", "EC-01", "A-01", "US1"])

    def test_next_includes_active_feature_definitions_only(self):
        result = self.run_check({
            "specs/TAK-999-active/spec.md": (
                "- **FR-415**\n- **SC-240**\n- **A-252**\n### US96（P1）\n"
                "本文の参照は FR-800。\n"
            ),
            "specs/TAK-999-active/plan.md": "- **FR-900**\n",
        }, "--next", base_files={
            "specs/product/overview.md": "- **FR-414**\n- **EC-285**\n### US95\n",
            "specs/001-archived/spec.md": "- **FR-999**\n### US999\n",
        })
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["FR-416", "SC-241", "EC-286", "A-253", "US97"])
