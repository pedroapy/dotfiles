#!/bin/bash

yay -S --noconfirm python-docker python-i3ipc

# Install sway
yay -S --noconfirm sway swayidle swaybg xorg-wayland swaylock-effects xdg-desktop-portal-wlr xdg-desktop-portal xorg-xwayland
# Install wayland tools
yay -S --noconfirm slock dunst azote gnome-keyring clipman alacritty slurp wtype wofi bemenu grim wlogout bemoji-git rofi drun gconf maim wlsunset libadwaita polkit-gnome-gtk2 qt6-wayland wob swappy
# Install themes
yay -S --noconfirm tela-icon-theme graphite-gtk-theme catppuccin-gtk-theme-macchiato nordic-polar-theme nordic-theme
# Install nwg-shell parts
yay -S --noconfirm nwg-look nwg-displays swaync nwg-shell-config nwg-panel gtklock autotiling

# Create /opt if not exists
sudo mkdir -p /opt

# Link config files
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
ln -sv $HOME/dotfiles/config/swaync $HOME/.config/swaync
ln -sv $HOME/dotfiles/config/nwg-bar $HOME/.config/nwg-bar
ln -sv $HOME/dotfiles/config/nwg-panel/pedro-config $HOME/.config/nwg-panel/pedro-config
ln -sv $HOME/dotfiles/config/nwg-panel/pedro-config.css $HOME/.config/nwg-panel/pedro-config.css

# Link icons
sudo ln -sv $HOME/dotfiles/config/icons /opt/user/icons
