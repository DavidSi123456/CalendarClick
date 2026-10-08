#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"
OUTPUT="$PROJECT_DIR/.build/iOSPreview"
STAGING="$(mktemp -d /private/tmp/calendarclick-ios-preview.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/日历打勾-iOS预览.app"
OUTPUT_APP="$OUTPUT/日历打勾-iOS预览.app"
mkdir -p "$APP/Contents/MacOS" "$OUTPUT/ModuleCache"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>日历打勾-iOS预览</string>
<key>CFBundleIdentifier</key><string>local.davidsi.CalendarClick.MobilePreview</string>
<key>CFBundleExecutable</key><string>iOSPreview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
swiftc -parse-as-library -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path "$OUTPUT/ModuleCache" \
  Sources/CompletionCore.swift iOS/Sources/{AgendaCore,CalendarRepository,DemoData,AgendaModel,AgendaView}.swift \
  iOS/Preview/main.swift -framework AppKit -framework SwiftUI -framework EventKit \
  -o "$APP/Contents/MacOS/iOSPreview"
xattr -cr "$APP"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto --norsrc --noextattr --noqtn "$APP" "$OUTPUT_APP"
print "预览已生成：$OUTPUT_APP"
