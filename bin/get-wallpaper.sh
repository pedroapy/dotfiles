#!/bin/sh

# get image
image=$(curl -s -X GET "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=es-ES" | jq ".images[0]")

# get metadata
urlpath=`jq -r '.url' <<< "${image}" | sed 's/1366x768/1920x1080/g'`
title=`jq -r '.title' <<< "${image}"| sed -e 's/ /_/g'`
filedate=`jq -r '.enddate' <<< "${image}"`

# build filename
filename="${filedate}_${title}"

# get file
wget "https://www.bing.com$urlpath" -O ~/BingWallpaper/$filename
feh --bg-fill ~/BingWallpaper/$filename