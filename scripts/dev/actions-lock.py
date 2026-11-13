#!/usr/bin/env python3
"""開発用・公開用の workflow の lock を、実行先のパスで生成・検証する。"""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]


def workflow_files(root, directory):
    if directory.is_symlink():
        raise ValueError(f'workflow の管理元は通常のディレクトリにしてください: {directory}')
    entries = subprocess.check_output(
        ['git', 'ls-files', '--stage', '-z', '--', directory.relative_to(root).as_posix() + '/'],
        cwd=root)
    tracked = set()
    for entry in entries.split(b'\0'):
        if not entry:
            continue
        info, path = entry.split(b'\t', 1)
        mode, oid, stage = info.decode().split()
        if stage != '0':
            raise ValueError('workflow の競合を解消してください')
        if mode in ('100644', '100755'):
            tracked.add(root / os.fsdecode(path))
    sources = []
    for path in sorted(directory.iterdir()):
        if path.is_symlink() or not path.is_file() or not path.name.endswith(('.yml', '.yaml')):
            continue
        # exporter と同じ名前の規則を使い、未追跡の下書きを lock に混ぜない。
        if not re.fullmatch(r'[A-Za-z0-9_.-]+', path.name):
            raise ValueError(f'workflow 名が不正です: {path.name}')
        if path not in tracked:
            raise ValueError(f'新しい workflow は先に git add してください: {path.relative_to(root)}')
        sources.append(path)
    lock = directory / 'actions.lock'
    if lock.is_symlink() or (lock.exists() and not lock.is_file()):
        raise ValueError(f'actions.lock は通常ファイルで管理してください: {lock}')
    if lock.exists() and not sources:
        raise ValueError(f'workflow がない actions.lock は削除してください: {lock}')
    return sources


def run_lock(root, mode):
    env = os.environ.copy()
    env['GH_ACTIONS_LOCK_REPO_ROOT'] = str(root)
    # 呼び出し元の設定で別のディレクトリを検査しないよう、標準の配置を使う。
    env.pop('GH_ACTIONS_LOCK_WORKFLOWS_DIR', None)
    command = ['gh', 'actions-lock', '--no-interactive']
    if mode:
        command.append(mode)
    subprocess.run(command, cwd=root, env=env, check=True)


def update_locks(root, mode):
    groups = [(root / '.github/workflows', '開発用'),
              (root / 'scripts/dev/oss-workflows', '公開用')]
    # 両方の前提条件を、CLI の実行前に確認する。
    inputs = [(managed, label, workflow_files(root, managed)) for managed, label in groups]
    with tempfile.TemporaryDirectory(prefix='folzio-actions-lock-') as directory:
        updates = []
        for index, (managed, label, sources) in enumerate(inputs):
            if not sources:
                continue
            staged = Path(directory) / str(index)
            workflows = staged / '.github/workflows'
            workflows.mkdir(parents=True)
            lock = managed / 'actions.lock'
            for source in sources + ([lock] if lock.exists() else []):
                shutil.copyfile(source, workflows / source.name)
            print(f'{label} workflow の lock（実行先のパスで検査）', flush=True)
            run_lock(staged, mode)
            if mode not in ('--verify', '--verify-local'):
                for target in sources + [lock]:
                    generated = workflows / target.name
                    if generated.is_symlink() or not generated.is_file():
                        raise ValueError(f'{label}の通常ファイルが生成されませんでした: {target.name}')
                    updates.append((target, generated.read_bytes()))
        # CLI は uses も書き換える。両方の生成と出力確認が成功してから戻す。
        for target, data in updates:
            target.write_bytes(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    for mode in ('--verify', '--verify-local', '--relock'):
        modes.add_argument(mode, dest='mode', action='store_const', const=mode)
    args = parser.parse_args()
    try:
        update_locks(ROOT, args.mode)
    except subprocess.CalledProcessError as error:
        return error.returncode
    except (OSError, ValueError) as error:
        print(f'actions-lock: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
