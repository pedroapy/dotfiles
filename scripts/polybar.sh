#!/usr/bin/env bash

# Main build dependencies #
###########################

sudo dnf install -y cmake @development-tools gcc-c++
sudo dnf install -y cairo-devel xcb-proto xcb-util-devel xcb-util-wm-devel xcb-util-image-devel

# Optional module dependencies #
################################

# i3
sudo dnf -y install i3-ipc jsoncpp-devel

# Volume
sudo dnf -y install alsa-lib-devel pulseaudio-libs-devel

# Network
sudo dnf -y install wireless-tools-devel

# MPD
sudo dnf -y install libmpdclient-devel

# Github
sudo dnf -y install libcurl-devel

sudo dnf -y install xcb-util-cursor xcb-util-cursor-devel xcb-util-xrm

# install polybar
#############################
sudo dnf -y install polybar

mkdir -p ~/.polybar/plugins
git clone https://github.com/meelkor/polybar-i3-windows.git ~/.polybar/plugins/polybar-i3-windows

git clone https://github.com/firecat53/networkmanager-dmenu.git /tmp/networkmanager_dmenu
cp /tmp/networkmanager_dmenu/networkmanager_dmenu $HOME/bin

git clone https://github.com/stark/siji /tmp/siji
cd /tmp/siji
./install.sh -d ~/.fonts
cd -

ln -sv $HOME/dotfiles/config/polybar $HOME/.config/polybar
git clone https://github.com/polybar/polybar-scripts.git ~/polybar-scripts
chmod u+x ~/polybar-scripts/**/*.sh