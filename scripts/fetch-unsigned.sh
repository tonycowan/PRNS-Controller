#!/usr/bin/env bash
# Download a pinned unsigned Controller triple from tonycowan/Prns Actions runs.
set -euo pipefail

: "${GH_TOKEN:?PRNS_ACTIONS_TOKEN is not set}"
: "${PRNS_SHA:?prns_sha is required}"
: "${MACOS_RUN_ID:?macos_run_id is required}"
: "${LINUX_RUN_ID:?linux_run_id is required}"
: "${WINDOWS_RUN_ID:?windows_run_id is required}"

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
        controller-macos-package|controller-linux-package|controller-windows-package) ;;
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

fetch_one macos "$MACOS_RUN_ID" PRNS-Controller-macos-unsigned PRNS-Controller-macos-unsigned.zip
fetch_one linux "$LINUX_RUN_ID" PRNS-Controller-linux-unsigned PRNS-Controller-linux-unsigned.tar.gz
fetch_one windows "$WINDOWS_RUN_ID" PRNS-Controller-windows-unsigned PRNS-Controller-windows-unsigned.zip

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
unzip -q "$out/windows/PRNS-Controller-windows-unsigned.zip" -d "$work/windows"
firmware="$(find "$work/windows" -type d -name firmware | head -n 1)"
if [[ -z "$firmware" || ! -f "$firmware/bundle.json" ]]; then
    echo "error: Windows package has no firmware/bundle.json (empty flash collection)" >&2
    exit 1
fi
bytes=0
while IFS= read -r -d '' firmware_file; do
    bytes=$((bytes + $(wc -c <"$firmware_file")))
done < <(find "$firmware" -type f -print0)
if [[ "$bytes" -lt 4096 ]]; then
    echo "error: Windows firmware tree is only ${bytes} bytes" >&2
    exit 1
fi

echo "unsigned triple matches $PRNS_SHA"
