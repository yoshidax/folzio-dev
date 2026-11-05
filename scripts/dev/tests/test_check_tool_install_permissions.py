import fnmatch
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


class ToolInstallPermissionTests(unittest.TestCase):
    """Check committed rules; merged user settings and runtime behavior require separate checks."""

    def test_claude_requests_approval_or_denies_homebrew_install(self):
        settings = json.loads((ROOT / '.claude/settings.json').read_text())
        permissions = settings['permissions']
        rule = 'Bash(brew install *)'
        self.assertTrue(rule in permissions.get('ask', []) or rule in permissions.get('deny', []))

    def test_kilo_last_matching_rule_denies_homebrew_install(self):
        settings = json.loads((ROOT / '.kilo/kilo.jsonc').read_text())
        rules = settings['permission']['bash']
        for command in ('brew install jq', 'brew install --cask example'):
            with self.subTest(command=command):
                matches = [action for pattern, action in rules.items() if fnmatch.fnmatchcase(command, pattern)]
                self.assertTrue(matches, f'No rule matches {command}')
                self.assertEqual(matches[-1], 'deny')


if __name__ == '__main__':
    unittest.main()
