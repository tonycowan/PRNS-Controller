#!/usr/bin/env bash
# Developer ID-sign and notarize each unsigned macOS Controller .app (per arch).
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
work="$(mktemp -d)"
keychain="$work/signing.keychain-db"
keychain_password="$(openssl rand -hex 16)"
trap 'security delete-keychain "$keychain" 2>/dev/null || true; rm -rf "$work"' EXIT

printf '%s' "$APPLE_CERTIFICATE_P12_BASE64" | base64 --decode >"$work/cert.p12"
printf '%s' "$APPLE_API_KEY_BASE64" | base64 --decode >"$work/AuthKey.p8"

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

sign_zip() {
    local zip_path="$1"
    local arch="$2"
    local stage="$work/app-$arch"

    rm -rf "$stage"
    mkdir -p "$stage"
    unzip -q "$zip_path" -d "$stage"
    local app
    app="$(find "$stage" -maxdepth 2 -type d -name '*.app' | head -n 1)"
    if [[ -z "$app" ]]; then
        echo "error: no .app in $zip_path" >&2
        exit 1
    fi

    while IFS= read -r -d '' candidate; do
        if file -b "$candidate" | grep -q 'Mach-O'; then
            echo "signing nested $(basename "$candidate") ($arch)"
            sign_one "$candidate"
        fi
    done < <(find "$app/Contents" -type f -print0)

    sign_one "$app"
    codesign --verify --strict --verbose=2 "$app"

    local signed_zip="$work/PRNS-Controller-macos-$arch.zip"
    ditto -c -k --keepParent "$app" "$signed_zip"

    local submit_out="$work/notary-$arch.txt"
    set +e
    xcrun notarytool submit "$signed_zip" \
        --key "$work/AuthKey.p8" \
        --key-id "$APPLE_API_KEY_ID" \
        --issuer "$APPLE_API_ISSUER" \
        --team-id "$APPLE_TEAM_ID" \
        --wait | tee "$submit_out"
    local submit_status=${PIPESTATUS[0]}
    set -e

    local submission_id
    submission_id="$(awk '/id:/{print $2; exit}' "$submit_out" || true)"
    if [[ "$submit_status" -ne 0 ]] || grep -Eq 'status: Invalid|status: Rejected' "$submit_out"; then
        echo "error: notarization failed for $arch (exit $submit_status)" >&2
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
    ditto -c -k --keepParent "$app" "$root/unsigned/macos/PRNS-Controller-macos-$arch.zip"
    echo "signed $(basename "$app") ($arch)"
}

shopt -s nullglob
unsigned_zips=( "$root"/unsigned/macos/PRNS-Controller-macos-*-unsigned.zip )
shopt -u nullglob
if [[ ${#unsigned_zips[@]} -eq 0 ]]; then
    echo "error: no unsigned macOS zips under unsigned/macos/" >&2
    exit 1
fi

for zip_path in "${unsigned_zips[@]}"; do
    base="$(basename "$zip_path")"
    # PRNS-Controller-macos-<arch>-unsigned.zip
    arch="${base#PRNS-Controller-macos-}"
    arch="${arch%-unsigned.zip}"
    if [[ -z "$arch" || "$arch" == "$base" ]]; then
        echo "error: cannot parse arch from $base" >&2
        exit 1
    fi
    sign_zip "$zip_path" "$arch"
done
