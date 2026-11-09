import pathlib
import shutil
import subprocess
import tempfile
import unittest


class NetworkImportExceptionTests(unittest.TestCase):
    def run_check(self, name, body):
        repository = pathlib.Path(__file__).resolve().parents[3]
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            (root / 'scripts').mkdir()
            script = root / 'scripts/check-no-network.sh'
            shutil.copyfile(repository / 'scripts/check-no-network.sh', script)
            source = root / 'Sources/FolzioCore/Operations' / name
            source.parent.mkdir(parents=True)
            source.write_text(body)
            return subprocess.run(['bash', str(script)], capture_output=True, text=True).returncode

    def test_allows_exact_scheme_comparison(self):
        self.assertEqual(self.run_check('ImportedFileName.swift', '    ["http", "https"].contains(scheme),\n'), 0)

    def test_rejects_network_call_on_exception_line(self):
        self.assertNotEqual(self.run_check('ImportedFileName.swift', '["http", "https"].contains(scheme), URLSession.shared\n'), 0)

    def test_rejects_other_urls_and_other_files(self):
        self.assertNotEqual(self.run_check('ImportedFileName.swift', 'let url = "https://example.com"\n'), 0)
        self.assertNotEqual(self.run_check('Other.swift', '["http", "https"].contains(scheme),\n'), 0)
