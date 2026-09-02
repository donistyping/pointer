#!/bin/bash
# Build Pointer.app from the Swift sources. Needs the Command Line Tools
# (or full Xcode) — no Xcode project required.
set -euo pipefail
cd "$(dirname "$0")"

APP="Pointer.app"
SDK="$(xcrun --sdk macosx --show-sdk-path)"

echo "▸ Compiling (universal: arm64 + x86_64)…"
rm -rf "$APP" build
mkdir -p build
for arch in arm64 x86_64; do
    swiftc -O \
        Sources/*.swift \
        -sdk "$SDK" \
        -target "${arch}-apple-macos13.0" \
        -framework Cocoa \
        -framework CoreGraphics \
        -framework ApplicationServices \
        -o "build/Pointer-${arch}"
done
lipo -create -output build/Pointer build/Pointer-arm64 build/Pointer-x86_64

echo "▸ Assembling bundle…"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/Pointer "$APP/Contents/MacOS/Pointer"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "▸ Signing…"
# Identity name is historical (predates the app's rename) and is pinned on
# purpose: the Accessibility grant is bound to this certificate, so renaming
# it would orphan existing grants.
IDENTITY="MouseFix Local Signer"

# First build on a machine: create a local signing certificate so the
# Accessibility grant survives rebuilds (ad-hoc signatures don't).
if ! security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    echo "  creating local signing certificate ('$IDENTITY')…"
    TMPD="$(mktemp -d)"
    cat > "$TMPD/cert.cnf" <<'CNF'
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = MouseFix Local Signer
[v3]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF
    openssl req -x509 -newkey rsa:2048 -keyout "$TMPD/key.pem" -out "$TMPD/cert.pem" \
        -days 3650 -nodes -config "$TMPD/cert.cnf" >/dev/null 2>&1 || true
    openssl pkcs12 -export -inkey "$TMPD/key.pem" -in "$TMPD/cert.pem" \
        -out "$TMPD/id.p12" -passout pass:pointer -name "$IDENTITY" >/dev/null 2>&1 || true
    security import "$TMPD/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
        -P pointer -T /usr/bin/codesign -A >/dev/null 2>&1 || true
    rm -rf "$TMPD"
fi

if security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    codesign --force --sign "$IDENTITY" --identifier com.local.mousefix "$APP"
    echo "  signed with stable identity — Accessibility grant persists across rebuilds"
else
    codesign --force --sign - --identifier com.local.mousefix "$APP"
    echo "  WARNING: couldn't create '$IDENTITY'; used ad-hoc (grant won't persist across rebuilds)"
fi

echo "✓ Built $(pwd)/$APP"

if [ "${1:-}" = "install" ]; then
    echo "▸ Installing to /Applications and enabling start-at-login…"
    rm -rf /Applications/Pointer.app
    cp -R "$APP" /Applications/ || { echo "  couldn't write /Applications (drag it in manually)"; exit 1; }
    LABEL="com.local.pointer"; UID_NUM="$(id -u)"
    PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array><string>/usr/bin/open</string><string>/Applications/Pointer.app</string></array>
    <key>RunAtLoad</key><true/>
    <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
EOF
    pkill -x Pointer 2>/dev/null || true
    launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
    launchctl bootstrap "gui/$UID_NUM" "$PLIST" 2>/dev/null || true
    # RunAtLoad doesn't reliably re-fire on an in-session re-bootstrap, so
    # launch explicitly; `open` won't duplicate an already-running instance.
    open /Applications/Pointer.app
    echo "✓ Installed → /Applications/Pointer.app  (running, starts at login)"
else
    echo "  Run it:        open \"$(pwd)/$APP\""
    echo "  Or install it: ./build.sh install"
fi
