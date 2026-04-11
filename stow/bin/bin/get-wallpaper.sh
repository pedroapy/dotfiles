#!/usr/bin/env bash
# Download Bing wallpaper of the day and set it with swww
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

# Set wallpaper with swww (smooth transition)
if command -v swww &>/dev/null && pgrep -x swww-daemon &>/dev/null; then
    swww img "$FILEPATH" --transition-type grow --transition-duration 2
fi
