#!/usr/bin/env bash
# Weather via wttr.in with caching
CACHE_DIR="$HOME/.cache/waybar-weather"
CACHE_FILE="$CACHE_DIR/weather.json"
CACHE_MAX_AGE=1800

mkdir -p "$CACHE_DIR"

if [ -f "$CACHE_FILE" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
    if [ "$age" -lt "$CACHE_MAX_AGE" ]; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

DATA=$(curl -sf "https://wttr.in/?format=j1" 2>/dev/null)
[ -z "$DATA" ] && echo '{"text":"󰖪","tooltip":"Weather unavailable"}' && exit 0

TEMP=$(echo "$DATA" | jq -r '.current_condition[0].temp_C')
FEELS=$(echo "$DATA" | jq -r '.current_condition[0].FeelsLikeC')
DESC=$(echo "$DATA" | jq -r '.current_condition[0].weatherDesc[0].value')
HUMID=$(echo "$DATA" | jq -r '.current_condition[0].humidity')
WIND=$(echo "$DATA" | jq -r '.current_condition[0].windspeedKmph')
AREA=$(echo "$DATA" | jq -r '.nearest_area[0].areaName[0].value')
CODE=$(echo "$DATA" | jq -r '.current_condition[0].weatherCode')

case "$CODE" in
    113) ICON="󰖙" ;;
    116) ICON="󰖕" ;;
    119|122) ICON="󰖐" ;;
    143|248|260) ICON="󰖑" ;;
    176|263|266|293|296|353) ICON="󰖗" ;;
    299|302|305|308|356|359) ICON="󰖖" ;;
    200|386|389|392|395) ICON="󰖓" ;;
    179|182|227|230|323|326|329|332|335|338|368|371|374|377) ICON="󰖘" ;;
    *) ICON="󰖐" ;;
esac

TOMORROW_MAX=$(echo "$DATA" | jq -r '.weather[1].maxtempC')
TOMORROW_MIN=$(echo "$DATA" | jq -r '.weather[1].mintempC')
TOOLTIP="${AREA}: ${DESC}\n🌡️ ${TEMP}°C (feels ${FEELS}°C)\n💧 Humidity: ${HUMID}%\n💨 Wind: ${WIND} km/h\n\nTomorrow: ${TOMORROW_MIN}°C - ${TOMORROW_MAX}°C"

OUTPUT="{\"text\":\"${ICON} ${TEMP}°C\",\"tooltip\":\"${TOOLTIP}\",\"class\":\"weather\"}"
echo "$OUTPUT" > "$CACHE_FILE"
echo "$OUTPUT"
