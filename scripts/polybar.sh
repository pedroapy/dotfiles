#!/usr/bin/env bash

# install polybar
#############################
yay -S --noconfirm polybar polybar-spotify-module pulseaudio-control wedder i3-agenda ttf-all-the-icons

mkdir -p ~/.polybar/plugins
git clone https://github.com/meelkor/polybar-i3-windows.git $HOME/.polybar/plugins/polybar-i3-windows


git clone https://github.com/firecat53/networkmanager-dmenu.git /tmp/networkmanager_dmenu
cp /tmp/networkmanager_dmenu/networkmanager_dmenu $HOME/bin

git clone https://github.com/stark/siji /tmp/siji
cd /tmp/siji
./install.sh -d ~/.fonts
cd -

ln -sv $HOME/dotfiles/config/polybar $HOME/.config/polybar
git clone https://github.com/polybar/polybar-scripts.git $HOME/polybar-scripts
chmod u+x $HOME/polybar-scripts/**/*.sh

ln -sv $HOME/dotfiles/config/wedder $HOME/.config/wedder


systemctl --user enable spotify-listener
systemctl --user start spotify-listener
