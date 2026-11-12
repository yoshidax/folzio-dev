#!/usr/bin/env python3
"""開発用・公開用の workflow の lock を、実行先のパスで生成・検証する。"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]


def workflow_files(directory):
    return sorted(path for path in directory.iterdir()
                  if not path.is_symlink() and path.is_file()
                  and path.suffix in ('.yml', '.yaml'))


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
    print('開発用 workflow の lock', flush=True)
    run_lock(root, mode)
    managed = root / 'scripts/dev/oss-workflows'
    with tempfile.TemporaryDirectory(prefix='folzio-actions-lock-') as directory:
        public = Path(directory)
        workflows = public / '.github/workflows'
        workflows.mkdir(parents=True)
        sources = workflow_files(managed)
        for source in sources:
            shutil.copyfile(source, workflows / source.name)
        lock = managed / 'actions.lock'
        if lock.is_symlink():
            raise ValueError('公開用 actions.lock は通常ファイルで管理してください')
        if lock.exists():
            shutil.copyfile(lock, workflows / lock.name)
        print('公開用 workflow の lock（書き出し先のパスで検査）', flush=True)
        run_lock(public, mode)
        if mode not in ('--verify', '--verify-local'):
            generated = workflows / 'actions.lock'
            if not generated.is_file():
                raise ValueError('公開用 actions.lock が生成されませんでした')
            # CLI は uses も書き換える。成功時だけ lock と一緒に管理元へ戻す。
            for source in sources:
                shutil.copyfile(workflows / source.name, source)
            shutil.copyfile(generated, lock)


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
