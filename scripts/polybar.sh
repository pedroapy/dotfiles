#!/usr/bin/env bash

# install polybar
#############################
yay -S --noconfirm polybar polybar-spotify-module pulseaudio-control wedder weather-bar i3-agenda

mkdir -p ~/.polybar/plugins
git clone https://github.com/meelkor/polybar-i3-windows.git ~/.polybar/plugins/polybar-i3-windows

git clone https://github.com/firecat53/networkmanager-dmenu.git /tmp/networkmanager_dmenu
cp /tmp/networkmanager_dmenu/networkmanager_dmenu $HOME/bin

git clone https://github.com/stark/siji /tmp/siji
cd /tmp/siji
./install.sh -d ~/.fonts
cd -

ln -sv $HOME/dotfiles/config/polybar $HOME/.config/polybar
git clone https://github.com/polybar/polybar-scripts.git ~/polybar-scripts
chmod u+x ~/polybar-scripts/**/*.sh
