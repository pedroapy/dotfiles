#!/bin/bash

touch $HOME/.custom_scripts
chmod u+x $HOME/.custom_scripts
sudo pacman -S --noconfirm i3-gaps dmenu perl rofi feh maim arandr i3status slock imagemagick xorg-xdpyinfo i3lock xautolock xorg-xbacklight python-netifaces python-psutil xxkb dunst xclip numlockx scrot gsimplecal
pacman -S --noconfirm nm-connection-editor networkmanager-openvpn networkmanager-vpnc

yay -S --noconfirm xkb-switch

ln -sv $HOME/dotfiles/config/i3 $HOME/.config/i3
ln -sv $HOME/dotfiles/config/dunst $HOME/.config/dunst

git clone https://github.com/jeffmhubbard/multilockscreen ~/.multilockscreen
cd ~/.multilockscreen
sudo install -Dm 755 multilockscreen /usr/bin/multilockscreen
cd -
rm -rf ~/.multilockscreen

sudo pip install --user datetime
sudo pip install --user xkbgroup
sudo pip install --user docker
pip install --user i3ipc
