#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

if grep -rnE 'forWritingAtPath|createFile|write\(to:|FileHandle\(forWritingTo:|O_WRONLY|O_RDWR|O_CREAT' Sources/MediaViewerCore/Archive --include='*.swift'; then
    echo "write API reference found in Sources/MediaViewerCore/Archive" >&2
    exit 1
fi

echo "no write API references in Sources/MediaViewerCore/Archive"
