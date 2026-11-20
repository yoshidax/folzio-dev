"""製品仕様の ID の参照を検査し、定義から次の ID を求める。"""

import argparse
from bisect import bisect_left, bisect_right
from collections import defaultdict
from pathlib import Path
import re
import sys


PRODUCT = Path("specs/product")
FAMILIES = {"FR-": 3, "SC-": 3, "EC-": 2, "A-": 2, "US": 1}
PREFIX = r"FR-|SC-|EC-|A-|US[0-9]+-AS|US"
ID = rf"(?P<prefix>{PREFIX})(?P<number>[0-9]+)"
DEFINITION = re.compile(rf"^[ \t]*(?:-|[0-9]+\.)[ \t]+\*\*{ID}\*\*")
STORY_HEADING = re.compile(r"^#{1,6}[ \t]+(?:US|User Story[ \t]+)([0-9]+)(?=[ \t]|$)")
REFERENCE = re.compile(rf"(?<![A-Za-z0-9_-]){ID}(?![A-Za-z0-9_-])")
GAP = r"[ \t]*(?:\n[ \t]*)?"
CONTINUATION = re.compile(
    rf"(?:`+|\*+)?{GAP}(?P<separator>[・〜～]){GAP}(?:`+|\*+)?"
    rf"(?P<prefix>{PREFIX}|AS)?(?P<number>[0-9]+)(?![A-Za-z0-9_-])"
)
FENCE = re.compile(r"^[ \t]*(`{3,}|~{3,})(.*)$")


def spec_id(match, inherited_prefix=None):
    prefix = match["prefix"]
    if not prefix or prefix == "AS":
        prefix = inherited_prefix
    elif prefix.endswith("-AS"):
        prefix = f"US{int(prefix[2:-3])}-AS"
    return prefix, int(match["number"])


def format_id(prefix, number):
    return f"{prefix}{number:0{FAMILIES.get(prefix, 1)}d}"


def read_specs():
    definitions = defaultdict(set)
    bodies = {}
    paths = sorted(PRODUCT.rglob("*.md"))
    if not paths:
        raise OSError(f"{PRODUCT} に Markdown ファイルがありません")
    for path in paths:
        lines = []
        fence = ""
        for line in path.read_text(encoding="utf-8").splitlines():
            marker = FENCE.match(line)
            if fence:
                if marker and marker[1].startswith(fence) and not marker[2].strip():
                    fence = ""
                lines.append("")
                continue
            if marker:
                fence = marker[1]
                lines.append("")
                continue
            if definition := DEFINITION.match(line):
                prefix, number = spec_id(definition)
                definitions[prefix].add(number)
                line = line[definition.end():]
            elif heading := STORY_HEADING.match(line):
                definitions["US"].add(int(heading[1]))
                line = line[heading.end():]
            lines.append(line)
        bodies[path] = "\n".join(lines)
    return {prefix: sorted(numbers) for prefix, numbers in definitions.items()}, bodies


def reference_ranges(body):
    """参照の種類・範囲・位置を順に返す。単独の参照は長さ 1 の範囲として扱う。"""
    position = 0
    while match := REFERENCE.search(body, position):
        prefix, number = spec_id(match)
        yield prefix, number, number, match.start("number")
        position = match.end()
        while match := CONTINUATION.match(body, position):
            if match["prefix"] == "AS" and not prefix.endswith("-AS"):
                break
            next_prefix, next_number = spec_id(match, prefix)
            start = next_number
            if match["separator"] != "・" and prefix == next_prefix and number != next_number:
                # 始点は検査済み。範囲の中の番号と終点を調べる。
                start = number + (1 if number < next_number else -1)
            yield next_prefix, min(start, next_number), max(start, next_number), match.start("number")
            prefix, number = next_prefix, next_number
            position = match.end()


def missing_ranges(numbers, start, end):
    """欠番の連続区間を返す。大きな番号があっても全番号を列挙しない。"""
    for number in numbers[bisect_left(numbers, start):bisect_right(numbers, end)]:
        if start < number:
            yield start, number - 1
        start = number + 1
    if start <= end:
        yield start, end


def check_references(definitions, bodies):
    found = False
    for path, body in bodies.items():
        newlines = [match.start() for match in re.finditer("\n", body)]
        for prefix, first, last, position in reference_ranges(body):
            for start, end in missing_ranges(definitions.get(prefix, ()), first, last):
                label = format_id(prefix, start)
                if start != end:
                    label += f"〜{format_id(prefix, end)}"
                line = bisect_left(newlines, position) + 1
                print(f"{path}:{line}: 定義のない仕様 ID {label}", file=sys.stderr)
                found = True
    if found:
        return 1
    print("定義のない仕様 ID の参照はありません。")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, prog="scripts/dev/check-spec-ids.sh", allow_abbrev=False)
    parser.add_argument("--next", action="store_true", help="製品仕様の定義から種類ごとの最大値の次を表示する")
    args = parser.parse_args()
    try:
        definitions, bodies = read_specs()
    except (OSError, UnicodeError) as error:
        print(error, file=sys.stderr)
        return 2
    if args.next:
        for prefix in FAMILIES:
            print(format_id(prefix, max(definitions.get(prefix, ()), default=0) + 1))
        return 0
    return check_references(definitions, bodies)


if __name__ == "__main__":
    sys.exit(main())
