"""Claude Code の MessageDisplay hook。回答に出る ID を、画面に表示するときだけ定義へのリンクにする。

  .claude/settings.json の hooks.MessageDisplay に、次のコマンドで登録する（保守者が登録する）。
  python3 -I "$CLAUDE_PROJECT_DIR/scripts/dev/link-spec-ids-hook.py"

標準入力の JSON の delta（新しく確定した行）の中で、
- 仕様の ID（FR・SC・EC・A・USn-ASm）は、定義の行への `[FR-080](specs/product/search.md#L8)` にする。
  探す場所と優先する順は scripts/dev/find-spec-id.sh と同じ（作業中の feature の spec.md、次に specs/product/）
- `TAK-xx` は Linear の Issue へのリンクにする
- 定義が見つからない ID、既存のリンク・URL・インラインコード・コードフェンスの中の ID は変えない

置き換えは表示だけに効き、会話の記録とエージェントが見る内容は変わらない。
変える箇所がないとき、または失敗したときは何も出力しない（Claude Code が元の文を表示する）。
delta は行のまとまりごとに届くので、コードフェンスの中にいるかを message_id ごとに一時ファイルへ覚える。
規則と環境ごとの確認結果: docs_private/agents/id-links.md
"""

import json
import os
import re
import sys
import tempfile
from pathlib import Path

# python3 -I でも同じディレクトリの解析モジュールを読み込む。
sys.path.insert(0, str(Path(__file__).resolve().parent))
from spec_id_definitions import FENCE_RE, ID_PATTERN, ROOT, locate_definitions

LINEAR_ISSUE_URL = "https://linear.app/takyoshida/issue/"
# 左から順に試す。先に一致した既存のリンク・URL・インラインコードは、そのまま残す。
TOKEN_RE = re.compile(
    r"(?P<link>!?\[[^\]\n]*\]\([^)\n]*\))"
    r"|(?P<url>(?:https?|file)://[^\s)>\]]+)"
    r"|(?P<code>`+)[^\n]*?(?P=code)"
    # 日本語の文字は \w に一致するので、前後の判定は ASCII に限る（「FR-080の定義」もリンクにする）。
    # 前に / や . がある ID はパスの一部（specs/TAK-82-foo など）として残す。
    rf"|(?<![A-Za-z0-9_/.-])(?P<id>{ID_PATTERN}|TAK-[0-9]+)(?![A-Za-z0-9_-])"
)
# 新しく確定した行の候補をすばやく判定する（ID がない delta では定義を探さない）。
CANDIDATE_RE = re.compile(rf"(?:{ID_PATTERN}|TAK-[0-9]+)")


def state_path(message_id):
    name = re.sub(r"[^A-Za-z0-9_-]", "", str(message_id))[:100] or "unknown"
    return Path(tempfile.gettempdir()) / f"folzio-link-spec-ids-{name}"


def split_by_fence(lines, fence):
    """各行がコードフェンスの外の本文か（True）を返す。判定は spec_id_definitions.lines_with_fence_kind と同じ。"""
    prose = []
    for line in lines:
        marker = FENCE_RE.match(line)
        if fence:
            prose.append(False)
            if marker and marker[1].startswith(fence) and not marker[2].strip():
                fence = ""
        elif marker and (marker[1].startswith("~") or "`" not in marker[2]):
            fence = marker[1]
            prose.append(False)
        else:
            prose.append(True)
    return prose, fence


def link_ids(lines, prose):
    spec_ids = {
        match["id"]
        for line, is_prose in zip(lines, prose) if is_prose
        for match in TOKEN_RE.finditer(line)
        if match["id"] and not match["id"].startswith("TAK-")
    }
    targets = {}
    for label, locations in locate_definitions(spec_ids).items() if spec_ids else ():
        path, number = min(locations, key=lambda location: (location[0].as_posix(), location[1]))
        target = f"{path.relative_to(ROOT).as_posix()}#L{number}"
        targets[label] = f"<{target}>" if " " in target else target

    def replace(match):
        label = match["id"]
        if not label:
            return match[0]
        if label.startswith("TAK-"):
            return f"[{label}]({LINEAR_ISSUE_URL}{label})"
        if label in targets:
            return f"[{label}]({targets[label]})"
        return label

    return "".join(TOKEN_RE.sub(replace, line) if is_prose else line for line, is_prose in zip(lines, prose))


def display_content(event):
    delta = event.get("delta")
    if not isinstance(delta, str):
        return None

    state = state_path(event.get("message_id", ""))
    try:
        fence = state.read_text(encoding="utf-8")
    except OSError:
        fence = ""
    lines = delta.splitlines(keepends=True)
    prose, fence = split_by_fence(lines, fence)
    if event.get("final", True):
        state.unlink(missing_ok=True)
    elif fence:
        state.write_text(fence, encoding="utf-8")
    else:
        state.unlink(missing_ok=True)

    if not CANDIDATE_RE.search(delta):
        return None
    content = link_ids(lines, prose)
    return content if content != delta else None


def main():
    try:
        content = display_content(json.load(sys.stdin))
    except Exception:  # 表示を止めないため、どの失敗でも元の文を表示させる。
        return 0
    if content is not None:
        json.dump(
            {"hookSpecificOutput": {"hookEventName": "MessageDisplay", "displayContent": content}},
            sys.stdout,
            ensure_ascii=False,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
