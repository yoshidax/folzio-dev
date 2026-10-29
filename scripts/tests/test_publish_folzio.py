import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class PublishTests(unittest.TestCase):
    def test_publish_preserves_private_editor_settings_and_excludes_migration(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            target = root / "target"
            source.mkdir()
            target.mkdir()
            scripts = source / "scripts"
            scripts.mkdir()
            shutil.copy2(ROOT / "scripts/publish.sh", scripts / "publish.sh")
            shutil.copy2(ROOT / ".gitattributes", source / ".gitattributes")
            (source / "README.md").write_text("Folzio\n")
            (scripts / "migrate-folzio-settings.sh").write_text("private helper\n")
            for name in ("check-readme-sync.sh", "check-english-comments.sh", "check-no-network.sh"):
                path = scripts / name
                path.write_text("#!/bin/sh\nexit 0\n")
                path.chmod(0o755)
            subprocess.run(["git", "init", "-b", "main", str(source)], check=True, capture_output=True)
            subprocess.run(["git", "-C", str(source), "add", "-A"], check=True)
            subprocess.run(["git", "-C", str(source), "-c", "user.name=Test", "-c",
                            "user.email=test@example.invalid", "commit", "-m", "fixture"],
                           check=True, capture_output=True)
            subprocess.run(["git", "init", "-b", "main", str(target)], check=True, capture_output=True)
            (target / ".vscode").mkdir()
            (target / ".vscode/settings.json").write_text('{"private": true}\n')
            (target / "obsolete.txt").write_text("old\n")
            bin_dir = root / "bin"
            bin_dir.mkdir()
            (bin_dir / "swift").write_text("#!/bin/sh\nexit 0\n")
            (bin_dir / "swift").chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = str(bin_dir) + os.pathsep + env["PATH"]
            result = subprocess.run(["bash", str(scripts / "publish.sh"), str(target)],
                                    cwd=source, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((target / ".vscode/settings.json").read_text(), '{"private": true}\n')
            self.assertEqual((target / "README.md").read_text(), "Folzio\n")
            self.assertFalse((target / "obsolete.txt").exists())
            self.assertFalse((target / "scripts/migrate-folzio-settings.sh").exists())


if __name__ == "__main__":
    unittest.main()
