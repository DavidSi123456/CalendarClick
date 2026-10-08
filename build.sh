#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h}"
cd "$PROJECT_DIR"
/bin/zsh "$PROJECT_DIR/setup-signing.sh"
STAGING_DIR="$(mktemp -d /private/tmp/calendar-check.XXXXXX)"
ORIGINAL_KEYCHAINS=("${(@f)$(security list-keychains -d user | sed 's/^ *"//;s/"$//')}")
trap 'security list-keychains -d user -s "${ORIGINAL_KEYCHAINS[@]}"; rm -rf "$STAGING_DIR"' EXIT
APP_DIR="$STAGING_DIR/日历打勾.app"
OUTPUT_APP="$PROJECT_DIR/日历打勾.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$PROJECT_DIR/.build/ModuleCache"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 \
    -module-cache-path "$PROJECT_DIR/.build/ModuleCache" \
    Sources/*.swift -o "$APP_DIR/Contents/MacOS/CalendarCheck" \
    -framework AppKit -framework SwiftUI -framework EventKit -framework ApplicationServices
# Sign outside Desktop so its file-provider cannot race with codesign.
xattr -cr "$APP_DIR"
SIGNING_CERT_HASH="$(/usr/bin/openssl x509 -in "$PROJECT_DIR/.build/Signing/certificate.pem" -noout -fingerprint -sha1 | tr -d ':' | sed 's/.*=//')"
security list-keychains -d user -s "${ORIGINAL_KEYCHAINS[@]}" "$PROJECT_DIR/.build/Signing/CalendarCheck.keychain-db"
security unlock-keychain -p "$(<"$PROJECT_DIR/.build/Signing/password")" "$PROJECT_DIR/.build/Signing/CalendarCheck.keychain-db"
codesign --force --sign "$SIGNING_CERT_HASH" \
    --keychain "$PROJECT_DIR/.build/Signing/CalendarCheck.keychain-db" \
    --identifier local.davidsi.CalendarCheck "$APP_DIR"
ditto --norsrc --noextattr --noqtn "$APP_DIR" "$OUTPUT_APP"
xattr -cr "$OUTPUT_APP"
codesign --verify --deep --strict "$APP_DIR"
print "构建完成：$OUTPUT_APP"
