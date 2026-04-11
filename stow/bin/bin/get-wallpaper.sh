#!/usr/bin/env bash
# Download Bing wallpaper of the day and set it with awww
WALLPAPER_DIR="$HOME/BingWallpaper"
mkdir -p "$WALLPAPER_DIR"

URL="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=es-ES"
IMG_PATH=$(curl -s "$URL" | jq -r '.images[0].url')
FULL_URL="https://www.bing.com${IMG_PATH}"
FILENAME="$(date +%Y%m%d).jpg"
FILEPATH="$WALLPAPER_DIR/$FILENAME"

if [[ ! -f "$FILEPATH" ]]; then
    curl -s -o "$FILEPATH" "$FULL_URL"
fi

# Set wallpaper with awww (smooth transition)
if command -v awww &>/dev/null && pgrep -x awww-daemon &>/dev/null; then
    awww img "$FILEPATH" --transition-type grow --transition-duration 2
fi
