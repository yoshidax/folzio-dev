import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


@unittest.skipUnless(shutil.which("rsync"), "ローカル復旧の検証には rsync が必要")
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
            (source / "README.ja.md").write_text("Folzio\n")
            dev = scripts / "dev"
            (dev / "nested").mkdir(parents=True)
            shutil.copy2(ROOT / "scripts/dev/publish.sh", dev / "publish.sh")
            shutil.copy2(ROOT / "scripts/dev/strip-readme-dev-note.sh", dev / "strip-readme-dev-note.sh")
            for name in ("export-public.sh", "export-public.py"):
                shutil.copy2(ROOT / "scripts/dev" / name, dev / name)
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
        self.write("README.ja.md", "Folzio\n")
        dev = self.source / "scripts/dev"
        dev.mkdir(parents=True)
        shutil.copy2(ROOT / "scripts/dev/publish.sh", dev / "publish.sh")
        shutil.copy2(ROOT / "scripts/dev/strip-readme-dev-note.sh", dev / "strip-readme-dev-note.sh")
        for name in ("export-public.sh", "export-public.py"):
            shutil.copy2(ROOT / "scripts/dev" / name, dev / name)
        shutil.copy2(ROOT / "scripts/check-readme-sync.sh", self.source / "scripts/check-readme-sync.sh")
        for path in ("scripts/dev/check-english-comments.sh", "scripts/check-no-network.sh"):
            self.write(path, "#!/bin/sh\nexit 0\n")
            (self.source / path).chmod(0o755)
        self.git("init", "-b", "main")
        self.commit()
        subprocess.run(["git", "init", "-b", "main", str(self.target)], check=True, capture_output=True)
        (self.target / "obsolete.txt").write_text("old\n")
        self.bin_dir = root / "bin"
        self.bin_dir.mkdir()
        (self.bin_dir / "swift").write_text("#!/bin/sh\nexit 0\n")
        (self.bin_dir / "swift").chmod(0o755)
        self.env = os.environ.copy()
        self.env["PATH"] = str(self.bin_dir) + os.pathsep + self.env["PATH"]

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


@unittest.skipUnless(shutil.which("rsync"), "ローカル復旧の検証には rsync が必要")
class PublishVerificationTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.fixture = PublishFixture(self.root)
        self.log = self.root / "commands.log"
        swift = self.fixture.bin_dir / "swift"
        swift.write_text(
            '#!/bin/sh\n'
            'echo "swift $*" >> "$PUBLISH_TEST_LOG"\n'
            'if [ "$*" = "$PUBLISH_TEST_FAIL" ]; then exit 1; fi\n'
        )
        swift.chmod(0o755)
        self.fixture.env["PUBLISH_TEST_LOG"] = str(self.log)
        self.fixture.env["PUBLISH_TEST_FAIL"] = ""
        self.fixture.write("scripts/check-no-network.sh", '#!/bin/sh\necho network >> "$PUBLISH_TEST_LOG"\n'
                           'if [ "$PUBLISH_TEST_FAIL" = network ]; then exit 1; fi\n')
        (self.fixture.source / "scripts/check-no-network.sh").chmod(0o755)
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

    def test_failed_build_stops_before_tests_and_staging(self):
        result = self.run_publish("build")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.commands(), ["swift build"])
        self.assertEqual(self.staged_files(), [])
        self.assertIn("未検証", result.stderr)

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
        self.assertIn("未検証", result.stderr)

    def test_failed_performance_tests_stop_before_staging(self):
        result = self.run_publish("test --filter FolzioPerformanceTests")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.commands(), [
            "swift build",
            "swift test --no-parallel --skip FolzioPerformanceTests",
            "swift test --filter FolzioPerformanceTests",
        ])
        self.assertEqual(self.staged_files(), [])

    def test_failed_network_check_stops_before_staging(self):
        result = self.run_publish("network")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.commands(), [
            "swift build",
            "swift test --no-parallel --skip FolzioPerformanceTests",
            "swift test --filter FolzioPerformanceTests",
            "network",
        ])
        self.assertEqual(self.staged_files(), [])
        self.assertIn("未検証", result.stderr)


def without_workflow_exclusion(text):
    return "".join(line for line in text.splitlines(keepends=True)
                   if not line.startswith("/.github/workflows "))


@unittest.skipUnless(shutil.which("rsync"), "ローカル復旧の検証には rsync が必要")
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
        fixture.write(".github/workflows/actions.lock", "development lock\n")
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
        fixture.write("scripts/dev/oss-workflows/actions.lock", "public lock\n")
        fixture.write("scripts/dev/oss-workflows/README.md", "managed public workflows\n")
        fixture.write("scripts/dev/oss-workflows/sub/nested.yml", "name: Nested\n")
        fixture.commit()
        result = fixture.publish()
        self.assert_published(result)
        self.assertEqual(fixture.published_workflows(),
                         {"release.yml": "name: Release\n", "check.yaml": "name: Check\n",
                          "actions.lock": "public lock\n"})
        self.assertIn("release.yml", result.stdout)
        self.assertFalse((fixture.target / "scripts/dev").exists())

        fixture.write("scripts/dev/oss-workflows/release.yml", "name: Release v2\n")
        fixture.write("scripts/dev/oss-workflows/actions.lock", "public lock v2\n")
        fixture.commit()
        self.assert_published(fixture.publish())
        self.assertEqual(fixture.published_workflows(),
                         {"release.yml": "name: Release v2\n", "check.yaml": "name: Check\n",
                          "actions.lock": "public lock v2\n"})

        fixture.remove("scripts/dev/oss-workflows/release.yml")
        fixture.remove("scripts/dev/oss-workflows/actions.lock")
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
        fixture.symlink("scripts/dev/oss-workflows/actions.lock", "release.yml")
        fixture.commit()
        self.assert_published(fixture.publish())
        self.assertEqual(fixture.published_workflows(), {"release.yml": "name: Release\n"})


README_WITHOUT_NOTE = "# Folzio\n\nEnglish | [日本語](README.ja.md)\n\nBrowse and organize.\n"
README_JA_WITHOUT_NOTE = "# Folzio\n\n[English](README.md) | 日本語\n\n見て、整理する。\n"
NOTE = ("<!-- dev-repo-note:start -->\n"
        "> [!NOTE]\n"
        "> Development repository. See [yoshidax/folzio](https://github.com/yoshidax/folzio).\n"
        "<!-- dev-repo-note:end -->\n"
        "\n")


def with_note(readme):
    head, separator, rest = readme.partition("\n\n")
    language, separator2, body = rest.partition("\n\n")
    return head + separator + language + separator2 + NOTE + body


@unittest.skipUnless(shutil.which("rsync"), "ローカル復旧の検証には rsync が必要")
class ReadmeDevNotePublishTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.fixture = PublishFixture(Path(directory.name))

    def test_publish_removes_development_note_from_both_readmes(self):
        self.fixture.write("README.md", with_note(README_WITHOUT_NOTE))
        self.fixture.write("README.ja.md", with_note(README_JA_WITHOUT_NOTE))
        self.fixture.commit()
        result = self.fixture.publish()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.fixture.target / "README.md").read_text(), README_WITHOUT_NOTE)
        self.assertEqual((self.fixture.target / "README.ja.md").read_text(), README_JA_WITHOUT_NOTE)
        self.assertIn("dev-repo-note", (self.fixture.source / "README.md").read_text())

    def test_publish_keeps_readme_without_note(self):
        self.fixture.write("README.md", README_WITHOUT_NOTE)
        self.fixture.write("README.ja.md", README_JA_WITHOUT_NOTE)
        self.fixture.commit()
        result = self.fixture.publish()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.fixture.target / "README.md").read_text(), README_WITHOUT_NOTE)

    def test_publish_rejects_missing_readme_before_sync(self):
        self.fixture.remove("README.ja.md")
        self.fixture.commit()
        result = self.fixture.publish()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("README.ja.md", result.stderr)
        self.assertEqual((self.fixture.target / "obsolete.txt").read_text(), "old\n")
        self.assertFalse((self.fixture.target / "README.md").exists())

    def test_publish_rejects_broken_note_markers_before_sync(self):
        self.fixture.write("README.md", with_note(README_WITHOUT_NOTE))
        self.fixture.write("README.ja.md", with_note(README_JA_WITHOUT_NOTE).replace(
            "<!-- dev-repo-note:end -->\n", ""))
        self.fixture.commit()
        result = self.fixture.publish()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("README.ja.md", result.stderr)
        self.assertEqual((self.fixture.target / "obsolete.txt").read_text(), "old\n")
        self.assertFalse((self.fixture.target / "README.md").exists())


class ExporterTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.fixture = PublishFixture(Path(self.directory.name))
        self.output = Path(self.directory.name) / 'export'

    def export(self, sha=None, user=None, home=None):
        if sha is None:
            sha = subprocess.check_output(['git', '-C', str(self.fixture.source), 'rev-parse', 'HEAD'], text=True).strip()
        command = ['bash', str(ROOT / 'scripts/dev/export-public.sh'), sha, str(self.output)]
        if user:
            code = (
                'import getpass,runpy,sys\n'
                'from pathlib import Path\n'
                'user,home=sys.argv[-2:]\n'
                'sys.argv=sys.argv[1:-2]\n'
                'getpass.getuser=lambda:user\n'
                'if home: Path.home=classmethod(lambda cls:Path(home))\n'
                'runpy.run_path(sys.argv[0],run_name="__main__")\n'
            )
            command = [sys.executable, '-c', code, str(ROOT / 'scripts/dev/export-public.py'),
                       sha, str(self.output), user, home or '']
        return subprocess.run(command, cwd=self.fixture.source, capture_output=True, text=True)

    def test_fixed_commit_and_dirty_worktree(self):
        sha = subprocess.check_output(['git', '-C', str(self.fixture.source), 'rev-parse', 'HEAD'], text=True).strip()
        self.fixture.write('README.md', 'uncommitted\n')
        result = self.export(sha)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.output / 'README.md').read_text(), 'Folzio\n')
        self.assertFalse((self.output / 'scripts/dev').exists())
        self.assertNotEqual(self.export(sha).returncode, 0)

    def test_bad_source_and_private_link_leave_no_output(self):
        self.assertNotEqual(self.export('HEAD').returncode, 0)
        self.assertFalse(self.output.exists())
        self.fixture.write('docs/test.md', '[private](../specs/product/overview.md)\n')
        self.fixture.commit()
        self.assertNotEqual(self.export().returncode, 0)
        self.assertFalse(self.output.exists())

    def test_real_public_workflow_and_export_helpers(self):
        self.fixture.write('scripts/dev/oss-workflows/release.yml',
                           (ROOT / 'scripts/dev/oss-workflows/release.yml').read_text()
                           if (ROOT / 'scripts/dev/oss-workflows/release.yml').exists() else 'name: Release\n')
        self.fixture.write('.github/workflows/private.yml', 'name: private\n')
        self.fixture.commit()
        self.assertEqual(self.export().returncode, 0)
        self.assertFalse((self.output / '.github/workflows/private.yml').exists())
        self.assertEqual((self.output / '.github/workflows/release.yml').read_text(),
                         (self.fixture.source / 'scripts/dev/oss-workflows/release.yml').read_text())

    def test_export_keeps_public_lock_separate_and_uses_committed_contents(self):
        self.fixture.write('.github/workflows/actions.lock', 'development lock\n')
        self.fixture.write('scripts/dev/oss-workflows/release.yml', 'name: Public\n')
        self.fixture.write('scripts/dev/oss-workflows/actions.lock', 'public lock\n')
        self.fixture.write('scripts/dev/oss-workflows/other.lock', 'not exported\n')
        self.fixture.write('scripts/dev/oss-workflows/sub/actions.lock', 'nested lock\n')
        self.fixture.commit()
        self.fixture.write('scripts/dev/oss-workflows/actions.lock', 'uncommitted lock\n')
        result = self.export()
        self.assertEqual(result.returncode, 0, result.stderr)
        directory = self.output / '.github/workflows'
        self.assertEqual({path.name for path in directory.iterdir()}, {'release.yml', 'actions.lock'})
        self.assertEqual((directory / 'actions.lock').read_text(), 'public lock\n')
        self.assertIn('公開用 workflow: release.yml\n', result.stdout)
        self.assertIn('公開用 lock: actions.lock\n', result.stdout)

    def test_export_rejects_lock_without_workflows_and_leaves_no_output(self):
        self.fixture.write('scripts/dev/oss-workflows/actions.lock', 'orphaned lock\n')
        self.fixture.commit()
        result = self.export()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('workflow がない公開用 actions.lock', result.stderr)
        self.assertFalse(self.output.exists())

    def test_export_rejects_invalid_workflow_name_and_leaves_no_output(self):
        self.fixture.write('scripts/dev/oss-workflows/my flow.yml', 'name: Invalid\n')
        self.fixture.commit()
        result = self.export()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('workflow 名が不正', result.stderr)
        self.assertFalse(self.output.exists())


    def test_explicit_fixture_paths_are_allowed_but_any_home_name_is_rejected(self):
        self.fixture.write('Tests/example.swift', 'let path = "/test-homes/fixture-person/a"\n')
        self.fixture.commit()
        self.assertEqual(self.export().returncode, 0)
        shutil.rmtree(self.output)
        for path in ['/Users/me/a', '/Users/me2/a', '/Users/x/a', '/Users/personal-name/a', '/home/example/a']:
            with self.subTest(path=path):
                self.fixture.write('Tests/example.swift', f'let path = "{path}"\n')
                self.fixture.commit()
                self.assertNotEqual(self.export().returncode, 0)
                self.assertFalse(self.output.exists())

    def test_structure_check_is_shared_and_leaves_no_output_on_mismatch(self):
        self.fixture.write('README.md', '# Header\n')
        self.fixture.write('README.ja.md', 'No heading\n')
        self.fixture.commit()
        result = self.export()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('differ in structure', result.stderr)
        self.assertFalse(self.output.exists())

    def test_export_uses_committed_rules_after_later_helper_change(self):
        sha = subprocess.check_output(['git', '-C', str(self.fixture.source), 'rev-parse', 'HEAD'], text=True).strip()
        self.fixture.write('scripts/dev/export-public.py', 'raise SystemExit("later exporter")\n')
        self.fixture.commit()
        result = self.export(sha)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.output / 'README.md').exists())

    def test_username_identifier_boundaries_allow_partial_matches(self):
        for user, text in [
            ('yoshida', 'https://github.com/yoshidax/folzio\n_yoshida yoshida-test yoshida.name yoshida2\n'),
            ('qa.user', 'qaXuser prefix-qa.user qa.user_suffix\n'),
        ]:
            with self.subTest(user=user):
                self.fixture.write('docs/example.txt', text)
                self.fixture.commit()
                result = self.export(user=user)
                self.assertEqual(result.returncode, 0, result.stderr)
                shutil.rmtree(self.output)
                self.fixture.write('docs/example.txt', f'Author: ({user})\n')
                self.fixture.commit()
                self.assertNotEqual(self.export(user=user).returncode, 0)
                self.assertFalse(self.output.exists())

    def test_generic_account_words_are_allowed_but_home_paths_are_not(self):
        for user in ['runner', 'runneradmin', 'root']:
            with self.subTest(user=user):
                self.fixture.write('Tests/example.swift', '// A busy runner and runneradmin use the root variable.\n')
                self.fixture.commit()
                home = '/root' if user == 'root' else f'/home/{user}'
                result = self.export(user=user, home=home)
                self.assertEqual(result.returncode, 0, result.stderr)
                shutil.rmtree(self.output)
                paths = [f'/Users/{user}/private', f'/home/{user}/private', home + '/private']
                for path in dict.fromkeys(paths):
                    with self.subTest(path=path):
                        self.fixture.write('Tests/example.swift', f'let path = "{path}"\n')
                        self.fixture.commit()
                        self.assertNotEqual(self.export(user=user, home=home).returncode, 0)
                        self.assertFalse(self.output.exists())


if __name__ == '__main__':
    unittest.main()
