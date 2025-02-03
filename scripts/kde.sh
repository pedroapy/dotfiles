#!/usr/bin/env bash

#############################
yay -S --noconfirm python-docker python-i3ipc

yay -S --noconfirm plama-meta kde-applications-meta

# Install themes
yay -S --noconfirm tela-icon-theme graphite-gtk-theme catppuccin-gtk-theme-macchiato nordic-polar-theme nordic-theme

ln -sv $HOME/dotfiles/config/autostart $HOME/.config/autostart
