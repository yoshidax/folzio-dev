import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/release-distribution.sh'


def run(*args, cwd=None, env=None, check=True):
    return subprocess.run(args, cwd=cwd, env=env, text=True, capture_output=True, check=check)


class ReleaseDistributionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = pathlib.Path(self.temp.name)
        self.root = self.base / 'development'
        self.public = self.base / 'public'
        self.remote = self.base / 'remote.git'
        self.bin = self.base / 'bin'
        for path in (self.root / 'scripts', self.public / 'scripts', self.bin):
            path.mkdir(parents=True)
        shutil.copy2(SCRIPT, self.root / 'scripts')
        run('git', 'init', '--bare', str(self.remote))
        run('git', 'init', '-b', 'main', str(self.public))
        run('git', 'config', 'user.name', 'Test', cwd=self.public)
        run('git', 'config', 'user.email', 'test@example.invalid', cwd=self.public)
        app_script = self.public / 'scripts/make-app.sh'
        app_script.write_text('''#!/bin/bash
set -eu
mkdir -p .build/Folzio.app/Contents/MacOS
cp /bin/ls .build/Folzio.app/Contents/MacOS/Folzio
cat > .build/Folzio.app/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleShortVersionString</key><string>$FOLZIO_VERSION</string><key>CFBundleVersion</key><string>$FOLZIO_BUILD_NUMBER</string></dict></plist>
PLIST
''')
        app_script.chmod(0o755)
        run('git', 'add', '.', cwd=self.public)
        run('git', 'commit', '-m', 'public source', cwd=self.public)
        run('git', 'remote', 'add', 'origin', 'https://github.com/test/folzio.git', cwd=self.public)
        self.env = os.environ.copy()
        self.env.update(PATH=f'{self.bin}:{self.env["PATH"]}', TEST_REMOTE=str(self.remote),
                        GH_LOG=str(self.base / 'gh.log'))
        run('git', 'push', str(self.remote), 'main', cwd=self.public, env=self.env)
        real_git = shutil.which('git')
        self.stub('git', f'''args=("$@")
if [[ "${{args[2]:-}}" == ls-remote ]]; then
    for ((i=0; i<${{#args[@]}}; i++)); do
        [[ "${{args[$i]}}" != origin ]] || args[$i]="$TEST_REMOTE"
    done
fi
exec "{real_git}" "${{args[@]}}"''')
        self.stub('lipo', 'echo arm64')
        self.stub('codesign', 'exit 0')
        self.stub('gh', 'printf "%s\\n" "$*" >> "$GH_LOG"')
        self.notes = self.base / 'notes.md'
        self.notes.write_text('Release notes\n')

    def tearDown(self):
        self.temp.cleanup()

    def stub(self, name, body):
        path = self.bin / name
        path.write_text(f'#!/bin/bash\n{body}\n')
        path.chmod(0o755)

    def invoke(self, *args):
        return run(str(self.root / 'scripts/release-distribution.sh'), *args,
                   cwd=self.root, env=self.env, check=False)

    def prepare(self):
        result = self.invoke('prepare', '1.2.3', '12', 'test/folzio', str(self.public))
        self.assertEqual(result.returncode, 0, result.stderr)

    def tag(self, name='v1.2.3', target='HEAD'):
        run('git', 'tag', '-a', name, target, '-m', 'release', cwd=self.public)
        run('git', 'push', str(self.remote), f'refs/tags/{name}', cwd=self.public, env=self.env)

    def draft(self):
        return self.invoke('draft', '1.2.3', 'test/folzio', str(self.notes), str(self.public))

    def test_prepare_and_draft_annotated_tag(self):
        self.prepare()
        self.tag()
        result = self.draft()
        self.assertEqual(result.returncode, 0, result.stderr)
        log = (self.base / 'gh.log').read_text()
        for item in ('release create v1.2.3', '--repo github.com/test/folzio', '--verify-tag', '--draft', 'SHA256SUMS'):
            self.assertIn(item, log)
        self.assertNotEqual(self.invoke('prepare', '1.2.3', '12', 'test/folzio', str(self.public)).returncode, 0)

    def test_missing_or_wrong_tag_never_invokes_gh(self):
        run('git', 'commit', '--allow-empty', '-m', 'second', cwd=self.public)
        run('git', 'push', str(self.remote), 'main', cwd=self.public, env=self.env)
        self.prepare()
        self.assertNotEqual(self.draft().returncode, 0)
        self.tag(target='HEAD~1')
        self.assertNotEqual(self.draft().returncode, 0)
        self.assertFalse((self.base / 'gh.log').exists())

    def test_changed_zip_and_unpublished_commit_are_rejected(self):
        self.prepare()
        self.tag()
        asset = self.root / '.build/releases/v1.2.3/Folzio-v1.2.3-macos-arm64.zip'
        with asset.open('ab') as file:
            file.write(b'changed')
        self.assertNotEqual(self.draft().returncode, 0)
        run('git', 'commit', '--allow-empty', '-m', 'not pushed', cwd=self.public)
        self.assertNotEqual(self.draft().returncode, 0)
        self.assertFalse((self.base / 'gh.log').exists())

    def test_dirty_worktree_and_wrong_repo_are_rejected(self):
        (self.public / 'unexpected').write_text('untracked')
        self.assertNotEqual(self.invoke('prepare', '1.2.3', '12', 'test/folzio', str(self.public)).returncode, 0)
        (self.public / 'unexpected').unlink()
        self.assertNotEqual(self.invoke('prepare', '1.2.3', '12', 'other/repo', str(self.public)).returncode, 0)

    def test_gh_failure_is_reported(self):
        self.prepare()
        self.tag()
        self.stub('gh', 'exit 1')
        self.assertNotEqual(self.draft().returncode, 0)


if __name__ == '__main__':
    unittest.main()
