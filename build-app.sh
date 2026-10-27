#!/bin/zsh
set -e
cd "$(dirname "$0")"
swift build -c release
BIN=$(swift build -c release --show-bin-path)/LiveWallpaper
APP="LiveWallpaper.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/LiveWallpaper"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LiveWallpaper</string>
<key>CFBundleIdentifier</key><string>com.local.livewallpaper</string>
<key>CFBundleName</key><string>Live Wallpaper</string>
<key>CFBundleVersion</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
echo "Built: $APP — double-click to run (menu bar icon)."
