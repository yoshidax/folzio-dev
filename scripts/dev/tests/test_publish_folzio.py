import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


class PublishTests(unittest.TestCase):
    def exercise_publish(self, exclude_dev):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            target = root / "target"
            source.mkdir()
            target.mkdir()
            scripts = source / "scripts"
            scripts.mkdir()
            shutil.copy2(ROOT / ".gitattributes", source / ".gitattributes")
            (source / "README.md").write_text("Folzio\n")
            dev = scripts / "dev"
            (dev / "nested").mkdir(parents=True)
            shutil.copy2(ROOT / "scripts/dev/publish.sh", dev / "publish.sh")
            (dev / "new-private.sh").write_text("private helper\n")
            (dev / "nested/secret.txt").write_text("private nested file\n")
            (scripts / "public.sh").write_text("public helper\n")
            attributes = source / ".gitattributes"
            if not exclude_dev:
                attributes.write_text(attributes.read_text().replace("/scripts/dev export-ignore", ""))
            for path in (scripts / "check-readme-sync.sh", dev / "check-english-comments.sh", scripts / "check-no-network.sh"):
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
            result = subprocess.run(["bash", str(dev / "publish.sh"), str(target)],
                                    cwd=source, env=env, capture_output=True, text=True)
            if not exclude_dev:
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((target / "obsolete.txt").read_text(), "old\n")
                self.assertFalse((target / "README.md").exists())
                return
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((target / ".vscode/settings.json").read_text(), '{"private": true}\n')
            self.assertEqual((target / "README.md").read_text(), "Folzio\n")
            self.assertFalse((target / "obsolete.txt").exists())
            self.assertFalse((target / "scripts/dev").exists())
            self.assertEqual((target / "scripts/public.sh").read_text(), "public helper\n")

    def test_publish_excludes_all_dev_files(self):
        self.exercise_publish(True)

    def test_publish_rejects_included_dev_before_sync(self):
        self.exercise_publish(False)


if __name__ == "__main__":
    unittest.main()
