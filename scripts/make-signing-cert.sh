#!/bin/bash
# Create a stable, self-signed code-signing identity for local development so that
# rebuilds keep the same code signature — which means macOS keeps the Accessibility
# permission grant instead of resetting it every build.
#
# Run once:  ./scripts/make-signing-cert.sh
set -euo pipefail

IDENTITY="FanzyZones Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$IDENTITY"; then
    echo "Signing identity '$IDENTITY' already exists — nothing to do."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cfg" <<EOF
[req]
distinguished_name = dn
x509_extensions    = v3
prompt             = no
[dn]
CN = $IDENTITY
[v3]
basicConstraints       = critical,CA:false
keyUsage               = critical,digitalSignature
extendedKeyUsage       = critical,codeSigning
EOF

echo "Generating self-signed code-signing certificate…"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cfg" 2>/dev/null

openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -name "$IDENTITY" -out "$TMP/identity.p12" -passout pass:fanzy 2>/dev/null

# -A: let any app (incl. codesign) use the key without a keychain prompt.
echo "Importing identity into the login keychain…"
security import "$TMP/identity.p12" -k "$KEYCHAIN" -P fanzy -A

# Trust it for code signing in the user domain (may show a one-time auth prompt).
echo "Trusting the certificate for code signing (authenticate if prompted)…"
security add-trusted-cert -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem" || \
    echo "  (trust step skipped/failed — codesign may still work; see README)"

echo
echo "Done. Verify with:  security find-identity -p codesigning"
echo "Then build with:    make app SIGN_IDENTITY=\"$IDENTITY\""
