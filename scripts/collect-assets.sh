#!/usr/bin/env bash
# Stage the archives that a GitHub Release should attach.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist="$root/dist"
rm -rf "$dist"
mkdir -p "$dist"

cp "$root"/unsigned/linux/PRNS-Controller-linux-*-unsigned.tar.gz "$dist/"
cp "$root"/unsigned/windows/PRNS-Controller-windows-*-unsigned.zip "$dist/"

shopt -s nullglob
signed=( "$root"/unsigned/macos/PRNS-Controller-macos-aarch64.zip \
         "$root"/unsigned/macos/PRNS-Controller-macos-x86_64.zip )
if [[ ${#signed[@]} -eq 2 && -f "${signed[0]}" && -f "${signed[1]}" ]]; then
    cp "${signed[@]}" "$dist/"
else
    cp "$root"/unsigned/macos/PRNS-Controller-macos-*-unsigned.zip "$dist/"
fi
shopt -u nullglob

(
    cd "$dist"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- * >SHA256SUMS
    else
        sha256sum -- * >SHA256SUMS
    fi
)
echo "staged $(ls "$dist" | tr '\n' ' ')"
