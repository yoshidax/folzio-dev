"""公開サイトの検査が、日英の対応・構造・参照・仮画像を検出することを確かめる。"""
import importlib.util
from pathlib import Path
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / 'check-site.py'
SPEC = importlib.util.spec_from_file_location('check_site', SCRIPT)
SITE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SITE)

PAGE = '''<!doctype html>
<html lang="{lang}">
<head><link rel="stylesheet" href="{up}style.css"><script src="{up}analytics.js"></script></head>
<body>
  <main class="doc">
    <h1>{title}</h1>
    <p>{text} <kbd>⌘1</kbd></p>
    <img class="shot" src="{up}{image}" alt="">
  </main>
</body>
</html>
'''


class CheckSiteTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.site = Path(directory.name) / 'site'
        (self.site / 'ja').mkdir(parents=True)
        (self.site / 'media/placeholder').mkdir(parents=True)
        for name in ('style.css', 'analytics.js', 'media/shot.jpg', 'media/placeholder/s1.svg'):
            (self.site / name).write_text('x')
        self.write('en', 'index.html')
        self.write('ja', 'index.html')

    def write(self, lang, name, image='media/shot.jpg', title='Title', text='Text', body=PAGE):
        path = self.site / name if lang == 'en' else self.site / 'ja' / name
        up = '' if lang == 'en' else '../'
        path.write_text(body.format(lang=lang, up=up, image=image, title=title, text=text))

    def test_translated_text_and_inline_elements_pass(self):
        self.write('ja', 'index.html', title='見出し', text='<strong>本文</strong>')
        errors, notes = SITE.check(self.site)
        self.assertEqual(errors, [])
        self.assertEqual(notes, [])

    def test_missing_translation_is_reported(self):
        self.write('en', 'privacy.html')
        errors, _ = SITE.check(self.site)
        self.assertEqual(len(errors), 1)
        self.assertIn('has no Japanese page', errors[0])

    def test_structure_difference_is_reported(self):
        self.write('ja', 'index.html', text='Text</p><p>extra')
        errors, _ = SITE.check(self.site)
        self.assertTrue(any('differ in structure' in error for error in errors))

    def test_wrong_language_is_reported(self):
        self.write('ja', 'index.html')
        path = self.site / 'ja/index.html'
        path.write_text(path.read_text().replace('lang="ja"', 'lang="en"'))
        errors, _ = SITE.check(self.site)
        self.assertTrue(any('<html lang> must be "ja"' in error for error in errors))

    def test_missing_and_outside_references_are_reported(self):
        self.write('en', 'index.html', image='media/missing.jpg')
        self.write('ja', 'index.html', image='../outside.jpg')
        errors, _ = SITE.check(self.site)
        self.assertTrue(any('media/missing.jpg not found' in error for error in errors))
        self.assertTrue(any('points outside' in error for error in errors))

    def test_external_script_is_reported(self):
        body = PAGE.replace('<script src="{up}analytics.js">', '<script src="https://example.com/a.js">')
        self.write('en', 'index.html', body=body)
        self.write('ja', 'index.html', body=body)
        errors, _ = SITE.check(self.site)
        self.assertEqual(sum('load scripts from local files only' in error for error in errors), 2)

    def test_placeholders_are_a_note_until_release(self):
        self.write('en', 'index.html', image='media/placeholder/s1.svg')
        self.write('ja', 'index.html', image='media/placeholder/s1.svg')
        errors, notes = SITE.check(self.site)
        self.assertEqual(errors, [])
        self.assertEqual(notes, ['placeholder media still referenced: s1.svg'])
        errors, notes = SITE.check(self.site, release=True)
        self.assertEqual(errors, ['placeholder media still referenced: s1.svg'])

    def test_repository_site_passes(self):
        site = Path(__file__).resolve().parents[3] / 'site'
        errors, _ = SITE.check(site)
        self.assertEqual(errors, [])


if __name__ == '__main__':
    unittest.main()
