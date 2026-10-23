#!/usr/bin/env python3
"""001 の spec.md をドメイン別の specs/product/*.md へ機械的に移し、移動以外の変更がないことを確かめる。

一回限りの移行用。対応表は docs/spec-restructure/domain-map.md。
移行は 2026-10-24 に完了し、以後 specs/product/ は手で更新する。generate は既存のファイルを上書きするため --force を要する。
verify は、移行直後の状態（specs/product/ が 001 の spec.md と一致すること）を確かめるためのもの。

  python3 scripts/spec-restructure/split_spec.py generate --force [--only search]
  python3 scripts/spec-restructure/split_spec.py verify
"""

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "specs/001-three-pane-media-viewer/spec.md"
OUT = ROOT / "specs/product"
SOURCE_REL = "specs/001-three-pane-media-viewer/spec.md"


def r(a, b):
    return list(range(a, b + 1))


# docs/spec-restructure/domain-map.md の §1〜§6 をそのまま写したもの
DOMAINS = {
    "overview": {
        "title": "概要と横断要件",
        "fr": [("保存と復元", [3]), ("対応形式", [9, 39]), ("横断要件", r(40, 42)), ("アプリアイコン", r(43, 45))],
        "sc": [2, 9, 11],
        "as": {},
        "ec": [13, 19, 31],
        "ke": ["表示設定", "動作オプション", "アプリアイコン"],
        "a": [1, 2, 9, 14, 16, 17, 18],
    },
    "window-layout": {
        "title": "ウィンドウの構成",
        "fr": [("画面構成", [1, 2]), ("ツールバー", r(49, 52)), ("ペインの表示切り替え", r(88, 94))],
        "sc": [],
        "as": {3: r(7, 10), 6: r(1, 10)},
        "ec": [37, 38, 39],
        "ke": ["ペインの表示状態"],
        "a": [],
    },
    "directory-tree": {
        "title": "ディレクトリツリー",
        "fr": [("ディレクトリツリー", [4, 5, 6, 7, 47, 53, 54, 55]), ("お気に入り", r(61, 67))],
        "sc": [13],
        "as": {1: [1, 7, 8, 9] + r(10, 14)},
        "ec": [5, 6, 7, 18, 20],
        "ke": ["フォルダ（ディレクトリ）", "ボリューム", "お気に入り"],
        "a": [4, 19, 20, 21, 27, 28],
    },
    "file-list": {
        "title": "ファイルリスト",
        "fr": [("ファイルリスト", [8] + r(10, 17) + [48]), ("種類フィルタ", r(56, 60)), ("ファイルリストのフォルダ", r(76, 78))],
        "sc": [3, 4, 5, 12],
        "as": {1: [2, 4, 21, 22], 3: r(1, 6) + r(11, 18)},
        "ec": [1, 2, 4, 9, 21],
        "ke": ["上の階層へ戻る行（`..`）", "メディアファイル", "種類フィルタ"],
        "a": [3, 8, 15, 25],
    },
    "zip": {
        "title": "zip ファイル",
        "fr": [("zip ファイル", r(68, 75)), ("zip ファイルの表示制御", r(95, 98))],
        "sc": [14, 15, 17],
        "as": {1: r(15, 20) + [29], 3: r(19, 22)},
        "ec": [10] + r(22, 30),
        "ke": ["zip ファイル", "zip の中の項目", "zip の中の現在位置"],
        "a": [22, 23, 24, 26],
    },
    "file-operations": {
        "title": "ファイル操作",
        "fr": [("ファイル操作", r(18, 27) + [79])],
        "sc": [6, 8],
        "as": {1: [23, 24], 4: r(1, 8)},
        "ec": [8, 14, 15, 16, 17],
        "ke": ["ファイル操作"],
        "a": [5, 7],
    },
    "search": {
        "title": "検索",
        "fr": [("検索", r(80, 87))],
        "sc": [16],
        "as": {1: r(25, 28)},
        "ec": r(32, 36),
        "ke": ["検索条件", "検索結果"],
        "a": [6],
    },
    "preview": {
        "title": "プレビュー",
        "fr": [("プレビュー", r(28, 34) + [38]), ("フルスクリーン", [35, 36, 37, 46])],
        "sc": [1, 7, 10],
        "as": {1: [3, 5, 6], 2: r(1, 5), 5: r(1, 6)},
        "ec": [3, 11, 12],
        "ke": [],
        "a": [10, 11, 12, 13],
    },
}

ITEM_START = re.compile(r"^(- |\d+\. )")
LABELED = re.compile(r"^- \*\*(.+?)\*\*: ?(.*)$")
ID_REF = re.compile(r"\b(FR|SC)-(\d{3})\b")

KE_HEADING = "## 主なエンティティ"


class Item:
    def __init__(self, label, first, rest):
        self.label = label
        self.first = first  # 先頭行のうちラベルより後ろ
        self.rest = rest  # 続きの行（インデントを外したもの）

    def body(self):
        return "".join([self.first.strip()] + [line.strip() for line in self.rest])

    def render(self):
        # 主なエンティティは元の spec.md と同じく名前をラベルにする
        label = self.label.removeprefix("KE:")
        return "\n".join([f"- **{label}**: {self.first}"] + [f"  {line}" for line in self.rest])


def split_items(lines):
    """`- ` または `N. ` で始まる項目を、続くインデント行とまとめて返す"""
    items, current = [], None
    for line in lines:
        if ITEM_START.match(line):
            current = [line]
            items.append(current)
        elif current is not None and line.startswith(" ") and line.strip():
            current.append(line)
        else:
            current = None
    return items


def between(lines, start, end_prefixes):
    i = lines.index(start)
    for j in range(i + 1, len(lines)):
        if any(lines[j].startswith(p) for p in end_prefixes):
            return lines[i + 1 : j]
    return lines[i + 1 :]


def rest_of(raw):
    return [line.strip() for line in raw[1:]]


def parse_source():
    lines = SOURCE.read_text(encoding="utf-8").splitlines()
    found = {}  # label -> Item
    stories = {}  # 番号 -> (タイトル, 優先度)

    def add(item):
        if item.label in found:
            sys.exit(f"spec.md でラベルが重複しています: {item.label}")
        found[item.label] = item

    for raw in split_items(between(lines, "### Functional Requirements", ["### Key Entities"])):
        m = LABELED.match(raw[0])
        add(Item(m.group(1), m.group(2), rest_of(raw)))
    for raw in split_items(between(lines, "### Measurable Outcomes", ["## Assumptions"])):
        m = LABELED.match(raw[0])
        add(Item(m.group(1), m.group(2), rest_of(raw)))
    for raw in split_items(between(lines, "### Key Entities", ["## Success Criteria"])):
        m = LABELED.match(raw[0])
        add(Item("KE:" + m.group(1), m.group(2), rest_of(raw)))
    for n, raw in enumerate(split_items(between(lines, "### Edge Cases", ["## Requirements"])), 1):
        add(Item(f"EC-{n:02d}", raw[0][2:], rest_of(raw)))
    for n, raw in enumerate(split_items(between(lines, "## Assumptions", [])), 1):
        add(Item(f"A-{n:02d}", raw[0][2:], rest_of(raw)))

    chunks = {}  # User Story の番号 -> その節の行
    story = None
    for line in between(lines, "## User Scenarios & Testing *(mandatory)*", ["### Edge Cases"]):
        m = re.match(r"^### User Story (\d+) - (.+) \(Priority: (P\d)\)$", line)
        if m:
            story = int(m.group(1))
            stories[story] = (m.group(2), m.group(3))
            chunks[story] = []
        elif story is not None:
            chunks[story].append(line)
    for story, chunk in chunks.items():
        for raw in split_items(chunk):
            m = re.match(r"^(\d+)\. (.*)$", raw[0])
            if m:
                add(Item(f"US{story}-AS{int(m.group(1))}", m.group(2), rest_of(raw)))

    # 箇条書きでない段落: 元の要望（Input）と、各 User Story の説明（Acceptance Scenarios より前）
    blocks = {}
    i = next(n for n, line in enumerate(lines) if line.startswith("**Input**:"))
    j = next(n for n in range(i, len(lines)) if not lines[n].strip())
    blocks["INPUT"] = lines[i:j]
    for story, chunk in chunks.items():
        end = chunk.index("**Acceptance Scenarios**:")
        blocks[f"US{story}"] = trim_blank(chunk[:end])

    return found, stories, blocks


def trim_blank(lines):
    while lines and not lines[0].strip():
        lines = lines[1:]
    while lines and not lines[-1].strip():
        lines = lines[:-1]
    return lines


def block_body(lines):
    return "".join(line.strip() for line in lines if line.strip())


def compact(numbers):
    """[1, 7, 8, 9, 10] -> "1・7〜10" """
    parts, start, prev = [], None, None
    for n in sorted(numbers) + [None]:
        if start is not None and n == prev + 1:
            prev = n
            continue
        if start is not None:
            if prev - start >= 2:
                parts.append(f"{start}〜{prev}")
            else:
                parts.extend(str(k) for k in range(start, prev + 1))
        start = prev = n
    return "・".join(parts)


def expected_labels(domain):
    cfg = DOMAINS[domain]
    labels = [f"FR-{n:03d}" for _, ids in cfg["fr"] for n in ids]
    labels += [f"SC-{n:03d}" for n in cfg["sc"]]
    labels += [f"US{s}-AS{n}" for s, ns in cfg["as"].items() for n in ns]
    labels += [f"EC-{n:02d}" for n in cfg["ec"]]
    labels += ["KE:" + name for name in cfg["ke"]]
    labels += [f"A-{n:02d}" for n in cfg["a"]]
    return labels


def owner_of():
    owners = {}
    for domain in DOMAINS:
        for label in expected_labels(domain):
            owners.setdefault(label, []).append(domain)
    return owners


INPUT_HEADING = "## 出発点となった要望"
STORIES_HEADING = "## ユーザーストーリー"
SCENARIO_PLACES = "受け入れシナリオ:"


def render_stories(stories, blocks):
    """overview.md に置く User Story の索引。シナリオ本体は各領域のファイルにある"""
    out = ["", STORIES_HEADING, "", "各ストーリーの受け入れシナリオは、関係する領域のファイルに振り分けている。"]
    for s, (title, priority) in stories.items():
        out.extend(["", f"### US{s} {title}（{priority}）", ""])
        out.extend(blocks[f"US{s}"])
        places = [
            f"[{d}.md]({d}.md)（AS{compact(cfg['as'][s])}）" for d, cfg in DOMAINS.items() if s in cfg["as"]
        ]
        out.extend(["", f"{SCENARIO_PLACES} " + "、".join(places)])
    return out


def render_domain(domain, found, stories, blocks):
    cfg = DOMAINS[domain]
    owners = owner_of()
    out = [
        f"# {cfg['title']}",
        "",
        "この領域の現在の仕様（Living spec）。ID は "
        f"`{SOURCE_REL}` から引き継いだもの。ほかの領域は [README.md](README.md) を参照。",
    ]
    if domain == "overview":
        out.extend(["", INPUT_HEADING, ""] + blocks["INPUT"])
        out.extend(render_stories(stories, blocks))
    used = []

    def emit(heading, labels):
        if not labels:
            return
        out.extend(["", heading, ""])
        for label in labels:
            item = found[label]
            used.append(item)
            out.append(item.render())

    out.extend(["", "## 機能要件"])
    for heading, ids in cfg["fr"]:
        if len(cfg["fr"]) > 1:
            out.extend(["", f"### {heading}"])
        out.append("")
        for n in ids:
            item = found[f"FR-{n:03d}"]
            used.append(item)
            out.append(item.render())

    emit(KE_HEADING, ["KE:" + name for name in cfg["ke"]])

    if cfg["as"]:
        out.extend(["", "## 受け入れシナリオ"])
        for s, ns in cfg["as"].items():
            title, priority = stories[s]
            out.extend(["", f"### US{s} {title}（{priority}）", ""])
            for n in sorted(ns):
                item = found[f"US{s}-AS{n}"]
                used.append(item)
                out.append(item.render())

    emit("## エッジケース", [f"EC-{n:02d}" for n in cfg["ec"]])
    emit("## 成功基準", [f"SC-{n:03d}" for n in cfg["sc"]])
    emit("## 前提", [f"A-{n:02d}" for n in cfg["a"]])

    refs = {}
    for item in used:
        for kind, num in ID_REF.findall(item.body()):
            label = f"{kind}-{num}"
            owner = owners.get(label, ["?"])[0]
            if owner != domain:
                refs.setdefault(owner, set()).add(label)
    if refs:
        out.extend(["", "## 参照しているほかの領域", ""])
        for owner in DOMAINS:
            if owner in refs:
                ids = "・".join(sorted(refs[owner]))
                out.append(f"- [{owner}.md]({owner}.md): {ids}")

    return "\n".join(out) + "\n"


def render_readme(present):
    out = [
        "# プロダクト仕様",
        "",
        "MediaViewer の現在の仕様（Living spec）を領域ごとに分けたもの。",
        f"`{SOURCE_REL}` から移行した。FR・SC の ID は元のまま引き継いでいる。",
        "",
        "| ファイル | 領域 | 機能要件 |",
        "|---|---|---|",
    ]
    for domain, cfg in DOMAINS.items():
        if domain not in present:
            continue
        frs = "、".join(f"{h}（{len(ids)}）" for h, ids in cfg["fr"])
        out.append(f"| [{domain}.md]({domain}.md) | {cfg['title']} | {frs} |")
    return "\n".join(out) + "\n"


def generate(only, force):
    if not force:
        sys.exit("specs/product/ は移行後に手で更新している。上書きしてよい場合だけ --force を付ける")
    found, stories, blocks = parse_source()
    OUT.mkdir(parents=True, exist_ok=True)
    targets = only or list(DOMAINS)
    for domain in targets:
        (OUT / f"{domain}.md").write_text(render_domain(domain, found, stories, blocks), encoding="utf-8")
        print(f"wrote specs/product/{domain}.md")
    present = [d for d in DOMAINS if (OUT / f"{d}.md").exists()]
    (OUT / "README.md").write_text(render_readme(present), encoding="utf-8")
    print("wrote specs/product/README.md")


def parse_product(path):
    """ラベル付きの項目を (ラベル, 本文) で返す。主なエンティティの節だけは名前をラベルとして扱う"""
    by_section = {}
    section = None
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            section = line
        by_section.setdefault(section, []).append(line)
    result = []
    for sec, sec_lines in by_section.items():
        for raw in split_items(sec_lines):
            m = LABELED.match(raw[0])
            if not m:
                continue
            label = ("KE:" if sec == KE_HEADING else "") + m.group(1)
            result.append(Item(label, m.group(2), rest_of(raw)))
    return result


def parse_overview_blocks(path):
    """overview.md の元の要望と User Story の説明を、ラベルごとの行で返す（シナリオの置き場所の行は除く）"""
    blocks, label = {}, None
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            label = "INPUT" if line == INPUT_HEADING else None
            continue
        m = re.match(r"^### US(\d+) ", line)
        if m:
            label = f"US{m.group(1)}"
            continue
        if line.startswith("### "):
            label = None
        if label and not line.startswith(SCENARIO_PLACES):
            blocks.setdefault(label, []).append(line)
    return blocks


def verify():
    found, _, source_blocks = parse_source()
    errors = []

    overview = OUT / "overview.md"
    if overview.exists():
        product_blocks = parse_overview_blocks(overview)
        for label, lines in source_blocks.items():
            if label not in product_blocks:
                errors.append(f"overview.md に {label} の段落がありません")
            elif block_body(product_blocks[label]) != block_body(lines):
                errors.append(f"overview.md の {label} の段落が spec.md と一致しません")

    owners = owner_of()
    for label, domains in owners.items():
        if len(domains) > 1:
            errors.append(f"対応表で {label} が複数の領域にあります: {domains}")
        if label not in found:
            errors.append(f"対応表の {label} が spec.md にありません")
    for label in found:
        if label not in owners:
            errors.append(f"spec.md の {label} が対応表のどの領域にもありません")

    seen = {}
    present = []
    for domain in DOMAINS:
        path = OUT / f"{domain}.md"
        if not path.exists():
            continue
        present.append(domain)
        expected = set(expected_labels(domain))
        labels = []
        for item in parse_product(path):
            if not re.match(r"^(FR-\d{3}|SC-\d{3}|US\d+-AS\d+|EC-\d{2}|A-\d{2}|KE:.+)$", item.label):
                continue
            labels.append(item.label)
            if item.label in seen:
                errors.append(f"{item.label} が {seen[item.label]}.md と {domain}.md の両方にあります")
            seen[item.label] = domain
            if item.label not in expected:
                errors.append(f"{domain}.md に対応表にない {item.label} があります")
            elif item.body() != found[item.label].body():
                errors.append(f"{domain}.md の {item.label} の本文が spec.md と一致しません")
        for label in expected - set(labels):
            errors.append(f"{domain}.md に {label} がありません")

    total = {k: 0 for k in ("FR", "SC", "AS", "EC", "A", "KE")}
    for label in seen:
        key = "AS" if "-AS" in label else label.split(":")[0].split("-")[0]
        total[key] += 1
    print("移行済みの領域: " + (", ".join(present) or "なし"))
    print("未移行の領域: " + (", ".join(d for d in DOMAINS if d not in present) or "なし"))
    print("移行済みの項目: " + "、".join(f"{k} {v}" for k, v in total.items()) + f"（spec.md 全体 {len(found)} 件中 {len(seen)} 件）")
    if overview.exists():
        print(f"overview.md の段落: 元の要望と User Story {len(source_blocks) - 1} 件")
    if errors:
        print(f"\nNG: {len(errors)} 件")
        for e in errors:
            print("  - " + e)
        sys.exit(1)
    print("OK: 対応表は spec.md の全項目をちょうど1回ずつ割り当てており、移行済みのファイルの本文は spec.md と一致する")


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    gen = sub.add_parser("generate")
    gen.add_argument("--only", nargs="*", choices=list(DOMAINS))
    gen.add_argument("--force", action="store_true")
    sub.add_parser("verify")
    args = parser.parse_args()
    if args.command == "generate":
        generate(args.only, args.force)
    else:
        verify()


if __name__ == "__main__":
    main()
