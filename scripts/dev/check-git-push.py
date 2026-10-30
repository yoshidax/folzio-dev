#!/usr/bin/env python3
"""Claude Code の PreToolUse フック。Bash の `git push` を許可リスト方式で判定する。

標準入力のフック JSON から tool_input.command を読み、`git push` を含むコマンドが次をすべて満たすときだけ通す。
  - リモートは origin、refspec（ブランチ名）を明示している
  - 宛先は作業ブランチ（ALLOWED_PREFIXES）で、master / main ではない
  - 強制 push・削除・ミラー・全ブランチ・`+` や `:` で始まる refspec を使わない
違反または解析できないときは終了コード 2 とメッセージ（標準エラー）で止める。

完全な防御ではない。`bash -c` の中身の解析・変数展開・`gh api` などの直接呼び出しは判定できないため、
`git push` を含む入れ子の実行は拒否し、それ以外は GitHub トークンの権限に任せる。
"""
import json
import re
import shlex
import sys

ALLOWED_PREFIXES = ('claude/', 'ci/', 'chore/', 'docs/', 'feature/', 'bugfix/', 'agent/')
PROTECTED_BRANCHES = ('master', 'main')
ALLOWED_FLAGS = {'-u', '--set-upstream', '-n', '--dry-run', '-v', '--verbose', '-q', '--quiet', '--no-verify'}
# `git` の直後に置ける、値を1つ取るグローバルオプション
GLOBAL_OPTIONS_WITH_VALUE = {'-C', '-c', '--git-dir', '--work-tree', '--namespace'}
SEPARATORS = {';', '&&', '||', '|', '&', '\n'}
WRAPPERS = {'sh', 'bash', 'zsh', 'eval', 'xargs', 'env', 'command', 'exec', 'nohup', 'time', 'sudo'}
# 1つのトークンの中に `git ... push` の文字列が入っている（`bash -c "git push ..."` など）
NESTED_PUSH = re.compile(r'\bgit\s+(?:\S+\s+)*push\b')


class Denied(Exception):
    pass


def split_segments(command):
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    segments, current = [], []
    skip_next = False
    for token in lexer:
        if skip_next:
            skip_next = False
        elif token in SEPARATORS:
            if current:
                segments.append(current)
            current = []
        elif set(token) <= set('<>&') and ('<' in token or '>' in token):
            # リダイレクト（`2>&1`、`> file`）は引数ではないので、演算子・先行する fd 番号・転送先を捨てる
            if current and current[-1].isdigit():
                current.pop()
            skip_next = True
        else:
            current.append(token)
    if current:
        segments.append(current)
    return segments


def check_refspec(refspec):
    if refspec.startswith('+') or refspec.startswith(':'):
        raise Denied(f'refspec "{refspec}" は強制 push または削除になるため使えません')
    parts = refspec.split(':')
    if len(parts) > 2:
        raise Denied(f'refspec "{refspec}" を解釈できません')
    source = parts[0]
    destination = parts[1] if len(parts) == 2 else source
    if destination in ('', 'HEAD'):
        raise Denied(f'refspec "{refspec}" は宛先のブランチ名を明示してください')
    destination = destination.removeprefix('refs/heads/')
    if destination in PROTECTED_BRANCHES or destination.rsplit('/', 1)[-1] in PROTECTED_BRANCHES:
        raise Denied(f'{destination} への push は禁止です')
    if not destination.startswith(ALLOWED_PREFIXES):
        raise Denied(f'{destination} は作業ブランチ（{", ".join(ALLOWED_PREFIXES)}）ではありません')


def check_push(args):
    positional = []
    for arg in args:
        if arg.startswith('-') and not positional:
            if arg not in ALLOWED_FLAGS:
                raise Denied(f'オプション {arg} は許可リストにありません')
        else:
            positional.append(arg)
    if len(positional) < 2:
        raise Denied('`git push origin <branch>` の形で、リモートとブランチを明示してください')
    if positional[0] != 'origin':
        raise Denied(f'リモート {positional[0]} への push は許可されていません')
    for refspec in positional[1:]:
        if refspec.startswith('-'):
            raise Denied(f'ブランチ名の後ろのオプション {refspec} は許可されていません')
        check_refspec(refspec)


def find_git_push(tokens):
    """tokens が `git [global options] push ...` なら push 以降の引数を返す。違えば None。"""
    if not tokens or tokens[0].rsplit('/', 1)[-1] != 'git':
        return None
    index = 1
    while index < len(tokens):
        token = tokens[index]
        if token in GLOBAL_OPTIONS_WITH_VALUE:
            index += 2
        elif token.startswith('-'):
            index += 1
        else:
            break
    if index < len(tokens) and tokens[index] == 'push':
        return tokens[index + 1:]
    return None


def check_command(command):
    for tokens in split_segments(command):
        push_args = find_git_push(tokens)
        if push_args is not None:
            check_push(push_args)
            continue
        if any(NESTED_PUSH.search(token) for token in tokens):
            raise Denied('入れ子や変数経由の `git push` は判定できないため拒否します')
        if tokens[0].rsplit('/', 1)[-1] in WRAPPERS and any('push' in token for token in tokens):
            raise Denied(f'`{tokens[0]}` 経由の push は判定できないため拒否します')


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 0
    if payload.get('tool_name') != 'Bash':
        return 0
    command = (payload.get('tool_input') or {}).get('command') or ''
    if 'push' not in command:
        return 0
    try:
        check_command(command)
    except Denied as error:
        print(f'git push guard: {error}', file=sys.stderr)
        return 2
    except ValueError as error:
        print(f'git push guard: コマンドを解析できないため拒否します ({error})', file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
