"""製品仕様で使う ID の定義の書式。"""

import re


DEFINITION_RE = re.compile(
    r"^[ \t]*(?:-|[0-9]+\.)[ \t]+\*\*(?P<id>(?:FR|SC|EC|A)-[0-9]+|US[0-9]+-AS[0-9]+)\*\*"
)
