#!/usr/bin/env bash
# Stage the archives that a GitHub Release should attach.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist="$root/dist"
rm -rf "$dist"
mkdir -p "$dist"

cp "$root/unsigned/linux/PRNS-Controller-linux-unsigned.tar.gz" "$dist/"
cp "$root/unsigned/windows/PRNS-Controller-windows-unsigned.zip" "$dist/"

if [[ -f "$root/unsigned/macos/PRNS-Controller-macos.zip" ]]; then
    cp "$root/unsigned/macos/PRNS-Controller-macos.zip" "$dist/"
else
    cp "$root/unsigned/macos/PRNS-Controller-macos-unsigned.zip" "$dist/"
fi

(
    cd "$dist"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- * >SHA256SUMS
    else
        sha256sum -- * >SHA256SUMS
    fi
)
echo "staged $(ls "$dist" | tr '\n' ' ')"
