#!/bin/bash

# Install sway
yay -S --noconfirm sway swayidle swaybg xorg-wayland swaylock-effects xdg-desktop-portal-wlr xdg-desktop-portal tela-icon-theme graphite-gtk-theme catppuccin-gtk-theme-macchiato
# Install sway tools
yay -S --noconfirm slock dunst azote gnome-keyring clipman alacritty slurp wtype wofi bemenu nwg-look grim wlogout bemoji-git

python -m pip install -U prettytable

ln -sv $HOME/dotfiles/config/sway $HOME/.config/sway
ln -sv $HOME/dotfiles/config/dunst $HOME/.config/dunst
ln -sv $HOME/dotfiles/config/rofi $HOME/.config/rofi
ln -sv $HOME/dotfiles/config/gtkrc-2.0 $HOME/.gtkrc-2.0
ln -sv $HOME/dotfiles/config/gtk-2.0 $HOME/.config/gtk-2.0
ln -sv $HOME/dotfiles/config/gtk-3.0 $HOME/.config/gtk-3.0
ln -sv $HOME/dotfiles/config/gtk-4.0 $HOME/.config/gtk-4.0
ln -sv $HOME/dotfiles/config/environment.d $HOME/.config/environment.d
ln -sv $HOME/dotfiles/config/alacritty $HOME/.config/alacritty
ln -sv $HOME/dotfiles/config/wlogout $HOME/.config/wlogout
