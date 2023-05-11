#!/bin/sh

urlpath=$(
    curl "https://www.bing.com/HPImageArchive.aspx?format=rss&idx=0&n=1&mkt=es-ES" |
        xmllint --xpath "/rss/channel/item/link/text()" - |
        sed 's/1366x768/1920x1080/g'
)

date=$(date '+%Y%m%d')
filename="$HOME/BingWallpaper/$date.jpg"
echo "saved to $filename"

# Download wallpaper to file
curl "https://www.bing.com$urlpath" -o "$filename"

if [ "$XDG_CURRENT_DESKTOP" = "i3" ]; then
    # Set wallpaper
    feh --bg-fill "$filename"
    # Set lockscreen
    betterlockscreen -u $filename --blur 0.5

elif [ "$XDG_CURRENT_DESKTOP" = "sway" ]; then
    swaymsg output "*" bg $filename fill

else
    echo "Estás en un gestor de ventanas desconocido"
fi
