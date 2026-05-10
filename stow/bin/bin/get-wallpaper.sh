#!/usr/bin/env bash
# Download Bing wallpaper of the day and set it with awww
set -euo pipefail

WALLPAPER_DIR="$HOME/BingWallpaper"
mkdir -p "$WALLPAPER_DIR"

URL="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=es-ES"
IMG_PATH=$(curl -sf "$URL" | jq -r '.images[0].url' 2>/dev/null) || {
    echo "get-wallpaper: Bing API unreachable" >&2
    exit 1
}
[[ -n "$IMG_PATH" && "$IMG_PATH" != "null" ]] || {
    echo "get-wallpaper: invalid response from Bing" >&2
    exit 1
}

FULL_URL="https://www.bing.com${IMG_PATH}"
FILENAME="$(date +%Y%m%d).jpg"
FILEPATH="$WALLPAPER_DIR/$FILENAME"

if [[ ! -f "$FILEPATH" ]]; then
    curl -sfo "$FILEPATH" "$FULL_URL" || {
        echo "get-wallpaper: download failed" >&2
        rm -f "$FILEPATH"
        exit 1
    }
    # Sanity check: must be JPEG (FF D8 FF magic bytes)
    if ! head -c 3 "$FILEPATH" | od -An -tx1 | grep -q "ff d8 ff"; then
        echo "get-wallpaper: not a JPEG, discarding" >&2
        rm -f "$FILEPATH"
        exit 1
    fi
fi

# Set wallpaper with awww (smooth transition)
if command -v awww &>/dev/null && pgrep -x awww-daemon &>/dev/null; then
    awww img "$FILEPATH" --transition-type grow --transition-duration 2
fi
