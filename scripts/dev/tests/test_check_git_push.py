import json
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[3]
SCRIPT = ROOT / 'scripts/dev/check-git-push.py'

ALLOWED = [
    'git push -u origin chore/tak-27-agent-push-permissions',
    'git push origin claude/foo',
    'git push origin HEAD:ci/foo',
    'git push -u origin feature/x bugfix/y',
    'git -C /tmp/repo push origin docs/readme',
    'git push --dry-run origin agent/T043-video',
    'git push origin refs/heads/chore/x',
    'git status && git push origin chore/x',
    'git push -u origin chore/x 2>&1 | tail -5',
    'git push origin chore/x > /dev/null 2>/dev/null',
    'git push origin chore/x &> out.log',
    'git log --oneline',
    'echo pushing the button',
]

DENIED = [
    'git push origin master',
    'git push origin main',
    'git push origin HEAD:master',
    'git push origin chore/x:master',
    'git push origin refs/heads/master',
    'git push origin master 2>&1 | tail -3',
    'git push origin :tak-27-test',
    'git push origin :ci/macos-swift-build-test',
    'git push --delete origin ci/foo',
    'git push -d origin ci/foo',
    'git push --force origin chore/x',
    'git push -f origin chore/x',
    'git push --force-with-lease origin chore/x',
    'git push origin +chore/x',
    'git push origin chore/x --force',
    'git push --mirror origin',
    'git push --all origin',
    'git push',
    'git push origin',
    'git push origin HEAD',
    'git push upstream chore/x',
    'git push https://example.com/x.git chore/x',
    'git push origin release/1.0',
    'git push origin chore/x; git push origin master',
    'git push origin chore/x && git push --force origin chore/y',
    'bash -c "git push origin master"',
    'sh -c "git push -f origin chore/x"',
    'eval git push origin master',
    'git push origin "unterminated',
]


def run(command, tool_name='Bash'):
    payload = json.dumps({'tool_name': tool_name, 'tool_input': {'command': command}})
    return subprocess.run(['python3', '-I', str(SCRIPT)], input=payload, text=True, capture_output=True)


class CheckGitPushTests(unittest.TestCase):
    def test_allowed_commands(self):
        for command in ALLOWED:
            with self.subTest(command=command):
                result = run(command)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_denied_commands(self):
        for command in DENIED:
            with self.subTest(command=command):
                result = run(command)
                self.assertEqual(result.returncode, 2)
                self.assertIn('git push guard', result.stderr)

    def test_ignores_other_tools(self):
        self.assertEqual(run('git push origin master', tool_name='Read').returncode, 0)

    def test_rejects_invalid_input(self):
        result = subprocess.run(['python3', '-I', str(SCRIPT)], input='not json', text=True, capture_output=True)
        self.assertEqual(result.returncode, 2)
        for command in (None, ['bash', '-lc', 'git push origin master'], 42, {}):
            with self.subTest(command=command):
                result = run(command)
                self.assertEqual(result.returncode, 2)
                self.assertIn('tool_input.command', result.stderr)

    def test_codex_hook_command(self):
        config = json.loads((ROOT / '.codex/hooks.json').read_text())
        entry = config['hooks']['PreToolUse'][0]
        self.assertEqual(entry['matcher'], '^Bash$')
        hook = entry['hooks'][0]['command']
        for command, expected in [('git push origin chore/example', 0),
                                  ('git push origin HEAD:master', 2),
                                  ('git push --force origin chore/example', 2)]:
            with self.subTest(command=command):
                payload = json.dumps({'tool_name': 'Bash', 'tool_input': {'command': command}})
                result = subprocess.run(hook, shell=True, cwd=ROOT, input=payload, text=True, capture_output=True)
                self.assertEqual(result.returncode, expected, result.stderr)

        with tempfile.TemporaryDirectory() as directory:
            payload = json.dumps({'tool_name': 'Bash', 'tool_input': {'command': 'ls'}})
            result = subprocess.run(hook, shell=True, cwd=directory, input=payload, text=True, capture_output=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn('検査スクリプトが見つかりません', result.stderr)


if __name__ == '__main__':
    unittest.main()
