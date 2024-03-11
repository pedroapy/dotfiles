#!/usr/bin/env bash

# install waybar
#############################
yay -S --noconfirm waybar gcalcli gsimplecal gopsuinfo

ln -sv $HOME/dotfiles/config/waybar $HOME/.config/waybar
