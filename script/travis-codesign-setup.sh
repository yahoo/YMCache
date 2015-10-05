#!/bin/sh

KEYCHAIN=ios-build.keychain
PASSWORD=cibuild
SCRIPT_DIR=$(dirname "$0")

# Create a temporary keychain for code signing.
security create-keychain -p "$PASSWORD" "$KEYCHAIN"
security default-keychain -s "$KEYCHAIN"
security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"
security set-keychain-settings -t 3600 -l "$KEYCHAIN"

# Download the certificate for the Apple Worldwide Developer Relations
# Certificate Authority.
CA_CERTPATH="$SCRIPT_DIR/apple_wwdr.cer"
curl 'https://developer.apple.com/certificationauthority/AppleWWDRCA.cer' > "$CA_CERTPATH"
security import "$CA_CERTPATH" -k "$KEYCHAIN" -T /usr/bin/codesign

# Import our development certificate.
MY_CERTPATH="$SCRIPT_DIR/certificates/Development.p12"
echo "Codesign development certificate expiration: "
echo "$KEY_PASSWORD" | openssl pkcs12 -in "$MY_CERTPATH" -password stdin -nokeys -nomacver | openssl x509 -noout -enddate

security import "$MY_CERTPATH" -k "$KEYCHAIN" -P "$KEY_PASSWORD" -T /usr/bin/codesign
