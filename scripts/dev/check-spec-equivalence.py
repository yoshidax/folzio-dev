#!/usr/bin/env python3
"""Check that changes to specs/product only change the format, not the text.

    python3 scripts/dev/check-spec-equivalence.py BASE

Compares specs/product at the merge base of BASE and HEAD with the working tree, including uncommitted
and untracked files. Whitespace, line breaks, list and heading markers, emphasis, table pipes and
separator rows, punctuation (。、,), and the format markers of table details (下記 cells, the 表の詳細
line, and the item labels under it) are ignored. The remaining text is compared character by character.
Lists moved, added, and removed text for human review.
Fails when any text is added or removed; moved text alone passes.
Uses only the Python standard library and runs on Python 3.9 or later.
"""

import argparse
import difflib
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC_DIR = "specs/product"

SEE_BELOW = "下記"
DETAILS_MARKER = "**表の詳細**"
IGNORED_CHARACTERS = set("|*。、,")
PREVIEW_LENGTH = 80
MIN_PARTIAL_MOVE = 4

HEADING_RE = re.compile(r"^#{1,6}\s+")
ITEM_RE = re.compile(r"^([-*]|\d+\.)\s+")
SEPARATOR_RE = re.compile(r"^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?$")
DETAIL_LABEL_RE = re.compile(r"^\*\*(.+?)\*\*")


class GitError(Exception):
    """An error in the arguments or in a git command."""


class Normalized:
    """The normalized text of a file and the source line of each character."""

    def __init__(self, text, lines):
        self.text = text
        self.lines = lines


def split_cells(row):
    """Splits a table row into cells, ignoring escaped pipes (`\\|`)."""
    body = row.strip()
    if body.startswith("|"):
        body = body[1:]
    if body.endswith("|") and not body.endswith("\\|"):
        body = body[:-1]
    return [cell.strip() for cell in re.split(r"(?<!\\)\|", body)]


def strip_emphasis(text):
    text = text.strip()
    if text.startswith("**") and text.endswith("**") and len(text) > 4:
        text = text[2:-2].strip()
    return text


def parenthesized_prefix(text):
    """Splits `（inner）rest` into (inner, rest), allowing nested parentheses, or returns (None, text)."""
    if not text.startswith("（"):
        return None, text
    depth = 0
    for index, character in enumerate(text):
        if character == "（":
            depth += 1
        elif character == "）":
            depth -= 1
            if depth == 0:
                return text[1:index], text[index + 1:]
    return None, text


def strip_detail_label(content, header, rows):
    """Removes the format markers from the label of an item under 表の詳細.

    The label repeats the key (first cell) of a row of the table above and adds a parenthesized column
    name or cell value, as in `**key**（column）: text`. The repeated key and a parenthesized text equal to
    a column name or a cell of that row are removed. The parentheses right after the label are removed
    in any case. Any other label text, such as the rest of a longer label or the key of a row that was
    moved out of the table, is kept so that it can be compared as text.
    """
    match = DETAIL_LABEL_RE.match(content)
    if not match:
        return content
    label = match.group(1).strip()
    rest = content[match.end():]
    matched_row = []
    for cells in sorted(rows, key=lambda cells: len(strip_emphasis(cells[0])), reverse=True):
        key = strip_emphasis(cells[0])
        if key and label.startswith(key):
            label = label[len(key):]
            matched_row = cells
            break
    suffix, after = parenthesized_prefix(rest)
    if suffix is None:
        suffix, after = "", rest
    else:
        known = list(header) + [strip_emphasis(cell) for cell in matched_row]
        # A known column name or cell value is a repetition; other text keeps its content without the parentheses.
        if suffix in known:
            suffix = ""
    if after.startswith(":"):
        after = after[1:]
    return label + suffix + after


def normalize(source):
    """Returns the normalized text of a Markdown file with the source line of each character."""
    characters = []
    line_numbers = []
    in_code = False
    details_indent = None
    # The header cells and the body rows of the most recent table.
    table_header = []
    table_rows = []
    in_table = False
    for number, raw in enumerate(source.split("\n"), start=1):
        stripped = raw.strip()
        indent = len(raw) - len(raw.lstrip(" "))
        if stripped.startswith("```"):
            in_code = not in_code
            in_table = False
            continue
        content = stripped
        if not in_code:
            is_table = stripped.startswith("|")
            if stripped == DETAILS_MARKER:
                details_indent = indent
                in_table = False
                continue
            if is_table:
                details_indent = None
                cells = split_cells(stripped)
                if not in_table:
                    table_header = cells
                    table_rows = []
                elif not SEPARATOR_RE.match(stripped):
                    table_rows.append(cells)
                content = "" if SEPARATOR_RE.match(stripped) else "".join(c for c in cells if c != SEE_BELOW)
            elif HEADING_RE.match(stripped):
                details_indent = None
                content = HEADING_RE.sub("", stripped)
            elif stripped:
                item = ITEM_RE.match(stripped)
                if item:
                    content = stripped[item.end():]
                    if details_indent is not None and indent == details_indent:
                        content = strip_detail_label(content, table_header, table_rows)
                elif details_indent is not None and indent <= details_indent:
                    details_indent = None
            in_table = is_table
        for character in unicodedata.normalize("NFC", content):
            if character.isspace() or character in IGNORED_CHARACTERS:
                continue
            characters.append(character)
            line_numbers.append(number)
    return Normalized("".join(characters), line_numbers)


def git(*args):
    result = subprocess.run(["git", *args], cwd=str(ROOT), capture_output=True)
    if result.returncode != 0:
        message = result.stderr.decode("utf-8", "replace").strip()
        raise GitError("git {} failed: {}".format(" ".join(args), message))
    return result.stdout


def base_files(base):
    """Returns the merge base and the Markdown files of specs/product at it, keyed by relative path."""
    try:
        git("rev-parse", "--verify", "--quiet", base + "^{commit}")
    except GitError:
        raise GitError("unknown revision: {}".format(base))
    merge_base = git("merge-base", base, "HEAD").decode().strip()
    if not merge_base:
        raise GitError("no common ancestor of {} and HEAD".format(base))
    names = git("ls-tree", "-r", "-z", "--name-only", merge_base, "--", SPEC_DIR).decode("utf-8").split("\0")
    files = {}
    for name in names:
        if name.endswith(".md"):
            text = git("show", "{}:{}".format(merge_base, name)).decode("utf-8")
            files[name[len(SPEC_DIR) + 1:]] = text
    return merge_base, files


def working_files():
    spec_root = ROOT / SPEC_DIR
    files = {}
    if spec_root.is_dir():
        for path in sorted(spec_root.rglob("*.md")):
            files[path.relative_to(spec_root).as_posix()] = path.read_text(encoding="utf-8")
    return files


def preview(text):
    return text if len(text) <= PREVIEW_LENGTH else text[:PREVIEW_LENGTH] + "…"


def match_moves(deletions, insertions, normalized_base, normalized_head):
    """Explains deleted text as moves into inserted text.

    Each deleted fragment is first searched as a whole in the remaining inserted segments. When it is not
    found, its longest common part with an inserted segment (at least MIN_PARTIAL_MOVE characters) is
    taken as a move, and the rest of the fragment is processed again. This absorbs boundaries that the
    character diff shifted, such as a closing parenthesis matched to the neighboring text.
    Returns the moves, the removed fragments, and the remaining inserted segments.
    """
    segments = [tuple(segment) for segment in insertions]
    moved = []
    removed = []
    pending = sorted(deletions, key=lambda d: d[2] - d[1], reverse=True)
    while pending:
        name, i1, i2 = pending.pop(0)
        old = normalized_base[name]
        fragment = old.text[i1:i2]
        best = None
        for position, (head_name, j1, j2) in enumerate(segments):
            new_text = normalized_head[head_name].text
            found = new_text.find(fragment, j1, j2)
            if found >= 0:
                best = (position, 0, found, len(fragment))
                break
            matcher = difflib.SequenceMatcher(None, fragment, new_text[j1:j2], autojunk=False)
            match = matcher.find_longest_match(0, len(fragment), 0, j2 - j1)
            if match.size >= MIN_PARTIAL_MOVE and (best is None or match.size > best[3]):
                best = (position, match.a, j1 + match.b, match.size)
        if best is None:
            removed.append(("{}:{}".format(name, old.lines[i1]), fragment))
            continue
        position, offset, found, size = best
        head_name, j1, j2 = segments[position]
        new = normalized_head[head_name]
        moved.append(("{}:{}".format(name, old.lines[i1 + offset]),
                      "{}:{}".format(head_name, new.lines[found]), fragment[offset:offset + size]))
        replacement = []
        if found > j1:
            replacement.append((head_name, j1, found))
        if found + size < j2:
            replacement.append((head_name, found + size, j2))
        segments[position:position + 1] = replacement
        rest = []
        if offset > 0:
            rest.append((name, i1, i1 + offset))
        if offset + size < i2 - i1:
            rest.append((name, i1 + offset + size, i2))
        pending = sorted(pending + rest, key=lambda d: d[2] - d[1], reverse=True)
    return moved, removed, segments


def compare(base, head):
    """Compares two {path: source} maps and returns (identical, changed, moved, added, removed)."""
    names = sorted(set(base) | set(head))
    normalized_base = {name: normalize(base[name]) for name in base}
    normalized_head = {name: normalize(head[name]) for name in head}
    empty = Normalized("", [])
    identical = 0
    changed = 0
    deletions = []
    insertions = []
    for name in names:
        old = normalized_base.get(name, empty)
        new = normalized_head.get(name, empty)
        if name in base and name in head and old.text == new.text:
            identical += 1
            continue
        changed += 1
        matcher = difflib.SequenceMatcher(None, old.text, new.text, autojunk=False)
        for tag, i1, i2, j1, j2 in matcher.get_opcodes():
            if tag in ("delete", "replace") and i2 > i1:
                deletions.append((name, i1, i2))
            if tag in ("insert", "replace") and j2 > j1:
                insertions.append([name, j1, j2])

    moved, removed, segments = match_moves(deletions, insertions, normalized_base, normalized_head)
    added = []
    for head_name, j1, j2 in segments:
        new = normalized_head[head_name]
        added.append(("{}:{}".format(head_name, new.lines[j1]), new.text[j1:j2]))
    moved.sort()
    added.sort()
    removed.sort()
    return identical, changed, moved, added, removed


def run(base):
    merge_base, old_files = base_files(base)
    new_files = working_files()
    print("Comparing {} at {} (merge-base of {} and HEAD) with the working tree".format(
        SPEC_DIR, merge_base[:7], base))
    identical, changed, moved, added, removed = compare(old_files, new_files)
    for source, destination, text in moved:
        print("moved   {} -> {}  {}".format(source, destination, preview(text)))
    for location, text in added:
        print("added   {}  {}".format(location, preview(text)))
    for location, text in removed:
        print("removed {}  {}".format(location, preview(text)))
    if not (moved or added or removed):
        print("No differences other than formatting.")
    print("Identical: {} files; changed: {} files".format(identical, changed))
    print("Moved: {}, added: {}, removed: {}".format(len(moved), len(added), len(removed)))
    return 1 if added or removed else 0


def main():
    parser = argparse.ArgumentParser(description="Check that specs/product changes only the format.")
    parser.add_argument("base", help="the revision to compare with, such as origin/master")
    args = parser.parse_args()
    try:
        return run(args.base)
    except GitError as error:
        print("check-spec-equivalence: {}".format(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
