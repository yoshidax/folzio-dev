#!/usr/bin/env python3
"""Check that the shortcut tables in the README and the user guide match the app's default keys.

    python3 scripts/dev/check-shortcut-docs.py [--root PATH]

Reads the default keys from ShortcutCommands.all in Sources/FolzioCore/Shortcuts/ShortcutCommand.swift.
- User guide (docs/usage.md, docs/usage.ja.md): every default key must appear in the shortcut tables.
- User guide and README (README.md, README.ja.md): every key with a modifier in the tables must be a known key.
Uses only the Python standard library and runs on Python 3.9 or later.
"""

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SWIFT_SOURCE = "Sources/FolzioCore/Shortcuts/ShortcutCommand.swift"

# (ファイル, 表を探す節の見出し, 既定のキーがすべて載っていることを求めるか)
# README の表は「よく使う」ものだけを載せる部分集合なので、載っているキーの正しさだけを確かめる。
DOCUMENTS = (
    ("docs/usage.md", "## Keyboard Shortcuts", True),
    ("docs/usage.ja.md", "## ショートカット一覧", True),
    ("README.md", "## Useful Shortcuts", False),
    ("README.ja.md", "## よく使うショートカット", False),
)

# Swift の定義から読めないが、表に書いてよい修飾キー付きのキー。
# - ⇧/⌥ と矢印: FixedShortcutKeys がループで作る固定キー
# - ⌃F2: macOS のメニューバーへ移るキー（「このアプリケーションで開く」の手順で使う）
EXTRA_KNOWN_KEYS = frozenset(
    [f"{modifier}{arrow}" for modifier in ("⇧", "⌥") for arrow in ("↑", "↓", "←", "→")] + ["⌃F2"]
)

# KeyCombination.displayText と同じ順序と表記。
MODIFIER_SYMBOLS = (("control", "⌃"), ("option", "⌥"), ("shift", "⇧"), ("command", "⌘"))
KEY_NAMES = {
    "up": "↑",
    "down": "↓",
    "left": "←",
    "right": "→",
    "delete": "Delete",
    "return": "Return",
    "escape": "Esc",
    "tab": "Tab",
    "space": "Space",
}

KEY_CALL_RE = re.compile(r'key\("((?:[^"\\]|\\.)+)",\s*\[([^\]]*)\]\)')
COMBINATION_RE = re.compile(r'KeyCombination\(key:\s*"((?:[^"\\]|\\.)+)",\s*modifiers:\s*\[([^\]]*)\]\)')
COMMAND_RE = re.compile(r"ShortcutCommand\(\s*id:\s*\.(\w+),")
CASE_RE = re.compile(r"^\s*case\s+(\w+)\s*$", re.MULTILINE)
# 文書の中の修飾キー付きのキー。名前のキーを 1 文字のキーより先に試す。
# 後ろに英字が続くもの（⌘-click など）はキーとして扱わない。
DOC_KEY_RE = re.compile(
    r"([⌃⌥⇧⌘]+)(Delete|Return|Esc|Tab|Space|F[0-9]{1,2}|[↑↓←→]|[!-~−])(?![A-Za-z])"
)
SEPARATOR_ROW_RE = re.compile(r"^\|[\s:|-]+\|$")


class CheckError(Exception):
    pass


def display_text(key, modifiers_source):
    """Swift の key 引数と修飾キーの配列の文字列から、displayText と同じ表示を作る。"""
    modifiers = set(re.findall(r"\.(\w+)", modifiers_source))
    unknown = modifiers - {name for name, _ in MODIFIER_SYMBOLS}
    if unknown:
        raise CheckError(f"未知の修飾キー {sorted(unknown)}")
    text = "".join(symbol for name, symbol in MODIFIER_SYMBOLS if name in modifiers)
    key = key.replace('\\"', '"').replace("\\\\", "\\")
    return text + KEY_NAMES.get(key, key.upper())


def block(source, start_pattern, label):
    """start_pattern の後の最初の [ と、対応する ] の間の文字列を返す。"""
    match = re.search(start_pattern, source)
    if not match:
        raise CheckError(f"{label} が見つからない")
    start = source.index("[", match.end() - 1)
    depth = 0
    for index in range(start, len(source)):
        if source[index] == "[":
            depth += 1
        elif source[index] == "]":
            depth -= 1
            if depth == 0:
                return source[start + 1:index]
    raise CheckError(f"{label} の終わりが見つからない")


def read_definitions(source):
    """既定のキーの {表示: コマンド ID} と、表に書いてよいキーの集合を返す。"""
    enum = re.search(r"enum ShortcutCommandID\b[^{]*\{(.*?)\n\}", source, re.DOTALL)
    if not enum:
        raise CheckError("ShortcutCommandID が見つからない")
    ids = CASE_RE.findall(enum.group(1))

    all_block = block(source, r"static let all: \[ShortcutCommand\] = \[", "ShortcutCommands.all")
    starts = [match.start() for match in COMMAND_RE.finditer(all_block)] + [len(all_block)]
    defaults = {}
    alternates = set()
    for begin, end in zip(starts, starts[1:]):
        chunk = all_block[begin:end]
        command_id = COMMAND_RE.match(chunk).group(1)
        default = re.search(r"defaultCombination:\s*" + KEY_CALL_RE.pattern, chunk)
        if not default:
            raise CheckError(f"{command_id} の既定のキーを読めない")
        defaults[display_text(*default.groups())] = command_id
        alternates_match = re.search(r"alternates:\s*\[(.*)\]", chunk, re.DOTALL)
        if alternates_match:
            alternates.update(display_text(*call) for call in KEY_CALL_RE.findall(alternates_match.group(1)))

    read_ids = list(defaults.values())
    if sorted(read_ids) != sorted(ids) or len(read_ids) != len(ids):
        missing = sorted(set(ids) - set(read_ids))
        extra = sorted(set(read_ids) - set(ids))
        raise CheckError(
            f"ShortcutCommands.all から読んだコマンドが ShortcutCommandID と一致しない（読めない: {missing}、余分: {extra}、"
            f"読んだ数 {len(read_ids)}、case の数 {len(ids)}）"
        )

    fixed_and_reserved = set()
    for name in ("FixedShortcutKeys", "ReservedShortcutKeys"):
        match = re.search(r"enum " + name + r"\b.*?\n\}", source, re.DOTALL)
        if not match:
            raise CheckError(f"{name} が見つからない")
        fixed_and_reserved.update(display_text(*call) for call in COMBINATION_RE.findall(match.group(0)))

    known = set(defaults) | alternates | fixed_and_reserved | EXTRA_KNOWN_KEYS
    return defaults, known


def table_keys(text, heading):
    """見出しの節にある表の、2 列目以降の修飾キー付きのキーを (行番号, キー) で返す。"""
    lines = text.splitlines()
    try:
        start = lines.index(heading)
    except ValueError:
        raise CheckError(f"見出し「{heading}」が見つからない") from None
    level = len(heading.split(" ", 1)[0])
    keys = []
    rows = 0
    in_fence = False
    for index in range(start + 1, len(lines)):
        line = lines[index].strip()
        if line.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        # 同じか上の階層の見出しで節が終わる。
        heading_match = re.match(r"(#+)\s", line)
        if heading_match and len(heading_match.group(1)) <= level:
            break
        if not line.startswith("|") or SEPARATOR_ROW_RE.match(line):
            continue
        following = lines[index + 1].strip() if index + 1 < len(lines) else ""
        if SEPARATOR_ROW_RE.match(following):
            continue  # 見出しの行
        rows += 1
        cells = line.strip("|").split("|")
        for cell in cells[1:]:
            for modifiers, key in DOC_KEY_RE.findall(cell):
                keys.append((index + 1, modifiers + ("-" if key == "−" else key)))
    if rows == 0:
        raise CheckError(f"見出し「{heading}」の節に表の行がない")
    return keys


def check(root):
    errors = []
    try:
        defaults, known = read_definitions((root / SWIFT_SOURCE).read_text(encoding="utf-8"))
    except (CheckError, OSError) as error:
        return [f"{SWIFT_SOURCE}: {error}"]

    for name, heading, require_all in DOCUMENTS:
        try:
            keys = table_keys((root / name).read_text(encoding="utf-8"), heading)
        except (CheckError, OSError) as error:
            errors.append(f"{name}: {error}")
            continue
        for line, key in keys:
            if key not in known:
                errors.append(f"{name}:{line}: {key} は既定のキー・別名・固定キー・予約キーのどれでもない")
        if require_all:
            found = {key for _, key in keys}
            for key, command_id in defaults.items():
                if key not in found:
                    errors.append(f"{name}: {command_id} の既定のキー {key} が「{heading[3:]}」の表にない")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=ROOT, help="リポジトリのルート（テスト用）")
    args = parser.parse_args()
    errors = check(args.root)
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        print(f"check-shortcut-docs: {len(errors)} 件の食い違い（定義: {SWIFT_SOURCE}）", file=sys.stderr)
        return 1
    print("check-shortcut-docs: ショートカットの表は既定のキーと一致している")
    return 0


if __name__ == "__main__":
    sys.exit(main())
