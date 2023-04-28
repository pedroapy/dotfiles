#!/bin/bash

# Update
yay -Syu --noconfirm

# Install basic system software
yay -S --noconfirm python python-pip openssh wget jq unzip freetype2 bat perl python-netifaces python-psutil mlocate

# Install network desktop software
yay -S --noconfirm network-manager-applet nm-connection-editor networkmanager-openvpn networkmanager-vpnc

# Install bluetooth
sudo pacman -S --noconfirm bluez bluez-utils bluez-plugins bluez-firmware pipewire-enable-bluez5 fix-bt-a2dp

# Install pipewire
sudo pacman -S --noconfirm pipewire pipewire-pulse pipewire-audio wireplumber

# Install graphical tools
yay -S --noconfirm feh maim arandr imagemagick scrot terminator gnome-tweaks pavucontrol flameshot pdfmod peek findutils

# Install thunar
sudo pacman -S --noconfirm thunar thunar-archive-plugin thunar-media-tags-plugin thunar-volman tumbler ffmpegthumbnailer gvfs gwenview

# Install software
yay -S --noconfirm vlc google-chrome github-cli evince firefox obs-studio gimp

# Install libreoffice
yay -S --noconfirm libreoffice-fresh libreoffice-fresh-es hunspell hunspell-es_es hunspell-es_any mythes-es hyphen hypen-es languagetool libreoffice-extension-languagetool languagetool-ngrams-es

# Install spotify
yay -S --noconfirm spotify
