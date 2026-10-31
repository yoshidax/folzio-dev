import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def skill_text(name="folzio-sample", description="Sample skill.", body="Body."):
    return f"---\nname: {name}\ndescription: {description}\n---\n\n{body}\n"


class CheckSkillSyncTests(unittest.TestCase):
    def run_check(self, agents=None, claude=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dev = root / "scripts/dev"
            dev.mkdir(parents=True)
            shutil.copy2(ROOT / "scripts/dev/check-skill-sync.sh", dev / "check-skill-sync.sh")
            for base, text in ((".agents/skills", agents), (".claude/skills", claude)):
                (root / base).mkdir(parents=True)
                if text is not None:
                    skill = root / base / "folzio-sample"
                    skill.mkdir()
                    (skill / "SKILL.md").write_text(text)
            return subprocess.run([str(dev / "check-skill-sync.sh")], capture_output=True, text=True)

    def test_passes_when_only_bodies_differ(self):
        result = self.run_check(skill_text(body="Codex notes."), skill_text(body="Claude Code notes."))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_fails_when_description_differs(self):
        result = self.run_check(skill_text(), skill_text(description="Other."))
        self.assertEqual(result.returncode, 1)
        self.assertIn("description differs", result.stderr)

    def test_fails_when_skill_is_missing_on_one_side(self):
        result = self.run_check(agents=skill_text())
        self.assertEqual(result.returncode, 1)
        self.assertIn(".claude/skills/folzio-sample/SKILL.md not found", result.stderr)

    def test_fails_when_name_does_not_match_directory(self):
        result = self.run_check(skill_text(name="folzio-other"), skill_text(name="folzio-other"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("name does not match", result.stderr)


if __name__ == "__main__":
    unittest.main()
