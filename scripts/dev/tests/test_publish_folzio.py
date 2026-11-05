import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


class PublishTests(unittest.TestCase):
    def exercise_publish(self, exclude_dev=True, exclude_shared=True):
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
            shared = source / "shared-skills"
            (shared / "nested").mkdir(parents=True)
            (shared / "folzio-sample.md").write_text("private skill instructions\n")
            (shared / "future-skill.md").write_text("future private instructions\n")
            (shared / "nested/context.md").write_text("private supporting context\n")
            (scripts / "public.sh").write_text("public helper\n")
            attributes = source / ".gitattributes"
            if not exclude_dev:
                attributes.write_text(attributes.read_text().replace("/scripts/dev export-ignore", ""))
            if not exclude_shared:
                attributes.write_text(attributes.read_text().replace("/shared-skills            export-ignore", ""))
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
            if not exclude_dev or not exclude_shared:
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn(".gitattributes", result.stderr)
                self.assertEqual((target / "obsolete.txt").read_text(), "old\n")
                self.assertFalse((target / "README.md").exists())
                return
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((target / ".vscode/settings.json").read_text(), '{"private": true}\n')
            self.assertEqual((target / "README.md").read_text(), "Folzio\n")
            self.assertFalse((target / "obsolete.txt").exists())
            self.assertFalse((target / "scripts/dev").exists())
            self.assertFalse((target / "shared-skills").exists())
            self.assertEqual((target / "scripts/public.sh").read_text(), "public helper\n")

    def test_publish_excludes_all_dev_files(self):
        self.exercise_publish(True)

    def test_publish_rejects_included_dev_before_sync(self):
        self.exercise_publish(False)

    def test_publish_rejects_included_shared_skills_before_sync(self):
        self.exercise_publish(exclude_shared=False)


class PublishFixture:
    """A development repository and a publish target in a temporary directory.

    Files can be changed, committed, and published any number of times.
    """

    def __init__(self, root, attributes=None):
        self.source = root / "source"
        self.target = root / "target"
        self.source.mkdir()
        self.target.mkdir()
        text = (ROOT / ".gitattributes").read_text()
        if attributes is not None:
            text = attributes(text)
        self.write(".gitattributes", text)
        self.write("README.md", "Folzio\n")
        dev = self.source / "scripts/dev"
        dev.mkdir(parents=True)
        shutil.copy2(ROOT / "scripts/dev/publish.sh", dev / "publish.sh")
        for path in ("scripts/check-readme-sync.sh", "scripts/dev/check-english-comments.sh",
                     "scripts/check-no-network.sh"):
            self.write(path, "#!/bin/sh\nexit 0\n")
            (self.source / path).chmod(0o755)
        self.git("init", "-b", "main")
        self.commit()
        subprocess.run(["git", "init", "-b", "main", str(self.target)], check=True, capture_output=True)
        (self.target / "obsolete.txt").write_text("old\n")
        bin_dir = root / "bin"
        bin_dir.mkdir()
        (bin_dir / "swift").write_text("#!/bin/sh\nexit 0\n")
        (bin_dir / "swift").chmod(0o755)
        self.env = os.environ.copy()
        self.env["PATH"] = str(bin_dir) + os.pathsep + self.env["PATH"]

    def git(self, *args):
        subprocess.run(["git", "-C", str(self.source), *args], check=True, capture_output=True)

    def write(self, path, text):
        file = self.source / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(text)

    def remove(self, path):
        (self.source / path).unlink()

    def symlink(self, path, destination):
        file = self.source / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.symlink_to(destination)

    def commit(self):
        self.git("add", "-A")
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                 "commit", "--allow-empty", "-m", "fixture")

    def publish(self):
        return subprocess.run(["bash", str(self.source / "scripts/dev/publish.sh"), str(self.target)],
                              cwd=self.source, env=self.env, capture_output=True, text=True)

    def published_workflows(self):
        directory = self.target / ".github/workflows"
        if not directory.exists():
            return {}
        return {path.name: path.read_text() for path in directory.iterdir()}


class PublishVerificationTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.fixture = PublishFixture(self.root)
        self.log = self.root / "commands.log"
        swift = self.root / "bin/swift"
        swift.write_text(
            '#!/bin/sh\n'
            'echo "swift $*" >> "$PUBLISH_TEST_LOG"\n'
            'if [ "$*" = "$PUBLISH_TEST_FAIL" ]; then exit 1; fi\n'
        )
        swift.chmod(0o755)
        self.fixture.env["PUBLISH_TEST_LOG"] = str(self.log)
        self.fixture.env["PUBLISH_TEST_FAIL"] = ""
        self.fixture.write("scripts/check-no-network.sh", '#!/bin/sh\necho network >> "$PUBLISH_TEST_LOG"\n')
        self.fixture.commit()

    def run_publish(self, fail=""):
        self.fixture.env["PUBLISH_TEST_FAIL"] = fail
        return self.fixture.publish()

    def commands(self):
        return self.log.read_text().splitlines()

    def staged_files(self):
        result = subprocess.run(
            ["git", "-C", str(self.fixture.target), "diff", "--cached", "--name-only"],
            check=True, capture_output=True, text=True,
        )
        return result.stdout.splitlines()

    def test_runs_normal_and_performance_tests_before_staging(self):
        result = self.run_publish()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.commands(), [
            "swift build",
            "swift test --no-parallel --skip FolzioPerformanceTests",
            "swift test --filter FolzioPerformanceTests",
            "network",
        ])
        self.assertIn("README.md", self.staged_files())

    def test_failed_normal_tests_stop_after_sync_before_staging(self):
        result = self.run_publish("test --no-parallel --skip FolzioPerformanceTests")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.commands(), [
            "swift build",
            "swift test --no-parallel --skip FolzioPerformanceTests",
        ])
        self.assertEqual(self.staged_files(), [])
        self.assertTrue((self.fixture.target / "README.md").exists())

    def test_failed_performance_tests_stop_before_staging(self):
        result = self.run_publish("test --filter FolzioPerformanceTests")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.commands(), [
            "swift build",
            "swift test --no-parallel --skip FolzioPerformanceTests",
            "swift test --filter FolzioPerformanceTests",
        ])
        self.assertEqual(self.staged_files(), [])


def without_workflow_exclusion(text):
    return "".join(line for line in text.splitlines(keepends=True)
                   if not line.startswith("/.github/workflows "))


class WorkflowPublishTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)

    def assert_published(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_publish_excludes_development_workflows(self):
        fixture = PublishFixture(self.root)
        fixture.write(".github/workflows/macos-swift-ci.yml", "name: macOS Swift CI\n")
        fixture.write(".github/workflows/lint.yml", "name: Lint\n")
        fixture.commit()
        self.assert_published(fixture.publish())
        self.assertEqual(fixture.published_workflows(), {})
        self.assertFalse((fixture.target / ".github").exists())
        self.assertEqual((fixture.target / "README.md").read_text(), "Folzio\n")

    def test_publish_rejects_included_development_workflows_before_sync(self):
        fixture = PublishFixture(self.root, attributes=without_workflow_exclusion)
        fixture.write(".github/workflows/macos-swift-ci.yml", "name: macOS Swift CI\n")
        fixture.commit()
        result = fixture.publish()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(".gitattributes", result.stderr)
        self.assertEqual((fixture.target / "obsolete.txt").read_text(), "old\n")
        self.assertFalse((fixture.target / "README.md").exists())

    def test_publish_places_and_updates_public_workflows(self):
        fixture = PublishFixture(self.root)
        fixture.write("scripts/dev/oss-workflows/release.yml", "name: Release\n")
        fixture.write("scripts/dev/oss-workflows/check.yaml", "name: Check\n")
        fixture.write("scripts/dev/oss-workflows/README.md", "managed public workflows\n")
        fixture.write("scripts/dev/oss-workflows/sub/nested.yml", "name: Nested\n")
        fixture.commit()
        result = fixture.publish()
        self.assert_published(result)
        self.assertEqual(fixture.published_workflows(),
                         {"release.yml": "name: Release\n", "check.yaml": "name: Check\n"})
        self.assertIn("release.yml", result.stdout)
        self.assertFalse((fixture.target / "scripts/dev").exists())

        fixture.write("scripts/dev/oss-workflows/release.yml", "name: Release v2\n")
        fixture.commit()
        self.assert_published(fixture.publish())
        self.assertEqual(fixture.published_workflows(),
                         {"release.yml": "name: Release v2\n", "check.yaml": "name: Check\n"})

        fixture.remove("scripts/dev/oss-workflows/release.yml")
        fixture.commit()
        self.assert_published(fixture.publish())
        self.assertEqual(fixture.published_workflows(), {"check.yaml": "name: Check\n"})

    def test_publish_removes_workflows_when_none_are_managed(self):
        fixture = PublishFixture(self.root)
        fixture.write("scripts/dev/oss-workflows/README.md", "managed public workflows\n")
        fixture.commit()
        manual = fixture.target / ".github/workflows/manual.yml"
        manual.parent.mkdir(parents=True)
        manual.write_text("name: Manual\n")
        result = fixture.publish()
        self.assert_published(result)
        self.assertFalse((fixture.target / ".github").exists())
        self.assertIn("公開用 workflow はありません", result.stdout)

    def test_publish_prefers_managed_workflow_over_development_workflow(self):
        fixture = PublishFixture(self.root)
        fixture.write(".github/workflows/release.yml", "name: Development release\n")
        fixture.write("scripts/dev/oss-workflows/release.yml", "name: Public release\n")
        fixture.commit()
        self.assert_published(fixture.publish())
        self.assertEqual(fixture.published_workflows(), {"release.yml": "name: Public release\n"})

    def test_publish_skips_symbolic_links_in_managed_workflows(self):
        fixture = PublishFixture(self.root)
        fixture.write("scripts/dev/oss-workflows/release.yml", "name: Release\n")
        fixture.symlink("scripts/dev/oss-workflows/link.yml", "release.yml")
        fixture.commit()
        self.assert_published(fixture.publish())
        self.assertEqual(fixture.published_workflows(), {"release.yml": "name: Release\n"})


if __name__ == "__main__":
    unittest.main()
