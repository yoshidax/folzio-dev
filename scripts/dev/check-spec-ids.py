"""製品仕様の ID の重複を検査する。

    scripts/dev/check-spec-ids.sh

FR・SC・EC・A・USn-ASm の定義は各 ID につき 1 か所に置く（specs/product/README.md）。
重複した ID はすべての定義位置を表示する。終了コードは、重複なしが 0、重複ありが 1、
ファイルを読み取れないかコードフェンスが閉じていない場合は 2。
"""

import re
import sys
from collections import defaultdict
from pathlib import Path

# python3 -I でも同じディレクトリの解析モジュールを読み込む。
sys.path.insert(0, str(Path(__file__).resolve().parent))
from spec_id_definitions import PRODUCT, ROOT, SpecInputError, definitions_in, product_markdown_paths


def id_sort_key(label):
    parts = re.split(r"([0-9]+)", label)
    return tuple(int(part) if part.isdigit() else part for part in parts), label


def check():
    definitions = defaultdict(list)
    for path in product_markdown_paths():
        relative = path.relative_to(ROOT)
        for label, number in definitions_in(path):
            definitions[label].append(f"{relative}:{number}")

    # 領域ごとに同じ US を別の題名で記述できるため、重複の判定には個々の AS を使う。
    duplicates = {label: locations for label, locations in definitions.items() if len(locations) > 1}

    if not duplicates:
        print("No duplicated spec IDs.")
        return 0

    print(f"Duplicated spec IDs under {PRODUCT.relative_to(ROOT)}:", file=sys.stderr)
    for label in sorted(duplicates, key=id_sort_key):
        print(label, file=sys.stderr)
        for location in duplicates[label]:
            print(f"  {location}", file=sys.stderr)
    return 1


def main():
    try:
        return check()
    except (OSError, SpecInputError) as error:
        print(f"check-spec-ids: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
