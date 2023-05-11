#!/usr/bin/env bash

# install polybar
#############################
yay -S --noconfirm polybar polybar-spotify-module pulseaudio-control ttf-all-the-icons

sudo pip install --user datetime
sudo pip install --user xkbgroup
sudo pip install --user docker
pip install --user i3ipc

mkdir -p ~/.polybar/plugins
git clone https://github.com/meelkor/polybar-i3-windows.git $HOME/.polybar/plugins/polybar-i3-windows

git clone https://github.com/firecat53/networkmanager-dmenu.git /tmp/networkmanager_dmenu
cp /tmp/networkmanager_dmenu/networkmanager_dmenu $HOME/bin

ln -sv $HOME/dotfiles/config/polybar $HOME/.config/polybar
git clone https://github.com/polybar/polybar-scripts.git $HOME/polybar-scripts
chmod u+x $HOME/polybar-scripts/**/*.sh
