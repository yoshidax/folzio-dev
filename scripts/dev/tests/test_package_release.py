import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


@unittest.skipUnless(sys.platform == 'darwin', 'macOS の make-app / PlistBuddy 検証')
class MakeAppResourceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.source, self.bin = self.base / 'source', self.base / 'bin'
        (self.source / 'scripts').mkdir(parents=True)
        self.bin.mkdir()
        shutil.copy2(ROOT / 'scripts/make-app.sh', self.source / 'scripts/make-app.sh')
        icon = self.source / 'scripts/make-icon.sh'
        icon.write_text('#!/bin/bash\nmkdir -p .build\nprintf icon > .build/AppIcon.icns\n')
        icon.chmod(0o755)
        self.stub('swift', 'if [[ " $* " == *" --show-bin-path "* ]]; then printf "%s\\n" "$PWD/.build/release"; fi')
        self.stub('codesign', 'touch "$PWD/signed"')
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        FOLZIO_VERSION='1.0.1', FOLZIO_BUILD_NUMBER='2', FOLZIO_ARCH='arm64')
        self.bundle = self.source / '.build/release/Folzio_FolzioLocalization.bundle'
        self.app = self.source / '.build/Folzio.app'

    def stub(self, name, body):
        file = self.bin / name
        file.write_text('#!/bin/bash\n' + body + '\n')
        file.chmod(0o755)

    def resources(self, nested=False, missing=None):
        shutil.rmtree(self.bundle, ignore_errors=True)
        folder = self.bundle / 'Contents/Resources' if nested else self.bundle
        for language in ('en', 'ja'):
            for name in ('Localizable.strings', 'Localizable.stringsdict'):
                if missing in (language, (language, name)):
                    continue
                resource = folder / (language + '.lproj') / name
                resource.parent.mkdir(parents=True, exist_ok=True)
                resource.write_text(language + ':' + name)
        executable = self.source / '.build/release/FolzioApp'
        executable.write_text('#!/bin/bash\nexit 0\n')
        executable.chmod(0o755)

    def make_app(self):
        return subprocess.run(['bash', str(self.source / 'scripts/make-app.sh')],
                              env=self.env, capture_output=True, text=True)

    def assert_resources_copied(self, nested):
        self.resources(nested=nested)
        result = self.make_app()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for language in ('en', 'ja'):
            for name in ('Localizable.strings', 'Localizable.stringsdict'):
                resource = self.app / 'Contents/Resources' / (language + '.lproj') / name
                self.assertEqual(resource.read_text(), language + ':' + name)
        info = plistlib.loads((self.app / 'Contents/Info.plist').read_bytes())
        self.assertEqual(info['CFBundleShortVersionString'], '1.0.1')
        self.assertEqual(info['CFBundleVersion'], '2')
        self.assertTrue((self.source / 'signed').exists())

    def test_flat_swiftpm_bundle(self):
        self.assert_resources_copied(nested=False)

    def test_contents_resources_bundle(self):
        self.assert_resources_copied(nested=True)

    def test_missing_language_stops_before_signing(self):
        for nested in (False, True):
            for language in ('en', 'ja'):
                with self.subTest(nested=nested, language=language):
                    self.resources(nested=nested, missing=language)
                    self.assertNotEqual(self.make_app().returncode, 0)
                    self.assertFalse(self.app.exists())
                    self.assertFalse((self.source / 'signed').exists())

    def test_missing_stringsdict_stops_before_signing(self):
        for nested in (False, True):
            for language in ('en', 'ja'):
                with self.subTest(nested=nested, language=language):
                    self.resources(nested=nested, missing=(language, 'Localizable.stringsdict'))
                    self.assertNotEqual(self.make_app().returncode, 0)
                    self.assertFalse(self.app.exists())
                    self.assertFalse((self.source / 'signed').exists())


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
