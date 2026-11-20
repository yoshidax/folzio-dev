"""製品仕様の ID の重複を検査し、定義された場所を表示する。"""

import os
import re
import sys
from collections import defaultdict
from pathlib import Path

from spec_id_definitions import DEFINITION_RE


PRODUCT = Path("specs/product")
FENCE_RE = re.compile(r"^[ \t]*(`{3,}|~{3,})(.*)$")


def read_error(error):
    raise error


def spec_paths():
    # pathlib の glob が列挙時のエラーを無視する環境でも、読み取り失敗を検査結果に反映する。
    for directory, subdirs, names in os.walk(PRODUCT, onerror=read_error):
        subdirs.sort()
        for name in sorted(names):
            if name.endswith(".md"):
                yield Path(directory) / name


def content_lines(path):
    fence = ""
    with path.open(encoding="utf-8") as source:
        for number, text in enumerate(source, start=1):
            line = text.rstrip("\n")
            marker = FENCE_RE.match(line)
            if fence:
                if marker and marker[1].startswith(fence) and not marker[2].strip():
                    fence = ""
            elif marker:
                fence = marker[1]
            else:
                yield number, line


def check():
    definitions = defaultdict(list)
    for path in spec_paths():
        try:
            for number, line in content_lines(path):
                if definition := DEFINITION_RE.match(line):
                    definitions[definition["id"]].append(f"{path}:{number}")
        except UnicodeError as error:
            raise OSError(f"{path}: {error}") from error

    # 領域ごとに同じ US を別の題名で記述できるため、重複の判定には個々の AS を使う。
    duplicates = {label: locations for label, locations in definitions.items() if len(locations) > 1}

    if not duplicates:
        print("No duplicated spec IDs.")
        return 0

    print(f"Duplicated spec IDs under {PRODUCT}:", file=sys.stderr)
    for label, locations in sorted(duplicates.items()):
        print(label, file=sys.stderr)
        for location in locations:
            print(f"  {location}", file=sys.stderr)
    return 1


def main():
    try:
        return check()
    except OSError as error:
        print(f"check-spec-ids: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
