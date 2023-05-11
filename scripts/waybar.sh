#!/usr/bin/env bash

# install waybar
#############################
yay -S --noconfirm waybar

ln -sv $HOME/dotfiles/config/waybar $HOME/.config/waybar
