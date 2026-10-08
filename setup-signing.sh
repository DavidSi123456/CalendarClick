#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h}"
SIGNING_DIR="$PROJECT_DIR/.build/Signing"
SIGNING_KEYCHAIN="$SIGNING_DIR/CalendarCheck.keychain-db"
mkdir -p "$SIGNING_DIR"
chmod 700 "$SIGNING_DIR"
umask 077
if [[ ! -f "$SIGNING_DIR/password" ]]; then
    /usr/bin/openssl rand -hex 32 > "$SIGNING_DIR/password"
fi
SIGNING_PASSWORD="$(<"$SIGNING_DIR/password")"
if [[ ! -f "$SIGNING_DIR/certificate.pem" ]]; then
    /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout "$SIGNING_DIR/private-key.pem" -out "$SIGNING_DIR/certificate.pem" \
        -days 3650 -subj '/CN=CalendarCheck Local Build/O=CalendarCheck Local' \
        -addext 'keyUsage=critical,digitalSignature' \
        -addext 'extendedKeyUsage=critical,codeSigning' > "$SIGNING_DIR/certificate-generation.log" 2>&1
fi
if [[ ! -f "$SIGNING_KEYCHAIN" ]]; then
    /usr/bin/openssl pkcs12 -export -inkey "$SIGNING_DIR/private-key.pem" \
        -in "$SIGNING_DIR/certificate.pem" -out "$SIGNING_DIR/identity.p12" \
        -passout "file:$SIGNING_DIR/password" -name 'CalendarCheck Local Build'
    security create-keychain -p "$SIGNING_PASSWORD" "$SIGNING_KEYCHAIN"
    security unlock-keychain -p "$SIGNING_PASSWORD" "$SIGNING_KEYCHAIN"
    security import "$SIGNING_DIR/identity.p12" -k "$SIGNING_KEYCHAIN" \
        -P "$SIGNING_PASSWORD" -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple: -s -k "$SIGNING_PASSWORD" "$SIGNING_KEYCHAIN" > "$SIGNING_DIR/key-partition.log"
fi
security unlock-keychain -p "$SIGNING_PASSWORD" "$SIGNING_KEYCHAIN"
if [[ ! -f "$SIGNING_DIR/code-sign-trusted" ]]; then
    # User-domain trust is restricted to local code signing, never TLS/SSL.
    security add-trusted-cert -r trustRoot -p codeSign -k "$SIGNING_KEYCHAIN" "$SIGNING_DIR/certificate.pem"
    touch "$SIGNING_DIR/code-sign-trusted"
fi
print '本项目的固定签名身份已准备好。'
