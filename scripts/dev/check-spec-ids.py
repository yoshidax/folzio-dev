"""製品仕様の ID の重複と参照を検査し、次の ID を求める。

    scripts/dev/check-spec-ids.sh [--next]

FR・SC・EC・A・USn-ASm の定義は各 ID につき 1 か所に置く（specs/product/README.md）。
重複した ID はすべての定義位置を表示する。終了コードは、問題なしが 0、重複または未定義参照ありが 1、
入力を読み取れないかコードフェンスが閉じていない場合は 2。
"""

import argparse
import re
import subprocess
import sys
from bisect import bisect_left, bisect_right
from collections import defaultdict
from pathlib import Path

# python3 -I でも同じディレクトリの解析モジュールを読み込む。
sys.path.insert(0, str(Path(__file__).resolve().parent))
from spec_id_definitions import DEFINITION_RE, PRODUCT, ROOT, SpecInputError, product_markdown_paths, spec_lines


FAMILIES = {"FR-": 3, "SC-": 3, "EC-": 2, "A-": 2, "US": 1}
PREFIX = r"FR-|SC-|EC-|A-|US[0-9]+-AS|US"
ID = rf"(?P<prefix>{PREFIX})(?P<number>[0-9]+)"
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


def spec_id(match, inherited_prefix=None):
    prefix = match["prefix"]
    if not prefix or prefix == "AS":
        prefix = inherited_prefix
    elif prefix.endswith("-AS"):
        prefix = f"US{int(prefix[2:-3])}-AS"
    return prefix, int(match["number"])


def format_id(prefix, number):
    return f"{prefix}{number:0{FAMILIES.get(prefix, 1)}d}"


def id_sort_key(label):
    parts = re.split(r"([0-9]+)", label)
    return tuple(int(part) if part.isdigit() else part for part in parts), label


def active_feature_specs():
    # find-spec-id.py と同じ基準で、既定ブランチにない feature だけを読む。
    base = subprocess.run([ROOT / "scripts/dev/base-ref.sh"], cwd=ROOT, capture_output=True, text=True)
    if base.returncode != 0:
        return []
    merged_dirs = subprocess.check_output(
        ["git", "ls-tree", "-dz", "--name-only", base.stdout.strip(), "specs/"], cwd=ROOT, encoding="utf-8",
    ).split("\0")
    return sorted(
        path for path in PRODUCT.parent.glob("*/spec.md")
        if path.parent != PRODUCT and path.parent.relative_to(ROOT).as_posix() not in merged_dirs and path.is_file()
    )


def read_specs(paths):
    definitions = defaultdict(list)
    bodies = {}
    for path in paths:
        relative = path.relative_to(ROOT)
        lines = []
        for number, line, kind in spec_lines(path):
            if kind is not None:
                lines.append("")
                continue
            line = line.rstrip("\n")
            if definition := DEFINITION_RE.match(line):
                key = spec_id(REFERENCE.fullmatch(definition["id"]))
                definitions[key].append(f"{relative}:{number}")
                line = line[definition.end():]
            elif heading := STORY_HEADING.match(line):
                definitions["US", int(heading[1])].append(f"{relative}:{number}")
                line = line[heading.end():]
            lines.append(line)
        bodies[relative] = "\n".join(lines)
    return definitions, bodies


def check_duplicates(definitions):
    # 領域ごとに同じ US を別の題名で記述できるため、重複の判定には個々の AS を使う。
    duplicates = {
        format_id(prefix, number): locations for (prefix, number), locations in definitions.items()
        if prefix != "US" and len(locations) > 1
    }

    if not duplicates:
        return False

    print(f"Duplicated spec IDs under {PRODUCT.relative_to(ROOT)}:", file=sys.stderr)
    for label in sorted(duplicates, key=id_sort_key):
        print(label, file=sys.stderr)
        for location in duplicates[label]:
            print(f"  {location}", file=sys.stderr)
    return True


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
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0], prog="scripts/dev/check-spec-ids.sh", allow_abbrev=False)
    parser.add_argument("--next", action="store_true", help="製品仕様と作業中 feature の定義から種類ごとの最大値の次を表示する")
    args = parser.parse_args()
    try:
        paths = sorted(product_markdown_paths())
        if not paths:
            raise SpecInputError(f"{PRODUCT.relative_to(ROOT)}: Markdown ファイルがありません")
        if args.next:
            paths.extend(active_feature_specs())
        definitions, bodies = read_specs(paths)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"check-spec-ids: {error}", file=sys.stderr)
        return 2
    if args.next:
        for prefix in FAMILIES:
            next_number = max((number for kind, number in definitions if kind == prefix), default=0) + 1
            print(format_id(prefix, next_number))
        return 0
    duplicates = check_duplicates(definitions)
    unresolved = check_references(definitions, bodies)
    if not (duplicates or unresolved):
        print("No duplicated spec IDs.")
    return int(duplicates or unresolved)


if __name__ == "__main__":
    sys.exit(main())
