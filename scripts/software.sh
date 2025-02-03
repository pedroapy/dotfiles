#!/bin/bash

# Update
yay -Syu --noconfirm

# Install basic drivers
yay -Syu --noconfirm alsa-card-profiles alsa-plugins v4l2loopback-dc-dkms v4l2loopback-dkms v4l2loopback-utils

# Install basic system software
yay -S --noconfirm python python-pip python-pipx openssh wget jq unzip freetype2 bat perl python-netifaces python-psutil mlocate inotify-tools reflector terminator pacutils pdfmod baph pacman-contrib

# Install network desktop software
yay -S --noconfirm network-manager-applet nm-connection-editor networkmanager-openvpn networkmanager-vpnc traceroute

# Install bluetooth
yay -S --noconfirm bluez bluez-utils bluez-plugins bluez-firmware pipewire-enable-bluez5 fix-bt-a2dp blueman bluez-firmware

# Install pipewire
yay -S --noconfirm pipewire pipewire-pulse pipewire-audio wireplumber gst-plugin-pipewire pipewire-audio

# Install graphical tools
yay -S --noconfirm gnome-tweaks pavucontrol pdfmod peek findutils emote gnome-keyring gnome-screenshot gnome-themes-extra gnome-sound-recorder krita ksnip kooha

# Install thunar
yay -S --noconfirm nemo nemo-fileroller nemo-share nemo-preview nemo-seahorse nemo-compare imv

# Install software
yay -S --noconfirm vlc google-chrome github-cli evince firefox obs-studio gimp firefox-developer-edition firefox-developer-edition-i18n-en-us firefox-developer-edition-i18n-es-es zoom

# Install libreoffice
yay -S --noconfirm libreoffice-fresh libreoffice-fresh-es hunspell hunspell-es_es hunspell-es_any mythes-es hyphen hypen-es languagetool libreoffice-extension-languagetool languagetool-ngrams-es

# Install spotify
yay -S --noconfirm spotify

# Install 1passsword
yay -S --noconfirm 1password 1password-cli

# Install basic tools
yay -S --noconfirm tree usbutils