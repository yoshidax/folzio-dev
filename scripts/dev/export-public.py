#!/usr/bin/env python3
"""指定したコミットを公開用ツリーへ変換し、公開前の静的検査を行う。"""
import getpass
import io
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile


def git(*args, binary=False):
    result = subprocess.run(['git', *args], capture_output=True, text=not binary)
    if result.returncode:
        raise ValueError('Git の読み取りに失敗しました')
    return result.stdout if binary else result.stdout.strip()


def skeleton(text):
    result, code = [], False
    for line in text.splitlines():
        if re.match(r'^\s*```', line):
            code = not code
            result.append('fence ' + line.strip())
        elif code:
            result.append('code ' + re.sub(r'\s*#.*$', '', line).rstrip())
        elif re.match(r'^#+ ', line):
            result.append('heading ' + re.match(r'^#+', line)[0])
        elif re.match(r'^\s*([-*]|[0-9]+\.) ', line):
            result.append('list ' + str(len(line) - len(line.lstrip())))
        elif re.match(r'^\s*\|', line):
            result.append('table')
    return result


def extract(data, root):
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for item in archive:
            path = Path(item.name)
            if path.is_absolute() or '..' in path.parts or '.git' in path.parts or '\\' in item.name:
                raise ValueError('不正な archive のパスです')
            dest = root / path
            if item.isdir():
                dest.mkdir(parents=True, exist_ok=True)
            elif item.isfile():
                dest.parent.mkdir(parents=True, exist_ok=True)
                with archive.extractfile(item) as source, dest.open('wb') as target:
                    shutil.copyfileobj(source, target)
                dest.chmod(item.mode & 0o777)
            else:
                raise ValueError(f'公開候補に通常ファイル以外が含まれています: {item.name}')


def export(sha, output):
    if not re.fullmatch(r'[0-9a-f]{40}', sha) or git('rev-parse', sha + '^{commit}') != sha:
        raise ValueError('source は完全なコミット SHA で指定してください')
    output = Path(output).absolute()
    if output.exists() or output.is_symlink():
        raise ValueError('出力先が既に存在します')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.export-', dir=output.parent) as temp:
        root = Path(temp) / 'source'
        root.mkdir()
        extract(git('archive', sha, binary=True), root)
        excluded = {'.specify', '.claude', '.agents', '.kilo', '.codex', '.vscode', 'specs',
                    'docs_private', 'shared-skills', 'AGENTS.md', '.gitattributes'}
        if any((root / path).exists() for path in excluded | {'scripts/dev', '.github/workflows'}):
            raise ValueError('書き出しに開発用のファイルが含まれています（.gitattributes を確認してください）')
        helper = Path(temp) / 'strip.sh'
        helper.write_bytes(git('show', f'{sha}:scripts/dev/strip-readme-dev-note.sh', binary=True))
        subprocess.run(['bash', str(helper), str(root / 'README.md'), str(root / 'README.ja.md')], check=True)
        if skeleton((root / 'README.md').read_text()) != skeleton((root / 'README.ja.md').read_text()):
            raise ValueError('README の構造が一致しません')
        definitions = git('ls-tree', '-z', sha, '--', 'scripts/dev/oss-workflows/', binary=True)
        names = []
        for entry in definitions.split(b'\0'):
            if not entry:
                continue
            info, path = entry.split(b'\t', 1)
            mode, kind, oid = info.decode().split()
            name = Path(os.fsdecode(path)).name
            if mode not in ('100644', '100755') or kind != 'blob' or not name.endswith(('.yml', '.yaml')):
                continue
            if not re.fullmatch(r'[A-Za-z0-9_.-]+', name):
                raise ValueError('workflow 名が不正です')
            file = root / '.github/workflows' / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_bytes(git('cat-file', 'blob', oid, binary=True))
            names.append(name)
        print('公開用 workflow: ' + ' '.join(names) if names else '公開用 workflow はありません')
        home, user = str(Path.home()), getpass.getuser()
        private_link = re.compile(r'(\]\(|href=")[^)"]*(specs/|\.specify/|docs_private/|shared-skills/|AGENTS\.md)')
        for file in root.rglob('*'):
            if not file.is_file():
                continue
            data = file.read_bytes()
            if b'\0' in data:
                continue
            text = data.decode('utf-8', errors='replace')
            path_users = re.findall(r'/(?:Users|home)/([A-Za-z0-9_.-]+)(?:/|[\"\'\s])', text)
            fixture = file.relative_to(root).parts[0] == 'Tests'
            personal = any(not (fixture and name in {'me', 'me2', 'x'}) for name in path_users)
            # GitHub 標準アカウント名は一般語にも現れる。パス検査は省略しない。
            username = user not in {'runner', 'runneradmin'} and user in text
            if home in text or username or personal:
                raise ValueError(f'ローカルのパスまたはユーザー名が含まれています: {file.relative_to(root)}')
            if file.suffix == '.md' and private_link.search(text):
                raise ValueError(f'公開しないファイルへのリンクがあります: {file.relative_to(root)}')
        root.rename(output)


if __name__ == '__main__':
    try:
        if len(sys.argv) != 3:
            raise ValueError('Usage: export-public.sh SOURCE_SHA OUTPUT_DIR')
        export(*sys.argv[1:])
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'export: {error}', file=sys.stderr)
        sys.exit(1)
