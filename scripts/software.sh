#!/bin/bash

# Update
yay -Syu --noconfirm

# Install basic system software
yay -S --noconfirm python python-pip openssh wget jq unzip freetype2 bat perl python-netifaces python-psutil mlocate inotify-tools reflector

# Install network desktop software
yay -S --noconfirm network-manager-applet nm-connection-editor networkmanager-openvpn networkmanager-vpnc

# Install bluetooth
yay -S --noconfirm bluez bluez-utils bluez-plugins bluez-firmware pipewire-enable-bluez5 fix-bt-a2dp

# Install pipewire
yay -S --noconfirm pipewire pipewire-pulse pipewire-audio wireplumber

# Install graphical tools
yay -S --noconfirm gnome-tweaks pavucontrol flameshot pdfmod peek findutils emote gnome-keyring

# Install thunar
yay -S --noconfirm nemo nemo-fileroller nemo-share nemo-preview nemo-seahorse nemo-compare imv

# Install software
yay -S --noconfirm vlc google-chrome github-cli evince firefox obs-studio gimp

# Install libreoffice
yay -S --noconfirm libreoffice-fresh libreoffice-fresh-es hunspell hunspell-es_es hunspell-es_any mythes-es hyphen hypen-es languagetool libreoffice-extension-languagetool languagetool-ngrams-es

# Install spotify
yay -S --noconfirm spotify
