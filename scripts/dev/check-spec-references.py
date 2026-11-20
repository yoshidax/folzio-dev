"""製品仕様の ID の重複と参照を検査し、定義から次の ID を求める。"""

import argparse
from bisect import bisect_left, bisect_right
from collections import defaultdict
from pathlib import Path
import re
import subprocess
import sys


PRODUCT = Path("specs/product")
FAMILIES = {"FR-": 3, "SC-": 3, "EC-": 2, "A-": 2, "US": 1}
PREFIX = r"FR-|SC-|EC-|A-|US[0-9]+-AS|US"
ID = rf"(?P<prefix>{PREFIX})(?P<number>[0-9]+)"
DEFINITION = re.compile(rf"^[ \t]*(?:-|[0-9]+\.)[ \t]+\*\*{ID}\*\*")
STORY_HEADING = re.compile(r"^#{1,6}[ \t]+(?:US|User Story[ \t]+)([0-9]+)(?=[ \t:：(（]|$)")
REFERENCE = re.compile(rf"(?<![A-Za-z0-9_-]){ID}(?![A-Za-z0-9_-])")
GAP = r"[ \t]*(?:\n[ \t]*)?"
CONTINUATION = re.compile(
    rf"(?:`+|\*+)?{GAP}(?P<separator>[・〜～~]){GAP}(?:`+|\*+)?"
    rf"(?P<prefix>{PREFIX}|AS)?(?P<number>[0-9]+)(?![A-Za-z0-9_-])"
)
QUANTITY_SUFFIX = re.compile(
    r"(?:`+|\*+)?[ \t]*(?:[.,][0-9]|[%％]|[秒分時年月日件回個人枚台桁文字行列倍番つ]|"
    r"(?:ms|s|KB|MB|GB|px)(?![A-Za-z0-9_]))"
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


def active_feature_specs():
    # find-spec-id.sh と同じ基準で、既定ブランチにない feature だけを読む。
    base = subprocess.run(["scripts/dev/base-ref.sh"], capture_output=True, text=True)
    if base.returncode != 0:
        return []
    merged_dirs = subprocess.check_output(
        ["git", "ls-tree", "-dz", "--name-only", base.stdout.strip(), "specs/"], encoding="utf-8",
    ).split("\0")
    return sorted(
        path for path in PRODUCT.parent.glob("*/spec.md")
        if path.parent != PRODUCT and path.parent.as_posix() not in merged_dirs and path.is_file()
    )


def read_specs(paths):
    definitions = defaultdict(list)
    bodies = {}
    for path in paths:
        lines = []
        fence = ""
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            marker = FENCE.match(line)
            if fence:
                if marker and marker[1].startswith(fence) and not marker[2].strip():
                    fence = ""
                lines.append("")
                continue
            if marker:
                fence = marker[1]
                fence_line = line_number
                lines.append("")
                continue
            if definition := DEFINITION.match(line):
                definitions[spec_id(definition)].append((path, line_number))
                line = line[definition.end():]
            elif heading := STORY_HEADING.match(line):
                definitions["US", int(heading[1])].append((path, line_number))
                line = line[heading.end():]
            lines.append(line)
        if fence:
            raise ValueError(f"{path}:{fence_line}: コードフェンスが閉じていません")
        bodies[path] = "\n".join(lines)
    return definitions, bodies


def check_duplicates(definitions):
    found = False
    for (prefix, number), locations in sorted(definitions.items()):
        # 同じユーザーストーリーの見出しは複数の領域に置ける。
        if prefix == "US" or len(locations) < 2:
            continue
        for path, line in locations:
            print(f"{path}:{line}: 重複した仕様 ID {format_id(prefix, number)}", file=sys.stderr)
        found = True
    if not found:
        print("No duplicated spec IDs.")
    return found


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
            # 単位の付いた数値だけを除き、接頭辞が明示された参照は常に検査する。
            if not match["prefix"] and QUANTITY_SUFFIX.match(body, match.end()):
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
    by_prefix = defaultdict(list)
    for prefix, number in sorted(definitions):
        by_prefix[prefix].append(number)
    found = False
    for path, body in bodies.items():
        newlines = [match.start() for match in re.finditer("\n", body)]
        for prefix, first, last, position in reference_ranges(body):
            for start, end in missing_ranges(by_prefix.get(prefix, ()), first, last):
                label = format_id(prefix, start)
                if start != end:
                    label += f"〜{format_id(prefix, end)}"
                line = bisect_left(newlines, position) + 1
                print(f"{path}:{line}: 定義のない仕様 ID {label}", file=sys.stderr)
                found = True
    if not found:
        print("定義のない仕様 ID の参照はありません。")
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__, prog="scripts/dev/check-spec-ids.sh", allow_abbrev=False)
    parser.add_argument("--next", action="store_true", help="製品仕様と作業中 feature の定義から種類ごとの最大値の次を表示する")
    args = parser.parse_args()
    try:
        paths = sorted(PRODUCT.rglob("*.md"))
        if not paths:
            raise OSError(f"{PRODUCT} に Markdown ファイルがありません")
        if args.next:
            paths.extend(active_feature_specs())
        definitions, bodies = read_specs(paths)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(error, file=sys.stderr)
        return 2
    if args.next:
        for prefix in FAMILIES:
            next_number = max((number for kind, number in definitions if kind == prefix), default=0) + 1
            print(format_id(prefix, next_number))
        return 0
    duplicates = check_duplicates(definitions)
    unresolved = check_references(definitions, bodies)
    return int(duplicates or unresolved)


if __name__ == "__main__":
    sys.exit(main())
