#!/bin/bash

CONFIG="$HOME/.config/waybar/config.jsonc"
STYLE="$HOME/.config/waybar/style.css"

trap "killall waybar" EXIT

while true; do
    if pgrep -x "waybar" >/dev/null; then
        killall waybar
        echo "Waybar killed"
    else
        waybar -c $CONFIG -s $STYLE &
        echo "Waybar launched and watching for changes..."
        inotifywait -e create,modify $CONFIG $STYLE
        echo "Waybar config changed, restarting..."
        killall waybar
    fi
done
