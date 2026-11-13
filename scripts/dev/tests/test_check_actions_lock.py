"""lock の生成失敗時は両方の管理元を保ち、公開する workflow だけを選ぶ。"""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / 'actions-lock.py'
SPEC = importlib.util.spec_from_file_location('actions_lock', SCRIPT)
LOCK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(LOCK)


class ActionsLockTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.development = self.root / '.github/workflows'
        self.managed = self.root / 'scripts/dev/oss-workflows'
        for target, name in ((self.development, 'ci.yml'), (self.managed, 'release.yml')):
            target.mkdir(parents=True)
            (target / name).write_text('uses: actions/checkout@v4\n')
            (target / 'actions.lock').write_text(f'old {name} lock\n')
        (self.managed / 'README.md').write_text('not a workflow\n')
        (self.managed / 'nested').mkdir()
        (self.managed / 'nested/extra.yml').write_text('not exported\n')
        (self.managed / 'link.yml').symlink_to('release.yml')
        self.git('init', '-q')
        self.git('add', '.')
        self.calls = []

    def git(self, *args):
        subprocess.run(['git', *args], cwd=self.root, check=True, capture_output=True)

    def snapshot(self):
        return {str(path.relative_to(self.root)): path.read_bytes()
                for directory in (self.development, self.managed)
                for path in directory.iterdir() if path.is_file() and not path.is_symlink()}

    def fake_cli(self, staged, mode):
        self.calls.append((staged, mode))
        self.assertNotEqual(staged, self.root)
        workflows = staged / '.github/workflows'
        name = 'ci.yml' if (workflows / 'ci.yml').exists() else 'release.yml'
        self.assertEqual({p.name for p in workflows.iterdir()}, {name, 'actions.lock'})
        self.assertEqual((workflows / 'actions.lock').read_text(), f'old {name} lock\n')
        (workflows / 'actions.lock').write_text(f'new {name} lock\n')
        (workflows / name).write_text('uses: actions/checkout@v4.4.0\n')

    def test_generation_copies_both_locks_and_narrowed_workflows_back(self):
        with patch.object(LOCK, 'run_lock', side_effect=self.fake_cli):
            LOCK.update_locks(self.root, None)
        self.assertEqual(len(self.calls), 2)
        for directory, name in ((self.development, 'ci.yml'), (self.managed, 'release.yml')):
            self.assertEqual((directory / 'actions.lock').read_text(), f'new {name} lock\n')
            self.assertIn('@v4.4.0', (directory / name).read_text())

    def test_verification_does_not_copy_back(self):
        before = self.snapshot()
        for mode in ('--verify', '--verify-local'):
            with self.subTest(mode=mode), patch.object(LOCK, 'run_lock', side_effect=self.fake_cli):
                LOCK.update_locks(self.root, mode)
                self.assertEqual(self.calls[-1][1], mode)
                self.assertEqual(self.snapshot(), before)

    def test_failed_public_generation_keeps_both_management_directories(self):
        before = self.snapshot()

        def fail_public(staged, mode):
            self.fake_cli(staged, mode)
            if len(self.calls) == 2:
                raise subprocess.CalledProcessError(1, ['gh', 'actions-lock'])

        with patch.object(LOCK, 'run_lock', side_effect=fail_public):
            with self.assertRaises(subprocess.CalledProcessError):
                LOCK.update_locks(self.root, '--relock')
        self.assertEqual(len(self.calls), 2)
        self.assertEqual(self.snapshot(), before)

    def test_failed_development_generation_never_runs_public_cli(self):
        before = self.snapshot()

        def fail_development(staged, mode):
            self.fake_cli(staged, mode)
            raise subprocess.CalledProcessError(1, ['gh', 'actions-lock'])

        with patch.object(LOCK, 'run_lock', side_effect=fail_development):
            with self.assertRaises(subprocess.CalledProcessError):
                LOCK.update_locks(self.root, None)
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(self.snapshot(), before)

    def test_missing_generated_public_lock_keeps_both_management_directories(self):
        before = self.snapshot()

        def omit_lock(staged, mode):
            self.fake_cli(staged, mode)
            if len(self.calls) == 2:
                (staged / '.github/workflows/actions.lock').unlink()

        with patch.object(LOCK, 'run_lock', side_effect=omit_lock):
            with self.assertRaisesRegex(ValueError, 'actions.lock'):
                LOCK.update_locks(self.root, None)
        self.assertEqual(self.snapshot(), before)

    def test_symlink_lock_is_rejected_before_either_cli_runs(self):
        for directory in (self.development, self.managed):
            with self.subTest(directory=directory):
                lock = directory / 'actions.lock'
                original = lock.read_bytes()
                lock.unlink()
                lock.symlink_to('missing')
                before = self.snapshot()
                with patch.object(LOCK, 'run_lock') as cli:
                    with self.assertRaisesRegex(ValueError, '通常ファイル'):
                        LOCK.update_locks(self.root, '--relock')
                    cli.assert_not_called()
                self.assertEqual(self.snapshot(), before)
                self.assertTrue(lock.is_symlink())
                lock.unlink()
                lock.write_bytes(original)

    def test_untracked_and_ignored_workflows_are_rejected_until_staged(self):
        (self.root / '.gitignore').write_text('ignored.yml\n')
        for name in ('draft.yml', 'ignored.yml'):
            with self.subTest(name=name):
                workflow = self.managed / name
                workflow.write_text('name: Draft\n')
                with patch.object(LOCK, 'run_lock') as cli:
                    with self.assertRaisesRegex(ValueError, 'git add'):
                        LOCK.update_locks(self.root, None)
                    cli.assert_not_called()
                workflow.unlink()
        added = self.managed / 'new.yaml'
        added.write_text('name: New\n')
        self.git('add', 'scripts/dev/oss-workflows/new.yaml')
        self.assertIn(added, LOCK.workflow_files(self.root, self.managed))

    def test_invalid_export_name_is_rejected_before_either_cli_runs(self):
        (self.managed / 'my flow.yml').write_text('name: Invalid\n')
        self.git('add', '.')
        with patch.object(LOCK, 'run_lock') as cli:
            with self.assertRaisesRegex(ValueError, 'workflow 名が不正'):
                LOCK.update_locks(self.root, None)
            cli.assert_not_called()

    def test_lock_without_workflows_is_rejected_before_either_cli_runs(self):
        (self.managed / 'release.yml').unlink()
        with patch.object(LOCK, 'run_lock') as cli:
            with self.assertRaisesRegex(ValueError, 'workflow がない'):
                LOCK.update_locks(self.root, None)
            cli.assert_not_called()

    def test_initial_generation_without_locks(self):
        for directory in (self.development, self.managed):
            (directory / 'actions.lock').unlink()

        def generate(staged, mode):
            workflows = staged / '.github/workflows'
            self.assertFalse((workflows / 'actions.lock').exists())
            (workflows / 'actions.lock').write_text('initial lock\n')

        with patch.object(LOCK, 'run_lock', side_effect=generate):
            LOCK.update_locks(self.root, None)
        for directory in (self.development, self.managed):
            self.assertEqual((directory / 'actions.lock').read_text(), 'initial lock\n')

    def test_run_lock_uses_staged_root_and_clears_directory_override(self):
        with patch.object(LOCK.subprocess, 'run') as command, patch.dict(
                os.environ, {'GH_ACTIONS_LOCK_WORKFLOWS_DIR': '/wrong'}):
            LOCK.run_lock(self.root, '--verify')
        args, kwargs = command.call_args
        self.assertEqual(args[0], ['gh', 'actions-lock', '--no-interactive', '--verify'])
        self.assertEqual(kwargs['env']['GH_ACTIONS_LOCK_REPO_ROOT'], str(self.root))
        self.assertNotIn('GH_ACTIONS_LOCK_WORKFLOWS_DIR', kwargs['env'])


if __name__ == '__main__':
    unittest.main()
