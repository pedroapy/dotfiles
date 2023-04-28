#!/bin/bash

# Install Xorg
sudo pacman -S --noconfirm xorg-server xorg xorg-apps xorg-xinit

ln -sv $HOME/dotfiles/config/.xinitrc $HOME/.xinitrc
ln -sv $HOME/dotfiles/config/.xserverrc $HOME/.xserverrc

# Install other xorg software
yay -S --noconfirm xorg-xdpyinfo xautolock xorg-xbacklight xxkb xclip xsettingsd lxappearance xkb-switch