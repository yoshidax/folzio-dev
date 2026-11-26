import pathlib
import shutil
import subprocess
import tempfile
import unittest


API_LINE = '    static let latestReleaseURL = URL(string: "https://api.github.com/repos/yoshidax/folzio/releases/latest")!\n'
SESSION_LINE = '        let session = URLSession(configuration: configuration)\n'
UPDATE_SOURCE = 'Sources/FolzioCore/Update/UpdateSource.swift'
TRANSPORT = 'Sources/FolzioApp/Update/URLSessionUpdateTransport.swift'


class NetworkCheckTestCase(unittest.TestCase):
    def run_files(self, files):
        repository = pathlib.Path(__file__).resolve().parents[3]
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            (root / 'scripts').mkdir()
            script = root / 'scripts/check-no-network.sh'
            shutil.copyfile(repository / 'scripts/check-no-network.sh', script)
            (root / 'Sources').mkdir()
            for path, body in files.items():
                source = root / path
                source.parent.mkdir(parents=True, exist_ok=True)
                source.write_text(body)
            return subprocess.run(['bash', str(script)], capture_output=True, text=True).returncode


class NetworkImportExceptionTests(NetworkCheckTestCase):
    def run_check(self, name, body):
        return self.run_files({f'Sources/FolzioCore/Operations/{name}': body})

    def test_allows_exact_scheme_comparison(self):
        self.assertEqual(self.run_check('ImportedFileName.swift', '    ["http", "https"].contains(scheme),\n'), 0)

    def test_rejects_network_call_on_exception_line(self):
        self.assertNotEqual(self.run_check('ImportedFileName.swift', '["http", "https"].contains(scheme), URLSession.shared\n'), 0)

    def test_rejects_other_urls_and_other_files(self):
        self.assertNotEqual(self.run_check('ImportedFileName.swift', 'let url = "https://example.com"\n'), 0)
        self.assertNotEqual(self.run_check('Other.swift', '["http", "https"].contains(scheme),\n'), 0)


class AboutLinkExceptionTests(NetworkCheckTestCase):
    about = 'Sources/FolzioCore/About/AboutInfo.swift'

    def test_allows_repository_link(self):
        line = '    public static let repositoryURL = URL(string: "https://github.com/yoshidax/folzio")!\n'
        self.assertEqual(self.run_files({self.about: line}), 0)

    def test_rejects_other_url_in_about(self):
        self.assertNotEqual(self.run_files({self.about: 'let url = "https://example.com"\n'}), 0)


class UpdateCheckExceptionTests(NetworkCheckTestCase):
    """The update check (TAK-95) may use exactly the API URL in one file and URLSession in another."""

    def test_allows_update_check_lines(self):
        self.assertEqual(self.run_files({UPDATE_SOURCE: API_LINE, TRANSPORT: SESSION_LINE}), 0)

    def test_allows_session_type_in_signature(self):
        line = '    static func make(session: URLSession = .shared) -> UpdateTransport {\n'
        self.assertEqual(self.run_files({TRANSPORT: line}), 0)

    def test_rejects_other_url_in_update_source(self):
        self.assertNotEqual(self.run_files({UPDATE_SOURCE: 'let url = "https://example.com"\n'}), 0)

    def test_rejects_extra_url_on_api_line(self):
        line = API_LINE.rstrip('\n') + ' // "https://example.com"\n'
        self.assertNotEqual(self.run_files({UPDATE_SOURCE: line}), 0)

    def test_rejects_session_in_update_source(self):
        self.assertNotEqual(self.run_files({UPDATE_SOURCE: SESSION_LINE}), 0)

    def test_rejects_url_in_transport(self):
        line = '        let session = URLSession.shared; let url = "https://example.com"\n'
        self.assertNotEqual(self.run_files({TRANSPORT: line}), 0)

    def test_rejects_network_framework_in_transport(self):
        self.assertNotEqual(self.run_files({TRANSPORT: 'import Network\n'}), 0)
        self.assertNotEqual(self.run_files({TRANSPORT: '        let connection = NWConnection(host: host, port: 443, using: .tls)\n'}), 0)
        self.assertNotEqual(self.run_files({TRANSPORT: '        _ = URLSession.shared; _ = NWConnection.self\n'}), 0)

    def test_rejects_session_in_other_files(self):
        self.assertNotEqual(self.run_files({'Sources/FolzioApp/Other.swift': SESSION_LINE}), 0)
        self.assertNotEqual(self.run_files({'Sources/FolzioCore/Update/UpdateChecker.swift': SESSION_LINE}), 0)

    def test_rejects_api_url_in_other_files(self):
        self.assertNotEqual(self.run_files({'Sources/FolzioCore/Update/UpdateChecker.swift': API_LINE}), 0)
        self.assertNotEqual(self.run_files({TRANSPORT: API_LINE}), 0)


if __name__ == '__main__':
    unittest.main()
