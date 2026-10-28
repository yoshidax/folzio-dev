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

localization_bundle="$bin_dir/my_img_viewer_MediaViewerLocalization.bundle/Contents/Resources"
for language in ja en; do
    source_dir="$localization_bundle/$language.lproj"
    if [ ! -f "$source_dir/Localizable.strings" ] && [ ! -f "$source_dir/Localizable.stringsdict" ]; then
        echo "翻訳リソースがありません: $source_dir" >&2
        rm -rf "$app"
        exit 1
    fi
    mkdir -p "$app/Contents/Resources/$language.lproj"
    cp "$source_dir"/Localizable.* "$app/Contents/Resources/$language.lproj/"
done

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MediaViewer</string>
    <key>CFBundleIdentifier</key>
    <string>local.my-img-viewer.MediaViewer</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>ja</string>
        <string>en</string>
    </array>
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
