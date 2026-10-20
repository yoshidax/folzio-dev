#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release --product MediaViewerApp

app=".build/MediaViewer.app"

rm -rf "$app"

scripts/make-icon.sh

bin_dir="$(swift build -c release --product MediaViewerApp --show-bin-path)"

mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

cp "$bin_dir/MediaViewerApp" "$app/Contents/MacOS/MediaViewer"
chmod +x "$app/Contents/MacOS/MediaViewer"

cp .build/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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
