#!/bin/bash

touch $HOME/.custom_scripts
chmod u+x $HOME/.custom_scripts

# Install Xorg
sudo pacman -S --noconfirm xorg-server xorg xorg-apps xorg-xinit
ln -sv $HOME/dotfiles/config/.xinitrc $HOME/.xinitrc
ln -sv $HOME/dotfiles/config/.xserverrc $HOME/.xserverrc

sudo pacman -S --noconfirm i3-gaps dmenu perl rofi feh maim arandr i3status slock imagemagick xorg-xdpyinfo i3lock xautolock xorg-xbacklight python-netifaces python-psutil xxkb dunst xclip scrot gsimplecal bluez-utils
pacman -S --noconfirm nm-connection-editor networkmanager-openvpn networkmanager-vpnc picom xsettingsd lxappearance

yay -S --noconfirm xkb-switch nordic-polar-theme volantes-cursors papirus-icon-theme

ln -sv $HOME/dotfiles/config/i3 $HOME/.config/i3
ln -sv $HOME/dotfiles/config/dunst $HOME/.config/dunst
ln -sv $HOME/dotfiles/config/rofi $HOME/.config/rofi
ln -sv $HOME/dotfiles/config/picom $HOME/.config/picom
ln -sv $HOME/dotfiles/config/xsettingsd $HOME/.xsettingsd
ln -sv $HOME/dotfiles/config/gtkrc-2.0 $HOME/.gtkrc-2.0
ln -sv $HOME/dotfiles/config/gtk-3.0 $HOME/.config/gtk-3.0

git clone https://github.com/jeffmhubbard/multilockscreen ~/.multilockscreen
cd ~/.multilockscreen
sudo install -Dm 755 multilockscreen /usr/bin/multilockscreen
cd -
rm -rf ~/.multilockscreen

sudo pip install --user datetime
sudo pip install --user xkbgroup
sudo pip install --user docker
pip install --user i3ipc
