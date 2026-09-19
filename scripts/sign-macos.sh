#!/usr/bin/env bash
# Developer ID-sign and notarize the unpacked macOS Controller app.
set -euo pipefail

require() {
    local name="$1"
    if [[ -z "${!name:-}" ]]; then
        echo "error: $name is not set" >&2
        exit 1
    fi
}

require APPLE_CERTIFICATE_P12_BASE64
require APPLE_CERTIFICATE_PASSWORD
require APPLE_SIGNING_IDENTITY
require APPLE_TEAM_ID
require APPLE_API_KEY_BASE64
require APPLE_API_KEY_ID
require APPLE_API_ISSUER

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
zip_path="$root/unsigned/macos/PRNS-Controller-macos-unsigned.zip"
work="$(mktemp -d)"
keychain="$work/signing.keychain-db"
keychain_password="$(openssl rand -hex 16)"
trap 'security delete-keychain "$keychain" 2>/dev/null || true; rm -rf "$work"' EXIT

unzip -q "$zip_path" -d "$work/app"
app="$(find "$work/app" -maxdepth 2 -type d -name '*.app' | head -n 1)"
if [[ -z "$app" ]]; then
    echo "error: no .app in macOS unsigned zip" >&2
    exit 1
fi

printf '%s' "$APPLE_CERTIFICATE_P12_BASE64" | base64 --decode >"$work/cert.p12"
printf '%s' "$APPLE_API_KEY_BASE64" | base64 --decode >"$work/AuthKey.p8"

# Hardened-runtime entitlements for the Dioxus/wry host and helper tools.
cat >"$work/entitlements.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.cs.allow-jit</key>
	<true/>
	<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
	<true/>
	<key>com.apple.security.device.bluetooth</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
	<key>com.apple.security.network.server</key>
	<true/>
</dict>
</plist>
EOF

security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$work/cert.p12" -k "$keychain" -P "$APPLE_CERTIFICATE_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain"
security list-keychains -d user -s "$keychain" $(security list-keychains -d user | tr -d '"')

sign_one() {
    local path="$1"
    codesign --force --options runtime --timestamp \
        --entitlements "$work/entitlements.plist" \
        --sign "$APPLE_SIGNING_IDENTITY" \
        --keychain "$keychain" \
        "$path"
}

# Sign nested Mach-O helpers first (hopspot-flash lives under Resources).
# Avoid --deep; notarization rejects helpers that were only covered loosely.
while IFS= read -r -d '' candidate; do
    if file -b "$candidate" | grep -q 'Mach-O'; then
        echo "signing nested $(basename "$candidate")"
        sign_one "$candidate"
    fi
done < <(find "$app/Contents" -type f -print0)

sign_one "$app"
codesign --verify --strict --verbose=2 "$app"

signed_zip="$work/PRNS-Controller-macos.zip"
ditto -c -k --keepParent "$app" "$signed_zip"

submit_out="$work/notary-submit.txt"
set +e
xcrun notarytool submit "$signed_zip" \
    --key "$work/AuthKey.p8" \
    --key-id "$APPLE_API_KEY_ID" \
    --issuer "$APPLE_API_ISSUER" \
    --team-id "$APPLE_TEAM_ID" \
    --wait | tee "$submit_out"
submit_status=${PIPESTATUS[0]}
set -e

submission_id="$(
    awk '/id:/{print $2; exit}' "$submit_out" || true
)"
if [[ "$submit_status" -ne 0 ]] || grep -Eq 'status: Invalid|status: Rejected' "$submit_out"; then
    echo "error: notarization failed (exit $submit_status)" >&2
    if [[ -n "$submission_id" ]]; then
        xcrun notarytool log "$submission_id" \
            --key "$work/AuthKey.p8" \
            --key-id "$APPLE_API_KEY_ID" \
            --issuer "$APPLE_API_ISSUER" \
            --team-id "$APPLE_TEAM_ID" || true
    fi
    exit 1
fi

xcrun stapler staple "$app"

rm -f "$zip_path"
ditto -c -k --keepParent "$app" "$root/unsigned/macos/PRNS-Controller-macos.zip"
echo "signed $(basename "$app")"
