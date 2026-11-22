#!/usr/bin/env bash
# Wallpapers per monitor with awww.
#   wallpaper.sh random          a different random image on each monitor
#   wallpaper.sh rotate [secs]   random now, then again every secs (default 1800)
#   wallpaper.sh pick            rofi picker with thumbnails, applies to the focused monitor
#   wallpaper.sh set <file> [monitor]
# Images live in $WALLPAPER_DIR. Files named px-* are pixel art and are scaled
# with the nearest filter so the pixels stay sharp.
# The image on each monitor is linked at ~/.cache/wallpaper/<monitor> (hyprlock reads it).

set -euo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpapers}"
STATE="$HOME/.cache/wallpaper"
THUMBS="$STATE/thumbs"
TRANSITIONS=(grow wave wipe outer center)
mkdir -p "$STATE"

monitors() { hyprctl monitors -j | jq -r '.[].name'; }

images() {
    find "$WALLPAPER_DIR" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) | sort
}

set_wall() {
    local img="$1" mon="$2" filter=Lanczos3
    [[ "$(basename "$img")" == px-* ]] && filter=Nearest
    local t=${TRANSITIONS[RANDOM % ${#TRANSITIONS[@]}]}
    awww img -o "$mon" --resize crop --filter "$filter" \
        --transition-type "$t" --transition-duration 1.5 --transition-fps 60 \
        --transition-pos "0.$((RANDOM % 90 + 10)),0.$((RANDOM % 90 + 10))" "$img" || return 1
    ln -sfn "$img" "$STATE/$mon"
}

random_all() {
    mapfile -t all < <(images)
    (( ${#all[@]} )) || { echo "No images in $WALLPAPER_DIR" >&2; exit 1; }
    local used=() mon img
    for mon in $(monitors); do
        used+=("$(readlink "$STATE/$mon" 2>/dev/null || true)")
    done
    for mon in $(monitors); do
        local tries=0
        while :; do
            img=${all[RANDOM % ${#all[@]}]}
            [[ " ${used[*]} " != *" $img "* || $tries -ge 20 ]] && break
            tries=$((tries + 1))
        done
        used+=("$img")
        set_wall "$img" "$mon"
    done
}

thumb() {
    local img="$1" out="$THUMBS/$(basename "${img%.*}").png"
    if [[ ! -s "$out" || "$img" -nt "$out" ]]; then
        mkdir -p "$THUMBS"
        python3 -I - "$img" "$out" <<'EOF' >/dev/null 2>&1 || cp "$img" "$out"
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
pixel = sys.argv[1].rsplit("/", 1)[-1].startswith("px-")
im.thumbnail((480, 270), Image.NEAREST if pixel else Image.LANCZOS)
im.save(sys.argv[2])
EOF
    fi
    printf '%s' "$out"
}

pick() {
    local mon choice
    mon=$(hyprctl activeworkspace -j | jq -r '.monitor')
    choice=$(images | while read -r img; do
        printf '%s\0icon\x1f%s\n' "$(basename "$img")" "$(thumb "$img")"
    done | rofi -dmenu -show-icons -i -p "Fondo · $mon" -theme-str '@import "wallpaper.rasi"') || exit 0
    [[ -n "$choice" ]] && set_wall "$WALLPAPER_DIR/$choice" "$mon"
}

case "${1:-random}" in
    random) random_all ;;
    rotate)
        secs="${2:-1800}"
        while :; do random_all || true; sleep "$secs"; done ;;
    pick) pick ;;
    set) set_wall "$2" "${3:-$(hyprctl activeworkspace -j | jq -r '.monitor')}" ;;
    *) echo "usage: $0 {random|rotate [secs]|pick|set <file> [monitor]}" >&2; exit 2 ;;
esac
