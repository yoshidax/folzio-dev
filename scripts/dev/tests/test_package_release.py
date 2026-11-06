import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


@unittest.skipUnless(sys.platform == 'darwin' and os.uname().machine == 'arm64', 'Apple silicon macOS のパッケージ検証')
class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.source, self.bin = self.base / 'source', self.base / 'bin'
        (self.source / 'scripts').mkdir(parents=True)
        self.bin.mkdir()
        self.output = self.base / 'result'
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ['PATH'])
        for name in ('package-release.sh', 'release.py'):
            shutil.copy2(ROOT / 'scripts' / name, self.source / 'scripts' / name)
        self.make_app = self.source / 'scripts/make-app.sh'
        self.make_app.write_text('''#!/bin/bash
set -eu
python3 - <<'PYAPP'
import os, pathlib, plistlib, shutil
app = pathlib.Path('.build/Folzio.app/Contents')
(app / 'MacOS').mkdir(parents=True)
shutil.copyfile('/bin/ls', app / 'MacOS/Folzio')
(app / 'MacOS/Folzio').chmod(0o755)
(app / 'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleShortVersionString=os.environ['FOLZIO_VERSION'],
                                                  CFBundleVersion=os.environ['FOLZIO_BUILD_NUMBER'])))
for language in ('en', 'ja'):
    folder = app / 'Resources' / (language + '.lproj')
    folder.mkdir(parents=True)
    for name in ('Localizable.strings', 'Localizable.stringsdict'):
        (folder / name).write_text('resource')
PYAPP
''')
        self.stub('lipo', 'echo arm64')
        self.stub('codesign', 'exit 0')

    def stub(self, name, body):
        file = self.bin / name
        file.write_text('#!/bin/bash\n' + body + '\n')
        file.chmod(0o755)

    def package(self, version='1.2.3', build='12'):
        return subprocess.run(['bash', str(self.source / 'scripts/package-release.sh'), version, build,
                               str(self.source), str(self.output)], env=self.env, capture_output=True, text=True)

    def test_isolated_archive_and_existing_output(self):
        result = self.package()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(set(p.name for p in self.output.iterdir()), {'Folzio-v1.2.3-macos-arm64.zip', 'SHA256SUMS'})
        self.assertFalse((self.source / '.build').exists())
        original = (self.output / 'SHA256SUMS').read_bytes()
        self.assertNotEqual(self.package().returncode, 0)
        self.assertEqual((self.output / 'SHA256SUMS').read_bytes(), original)

    def test_wrong_architecture_does_not_leave_output(self):
        self.stub('lipo', 'echo x86_64')
        self.assertNotEqual(self.package().returncode, 0)
        self.assertFalse(self.output.exists())

    def test_signature_and_resources_are_required(self):
        self.stub('codesign', 'exit 1')
        self.assertNotEqual(self.package().returncode, 0)
        self.assertFalse(self.output.exists())
        self.stub('codesign', 'exit 0')
        self.make_app.write_text(self.make_app.read_text() + 'rm .build/Folzio.app/Contents/Resources/ja.lproj/Localizable.stringsdict\n')
        self.assertNotEqual(self.package().returncode, 0)
        self.assertFalse(self.output.exists())

    def test_leading_zero_and_bad_build_are_rejected(self):
        for version, build in [('01.2.3', '12'), ('1.2.3', '007')]:
            with self.subTest(version=version, build=build):
                self.assertNotEqual(self.package(version, build).returncode, 0)
                self.assertFalse(self.output.exists())

    def test_both_embedded_versions_must_match_request(self):
        original = self.make_app.read_text()
        for key in ('CFBundleShortVersionString', 'CFBundleVersion'):
            with self.subTest(key=key):
                self.make_app.write_text(original +
                    f"/usr/libexec/PlistBuddy -c 'Set :{key} 99' .build/Folzio.app/Contents/Info.plist\n")
                self.assertNotEqual(self.package().returncode, 0)
                self.assertFalse(self.output.exists())
