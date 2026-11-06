import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def module():
    spec = importlib.util.spec_from_file_location('folzio_release', ROOT / 'scripts/release.py')
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class RequestTests(unittest.TestCase):
    def setUp(self):
        self.release = module()
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'release-notes').mkdir()
        (self.root / 'release-notes/v1.2.3.md').write_text('Changes\n')
        self.request = dict(version='1.2.3', build_number='12', notes_file='release-notes/v1.2.3.md')

    def write(self):
        (self.root / 'release.json').write_text(json.dumps(self.request))

    def test_canonical_numbers(self):
        for version in ['0.0.0', '1.2.3', '100.20.0']:
            self.release.validate_numbers(version, '0')
        for version in ['01.2.3', '1.02.3', '1.2.03', '1.2', '1.2.3\n']:
            with self.subTest(version=version), self.assertRaises(ValueError):
                self.release.validate_numbers(version, '12')
        for build in ['007', '01', '-1', 12, '1\n']:
            with self.subTest(build=build), self.assertRaises(ValueError):
                self.release.validate_numbers('1.2.3', build)

    def test_request_and_notes(self):
        self.write()
        self.assertEqual(self.release.load_request(self.root), self.request)
        for invalid in ['../secret.md', '/tmp/file.md', 'release-notes/../secret.md', 'release-notes/a\nb.md']:
            self.request['notes_file'] = invalid
            self.write()
            with self.subTest(path=invalid), self.assertRaises(ValueError):
                self.release.load_request(self.root)

    def test_unknown_duplicate_empty_and_symlink(self):
        self.write()
        path = self.root / 'release.json'
        path.write_text('{"version":"1.2.3","version":"1.2.4"}')
        with self.assertRaises(ValueError):
            self.release.load_request(self.root)
        self.request['extra'] = True
        self.write()
        with self.assertRaises(ValueError):
            self.release.load_request(self.root)
        del self.request['extra']
        self.write()
        note = self.root / self.request['notes_file']
        note.write_text(' \n')
        with self.assertRaises(ValueError):
            self.release.load_request(self.root)
        note.unlink()
        note.symlink_to(self.root / 'release.json')
        with self.assertRaises(ValueError):
            self.release.load_request(self.root)
