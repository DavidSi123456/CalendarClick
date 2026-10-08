#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
cd "$PROJECT_DIR"
APP_SOURCE="$PROJECT_DIR/日历打勾.app"
if [[ ! -d "$APP_SOURCE" ]]; then
  print -u2 '请先运行 ./build.sh 生成日历打勾.app。'
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_SOURCE/Contents/Info.plist")"
if [[ ! "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  print -u2 '应用版本号必须为三个数字段。'
  exit 1
fi

PACKAGE_NAME="CalendarClick-v${VERSION}-macOS-arm64-zh-CN"
PACKAGE_WORK="$(mktemp -d /private/tmp/calendarclick-package.XXXXXX)"
trap 'rm -rf "$PACKAGE_WORK"' EXIT
PACKAGE_CONTENT="$PACKAGE_WORK/日历打勾"
OUTPUT_DIR="$PROJECT_DIR/dist"
mkdir -p "$PACKAGE_CONTENT" "$OUTPUT_DIR"

ditto --norsrc --noextattr --noqtn "$APP_SOURCE" "$PACKAGE_CONTENT/日历打勾.app"
cp "$PROJECT_DIR/使用说明.txt" "$PACKAGE_CONTENT/使用说明.txt"
xattr -cr "$PACKAGE_CONTENT"
SIGNATURE_OPTIONS=()
if [[ -f "$PROJECT_DIR/.build/Signing/CalendarCheck.keychain-db" ]]; then
  SIGNATURE_OPTIONS=(--keychain "$PROJECT_DIR/.build/Signing/CalendarCheck.keychain-db")
fi
codesign --verify --deep --strict "${SIGNATURE_OPTIONS[@]}" "$PACKAGE_CONTENT/日历打勾.app"
if [[ "$(lipo -archs "$PACKAGE_CONTENT/日历打勾.app/Contents/MacOS/CalendarCheck")" != 'arm64' ]]; then
  print -u2 '应用架构不是预期的 arm64。'
  exit 1
fi

ditto -c -k --norsrc --noextattr --keepParent "$PACKAGE_CONTENT" "$OUTPUT_DIR/$PACKAGE_NAME.zip"
ln -s /Applications "$PACKAGE_CONTENT/应用程序"
hdiutil create -volname '日历打勾' -srcfolder "$PACKAGE_CONTENT" -ov -format UDZO "$OUTPUT_DIR/$PACKAGE_NAME.dmg"
cd "$OUTPUT_DIR"
shasum -a256 "$PACKAGE_NAME.dmg" "$PACKAGE_NAME.zip" > SHA256SUMS.txt
print "安装包已生成：$OUTPUT_DIR"
