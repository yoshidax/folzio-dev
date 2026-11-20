"""作業中の feature と製品仕様から ID の定義へのリンクを出力する。"""

import argparse
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

# python3 -I でも同じディレクトリの解析モジュールを読み込む。
sys.path.insert(0, str(Path(__file__).resolve().parent))
from spec_id_definitions import ID_RE, PRODUCT, ROOT, SpecInputError, definitions_in, product_markdown_paths


def spec_id(value):
    if not ID_RE.fullmatch(value):
        raise argparse.ArgumentTypeError(f"仕様 ID の形ではありません: {value}")
    return value


def active_feature_specs():
    result = subprocess.run([ROOT / "scripts/dev/base-ref.sh"], cwd=ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        return

    base = result.stdout.strip()
    for path in sorted((ROOT / "specs").glob("*/spec.md")):
        if path.parent == PRODUCT or not path.is_file():
            continue
        directory = path.parent.relative_to(ROOT)
        result = subprocess.run(
            ["git", "cat-file", "-e", f"{base}:{directory}"], cwd=ROOT, stderr=subprocess.DEVNULL,
        )
        if result.returncode != 0:
            yield path


def find_definitions(paths, ids):
    matches = defaultdict(list)
    for path in paths:
        for label, number in definitions_in(path):
            if label in ids:
                matches[label].append((path, number))
    return matches


def print_links(ids, absolute):
    matches = find_definitions(active_feature_specs(), set(ids))
    missing = set(ids) - matches.keys()
    if missing and PRODUCT.exists():
        matches.update(find_definitions(product_markdown_paths(), missing))

    status = 0
    for label in ids:
        locations = matches.get(label)
        if not locations:
            print(f"見つかりません: {label}", file=sys.stderr)
            status = 1
            continue
        for path, number in sorted(locations, key=lambda location: (location[0].as_posix(), location[1])):
            target = f"{path if absolute else path.relative_to(ROOT)}#L{number}"
            # 空白を含むリンク先は <> で囲む。
            if " " in target:
                target = f"<{target}>"
            print(f"[{label}]({target})")
    return status


def main():
    parser = argparse.ArgumentParser(prog="scripts/dev/find-spec-id.sh", allow_abbrev=False)
    parser.add_argument("--absolute", action="store_true")
    parser.add_argument("ids", metavar="ID", nargs="+", type=spec_id)
    args = parser.parse_intermixed_args()
    try:
        return print_links(args.ids, args.absolute)
    except (OSError, SpecInputError) as error:
        print(f"find-spec-id: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
