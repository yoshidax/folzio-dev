import importlib.util
import json
import os
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
        from unittest.mock import patch
        quiet = patch.object(self.release, 'summary')
        quiet.start()
        self.addCleanup(quiet.stop)
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


class AssetTests(unittest.TestCase):
    def test_checksum_and_zip_boundary_are_required(self):
        import hashlib, zipfile
        release = module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / 'Folzio-v1.2.3-macos-arm64.zip'
            sums = root / 'SHA256SUMS'
            for members, valid in [(['Folzio.app/Contents/MacOS/Folzio'], True),
                                   (['Folzio.app/Contents/MacOS/Folzio', 'extra.txt'], False),
                                   (['Folzio.app/Contents/Info.plist'], False),
                                   (['Folzio.app/Contents/MacOS/Folzio', 'Folzio.app/../extra'], False)]:
                with self.subTest(members=members):
                    with zipfile.ZipFile(archive, 'w') as stream:
                        for member in members:
                            stream.writestr(member, 'fixture')
                    checksum = hashlib.sha256(archive.read_bytes()).hexdigest() + '  ' + archive.name + '\n'
                    sums.write_text(checksum)
                    if valid:
                        release.verify_assets(root, '1.2.3')
                    else:
                        with self.assertRaises(ValueError):
                            release.verify_assets(root, '1.2.3')
                    sums.write_text('0' * 64 + '  ' + archive.name + '\n')
                    with self.assertRaisesRegex(ValueError, 'Checksum'):
                        release.verify_assets(root, '1.2.3')


class FakeAPI:
    def __init__(self, values):
        self.values, self.calls = values, []

    def api(self, path, method='GET', data=None, missing=False):
        self.calls.append((method, path, data))
        if path in self.values:
            value = self.values[path]
            if isinstance(value, Exception):
                raise value
            return value
        if missing:
            return None
        raise AssertionError(path)


class APITests(unittest.TestCase):
    def test_only_explicit_404_means_absent(self):
        from unittest.mock import patch
        release = module()
        for status in (401, 403, 500):
            response = subprocess.CompletedProcess([], 1, f'HTTP/2.0 {status} Error\n\n{{}}', '')
            with patch.object(release.subprocess, 'run', return_value=response), self.assertRaises(release.APIError):
                release.GitHub('test/repo').api('releases/tags/v1.2.3', missing=True)
        response = subprocess.CompletedProcess([], 1, 'HTTP/2.0 404 Not Found\n\n{}', '')
        with patch.object(release.subprocess, 'run', return_value=response):
            self.assertIsNone(release.GitHub('test/repo').api('missing', missing=True))
            with self.assertRaises(release.APIError):
                release.GitHub('test/repo').api('missing')
        response = subprocess.CompletedProcess([], 1, '', 'transport down')
        with patch.object(release.subprocess, 'run', return_value=response), self.assertRaises(release.APIError):
            release.GitHub('test/repo').api('missing', missing=True)

    def test_annotated_and_conflicting_tags_and_existing_releases(self):
        release = module()
        sha, tag = 'a' * 40, 'b' * 40
        api = FakeAPI({'git/ref/tags/v1.2.3': {'object': {'type': 'tag', 'sha': tag}},
                       'git/tags/' + tag: {'object': {'type': 'commit', 'sha': sha}}})
        self.assertEqual(release.check_release_state(api, 'v1.2.3', sha), sha)
        with self.assertRaises(ValueError):
            release.check_release_state(api, 'v1.2.3', 'c' * 40)
        for draft in (True, False):
            api = FakeAPI({'releases/tags/v1.2.3': {'draft': draft}})
            with self.assertRaises(ValueError):
                release.check_release_state(api, 'v1.2.3', sha)
            self.assertEqual([c[0] for c in api.calls], ['GET'])


class PublicPlanTests(unittest.TestCase):
    def setUp(self):
        from unittest.mock import patch
        self.release = module()
        from unittest.mock import patch
        quiet = patch.object(self.release, 'summary')
        quiet.start()
        self.addCleanup(quiet.stop)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / 'repo'
        self.root.mkdir()
        subprocess.run(['git', 'init', '-q', '-b', 'main', str(self.root)], check=True)
        self.git('config', 'user.name', 'Test')
        self.git('config', 'user.email', 'test@example.invalid')
        (self.root / 'README.md').write_text('public\n')
        self.commit()
        self.before = self.git('rev-parse', 'HEAD')
        self.event = self.base / 'event.json'
        self.event.write_text(json.dumps({'repository': {'default_branch': 'main'}, 'before': self.before}))
        self.env = patch.dict(os.environ, GITHUB_EVENT_PATH=str(self.event), GITHUB_EVENT_NAME='push',
                              GITHUB_REPOSITORY='yoshidax/folzio', GITHUB_REF='refs/heads/main', GITHUB_SHA=self.before)
        self.env.start()
        self.addCleanup(self.env.stop)

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.root), *args], text=True).strip()

    def commit(self):
        self.git('add', '-A')
        self.git('commit', '-qm', 'public')
        sha = self.git('rev-parse', 'HEAD')
        if hasattr(self, 'before'):
            os.environ['GITHUB_SHA'] = sha
        return sha

    def request(self):
        (self.root / 'release-notes').mkdir()
        (self.root / 'release-notes/v1.2.3.md').write_text('Notes\n')
        (self.root / 'release.json').write_text(json.dumps(dict(version='1.2.3', build_number='12', notes_file='release-notes/v1.2.3.md')))
        return self.commit()

    def test_skip_unchanged_and_build_new_request(self):
        api = FakeAPI({})
        self.assertFalse(self.release.public_plan(self.root, api)['ready'])
        self.assertEqual(api.calls, [])
        sha = self.request()
        self.assertTrue(self.release.public_plan(self.root, api)['ready'])
        self.event.write_text(json.dumps({'repository': {'default_branch': 'main'}, 'before': sha}))
        (self.root / 'README.md').write_text('docs only\n')
        self.commit()
        api = FakeAPI({})
        self.assertFalse(self.release.public_plan(self.root, api)['ready'])
        self.assertEqual(api.calls, [])

    def test_initial_push_missing_parent_and_manual(self):
        self.request()
        self.event.write_text(json.dumps({'repository': {'default_branch': 'main'}, 'before': '0' * 40}))
        self.assertTrue(self.release.public_plan(self.root, FakeAPI({}))['ready'])
        self.event.write_text(json.dumps({'repository': {'default_branch': 'main'}, 'before': 'f' * 40}))
        with self.assertRaises(ValueError):
            self.release.public_plan(self.root, FakeAPI({}))
        os.environ['GITHUB_EVENT_NAME'] = 'workflow_dispatch'
        self.assertTrue(self.release.public_plan(self.root, FakeAPI({}))['ready'])
        os.environ['GITHUB_REF'] = 'refs/heads/other'
        with self.assertRaises(ValueError):
            self.release.public_plan(self.root, FakeAPI({}))

    def test_dirty_metadata_never_changes_committed_request(self):
        self.request()
        (self.root / 'release.json').write_text('{}')
        self.assertEqual(self.release.public_plan(self.root, FakeAPI({}))['version'], '1.2.3')

    def assets(self):
        import hashlib, zipfile
        output = self.base / 'assets'
        output.mkdir()
        asset = output / 'Folzio-v1.2.3-macos-arm64.zip'
        with zipfile.ZipFile(asset, 'w') as zf:
            zf.writestr('Folzio.app/Contents/MacOS/Folzio', 'binary')
        (output / 'SHA256SUMS').write_text(hashlib.sha256(asset.read_bytes()).hexdigest() + '  ' + asset.name + '\n')
        return output

    def test_draft_is_immutable_and_partial_upload_failure_surfaces(self):
        from unittest.mock import patch
        sha = self.request()
        output = self.assets()
        os.environ['GITHUB_RUN_ID'] = '123'
        api = FakeAPI({'git/ref/tags/v1.2.3': {'object': {'type': 'commit', 'sha': sha}}})
        original, calls = self.release.run, []

        def run(*args, **kwargs):
            if args[0] == 'gh':
                calls.append(args)
                notes = Path(args[-1]).read_text()
                self.assertIn(sha, notes)
                self.assertIn('--draft', args)
                self.assertNotIn('--clobber', args)
                raise ValueError('partial upload')
            return original(*args, **kwargs)

        with patch.object(self.release, 'run', side_effect=run), self.assertRaisesRegex(ValueError, 'inspect'):
            self.release.public_draft(self.root, output, api)
        self.assertEqual(len(calls), 1)
        self.assertFalse(any(c[0] in ('PATCH', 'DELETE') for c in api.calls))
        (output / 'SHA256SUMS').write_text('tampered')
        api = FakeAPI({})
        with self.assertRaises(ValueError):
            self.release.public_draft(self.root, output, api)
        self.assertEqual(api.calls, [])

    def test_new_tag_and_tag_creation_race_use_verified_commit(self):
        from unittest.mock import patch
        sha = self.request()
        output = self.assets()
        os.environ['GITHUB_RUN_ID'] = '123'
        release = self.release
        owner = self

        class StatefulAPI:
            def __init__(self, race):
                self.tag, self.race, self.posts = None, race, 0

            def api(self, path, method='GET', data=None, missing=False):
                if path.startswith('releases/tags/'):
                    return None
                if path == 'git/ref/tags/v1.2.3':
                    return None if self.tag is None else dict(object=dict(type='commit', sha=self.tag))
                if path == 'git/refs':
                    owner.assertEqual(data, dict(ref='refs/tags/v1.2.3', sha=sha))
                    self.tag, self.posts = sha, self.posts + 1
                    if self.race:
                        raise release.APIError('422 concurrent creation')
                    return dict(ref=data['ref'])
                raise AssertionError(path)

        original = release.run
        for race in (False, True):
            calls = []

            def run(*args, **kwargs):
                if args[0] == 'gh':
                    calls.append(args)
                    self.assertIn('--verify-tag', args)
                    self.assertIn('--draft', args)
                    return ''
                return original(*args, **kwargs)

            api = StatefulAPI(race)
            with self.subTest(race=race), patch.object(release, 'run', side_effect=run):
                release.public_draft(self.root, output, api)
            self.assertEqual(api.posts, 1)
            self.assertEqual(api.tag, sha)
            self.assertEqual(len(calls), 1)
