import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


class CheckAgentsMdTests(unittest.TestCase):
    def run_check(self, text, files=(), base_text=None, base_ref="master", base_files=()):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dev = root / "scripts/dev"
            dev.mkdir(parents=True)
            for script in ("check-agents-md.sh", "base-ref.sh"):
                shutil.copy2(ROOT / "scripts/dev" / script, dev / script)
            for name in files:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                if name.endswith("/"):
                    path.mkdir(exist_ok=True)
                else:
                    path.write_text("x\n")
            if base_text is not None:
                self.commit_base(root, base_text, base_ref, base_files)
            (root / "AGENTS.md").write_text(text)
            return subprocess.run([str(dev / "check-agents-md.sh")], capture_output=True, text=True)

    def commit_base(self, root, text, ref, files=()):
        """Commits AGENTS.md and `files` as the base ref, then removes `files` from the working tree."""
        def git(*args):
            subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True)
        git("init", "-q", "-b", "work")
        (root / "AGENTS.md").write_text(text)
        for name in files:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("x\n")
        git("add", "-A")
        git("-c", "user.name=test", "-c", "user.email=test@example.com", "commit", "-q", "-m", "base")
        git("update-ref", f"refs/{'remotes/' if '/' in ref else 'heads/'}{ref}", "HEAD")
        for name in files:
            (root / name).unlink()
            if (root / name).parent != root and not any((root / name).parent.iterdir()):
                (root / name).parent.rmdir()

    def lines(self, count):
        return "".join(f"line {i}\n" for i in range(count))

    def test_passes_without_warning_at_45_lines(self):
        result = self.run_check(self.lines(45))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("warning", result.stderr)

    def test_warns_but_passes_between_46_and_50_lines(self):
        for count in (46, 50):
            result = self.run_check(self.lines(count))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("warning: AGENTS.md has", result.stderr)

    def test_fails_above_50_lines(self):
        result = self.run_check(self.lines(51))
        self.assertEqual(result.returncode, 1)
        self.assertIn("AGENTS.md has 51 lines (limit: 50)", result.stderr)
        self.assertIn("docs_private/agents/README.md", result.stderr)

    def test_passes_when_referenced_paths_exist(self):
        text = "Read `docs/guide.md` and `specs/product/`. Run `python3 scripts/dev/check.py`.\n"
        result = self.run_check(text, files=("docs/guide.md", "specs/product/", "scripts/dev/check.py"))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_fails_when_referenced_path_is_missing(self):
        result = self.run_check("Read `docs/guide.md` and `docs/old.md`.\n", files=("docs/guide.md",))
        self.assertEqual(result.returncode, 1)
        self.assertIn("  docs/old.md", result.stderr)
        self.assertNotIn("  docs/guide.md", result.stderr)

    def test_ignores_globs_placeholders_urls_build_output_and_plain_words(self):
        text = ("`specs/TAK-*` `specs/TAK-<nn>-<slug>` `claude/*` `https://example.com/x` "
                "`open .build/Folzio.app` `FolzioCore` `brew install`\n")
        result = self.run_check(text)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_counts_last_line_without_trailing_newline(self):
        result = self.run_check(self.lines(51).rstrip("\n"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("AGENTS.md has 51 lines", result.stderr)

    def test_does_not_warn_when_not_longer_than_base(self):
        for ref in ("origin/master", "master"):
            result = self.run_check(self.lines(48), base_text=self.lines(48), base_ref=ref)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn("warning", result.stderr)

    def test_warns_when_longer_than_base(self):
        result = self.run_check(self.lines(48), base_text=self.lines(47), base_ref="origin/master")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("warning: AGENTS.md has 48 lines (47 on origin/master", result.stderr)

    def test_ignores_slash_words_that_are_not_repository_paths(self):
        text = "`git merge origin/master` `/speckit-bug-assess` `yoshidax/folzio` `/Users/name/x`\n"
        result = self.run_check(text, files=("docs/",))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_strips_line_numbers(self):
        result = self.run_check("See `docs/guide.md:42` and `docs/old.md:7`.\n", files=("docs/guide.md",))
        self.assertEqual(result.returncode, 1)
        self.assertIn("  docs/old.md\n", result.stderr)
        self.assertNotIn("guide", result.stderr)

    def test_checks_paths_inside_fenced_code_blocks(self):
        text = "```bash\nscripts/old.sh --flag\n'scripts/ok.sh'\n```\n"
        result = self.run_check(text, files=("scripts/ok.sh",))
        self.assertEqual(result.returncode, 1)
        self.assertIn("  scripts/old.sh", result.stderr)
        self.assertNotIn("ok.sh", result.stderr)

    def test_checks_markdown_link_targets(self):
        text = "See [guide](docs/guide.md), [old](docs/old.md), [site](https://example.com/x) and [top](#usage).\n"
        result = self.run_check(text, files=("docs/guide.md",))
        self.assertEqual(result.returncode, 1)
        self.assertIn("  docs/old.md\n", result.stderr)
        self.assertNotIn("guide", result.stderr)
        self.assertNotIn("example", result.stderr)

    def test_detects_renamed_top_level_directory(self):
        text = "Read `oldtop/rules.md` and `notapath/x`.\n"
        result = self.run_check(text, base_text=text, base_files=("oldtop/rules.md",))
        self.assertEqual(result.returncode, 1)
        self.assertIn("  oldtop/rules.md", result.stderr)
        self.assertNotIn("notapath", result.stderr)

    def test_detects_removed_root_file_but_not_other_file_names(self):
        text = "Read `README.ja.md` and the feature's `tasks.md`.\n"
        result = self.run_check(text, base_text=text, base_files=("README.ja.md",))
        self.assertEqual(result.returncode, 1)
        self.assertIn("  README.ja.md", result.stderr)
        self.assertNotIn("tasks.md", result.stderr)

    def test_strips_anchors(self):
        text = "See `docs/guide.md#usage` and [guide](docs/guide.md#install).\n"
        result = self.run_check(text, files=("docs/guide.md",))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_accepts_existing_path_with_spaces(self):
        result = self.run_check("See `docs/release notes.md`.\n", files=("docs/release notes.md",))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_warns_without_base_ref(self):
        result = self.run_check(self.lines(46))
        self.assertIn("no base ref to compare against", result.stderr)

    def test_detects_misspelled_first_directory_when_the_path_has_an_extension(self):
        text = "Read `doc_private/x.md`, but not branches like `claude/tak-72-spec` or `owner/repo`.\n"
        result = self.run_check(text, files=("docs_private/",))
        self.assertEqual(result.returncode, 1)
        self.assertIn("  doc_private/x.md", result.stderr)
        self.assertNotIn("claude", result.stderr)
        self.assertNotIn("owner", result.stderr)

    def test_detects_misspelled_root_file_near_an_existing_one(self):
        text = "Read `READMEE.md`, the feature's `tasks.md`, and `SKILL.md`.\n"
        result = self.run_check(text, files=("README.md",))
        self.assertEqual(result.returncode, 1)
        self.assertIn("  READMEE.md", result.stderr)
        self.assertNotIn("tasks.md", result.stderr)
        self.assertNotIn("SKILL.md", result.stderr)

    def test_checks_reference_style_link_definitions(self):
        text = "See [x][r] and [y][s].\n\n[r]: docs/missing.md\n[s]: <docs/guide.md> \"Guide\"\n[t]: https://example.com/x\n"
        result = self.run_check(text, files=("docs/guide.md",))
        self.assertEqual(result.returncode, 1)
        self.assertIn("  docs/missing.md", result.stderr)
        self.assertNotIn("guide", result.stderr)
        self.assertNotIn("example", result.stderr)

    def test_says_last_fetch_only_for_origin(self):
        result = self.run_check(self.lines(48), base_text=self.lines(47), base_ref="master")
        self.assertIn("(47 on master, limit", result.stderr)
        self.assertNotIn("fetch", result.stderr)

    def test_passes_without_any_backticks(self):
        result = self.run_check("Plain text only.\n")
        self.assertEqual(result.returncode, 0, result.stderr)


class BaseRefTests(unittest.TestCase):
    def run_base_ref(self, refs):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dev = root / "scripts/dev"
            dev.mkdir(parents=True)
            shutil.copy2(ROOT / "scripts/dev/base-ref.sh", dev / "base-ref.sh")
            if refs is not None:
                def git(*args):
                    subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True)
                git("init", "-q", "-b", "work")
                git("-c", "user.name=test", "-c", "user.email=test@example.com",
                    "commit", "-q", "--allow-empty", "-m", "base")
                for ref in refs:
                    git("update-ref", f"refs/{'remotes/' if '/' in ref else 'heads/'}{ref}", "HEAD")
            return subprocess.run([str(dev / "base-ref.sh")], cwd=root, capture_output=True, text=True)

    def test_prefers_origin_master(self):
        result = self.run_base_ref(["master", "origin/master"])
        self.assertEqual((result.returncode, result.stdout), (0, "origin/master\n"))

    def test_falls_back_to_master(self):
        result = self.run_base_ref(["master"])
        self.assertEqual((result.returncode, result.stdout), (0, "master\n"))

    def test_fails_without_either_ref(self):
        for refs in ([], None):
            result = self.run_base_ref(refs)
            self.assertEqual((result.returncode, result.stdout), (1, ""))


if __name__ == "__main__":
    unittest.main()
