import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def module():
    spec = importlib.util.spec_from_file_location('folzio_sync', ROOT / 'scripts/dev/sync-public.py')
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class PublicationStateTests(unittest.TestCase):
    def setUp(self):
        self.sync = module()
        self.base, self.old, self.new = 'a' * 40, 'b' * 40, 'c' * 40

    def decide(self, **changes):
        args = dict(base=self.base, expected=self.base, body=f'Development-Commit: {self.old}\n',
                    target=self.new, same_tree=False, bootstrap='', initialized=True,
                    ancestor=lambda old, new: (old, new) == (self.old, self.new))
        args.update(changes)
        return self.sync.publication_state(**args)

    def test_forward_skip_and_stale(self):
        self.assertEqual(self.decide(), 'write')
        self.assertEqual(self.decide(same_tree=True), 'skip')
        with self.assertRaises(ValueError):
            self.decide(ancestor=lambda *_: False, same_tree=True)

    def test_base_change_and_malformed_trailers(self):
        with self.assertRaises(ValueError):
            self.decide(base='d' * 40)
        for body in ['Development-Commit: broken', f'Development-Commit: {self.old}\nDevelopment-Commit: {self.old}']:
            with self.subTest(body=body), self.assertRaises(ValueError):
                self.decide(body=body)
        with self.assertRaises(ValueError):
            self.decide(body='manual edit without trailer')

    def test_explicit_bootstrap_only_once(self):
        self.assertEqual(self.decide(body='legacy', initialized=False), 'bootstrap')
        self.assertEqual(self.decide(body='legacy', initialized=False, bootstrap=self.base, same_tree=True), 'initialize')
        with self.assertRaises(ValueError):
            self.decide(body='legacy', initialized=False, bootstrap='d' * 40)
        with self.assertRaises(ValueError):
            self.decide(bootstrap=self.base)

    def test_same_source_cannot_change_tree(self):
        with self.assertRaises(ValueError):
            self.decide(target=self.old)
        self.assertEqual(self.decide(target=self.old, same_tree=True), 'skip')


class CandidateValidationTests(unittest.TestCase):
    def setUp(self):
        self.sync = module()
        self.target, self.head, self.tree = 'a' * 40, 'b' * 40, 'c' * 40
        self.pr = dict(number=7, head=dict(sha=self.head))
        self.request = dict(version='1.2.3', build_number='12', notes_file='release-notes/v1.2.3.md')
        self.meta = dict(self.request, source_kind='pr-preview', source_sha='d' * 40, public_tree=self.tree,
                         release_pr=7, pr_head_sha=self.head, run_id=42, run_attempt=1,
                         required_checks={k: 'success' for k in self.sync.REQUIRED},
                         performance='failure', toolchain='Xcode 16.0\nSwift 6.0')
        self.run = dict(id=42, run_attempt=1, status='completed', conclusion='success', event='pull_request',
                        path='.github/workflows/release-candidate.yml', head_sha=self.head)
        self.jobs = [dict(name='Build release candidate', conclusion='success', steps=[
            dict(name='Validate and package candidate', conclusion='success')])]

    def check(self):
        return self.sync.validate_candidate(self.meta, self.run, self.jobs, self.target, self.pr, self.tree, self.request)

    def test_performance_failure_is_observation_only(self):
        self.check()
        self.meta['performance'] = 'timed_out'
        self.check()

    def test_same_head_with_different_merge_tree_is_rejected(self):
        self.meta['public_tree'] = 'e' * 40
        with self.assertRaisesRegex(ValueError, 'tree'):
            self.check()

    def test_successful_run_does_not_hide_bad_mandatory_checks(self):
        self.meta['required_checks']['network'] = 'failure'
        with self.assertRaises(ValueError):
            self.check()
        self.meta['required_checks']['network'] = 'success'
        self.jobs[0]['steps'][0]['conclusion'] = 'failure'
        with self.assertRaises(ValueError):
            self.check()

    def test_merged_candidate_pins_m_after_master_advances(self):
        self.meta.update(source_kind='merged-source', source_sha=self.target)
        self.run.update(event='workflow_dispatch', head_sha='f' * 40)
        self.check()
        self.meta['source_sha'] = 'f' * 40
        with self.assertRaises(ValueError):
            self.check()

    def test_attempt_and_workflow_must_match(self):
        self.run['run_attempt'] = 2
        with self.assertRaises(ValueError):
            self.check()
        self.run.update(run_attempt=1, path='.github/workflows/other.yml')
        with self.assertRaises(ValueError):
            self.check()


class CandidateCommandTests(unittest.TestCase):
    def setUp(self):
        import os, shutil, tempfile
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root, self.source, self.bin = self.base / 'dev', self.base / 'source', self.base / 'bin'
        for p in (self.root / 'scripts/dev', self.source / 'scripts', self.source / 'release-notes', self.bin):
            p.mkdir(parents=True)
        shutil.copy2(ROOT / 'scripts/dev/validate-release-candidate.sh', self.root / 'scripts/dev')
        shutil.copy2(ROOT / 'scripts/release.py', self.root / 'scripts')
        import json
        (self.source / 'release.json').write_text(json.dumps(dict(version='1.2.3', build_number='12', notes_file='release-notes/v1.2.3.md')))
        (self.source / 'release-notes/v1.2.3.md').write_text('Notes\n')
        self.log = self.base / 'calls'
        self.output = self.base / 'candidate'
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        CANDIDATE_TEST_LOG=str(self.log), CANDIDATE_TEST_FAIL='')
        self.script(self.bin / 'swift', 'echo "swift $*" >> "$CANDIDATE_TEST_LOG"\n'
                    'if [[ "$*" == "$CANDIDATE_TEST_FAIL" ]]; then exit 1; fi')
        self.script(self.source / 'scripts/check-no-network.sh', 'echo network >> "$CANDIDATE_TEST_LOG"\n'
                    'if [[ "$CANDIDATE_TEST_FAIL" == network ]]; then exit 1; fi')
        self.script(self.root / 'scripts/package-release.sh', 'echo package >> "$CANDIDATE_TEST_LOG"\nmkdir "$4"')

    def script(self, path, body):
        path.write_text('#!/bin/bash\nset -e\n' + body + '\n')
        path.chmod(0o755)

    def execute(self, failure):
        import subprocess
        self.env['CANDIDATE_TEST_FAIL'] = failure
        return subprocess.run(['bash', str(self.root / 'scripts/dev/validate-release-candidate.sh'),
                               str(self.source), str(self.output)], env=self.env, capture_output=True, text=True)

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_required_failure_stops_remaining_work(self):
        result = self.execute('test --no-parallel --skip FolzioPerformanceTests')
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), ['swift build', 'swift test --no-parallel --skip FolzioPerformanceTests'])
        self.assertFalse(self.output.exists())

    def test_performance_failure_is_recorded_then_network_and_package_run(self):
        import json
        result = self.execute('test --filter FolzioPerformanceTests')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-3:], ['swift test --filter FolzioPerformanceTests', 'network', 'package'])
        self.assertEqual(json.loads((self.output / 'checks.json').read_text())['performance'], 'failure')
        self.assertTrue((self.output / 'performance.log').exists())

    def test_network_failure_prevents_package(self):
        result = self.execute('network')
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1], 'network')
        self.assertNotIn('package', self.calls())
        self.assertFalse(self.output.exists())


class SyncIntegrationTests(unittest.TestCase):
    def setUp(self):
        import json, os, tempfile
        from unittest.mock import patch
        from test_publish_folzio import PublishFixture
        self.sync = module()
        quiet = patch.object(self.sync.release, 'summary')
        quiet.start()
        self.addCleanup(quiet.stop)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.fixture = PublishFixture(self.base)
        self.root = self.fixture.source
        self.fixture.git('branch', '-m', 'master')
        self.previous = self.sync.release.git(self.root, 'rev-parse', 'HEAD')
        self.fixture.write('release.json', json.dumps(dict(version='1.2.3', build_number='12', notes_file='release-notes/v1.2.3.md')))
        self.fixture.write('release-notes/v1.2.3.md', 'Release notes\n')
        self.fixture.commit()
        self.target = self.sync.release.git(self.root, 'rev-parse', 'HEAD')
        for i in range(3):
            self.fixture.write('ordinary.txt', str(i))
            self.fixture.commit()
        self.latest = self.sync.release.git(self.root, 'rev-parse', 'HEAD')
        self.fixture.git('update-ref', 'refs/remotes/origin/master', self.latest)
        self.event = self.base / 'event.json'
        self.event.write_text(json.dumps(dict(repository=dict(default_branch='master'), before=self.previous)))
        self.env = patch.dict(os.environ, GITHUB_REPOSITORY=self.sync.DEV_REPO,
                              GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REF='refs/heads/master',
                              GITHUB_EVENT_PATH=str(self.event), GITHUB_SHA=self.latest)
        self.env.start()
        self.addCleanup(self.env.stop)
        self.pr = dict(number=7, merged=True, merge_commit_sha=self.target, head=dict(sha=self.target),
                       base=dict(ref='master', sha=self.previous, repo=dict(full_name=self.sync.DEV_REPO)))
        owner = self

        class API:
            def pages(self, path, key=None):
                if path == f'commits/{owner.target}/pulls':
                    return [{'number': 7}]
                if path == f'pulls/7/files':
                    return [{'filename': 'release.json'}]
                if path.startswith('actions/workflows/'):
                    return []
                if path.startswith('commits/'):
                    return []
                raise AssertionError(path)

            def api(self, path, **kwargs):
                if path == 'pulls/7':
                    return owner.pr
                raise AssertionError(path)

        self.api = API()
        self.request = self.sync.release.load_request(self.root, self.target)

    def test_manual_candidate_uses_m_instead_of_m_plus_three(self):
        result = self.sync.preview_plan(self.root, self.target, self.api)
        self.assertEqual(result['source_sha'], self.target)
        self.assertNotEqual(result['source_sha'], self.latest)
        with self.assertRaises(ValueError):
            self.sync.preview_plan(self.root, self.latest, self.api)

    def test_missing_preview_builds_fixed_m_and_waits(self):
        import os
        os.environ.update(GITHUB_EVENT_NAME='push', GITHUB_SHA=self.target)
        result = self.sync.sync_plan(self.root, '', '', '', self.base / 'plan', self.api)
        self.assertEqual(result['state'], 'rebuild')
        self.assertFalse(result['ready'])
        self.assertEqual(result['source_sha'], self.target)
        self.assertFalse((self.base / 'plan/source').exists())
        os.environ.update(EXPECTED_PAYLOAD_DIGEST=result['payload_digest'], EXPECTED_SOURCE_SHA=self.target)
        self.sync.unpack(self.base / 'plan')
        self.assertFalse((self.base / 'plan/source/ordinary.txt').exists())
        self.assertEqual(self.sync.tree_id(self.base / 'plan/source'), result['public_tree'])
        self.assertTrue((self.base / 'plan/source/scripts/check-no-network.sh').stat().st_mode & 0o111)

    def plan_for_write(self, legacy=False):
        from unittest.mock import patch
        self.remote = self.base / 'public.git'
        self.sync.release.run('git', 'init', '--bare', '-q', self.remote)
        self.sync.release.run('git', '--git-dir=' + str(self.remote), 'symbolic-ref', 'HEAD', 'refs/heads/main')
        public = self.base / 'initial'
        public.mkdir()
        self.sync.release.git(public, 'init', '-q', '-b', 'main')
        self.sync.release.git(public, 'config', 'user.name', 'Test')
        self.sync.release.git(public, 'config', 'user.email', 'test@example.invalid')
        (public / 'README.md').write_text('Initial\n')
        self.sync.release.git(public, 'add', '-A')
        body = 'Legacy' if legacy else 'Initial\n\nDevelopment-Commit: ' + self.previous
        self.sync.release.git(public, 'commit', '-qm', body)
        base = self.sync.release.git(public, 'rev-parse', 'HEAD')
        initial_tree = self.sync.release.git(public, 'rev-parse', 'HEAD^{tree}')
        self.sync.release.git(public, 'push', str(self.remote), 'main')
        metadata = dict(self.request, source_sha=self.target)
        directory = self.base / 'plan'
        with patch.object(self.sync, 'candidate', return_value=metadata), patch.object(
                self.sync, 'public_snapshot', return_value=(base, initial_tree, body, not legacy)):
            result = self.sync.sync_plan(self.root, self.target, '42', base if legacy else '', directory, self.api)
        self.assertEqual(result['state'], 'write')
        return directory, result, base

    def test_writer_publishes_single_public_commit_from_verified_tree(self):
        import os
        from unittest.mock import patch
        directory, result, base = self.plan_for_write()
        os.environ.update(EXPECTED_PLAN_DIGEST=result['plan_digest'], EXPECTED_PAYLOAD_DIGEST=result['payload_digest'],
                          EXPECTED_SOURCE_SHA=self.target, GH_TOKEN='local-test-only')
        original = self.sync.release.run

        def local_run(*args, **kwargs):
            args = tuple(str(self.remote) if str(a) == self.sync.PUBLIC_URL else a for a in args)
            return original(*args, **kwargs)

        with patch.object(self.sync.release, 'run', side_effect=local_run):
            self.sync.write(self.root, directory)
        current = self.sync.release.git(self.remote, 'rev-parse', 'refs/heads/main')
        self.assertNotEqual(current, base)
        self.assertEqual(self.sync.release.git(self.remote, 'show', '-s', '--format=%P', current), base)
        self.assertIn(self.target, self.sync.release.git(self.remote, 'show', '-s', '--format=%B', current))
        self.assertEqual(self.sync.release.git(self.remote, 'show', current + ':release.json'),
                         (self.root / 'release.json').read_text())
        self.assertFalse(self.sync.release.git(self.remote, 'ls-tree', current, '--', 'ordinary.txt'))

    def test_writer_rejects_payload_tampering_before_any_clone(self):
        import os
        from unittest.mock import patch
        directory, result, _ = self.plan_for_write()
        os.environ.update(EXPECTED_PLAN_DIGEST=result['plan_digest'], EXPECTED_PAYLOAD_DIGEST=result['payload_digest'],
                          EXPECTED_SOURCE_SHA=self.target)
        with (directory / 'source.tar').open('ab') as stream:
            stream.write(b'tampered')
        with patch.object(self.sync.release, 'run') as command, self.assertRaises(ValueError):
            self.sync.write(self.root, directory)
        command.assert_not_called()

    def test_api_authentication_failure_does_not_become_rebuild(self):
        from unittest.mock import patch
        with patch.object(self.sync, 'candidate', side_effect=self.sync.release.APIError('403')):
            with self.assertRaises(self.sync.release.APIError):
                self.sync.sync_plan(self.root, self.target, '42', '', self.base / 'plan', self.api)

    def test_first_sync_waits_for_explicit_base(self):
        from unittest.mock import patch
        with patch.object(self.sync, 'candidate', return_value=dict(self.request)), patch.object(
                self.sync, 'public_snapshot', return_value=('a' * 40, 'b' * 40, 'legacy', False)):
            result = self.sync.sync_plan(self.root, self.target, '42', '', self.base / 'plan', self.api)
        self.assertEqual(result['state'], 'bootstrap')
        self.assertFalse(result['ready'])

    def test_real_git_race_rejects_non_fast_forward(self):
        import os
        from unittest.mock import patch
        directory, result, base = self.plan_for_write()
        os.environ.update(EXPECTED_PLAN_DIGEST=result['plan_digest'], EXPECTED_PAYLOAD_DIGEST=result['payload_digest'],
                          EXPECTED_SOURCE_SHA=self.target, GH_TOKEN='local-test-only')
        original = self.sync.release.run
        competing = []

        def local_run(*args, **kwargs):
            args = tuple(str(self.remote) if str(a) == self.sync.PUBLIC_URL else a for a in args)
            if args[0] == 'git' and 'push' in args and not competing:
                other = self.base / 'competitor'
                original('git', 'clone', '-q', self.remote, other)
                original('git', '-C', other, 'config', 'user.name', 'Test')
                original('git', '-C', other, 'config', 'user.email', 'test@example.invalid')
                (other / 'README.md').write_text('Concurrent change\n')
                original('git', '-C', other, 'add', '-A')
                original('git', '-C', other, 'commit', '-qm', 'Concurrent publication')
                competing.append(original('git', '-C', other, 'rev-parse', 'HEAD'))
                original('git', '-C', other, 'push', 'origin', 'main')
            return original(*args, **kwargs)

        with patch.object(self.sync.release, 'run', side_effect=local_run), self.assertRaises(ValueError):
            self.sync.write(self.root, directory)
        self.assertEqual(self.sync.release.git(self.remote, 'rev-parse', 'refs/heads/main'), competing[0])
        self.assertNotEqual(competing[0], base)


class CandidateDownloadTests(unittest.TestCase):
    setUp = CandidateValidationTests.setUp

    def bundle(self):
        import hashlib, io, json, zipfile
        inner = io.BytesIO()
        with zipfile.ZipFile(inner, 'w') as archive:
            archive.writestr('Folzio.app/Contents/MacOS/Folzio', 'binary')
        name = 'Folzio-v1.2.3-macos-arm64.zip'
        outer = io.BytesIO()
        with zipfile.ZipFile(outer, 'w') as archive:
            archive.writestr(name, inner.getvalue())
            archive.writestr('SHA256SUMS', hashlib.sha256(inner.getvalue()).hexdigest() + '  ' + name + '\n')
            archive.writestr('candidate.json', json.dumps(self.meta))
        data = outer.getvalue()
        self.run['repository'] = dict(full_name=self.sync.DEV_REPO)
        item = dict(id=99, expired=False, name=f'release-candidate-{self.meta["source_sha"]}-42-1',
                    digest='sha256:' + hashlib.sha256(data).hexdigest())
        owner = self

        class API:
            def api(self, path, **kwargs):
                if path == 'actions/runs/42':
                    return owner.run
                raise AssertionError(path)

            def pages(self, path, key=None):
                if key == 'jobs':
                    return owner.jobs
                if key == 'artifacts':
                    return [item]
                raise AssertionError(path)

        return API(), data, item

    def test_download_is_bound_to_api_digest_and_attempt(self):
        from unittest.mock import patch
        api, data, item = self.bundle()
        with patch.object(self.sync.release, 'run', return_value=data):
            result = self.sync.candidate(api, '42', self.target, self.pr, self.tree, self.request)
            self.assertEqual(result['public_tree'], self.tree)
            item['digest'] = 'sha256:' + '0' * 64
            with self.assertRaisesRegex(ValueError, 'digest'):
                self.sync.candidate(api, '42', self.target, self.pr, self.tree, self.request)

    def test_expired_artifact_never_downloads(self):
        from unittest.mock import patch
        api, _, item = self.bundle()
        item['expired'] = True
        with patch.object(self.sync.release, 'run') as download, self.assertRaises(ValueError):
            self.sync.candidate(api, '42', self.target, self.pr, self.tree, self.request)
        download.assert_not_called()
