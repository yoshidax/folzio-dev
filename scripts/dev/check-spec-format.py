#!/usr/bin/env python3
"""Check the Markdown format of the product specs under specs/product.

    python3 scripts/dev/check-spec-format.py [--update-baseline] [--config PATH] [--baseline PATH] [PATH ...]

Reports errors and warnings with the file, line, and rule.
Fails when any error exists, or when the warning count of a file and rule exceeds the baseline.
The rules, thresholds, and exclusions are described in specs/product/README.md.
Uses only the Python standard library and runs on Python 3.9 or later.
"""

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC_DIR = "specs/product"
DEFAULT_CONFIG = "scripts/dev/spec-format-config.json"
DEFAULT_BASELINE = "scripts/dev/spec-format-baseline.json"

RULES = (
    "line-width",
    "table-row-split",
    "table-columns",
    "table-separator",
    "table-empty",
    "code-split",
    "quote-split",
    "english-split",
    "see-below-detail",
    "cell-width",
    "multi-sentence",
)

SEE_BELOW = "下記"
DETAILS_MARKER = "**表の詳細**"
QUOTE_PAIRS = (("「", "」"), ("“", "”"))

HEADING_RE = re.compile(r"^(#{1,6})\s")
ITEM_RE = re.compile(r"^(\s*)([-*]|\d+\.)\s")
SEPARATOR_RE = re.compile(r"^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?$")
DEFINITION_RE = re.compile(r"^\s*- \*\*((FR|SC|EC|A)-\d+|US\d+-AS\d+)\*\*")
DETAIL_LABEL_RE = re.compile(r"^- \*\*(.+?)\*\*")
BACKTICK_RUN_RE = re.compile(r"`+")


class ConfigError(Exception):
    """An error in the arguments, the configuration, or the baseline."""


class Finding:
    def __init__(self, key, line, rule, severity, message):
        self.key = key
        self.line = line
        self.rule = rule
        self.severity = severity
        self.message = message


def display_width(text):
    """Returns the display width, counting East Asian Wide and Fullwidth characters as two columns."""
    return sum(2 if unicodedata.east_asian_width(c) in ("W", "F") else 1 for c in text)


def indent_of(line):
    return len(line) - len(line.lstrip(" "))


def classify(lines):
    """Returns the kind of each line: fence, code, table, heading, item, text, or blank."""
    kinds = []
    in_code = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("```"):
            kinds.append("fence")
            in_code = not in_code
        elif in_code:
            kinds.append("code")
        elif not stripped:
            kinds.append("blank")
        elif stripped.startswith("|"):
            kinds.append("table")
        elif HEADING_RE.match(stripped) and indent_of(line) == 0:
            kinds.append("heading")
        elif ITEM_RE.match(line):
            kinds.append("item")
        else:
            kinds.append("text")
    return kinds


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


def unclosed_code(line):
    """Whether an inline code span opened on this line is not closed on the same line."""
    opened = None
    for run in BACKTICK_RUN_RE.finditer(line):
        length = len(run.group(0))
        if opened is None:
            opened = length
        elif length == opened:
            opened = None
    return opened is not None


def remove_code_spans(line):
    result = []
    position = 0
    opened = None
    for run in BACKTICK_RUN_RE.finditer(line):
        length = len(run.group(0))
        if opened is None:
            result.append(line[position:run.start()])
            opened = (length, run.start())
        elif length == opened[0]:
            position = run.end()
            opened = None
    if opened is None:
        result.append(line[position:])
    else:
        result.append(line[opened[1]:])
    return "".join(result)


def table_blocks(kinds):
    """Returns (start, end) index ranges of consecutive table lines."""
    blocks = []
    index = 0
    while index < len(kinds):
        if kinds[index] == "table":
            start = index
            while index < len(kinds) and kinds[index] == "table":
                index += 1
            blocks.append((start, index))
        else:
            index += 1
    return blocks


def detail_labels(lines, kinds, table_end):
    """Returns the labels of the items under the "表の詳細" marker right after a table."""
    index = table_end
    while index < len(lines) and kinds[index] == "blank":
        index += 1
    if index >= len(lines) or lines[index].strip() != DETAILS_MARKER:
        return []
    marker_indent = indent_of(lines[index])
    labels = []
    index += 1
    while index < len(lines):
        kind = kinds[index]
        line = lines[index]
        if kind in ("heading", "table", "fence") or line.strip() == DETAILS_MARKER:
            break
        if kind == "text" and indent_of(line) <= marker_indent:
            break
        if kind == "item" and indent_of(line) == marker_indent:
            match = DETAIL_LABEL_RE.match(line[marker_indent:])
            if match:
                labels.append(match.group(1).strip())
        index += 1
    return labels


def section_ranges(lines, kinds, heading):
    """Returns the line index ranges of sections that start with the given heading."""
    ranges = []
    for index, line in enumerate(lines):
        if kinds[index] == "heading" and line.rstrip() == heading:
            level = len(HEADING_RE.match(line).group(1))
            end = index + 1
            while end < len(lines):
                if kinds[end] == "heading" and len(HEADING_RE.match(lines[end]).group(1)) <= level:
                    break
                end += 1
            ranges.append((index, end))
    return ranges


def check_file(key, text, config):
    """Returns the findings for one file as a list of Finding objects."""
    lines = text.split("\n")
    kinds = classify(lines)
    findings = []

    def add(index, rule, severity, message):
        findings.append(Finding(key, index + 1, rule, severity, message))

    warn_width = config["line_width_warning"]
    error_width = config["line_width_error"]
    cell_limit = config["cell_width_warning"]

    for index, line in enumerate(lines):
        kind = kinds[index]
        if kind not in ("heading", "item", "text"):
            continue
        width = display_width(line.rstrip())
        if width > error_width:
            add(index, "line-width", "error", "display width {} > {}".format(width, error_width))
        elif width > warn_width:
            add(index, "line-width", "warning", "display width {} > {}".format(width, warn_width))
        if unclosed_code(line):
            add(index, "code-split", "error", "an inline code span is not closed on this line")
        plain = remove_code_spans(line)
        for opening, closing in QUOTE_PAIRS:
            if plain.count(opening) != plain.count(closing):
                add(index, "quote-split", "error",
                    "{}{} is not balanced on this line".format(opening, closing))
        if kind == "text" and index > 0 and kinds[index - 1] in ("item", "text"):
            previous = lines[index - 1].rstrip()
            if re.search(r"[A-Za-z]$", previous) and re.match(r"[a-z]", line.strip()):
                add(index, "english-split", "error", "an English phrase continues from the previous line")
        if kind == "item" and DEFINITION_RE.match(line):
            body = line.strip()
            following = index + 1
            while following < len(lines) and kinds[following] == "text":
                body += lines[following].strip()
                following += 1
            sentences = [part for part in body.split("。") if part.strip()]
            if len(sentences) >= 2:
                add(index, "multi-sentence", "warning",
                    "the definition has {} sentences".format(len(sentences)))

    for start, end in table_blocks(kinds):
        rows = lines[start:end]
        for offset, row in enumerate(rows):
            body = row.strip()
            if not body.endswith("|") or body.endswith("\\|"):
                add(start + offset, "table-row-split", "error", "the table row does not end with |")
        if end < len(lines) and kinds[end] in ("text", "item"):
            tail = lines[end].strip()
            if tail.endswith("|") and not tail.endswith("\\|"):
                add(end, "table-row-split", "error", "the line continues the table row above")
        if len(rows) < 2 or not SEPARATOR_RE.match(rows[1].strip()):
            add(start + 1 if len(rows) >= 2 else start, "table-separator", "error",
                "the second row of the table is not a separator row")
            continue
        header = split_cells(rows[0])
        if len(rows) == 2:
            add(start, "table-empty", "error", "the table has no body rows")
        for offset, row in enumerate(rows):
            if offset == 1:
                continue
            cells = split_cells(row)
            if len(cells) != len(header):
                add(start + offset, "table-columns", "error",
                    "{} cells, but the header has {}".format(len(cells), len(header)))
        labels = None
        for offset in range(2, len(rows)):
            cells = split_cells(rows[offset])
            for cell in cells:
                width = display_width(cell)
                if width > cell_limit:
                    add(start + offset, "cell-width", "warning",
                        "cell display width {} > {}".format(width, cell_limit))
            if any(cell == SEE_BELOW for cell in cells):
                if labels is None:
                    labels = detail_labels(lines, kinds, end)
                row_key = strip_emphasis(cells[0])
                if not any(label.startswith(row_key) for label in labels):
                    add(start + offset, "see-below-detail", "error",
                        "no item under {} starts with \"{}\"".format(DETAILS_MARKER, row_key))
    return findings, lines, kinds


def excluded_ranges(exclusion, lines, kinds):
    """Returns the line index ranges an exclusion covers, or raises ConfigError if it matches nothing."""
    if "section" in exclusion:
        ranges = section_ranges(lines, kinds, exclusion["section"])
        if not ranges:
            raise ConfigError("exclusion section not found in {}: {}".format(
                exclusion["file"], exclusion["section"]))
        return ranges
    if "table_columns" in exclusion:
        wanted = exclusion["table_columns"]
        ranges = []
        for start, end in table_blocks(kinds):
            header = split_cells(lines[start])
            if all(name in header for name in wanted):
                ranges.append((start, end))
        if not ranges:
            raise ConfigError("no table with columns {} in {}".format(wanted, exclusion["file"]))
        return ranges
    return [(0, len(lines))]


def load_json(path, default=None):
    if not path.exists():
        if default is not None:
            return default
        raise ConfigError("file not found: {}".format(path))
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (ValueError, OSError) as error:
        raise ConfigError("cannot read {}: {}".format(path, error))


def load_config(path):
    config = load_json(path)
    for name in ("line_width_warning", "line_width_error", "cell_width_warning"):
        if not isinstance(config.get(name), int):
            raise ConfigError("{} must be an integer in {}".format(name, path))
    for exclusion in config.get("exclusions", []):
        if "file" not in exclusion or not exclusion.get("rules"):
            raise ConfigError("each exclusion needs file and rules in {}".format(path))
        unknown = [rule for rule in exclusion["rules"] if rule not in RULES]
        if unknown:
            raise ConfigError("unknown rules in exclusion for {}: {}".format(exclusion["file"], unknown))
    return config


def collect_files(arguments):
    files = []
    for argument in arguments:
        path = (ROOT / argument).resolve()
        if path.is_dir():
            files.extend(sorted(path.rglob("*.md")))
        elif path.is_file():
            files.append(path)
        else:
            raise ConfigError("path not found: {}".format(argument))
    unique = []
    for path in files:
        if path not in unique:
            unique.append(path)
    return unique


def key_of(path):
    """Returns the path relative to specs/product, or to the repository root outside it."""
    spec_root = (ROOT / SPEC_DIR).resolve()
    try:
        return path.relative_to(spec_root).as_posix()
    except ValueError:
        return path.relative_to(ROOT).as_posix()


def run(args):
    config_path = ROOT / args.config
    baseline_path = ROOT / args.baseline
    config = load_config(config_path)
    baseline = load_json(baseline_path, default={"warnings": {}}).get("warnings", {})
    files = collect_files(args.paths or [SPEC_DIR])
    checked = {key_of(path): path for path in files}

    for exclusion in config.get("exclusions", []):
        if not (ROOT / SPEC_DIR / exclusion["file"]).is_file():
            raise ConfigError("exclusion file not found: {}/{}".format(SPEC_DIR, exclusion["file"]))

    findings = []
    for key, path in checked.items():
        file_findings, lines, kinds = check_file(key, path.read_text(encoding="utf-8"), config)
        ignored = []
        for exclusion in config.get("exclusions", []):
            if exclusion["file"] == key:
                for start, end in excluded_ranges(exclusion, lines, kinds):
                    ignored.append((start, end, set(exclusion["rules"])))
        for finding in file_findings:
            index = finding.line - 1
            if any(start <= index < end and finding.rule in rules for start, end, rules in ignored):
                continue
            findings.append(finding)

    findings.sort(key=lambda f: (f.key, f.line, f.rule))
    for finding in findings:
        display = checked[finding.key].relative_to(ROOT).as_posix()
        print("{}:{}: {} {}: {}".format(display, finding.line, finding.severity, finding.rule, finding.message))

    errors = [f for f in findings if f.severity == "error"]
    counts = {}
    for finding in findings:
        if finding.severity == "warning":
            counts.setdefault(finding.key, {}).setdefault(finding.rule, 0)
            counts[finding.key][finding.rule] += 1

    exceeded = []
    decreased = False
    for key in sorted(checked):
        current = counts.get(key, {})
        recorded = baseline.get(key, {})
        for rule in sorted(set(current) | set(recorded)):
            now = current.get(rule, 0)
            limit = recorded.get(rule, 0)
            if now > limit:
                exceeded.append("  {} {}: {} > {}".format(key, rule, now, limit))
            elif now < limit:
                decreased = True

    total_warnings = sum(sum(rules.values()) for rules in counts.values())
    total_baseline = sum(sum(baseline.get(key, {}).values()) for key in checked)
    print("Errors: {}".format(len(errors)))
    print("Warnings: {} (baseline {})".format(total_warnings, total_baseline))

    if args.update_baseline:
        if errors:
            print("The baseline was not updated because errors exist.", file=sys.stderr)
            return 1
        updated = {key: rules for key, rules in baseline.items() if key not in checked}
        updated.update(counts)
        content = {"warnings": {key: dict(sorted(updated[key].items())) for key in sorted(updated)}}
        baseline_path.write_text(json.dumps(content, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("Updated the baseline: {}".format(args.baseline))
        return 0

    for line in exceeded:
        print(line)
    if exceeded:
        print("Warnings exceed the baseline.", file=sys.stderr)
    elif decreased:
        print("Warnings decreased; run with --update-baseline to record the new counts.")
    return 1 if errors or exceeded else 0


def main():
    parser = argparse.ArgumentParser(description="Check the Markdown format of specs/product.")
    parser.add_argument("paths", nargs="*", help="files or directories relative to the repository root")
    parser.add_argument("--config", default=DEFAULT_CONFIG)
    parser.add_argument("--baseline", default=DEFAULT_BASELINE)
    parser.add_argument("--update-baseline", action="store_true")
    args = parser.parse_args()
    try:
        return run(args)
    except ConfigError as error:
        print("check-spec-format: {}".format(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
