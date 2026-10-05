#!/usr/bin/env bash
# Download a pinned unsigned Controller matrix from tonycowan/Prns Actions runs.
set -euo pipefail

: "${GH_TOKEN:?PRNS_ACTIONS_TOKEN is not set}"
: "${PRNS_SHA:?prns_sha is required}"
: "${MACOS_RUN_ID:?macos_run_id is required}"
: "${LINUX_RUN_ID:?linux_run_id is required}"
: "${WINDOWS_RUN_ID:?windows_run_id is required}"
: "${ANDROID_RUN_ID:?android_run_id is required}"

repo="tonycowan/Prns"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/unsigned"
rm -rf "$out"
mkdir -p "$out"

fetch_one() {
    local platform="$1"
    local run_id="$2"
    local artifact="$3"
    local archive="$4"
    local dest="$out/$platform"

    local head conclusion name
    head="$(gh run view "$run_id" --repo "$repo" --json headSha --jq .headSha)"
    conclusion="$(gh run view "$run_id" --repo "$repo" --json conclusion --jq .conclusion)"
    name="$(gh run view "$run_id" --repo "$repo" --json name --jq .name)"

    if [[ "$head" != "$PRNS_SHA" ]]; then
        echo "error: $platform run $run_id is $head, not pinned $PRNS_SHA" >&2
        exit 1
    fi
    if [[ "$conclusion" != "success" ]]; then
        echo "error: $platform run $run_id conclusion is $conclusion" >&2
        exit 1
    fi
    case "$name" in
        controller-macos-package|controller-linux-package|controller-windows-package|controller-android-package) ;;
        *)
            echo "error: $platform run $run_id is workflow '$name', not a controller package" >&2
            exit 1
            ;;
    esac

    mkdir -p "$dest"
    gh run download "$run_id" --repo "$repo" --name "$artifact" --dir "$dest"
    if [[ ! -f "$dest/$archive" ]]; then
        echo "error: $dest/$archive missing after download" >&2
        exit 1
    fi
}

fetch_one macos "$MACOS_RUN_ID" PRNS-Controller-macos-aarch64-unsigned PRNS-Controller-macos-aarch64-unsigned.zip
fetch_one macos "$MACOS_RUN_ID" PRNS-Controller-macos-x86_64-unsigned PRNS-Controller-macos-x86_64-unsigned.zip
fetch_one linux "$LINUX_RUN_ID" PRNS-Controller-linux-aarch64-unsigned PRNS-Controller-linux-aarch64-unsigned.tar.gz
fetch_one linux "$LINUX_RUN_ID" PRNS-Controller-linux-x86_64-unsigned PRNS-Controller-linux-x86_64-unsigned.tar.gz
fetch_one windows "$WINDOWS_RUN_ID" PRNS-Controller-windows-aarch64-unsigned PRNS-Controller-windows-aarch64-unsigned.zip
fetch_one windows "$WINDOWS_RUN_ID" PRNS-Controller-windows-x86_64-unsigned PRNS-Controller-windows-x86_64-unsigned.zip
fetch_one android "$ANDROID_RUN_ID" PRNS-Controller-android-aarch64-unsigned PRNS-Controller-android-aarch64-unsigned.apk

fetch_prnsd() {
    local platform="$1"
    local run_id="$2"
    local artifact="$3"
    local archive="$4"
    fetch_one "$platform" "$run_id" "$artifact" "$archive"
    local path="$out/$platform/$archive"
    local size
    size="$(wc -c <"$path" | tr -d ' ')"
    if [[ "$size" -lt 1000000 ]]; then
        echo "error: $path is only $size bytes" >&2
        exit 1
    fi
    echo "$path: $size bytes"
}

fetch_prnsd macos "$MACOS_RUN_ID" prnsd-macos-aarch64 prnsd-macos-aarch64
fetch_prnsd macos "$MACOS_RUN_ID" prnsd-macos-x86_64 prnsd-macos-x86_64
fetch_prnsd linux "$LINUX_RUN_ID" prnsd-linux-aarch64 prnsd-linux-aarch64
fetch_prnsd linux "$LINUX_RUN_ID" prnsd-linux-x86_64 prnsd-linux-x86_64
fetch_prnsd windows "$WINDOWS_RUN_ID" prnsd-windows-aarch64 prnsd-windows-aarch64.exe
fetch_prnsd windows "$WINDOWS_RUN_ID" prnsd-windows-x86_64 prnsd-windows-x86_64.exe

# Compress-Archive on Windows stores backslash paths. Verify inside the zip.
verify_windows_flash() {
    local windows_zip="$1"
    python3 - "$windows_zip" <<'PY'
import sys
import zipfile

path = sys.argv[1]
with zipfile.ZipFile(path) as archive:
    matches = [
        info
        for info in archive.infolist()
        if info.filename.replace("\\", "/").rstrip("/").endswith("hopspot-flash.exe")
    ]
if not matches:
    print(f"error: {path} has no hopspot-flash.exe", file=sys.stderr)
    sys.exit(1)
size = max(info.file_size for info in matches)
if size < 1_000_000:
    print(f"error: hopspot-flash.exe in {path} is only {size} bytes", file=sys.stderr)
    sys.exit(1)
print(f"{path}: hopspot-flash.exe {size} bytes")
PY
}

verify_windows_flash "$out/windows/PRNS-Controller-windows-aarch64-unsigned.zip"
verify_windows_flash "$out/windows/PRNS-Controller-windows-x86_64-unsigned.zip"

apk="$out/android/PRNS-Controller-android-aarch64-unsigned.apk"
size="$(wc -c <"$apk" | tr -d ' ')"
if [[ "$size" -lt 1_000_000 ]]; then
    echo "error: $apk is only $size bytes" >&2
    exit 1
fi
echo "$apk: $size bytes"

echo "unsigned desktop six-way + Android aarch64 + six prnsd binaries match $PRNS_SHA"
