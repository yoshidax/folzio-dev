"""仕様 ID の定義と Markdown のコードフェンスを読み取る。"""

import os
import re
import subprocess
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PRODUCT = ROOT / "specs/product"
ID_PATTERN = r"(?:FR|SC|EC|A)-[0-9]+|US[0-9]+-AS[0-9]+"
ID_RE = re.compile(ID_PATTERN)
DEFINITION_RE = re.compile(rf"^[ \t]*(?:-|[0-9]+\.)[ \t]+\*\*(?P<id>{ID_PATTERN})\*\*")
FENCE_RE = re.compile(r"^[ \t]*(`{3,}|~{3,})(.*)$")


class UnclosedFenceError(ValueError):
    def __init__(self, line):
        super().__init__("unclosed code fence")
        self.line = line


class SpecInputError(ValueError):
    """仕様ファイルを読み取れない。"""


def lines_with_fence_kind(lines):
    """行番号・本文・フェンス内での種類を返す。開いたままならファイル末尾で失敗する。"""
    fence = ""
    opening_line = 0
    for number, line in enumerate(lines, start=1):
        marker = FENCE_RE.match(line)
        kind = None
        if fence:
            kind = "code"
            if marker and marker[1].startswith(fence) and not marker[2].strip():
                fence = ""
                kind = "fence"
        elif marker and (marker[1].startswith("~") or "`" not in marker[2]):
            fence = marker[1]
            opening_line = number
            kind = "fence"
        yield number, line, kind
    if fence:
        raise UnclosedFenceError(opening_line)


def walk_error(error):
    relative = Path(error.filename).relative_to(ROOT)
    raise SpecInputError(f"{relative}: {error.strerror}") from error


def product_markdown_paths():
    # pathlib の glob が列挙時のエラーを無視する環境でも、読み取り失敗を検査結果に反映する。
    for directory, subdirs, names in os.walk(PRODUCT, onerror=walk_error):
        subdirs.sort()
        for name in sorted(names):
            if name.endswith(".md"):
                yield Path(directory) / name


def spec_lines(path):
    """仕様ファイルの行番号・本文・フェンス内での種類を返す。"""
    relative = path.relative_to(ROOT)
    try:
        with path.open(encoding="utf-8") as source:
            yield from lines_with_fence_kind(source)
    except OSError as error:
        raise SpecInputError(f"{relative}: {error.strerror or error}") from error
    except UnicodeError as error:
        raise SpecInputError(f"{relative}: {error}") from error
    except UnclosedFenceError as error:
        raise SpecInputError(f"{relative}:{error.line}: {error}") from error


def definitions_in(path):
    """ファイル内の ID と行番号を定義順に返す。"""
    for number, line, kind in spec_lines(path):
        if kind is None and (definition := DEFINITION_RE.match(line)):
            yield definition["id"], number


def active_feature_specs():
    """作業中の feature の spec.md を返す。

    作業中の feature は、specs/ の下の feature のディレクトリのうち、比べる基準（scripts/dev/base-ref.sh）にまだないもの。
    基準がないとき（git のリポジトリの外など）は、判定できないので空にする。
    git の呼び出しは、ディレクトリの数によらず 2 回にする（MessageDisplay の hook が表示のたびに呼ぶため）。
    """
    base = subprocess.run([ROOT / "scripts/dev/base-ref.sh"], cwd=ROOT, capture_output=True, text=True)
    if base.returncode != 0:
        return []
    tree = subprocess.run(
        ["git", "ls-tree", "-d", "-z", "--name-only", base.stdout.strip(), "--", "specs/"],
        cwd=ROOT, capture_output=True, text=True,
    )
    if tree.returncode != 0:
        return []
    known = set(tree.stdout.split("\0"))
    return [
        path for path in sorted((ROOT / "specs").glob("*/spec.md"))
        if path.parent != PRODUCT and path.is_file() and path.parent.relative_to(ROOT).as_posix() not in known
    ]


def find_definitions(paths, ids):
    """paths の中で ids を定義している場所を、ID ごとに (パス, 行番号) のリストで返す。"""
    matches = defaultdict(list)
    for path in paths:
        for label, number in definitions_in(path):
            if label in ids:
                matches[label].append((path, number))
    return matches


def locate_definitions(ids):
    """ids の定義の場所を返す。作業中の feature で見つかった ID は、specs/product/ を探さない。"""
    ids = set(ids)
    matches = find_definitions(active_feature_specs(), ids)
    missing = ids - matches.keys()
    if missing and PRODUCT.exists():
        matches.update(find_definitions(product_markdown_paths(), missing))
    return matches
