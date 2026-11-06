#!/usr/bin/env python3
"""固定したリリース対象と検証済み候補を照合し、公開用への更新を制御する。"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import release

DEV_REPO = 'yoshidax/folzio-dev'
PUBLIC_URL = 'https://github.com/yoshidax/folzio.git'
REQUIRED = {'static', 'build', 'normal', 'network', 'package'}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def ancestor(root, older, newer):
    result = subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', older, newer], capture_output=True)
    if result.returncode not in (0, 1):
        raise ValueError('source の祖先関係を解決できません')
    return result.returncode == 0


def tree_id(source):
    with tempfile.TemporaryDirectory() as temp:
        release.git(temp, 'init', '-q')
        args = ['-c', 'core.autocrlf=false', '-c', 'core.filemode=true',
                '-c', 'core.attributesFile=/dev/null', '--work-tree=' + str(Path(source).resolve())]
        release.git(temp, *args, 'add', '-f', '-A', '--', '.')
        return release.git(temp, *args, 'write-tree')


def export(root, sha, dest):
    # default branch が進んでも、書き出し規則は対象コミットから読み取る。
    with tempfile.TemporaryDirectory() as temp:
        for name in ('export-public.sh', 'export-public.py'):
            (Path(temp) / name).write_bytes(release.blob(root, sha, 'scripts/dev/' + name))
        release.run('bash', Path(temp) / 'export-public.sh', sha, dest, cwd=root)
    return tree_id(dest)


def pack_source(source, archive):
    with tarfile.open(archive, 'w') as stream:
        for file in sorted(Path(source).rglob('*')):
            if file.is_file():
                stream.add(file, arcname=str(file.relative_to(source)), recursive=False)


def extract_source(archive, destination):
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=False)
    seen = set()
    with tarfile.open(archive) as stream:
        for item in stream:
            path = Path(item.name)
            if (not item.isfile() or path.is_absolute() or '..' in path.parts or '.git' in path.parts
                    or '\\' in item.name or item.name in seen):
                raise ValueError('payload が通常の一意な公開ファイルではありません')
            seen.add(item.name)
            dest = destination / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            with stream.extractfile(item) as src, dest.open('wb') as target:
                shutil.copyfileobj(src, target)
            dest.chmod(item.mode & 0o777)


def unpack(directory):
    directory = Path(directory)
    if digest(directory / 'source.tar') != os.environ.get('EXPECTED_PAYLOAD_DIGEST'):
        raise ValueError('再候補の source digest が判定 job と一致しません')
    info = json.loads((directory / 'candidate-info.json').read_text())
    if info['source_sha'] != os.environ.get('EXPECTED_SOURCE_SHA'):
        raise ValueError('再候補の対象 SHA が判定 job と一致しません')
    extract_source(directory / 'source.tar', directory / 'source')


def publication_state(base, expected, body, target, same_tree, bootstrap, initialized, ancestor):
    release.require_sha(base)
    release.require_sha(expected)
    release.require_sha(target)
    if base != expected:
        raise ValueError('公開用 main が変わりました。非 force で再確認してください')
    lines = [line for line in body.splitlines() if line.startswith('Development-Commit:')]
    if not lines:
        if initialized:
            raise ValueError('初期化済みの公開先で source trailer が失われています')
        if not bootstrap:
            return 'bootstrap'
        if release.require_sha(bootstrap) != base:
            raise ValueError('bootstrap_public_base が公開用 main と一致しません')
        return 'initialize'
    if len(lines) != 1 or not re.fullmatch(r'Development-Commit: [0-9a-f]{40}', lines[0]):
        raise ValueError('source trailer が不正または重複しています')
    if bootstrap:
        raise ValueError('初期化済みの公開先には bootstrap を指定できません')
    previous = lines[0].split(': ', 1)[1]
    if previous != target and not ancestor(previous, target):
        raise ValueError('古い対象による公開内容の巻き戻しを拒否しました')
    if same_tree:
        return 'skip'
    if previous == target:
        raise ValueError('同じ source の公開 tree を変更できません')
    return 'write'


def event_context(root, preview=False):
    if os.environ.get('GITHUB_REPOSITORY') != DEV_REPO:
        raise ValueError('開発用リポジトリ以外では実行できません')
    event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
    if event['repository']['default_branch'] != 'master':
        raise ValueError('default branch の変更を先に設定へ反映してください')
    name = os.environ['GITHUB_EVENT_NAME']
    if preview and name == 'pull_request':
        if event['pull_request']['base']['ref'] != 'master':
            raise ValueError('候補の base は master に限定します')
    elif name not in ('push', 'workflow_dispatch') or os.environ.get('GITHUB_REF') != 'refs/heads/master':
        raise ValueError('書き込みと手動起動は master の実行に限定します')
    return event


def merged_release(root, sha, api):
    release.require_sha(sha)
    if not ancestor(root, sha, 'origin/master'):
        raise ValueError('対象は origin/master に含まれる必要があります')
    candidates = api.pages(f'commits/{sha}/pulls')
    prs = [api.api(f'pulls/{p["number"]}') for p in candidates]
    prs = [p for p in prs if p.get('merged') and p.get('merge_commit_sha') == sha
           and p['base']['ref'] == 'master' and p['base']['repo']['full_name'] == DEV_REPO]
    if len(prs) != 1:
        raise ValueError('マージ済みリリース PR を一意に特定できません')
    pr = prs[0]
    if not any(f['filename'] == 'release.json' for f in api.pages(f'pulls/{pr["number"]}/files')):
        raise ValueError('対象の PR は release.json を変更していません')
    release.load_request(root, sha)
    return pr


def preview_plan(root, requested, api):
    event = event_context(root, preview=True)
    if os.environ['GITHUB_EVENT_NAME'] == 'pull_request':
        pr = event['pull_request']
        head = release.require_sha(pr['head']['sha'])
        base = release.require_sha(pr['base']['sha'])
        merge_base = release.git(root, 'merge-base', base, head)
        if release.blob(root, merge_base, 'release.json', optional=True) == release.blob(root, head, 'release.json', optional=True):
            return dict(ready=False, reason='通常の PR: 配布要求の変更なし')
        sha = release.require_sha(os.environ['GITHUB_SHA'])
        request = release.load_request(root, sha)
        release.require_unused_version(release.GitHub(release.PUBLIC_REPO), request['version'])
        return dict(ready=True, source_sha=sha, source_kind='pr-preview', release_pr=pr['number'],
                    pr_head_sha=head, pr_base_sha=base)
    sha = release.require_sha(requested)
    pr = merged_release(root, sha, api)
    return dict(ready=True, source_sha=sha, source_kind='merged-source', release_pr=pr['number'],
                pr_head_sha=pr['head']['sha'], pr_base_sha=pr['base']['sha'])


def record(root, source, output, info):
    output = Path(output)
    request = release.load_request(source)
    release.verify_assets(output, request['version'])
    checks = json.loads((output / 'checks.json').read_text())
    if checks['required_checks'] != {key: 'success' for key in REQUIRED}:
        raise ValueError('候補の必須検証が完了していません')
    toolchain = release.run('xcodebuild', '-version') + '\n' + release.run('swift', '--version')
    metadata = dict(info, **request, public_tree=tree_id(source), toolchain=toolchain,
                    run_id=int(os.environ['GITHUB_RUN_ID']), run_attempt=int(os.environ['GITHUB_RUN_ATTEMPT']),
                    run_url=f'https://github.com/{DEV_REPO}/actions/runs/{os.environ["GITHUB_RUN_ID"]}', **checks)
    (output / 'checks.json').unlink()
    (output / 'candidate.json').write_text(json.dumps(metadata, indent=2) + '\n')
    name = f'release-candidate-{info["source_sha"]}-{metadata["run_id"]}-{metadata["run_attempt"]}'
    release.output(dict(artifact_name=name))
    release.summary(f'候補: {name}\n\n対象: {info["source_sha"]}\n\n性能: {metadata["performance"]}\n\n'
                    'ZIP を取得しローカル確認後、この SHA と run ID で同期を再開できます。')


def validate_candidate(meta, run, jobs, target, pr, tree, request):
    release.require_sha(meta['source_sha'])
    release.require_sha(meta['public_tree'])
    path = run['path'].split('@')[0]
    allowed = {'.github/workflows/release-candidate.yml', '.github/workflows/sync-public.yml'}
    if path not in allowed or run['status'] != 'completed':
        raise ValueError('信頼された成功 run の候補ではありません')
    latest = latest_jobs(jobs)
    if run['conclusion'] != 'success':
        waiting = latest.get('Await local verification')
        if (path != '.github/workflows/sync-public.yml' or run['conclusion'] != 'failure'
                or not waiting or waiting['conclusion'] != 'failure'
                or not any(s['name'] == 'Await local verification' and s['conclusion'] == 'failure' for s in waiting['steps'])
                or any(j['conclusion'] not in ('success', 'skipped') for name, j in latest.items() if name != 'Await local verification')):
            raise ValueError('確認待ち以外の失敗を含む run は利用できません')
    expected_job = 'Rebuild release candidate' if path.endswith('sync-public.yml') else 'Build release candidate'
    producer = latest.get(expected_job)
    if (int(meta['run_id']) != int(run['id']) or not producer
            or int(meta['run_attempt']) != int(producer['run_attempt'])
            or not 1 <= int(meta['run_attempt']) <= int(run['run_attempt'])):
        raise ValueError('候補と run / attempt が一致しません')
    good = [j for j in [producer] if j['conclusion'] == 'success'
            and any(s['name'] == 'Validate and package candidate' and s['conclusion'] == 'success' for s in j['steps'])]
    if len(good) != 1 or meta['required_checks'] != {key: 'success' for key in REQUIRED}:
        raise ValueError('候補の必須 job / step が成功していません')
    if meta['performance'] not in ('success', 'failure', 'timed_out'):
        raise ValueError('性能測定の結果がありません')
    if meta['source_kind'] == 'pr-preview':
        if path.endswith('sync-public.yml') or run['event'] != 'pull_request' or run['head_sha'] != pr['head']['sha']:
            raise ValueError('preview の run と PR head が一致しません')
        if meta['pr_head_sha'] != pr['head']['sha'] or meta['release_pr'] != pr['number']:
            raise ValueError('preview の PR が一致しません')
    elif meta['source_kind'] != 'merged-source' or meta['source_sha'] != target:
        raise ValueError('候補の固定対象 SHA が一致しません')
    elif run['event'] not in ('push', 'workflow_dispatch') or (path.endswith('release-candidate.yml') and run['event'] != 'workflow_dispatch'):
        raise ValueError('候補の実行イベントが一致しません')
    if meta['public_tree'] != tree or any(meta[key] != request[key] for key in request):
        raise ValueError('候補と対象の公開 tree または要求が異なります')
    if not isinstance(meta.get('toolchain'), str) or 'Xcode 16.0' not in meta['toolchain']:
        raise ValueError('候補の toolchain が一致しません')


def latest_jobs(jobs):
    latest = {}
    for job in jobs:
        name = job['name']
        if name not in latest or int(job['run_attempt']) > int(latest[name]['run_attempt']):
            latest[name] = job
        elif int(job['run_attempt']) == int(latest[name]['run_attempt']):
            raise ValueError('同じ attempt の job が重複しています')
    result = {}
    for name, job in latest.items():
        # failed jobs だけの再実行では、実行していない job も新しい ID / attempt で複製される。
        # API のランナー・時刻・全 step が同一なら、最初の実行に成果物を結び付ける。
        copies = [job]
        if job.get('runner_id') and job.get('started_at') and job.get('completed_at'):
            copies = [other for other in jobs if other['name'] == name and all(
                other.get(key) == job.get(key) for key in
                ('runner_id', 'started_at', 'completed_at', 'conclusion', 'steps'))]
        result[name] = dict(job, run_attempt=min(int(other['run_attempt']) for other in copies))
    return result


def candidate(api, run_id, target, pr, tree, request):
    if not str(run_id).isdigit() or int(run_id) <= 0:
        raise ValueError('candidate_run_id は正の数字で指定してください')
    run = api.api(f'actions/runs/{int(run_id)}')
    if run.get('repository', {}).get('full_name') != DEV_REPO:
        raise ValueError('候補のリポジトリが一致しません')
    jobs = api.pages(f'actions/runs/{run_id}/jobs?filter=all', key='jobs')
    expected_job = 'Rebuild release candidate' if run['path'].split('@')[0].endswith('sync-public.yml') else 'Build release candidate'
    producer = latest_jobs(jobs).get(expected_job)
    if not producer:
        raise ValueError('候補を生成した job がありません')
    attempt = int(producer['run_attempt'])
    artifacts = api.pages(f'actions/runs/{run_id}/artifacts', key='artifacts')
    artifacts = [a for a in artifacts if not a['expired'] and re.fullmatch(
        rf'release-candidate-[0-9a-f]{{40}}-{int(run_id)}-{attempt}', a['name'])]
    if len(artifacts) != 1:
        raise ValueError('有効な候補 artifact が一意に見つかりません')
    item = artifacts[0]
    data = release.run('gh', 'api', f'repos/{DEV_REPO}/actions/artifacts/{item["id"]}/zip', binary=True)
    if item.get('digest') != 'sha256:' + hashlib.sha256(data).hexdigest():
        raise ValueError('候補 artifact の digest が API と一致しません')
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            if len(archive.namelist()) != len(set(archive.namelist())):
                raise ValueError('候補 archive のファイル名が重複しています')
            for name in archive.namelist():
                if '/' in name or '\\' in name or name in ('.', '..'):
                    raise ValueError('候補 archive に不正なパスがあります')
            archive.extractall(root)
        meta = json.loads((root / 'candidate.json').read_text(), object_pairs_hook=release.json_object)
        expected_name = f'release-candidate-{meta["source_sha"]}-{run_id}-{attempt}'
        if item['name'] != expected_name:
            raise ValueError('候補名と metadata が一致しません')
        validate_candidate(meta, run, jobs, target, pr, tree, request)
        release.verify_assets(root, request['version'])
    return meta


def public_snapshot():
    temp = tempfile.TemporaryDirectory()
    try:
        path = Path(temp.name) / 'public'
        release.run('git', 'clone', '--bare', '--quiet', '--filter=blob:none', '--single-branch', '--branch', 'main', PUBLIC_URL, path)
        base = release.git(path, 'rev-parse', 'refs/heads/main')
        tree = release.git(path, 'rev-parse', base + '^{tree}')
        body = release.git(path, 'show', '-s', '--format=%B', base)
        history = release.git(path, 'log', '--format=%B', 'refs/heads/main')
        return base, tree, body, 'Development-Commit:' in history
    finally:
        temp.cleanup()


def sync_plan(root, source_sha, run_id, bootstrap, output_dir, api):
    event = event_context(root)
    manual = os.environ['GITHUB_EVENT_NAME'] == 'workflow_dispatch'
    if not manual:
        source_sha = release.require_sha(os.environ['GITHUB_SHA'])
        before = release.require_sha(event['before'])
        previous = None if before == '0' * 40 else release.blob(root, before, 'release.json', optional=True)
        current = release.blob(root, source_sha, 'release.json', optional=True)
        if previous == current or current is None:
            return dict(state='skip', ready=False, reason='通常の master 更新: 配布要求の変更なし')
    elif not run_id:
        raise ValueError('手動再開には確認した candidate_run_id が必要です')
    pr = merged_release(root, source_sha, api)
    request = release.load_request(root, source_sha)
    info = dict(source_sha=source_sha, source_kind='merged-source', release_pr=pr['number'],
                pr_head_sha=pr['head']['sha'], pr_base_sha=pr['base']['sha'])
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=False)
    source = output_dir / 'source'
    tree = export(root, source_sha, source)
    base, existing_tree, body, initialized = public_snapshot()
    decision = publication_state(base, base, body, source_sha, tree == existing_tree,
                                 bootstrap, initialized, lambda a, b: ancestor(root, a, b))
    if tree != existing_tree:
        release.require_unused_version(release.GitHub(release.PUBLIC_REPO), request['version'])
    archive = output_dir / 'source.tar'
    pack_source(source, archive)
    selected = run_id
    if not selected:
        runs = api.pages(f'actions/workflows/release-candidate.yml/runs?event=pull_request&head_sha={pr["head"]["sha"]}', key='workflow_runs')
        runs = [r for r in runs if r['conclusion'] == 'success' and r['head_sha'] == pr['head']['sha']]
        if runs:
            selected = str(max(runs, key=lambda r: r['id'])['id'])
    try:
        if not selected:
            raise ValueError('preview の候補がありません')
        meta = candidate(api, selected, source_sha, pr, tree, request)
    except (ValueError, KeyError, OSError, zipfile.BadZipFile) as error:
        if isinstance(error, release.APIError):
            raise
        if manual:
            raise ValueError(f'指定した候補を検証できません。対象 {source_sha} で再生成してください: {error}') from error
        (output_dir / 'candidate-info.json').write_text(json.dumps(info))
        shutil.rmtree(source)
        return dict(state='rebuild', ready=False, reason=str(error), public_tree=tree, payload_digest=digest(archive), **info)
    if decision in ('bootstrap', 'skip'):
        return dict(state=decision, ready=False, source_sha=source_sha, public_base=base,
                    reason='初期 base の明示が必要です' if decision == 'bootstrap' else '公開済みの同じ tree')
    plan = dict(source_sha=source_sha, public_tree=tree, expected_public_base=base,
                public_initialized=initialized,
                bootstrap_public_base=bootstrap, payload_digest=digest(archive),
                candidate_run_id=int(selected), candidate=meta, release_pr=pr['number'])
    plan_file = output_dir / 'plan.json'
    plan_file.write_text(json.dumps(plan, indent=2) + '\n')
    shutil.rmtree(source)
    return dict(state='write', ready=True, source_sha=source_sha, payload_digest=plan['payload_digest'],
                plan_digest=digest(plan_file), public_tree=tree, public_base=base)


def write(root, directory):
    event_context(root)
    directory = Path(directory)
    if digest(directory / 'plan.json') != os.environ.get('EXPECTED_PLAN_DIGEST'):
        raise ValueError('plan の digest が判定 job と一致しません')
    plan = json.loads((directory / 'plan.json').read_text())
    if plan['source_sha'] != os.environ.get('EXPECTED_SOURCE_SHA'):
        raise ValueError('対象 SHA が判定 job と一致しません')
    if digest(directory / 'source.tar') != os.environ.get('EXPECTED_PAYLOAD_DIGEST') or digest(directory / 'source.tar') != plan['payload_digest']:
        raise ValueError('payload の digest が一致しません')
    # writer は受け取ったスクリプトを実行せず、通常ファイルだけを別領域へ展開する。
    with tempfile.TemporaryDirectory() as temp:
        temp = Path(temp)
        source = temp / 'source'
        extract_source(directory / 'source.tar', source)
        if tree_id(source) != plan['public_tree']:
            raise ValueError('payload の公開 tree が一致しません')
        public = temp / 'public'
        release.git(temp, 'init', '--bare', '--quiet', public)
        release.git(public, 'remote', 'add', 'origin', PUBLIC_URL)
        release.git(public, 'fetch', '--quiet', '--depth=1', '--filter=blob:none', 'origin', 'refs/heads/main:refs/heads/main')
        base = release.git(public, 'rev-parse', 'refs/heads/main')
        body = release.git(public, 'show', '-s', '--format=%B', base)
        initialized = plan['public_initialized']
        existing_tree = release.git(public, 'rev-parse', base + '^{tree}')
        decision = publication_state(base, plan['expected_public_base'], body, plan['source_sha'],
                                     existing_tree == plan['public_tree'],
                                     plan['bootstrap_public_base'], initialized, lambda a, b: ancestor(root, a, b))
        if decision == 'skip':
            release.summary('同じ tree は公開済みです')
            return
        if decision not in ('write', 'initialize'):
            raise ValueError('初期化の明示が必要です')
        if existing_tree != plan['public_tree']:
            # App の資格情報でドラフトも含めて再照合し、同期前に使用済み version を拒否する。
            release.require_unused_version(release.GitHub(release.PUBLIC_REPO), plan['candidate']['version'])
        release.git(public, 'read-tree', '--empty')
        release.git(public, '-c', 'core.autocrlf=false', '-c', 'core.filemode=true',
                    '-c', 'core.attributesFile=/dev/null', '--work-tree=' + str(source), 'add', '-f', '-A', '--', '.')
        tree = release.git(public, 'write-tree')
        if tree != plan['public_tree']:
            raise ValueError('書き込み直前の tree が一致しません')
        env = os.environ.copy()
        for role in ('AUTHOR', 'COMMITTER'):
            env['GIT_' + role + '_NAME'] = 'Folzio Release'
            env['GIT_' + role + '_EMAIL'] = 'folzio-release@users.noreply.github.com'
        message = f'Publish {plan["candidate"]["version"]}\n\nDevelopment-Commit: {plan["source_sha"]}\n'
        commit = release.run('git', '-C', public, 'commit-tree', tree, '-p', base, env=env, data=message)
        remote = release.git(public, 'ls-remote', '--exit-code', 'origin', 'refs/heads/main').split()[0]
        if remote != base:
            raise ValueError('公開先の並行更新を検出しました。force せず再実行してください')
        askpass = temp / 'askpass.py'
        askpass.write_text('#!/usr/bin/env python3\nimport os,sys\nprint("x-access-token" if "Username" in sys.argv[1] else os.environ["GH_TOKEN"])\n')
        askpass.chmod(0o700)
        env.update(GIT_ASKPASS=str(askpass), GIT_TERMINAL_PROMPT='0')
        release.run('git', '-C', public, 'push', 'origin', f'{commit}:refs/heads/main', env=env)
        release.summary(f'同期成功: source {plan["source_sha"]} → public {commit}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['preview-plan', 'sync-plan', 'record', 'write', 'unpack', 'export'])
    parser.add_argument('--source-sha', default='')
    parser.add_argument('--candidate-run-id', default='')
    parser.add_argument('--bootstrap-public-base', default='')
    parser.add_argument('--directory', required=True)
    parser.add_argument('--info')
    args = parser.parse_args()
    root = Path.cwd()
    api = release.GitHub(DEV_REPO)
    if args.operation == 'preview-plan':
        result = preview_plan(root, args.source_sha, api)
        Path(args.directory).mkdir(parents=True, exist_ok=False)
        (Path(args.directory) / 'candidate-info.json').write_text(json.dumps(result))
        release.output(result)
        release.summary(str(result))
    elif args.operation == 'sync-plan':
        result = sync_plan(root, args.source_sha, args.candidate_run_id, args.bootstrap_public_base, args.directory, api)
        release.output(result)
        release.summary(str(result))
    elif args.operation == 'record':
        info = json.loads(Path(args.info).read_text())
        record(root, args.directory, Path(args.directory).parent / 'candidate', info)
    elif args.operation == 'unpack':
        unpack(args.directory)
    elif args.operation == 'export':
        export(root, release.require_sha(args.source_sha), args.directory)
    else:
        write(root, args.directory)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError, zipfile.BadZipFile) as error:
        release.summary(f'公開処理を停止しました: {error}')
        sys.exit(1)
