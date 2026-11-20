"""仕様 ID の参照検査と採番の回帰テスト。"""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = "scripts/dev/check-spec-ids.sh"


class CheckSpecReferencesTests(unittest.TestCase):
    def run_check(self, files, *options):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts/dev").mkdir(parents=True)
            for script in (SCRIPT, "scripts/dev/check-spec-references.py"):
                shutil.copy2(ROOT / script, root / script)
            for name, content in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")
            return subprocess.run([str(root / SCRIPT), *options], capture_output=True, text=True, cwd="/")

    def test_accepts_normalized_references_and_legacy_story_headings(self):
        result = self.run_check({
            "specs/product/overview.md": (
                "本文は（FR-40・041〜FR-043、SC-002・EC-3・A-001）を参照する。\n"
                "`US017-AS02`・`AS3`〜`4` と US17〜US18 を参照する。\n"
                "- **FR-040**: FR-41 を参照する。\n"
                "- **FR-041**\n- **FR-042**\n- **FR-043**\n"
                "- **SC-002**\n- **EC-03**\n- **A-01**\n"
                "### User Story 17 - 旧形式の見出し\n"
                "1. **US17-AS2**\n2. **US17-AS3**\n- **US17-AS4**\n"
                "### US18 見出し\n"
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

    def test_ignores_fenced_examples_and_keeps_existing_duplicate_check(self):
        result = self.run_check({
            "specs/product/overview.md": (
                "- **FR-001**\n- **FR-001**\n"
                "```markdown\nFR-999\n```\n~~~\nUS999\n~~~\n"
            ),
        })
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stderr.splitlines(), [
            "Duplicated spec IDs under specs/product:", "**FR-001**",
        ])

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
