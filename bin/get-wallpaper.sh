#!/bin/sh

urlpath=$(
    curl "https://www.bing.com/HPImageArchive.aspx?format=rss&idx=0&n=1&mkt=es-ES" |
        xmllint --xpath "/rss/channel/item/link/text()" - |
        sed 's/1366x768/1920x1080/g'
)

date=$(date '+%Y%m%d')
filename="$HOME/BingWallpaper/$date.jpg"
current="$HOME/BingWallpaper/current.jpg"

echo "saved to $filename"

# Download wallpaper to file
curl "https://www.bing.com$urlpath" -o "$filename"

# Copy as current wallpaper
cp $filename $current

dbus-send --session --dest=org.kde.plasmashell --type=method_call /PlasmaShell org.kde.PlasmaShell.evaluateScript 'string:
    var allDesktops = desktops();
    print (allDesktops);
    for (i=0;i<allDesktops.length;i++) {
        d = allDesktops[i];
        d.wallpaperPlugin = "org.kde.image";
        d.currentConfigGroup = Array("Wallpaper", "org.kde.image", "General");
        d.writeConfig("Image", "file:///'${filename}'")
}'
