#!/bin/bash

touch $HOME/.custom_scripts
chmod u+x $HOME/.custom_scripts

# Install i3
yay -S --noconfirm i3-gaps i3status i3lock i3-agenda
# Install i3 tools
yay -S --noconfirm dmenu rofi slock dunst gsimplecal gnome-keyring betterlockscreen xdotool
# Install theme things
yay -S --noconfirm nordic-polar-theme volantes-cursors papirus-icon-theme

ln -sv $HOME/dotfiles/config/i3 $HOME/.config/i3
ln -sv $HOME/dotfiles/config/dunst $HOME/.config/dunst
ln -sv $HOME/dotfiles/config/rofi $HOME/.config/rofi
ln -sv $HOME/dotfiles/config/picom $HOME/.config/picom
ln -sv $HOME/dotfiles/config/xsettingsd $HOME/.xsettingsd
ln -sv $HOME/dotfiles/config/gtkrc-2.0 $HOME/.gtkrc-2.0
ln -sv $HOME/dotfiles/config/gtk-3.0 $HOME/.config/gtk-3.0
