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

swaymsg output "*" bg $filename fill
