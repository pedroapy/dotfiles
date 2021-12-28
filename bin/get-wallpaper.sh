#!/bin/sh

# Location img with date
filedate=`date +'%Y%m%d'`
# build filename
filename="${filedate}.jpg"

# get file from https://source.unsplash.com/5120x1440/?nature,water,night,sky,mountain,landscape,clouds,sunset,sunrise,sun,moon,stars,day,snow,backgrounds
wget -q "https://source.unsplash.com/5120x1440/?wallpapers" -O ~/BingWallpaper/$filename
feh --bg-scale --no-xinerama  ~/BingWallpaper/$filename