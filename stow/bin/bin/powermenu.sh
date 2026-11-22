#!/usr/bin/env bash
# Rofi power menu: lock, log out, suspend, reboot, power off.

set -euo pipefail

lock="󰌾"; logout="󰍃"; suspend="󰤄"; reboot="󰜉"; poweroff="󰐥"

uptime_txt=$(uptime -p | sed 's/^up //')
choice=$(printf '%s\n' "$lock" "$logout" "$suspend" "$reboot" "$poweroff" |
    rofi -dmenu -i -p "  $uptime_txt" -theme-str '@import "powermenu.rasi"') || exit 0

confirm() {
    [[ "$(printf 'Sí\nNo\n' | rofi -dmenu -i -p "¿$1?")" == "Sí" ]]
}

case "$choice" in
    "$lock")     hyprlock ;;
    "$logout")   confirm "Cerrar sesión" && hyprctl dispatch 'hl.dsp.exit()' ;;
    "$suspend")  systemctl suspend ;;
    "$reboot")   confirm "Reiniciar" && systemctl reboot ;;
    "$poweroff") confirm "Apagar" && systemctl poweroff ;;
esac
