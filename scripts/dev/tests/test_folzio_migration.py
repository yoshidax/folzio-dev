import os
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "scripts/dev/migrate-folzio-settings.sh"
FAKE_DEFAULTS = '''#!/usr/bin/env python3
import os, pathlib, shutil, sys
root = pathlib.Path(os.environ["FOLZIO_TEST_DOMAINS"])
command, *args = sys.argv[1:]
if os.environ.get("FOLZIO_TEST_FAIL") == command:
    raise SystemExit(1)
if command == "domains":
    print(", ".join(p.stem for p in root.glob("*.plist")))
elif command == "export":
    shutil.copyfile(root / (args[0] + ".plist"), args[1])
elif command == "import":
    shutil.copyfile(args[1], root / (args[0] + ".plist"))
else:
    raise SystemExit(2)
'''


class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.domains = self.root / "domains"
        self.domains.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        fake = self.bin / "defaults"
        fake.write_text(FAKE_DEFAULTS)
        fake.chmod(0o755)
        self.env = os.environ.copy()
        self.env["PATH"] = str(self.bin) + os.pathsep + self.env["PATH"]
        self.env["FOLZIO_TEST_DOMAINS"] = str(self.domains)
        self.source = "test.folzio.source"
        self.destination = "test.folzio.destination"
        self.original = {
            "appearance.language": "ja",
            "favorites.paths": ["/tmp/example"],
            "NSWindow Frame MainWindow": "1 2 3 4",
            "NSSplitView Subview Frames MainSplit": ["1, 2, 3, 4"],
        }

    def put(self, domain, value):
        with (self.domains / (domain + ".plist")).open("wb") as file:
            plistlib.dump(value, file)

    def get(self, domain):
        with (self.domains / (domain + ".plist")).open("rb") as file:
            return plistlib.load(file)

    def migrate(self):
        return subprocess.run(
            ["bash", "-c", 'source "$1"; migrate_settings "$2" "$3" "$4"',
             "test", str(SCRIPT), self.source, self.destination, str(self.root / "backups")],
            env=self.env, capture_output=True, text=True,
        )

    def test_copy_preserves_settings_and_rejects_second_run(self):
        self.put(self.source, self.original)
        result = self.migrate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.get(self.source), self.original)
        self.assertEqual(self.get(self.destination), self.original)
        backups = list((self.root / "backups").glob("*/source.plist"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(plistlib.loads(backups[0].read_bytes()), self.original)
        self.assertNotEqual(self.migrate().returncode, 0)
        self.assertEqual(self.get(self.destination), self.original)

    def test_existing_destination_is_untouched(self):
        self.put(self.source, self.original)
        self.put(self.destination, {"existing": True})
        self.assertNotEqual(self.migrate().returncode, 0)
        self.assertEqual(self.get(self.destination), {"existing": True})
        self.assertEqual(self.get(self.source), self.original)

    def test_missing_source_makes_no_changes(self):
        self.assertEqual(self.migrate().returncode, 0)
        self.assertFalse((self.domains / (self.destination + ".plist")).exists())
        self.assertFalse((self.root / "backups").exists())

    def test_backup_failure_does_not_import(self):
        self.put(self.source, self.original)
        self.env["FOLZIO_TEST_FAIL"] = "export"
        self.assertNotEqual(self.migrate().returncode, 0)
        self.assertEqual(self.get(self.source), self.original)
        self.assertFalse((self.domains / (self.destination + ".plist")).exists())

    def test_import_failure_keeps_backup(self):
        self.put(self.source, self.original)
        self.env["FOLZIO_TEST_FAIL"] = "import"
        self.assertNotEqual(self.migrate().returncode, 0)
        self.assertEqual(self.get(self.source), self.original)
        self.assertEqual(len(list((self.root / "backups").glob("*/source.plist"))), 1)

    def test_domain_list_failure_does_not_change_settings(self):
        self.put(self.source, self.original)
        self.env["FOLZIO_TEST_FAIL"] = "domains"
        self.assertNotEqual(self.migrate().returncode, 0)
        self.assertEqual(self.get(self.source), self.original)
        self.assertFalse((self.root / "backups").exists())


if __name__ == "__main__":
    unittest.main()
