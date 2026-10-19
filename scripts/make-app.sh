#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release --product MediaViewerApp

bin_dir="$(swift build -c release --product MediaViewerApp --show-bin-path)"
app=".build/MediaViewer.app"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"

cp "$bin_dir/MediaViewerApp" "$app/Contents/MacOS/MediaViewer"
chmod +x "$app/Contents/MacOS/MediaViewer"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MediaViewer</string>
    <key>CFBundleIdentifier</key>
    <string>local.my-img-viewer.MediaViewer</string>
    <key>CFBundleName</key>
    <string>MediaViewer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$app"

echo "created $app"
