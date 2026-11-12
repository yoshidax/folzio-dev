"""公開用の lock が実行先のパスで作られ、検証では管理元を変えないこと。"""
import importlib.util
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
        self.managed = self.root / 'scripts/dev/oss-workflows'
        self.managed.mkdir(parents=True)
        (self.managed / 'release.yml').write_text('uses: actions/checkout@v4\n')
        (self.managed / 'actions.lock').write_text('old public lock\n')
        (self.managed / 'README.md').write_text('not a workflow\n')
        (self.managed / 'nested').mkdir()
        (self.managed / 'nested/extra.yml').write_text('not exported\n')
        (self.managed / 'link.yml').symlink_to('release.yml')
        self.calls = []

    def fake_cli(self, command, *, cwd, env, check):
        self.calls.append((command, cwd, env))
        self.assertTrue(check)
        self.assertEqual(env['GH_ACTIONS_LOCK_REPO_ROOT'], str(cwd))
        self.assertNotIn('GH_ACTIONS_LOCK_WORKFLOWS_DIR', env)
        if cwd != self.root:
            workflows = cwd / '.github/workflows'
            self.assertEqual({path.name for path in workflows.iterdir()}, {'release.yml', 'actions.lock'})
            self.assertEqual((workflows / 'actions.lock').read_text(), 'old public lock\n')
            (workflows / 'actions.lock').write_text('new public lock\n')
            (workflows / 'release.yml').write_text('uses: actions/checkout@v4.3.1\n')

    def test_generation_copies_lock_and_narrowed_workflow_back_together(self):
        with patch.object(LOCK.subprocess, 'run', side_effect=self.fake_cli), patch.dict(
                LOCK.os.environ, {'GH_ACTIONS_LOCK_WORKFLOWS_DIR': '/wrong'}):
            LOCK.update_locks(self.root, None)
        self.assertEqual(len(self.calls), 2)
        self.assertEqual(self.calls[0][0], ['gh', 'actions-lock', '--no-interactive'])
        self.assertEqual((self.managed / 'actions.lock').read_text(), 'new public lock\n')
        self.assertIn('@v4.3.1', (self.managed / 'release.yml').read_text())

    def test_verification_does_not_copy_back(self):
        for mode in ('--verify', '--verify-local'):
            with self.subTest(mode=mode), patch.object(LOCK.subprocess, 'run', side_effect=self.fake_cli):
                LOCK.update_locks(self.root, mode)
                self.assertIn(mode, self.calls[-1][0])
                self.assertEqual((self.managed / 'actions.lock').read_text(), 'old public lock\n')
                self.assertEqual((self.managed / 'release.yml').read_text(), 'uses: actions/checkout@v4\n')

    def test_failed_public_generation_leaves_managed_files_unchanged(self):
        def fail_public(command, **kwargs):
            self.fake_cli(command, **kwargs)
            if kwargs['cwd'] != self.root:
                raise subprocess.CalledProcessError(1, command)

        with patch.object(LOCK.subprocess, 'run', side_effect=fail_public):
            with self.assertRaises(subprocess.CalledProcessError):
                LOCK.update_locks(self.root, '--relock')
        self.assertEqual((self.managed / 'actions.lock').read_text(), 'old public lock\n')
        self.assertEqual((self.managed / 'release.yml').read_text(), 'uses: actions/checkout@v4\n')

    def test_initial_generation_without_public_lock(self):
        (self.managed / 'actions.lock').unlink()

        def generate(command, *, cwd, **kwargs):
            if cwd != self.root:
                workflows = cwd / '.github/workflows'
                self.assertEqual({p.name for p in workflows.iterdir()}, {'release.yml'})
                (workflows / 'actions.lock').write_text('initial lock\n')

        with patch.object(LOCK.subprocess, 'run', side_effect=generate):
            LOCK.update_locks(self.root, None)
        self.assertEqual((self.managed / 'actions.lock').read_text(), 'initial lock\n')


if __name__ == '__main__':
    unittest.main()
