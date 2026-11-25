import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


class ToolInstallPermissionTests(unittest.TestCase):
    """Check committed rules; merged user settings and runtime behavior require separate checks."""

    def test_claude_requests_approval_for_homebrew_install(self):
        settings = json.loads((ROOT / '.claude/settings.json').read_text())
        permissions = settings['permissions']
        rule = 'Bash(brew install *)'
        self.assertIn(rule, permissions.get('ask', []))
        self.assertNotIn(rule, permissions.get('deny', []))


if __name__ == '__main__':
    unittest.main()
