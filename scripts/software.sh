#!/bin/bash

# Update
yay -Syu --noconfirm

# Install basic software
yay -S --noconfirm python python-pip openssh wget

# Install system software
yay -S --noconfirm terminator gnome-tweaks jq pavucontrol network-manager-applet ytop

# Install thunar
sudo pacman -S thunar thunar-archive-plugin thunar-media-tags-plugin thunar-volman tumbler freetype2 ffmpegthumbnailer gvfs unzip gwenview

# Install other software
yay -S --noconfirm vlc google-chrome flameshot albert pdfmod github-cli evince

# Install libreoffice
yay -S libreoffice-fresh libreoffice-fresh-es  hunspell  hunspell-es_es  hunspell-es_any mythes-es hyphen hypen-es languagetool libreoffice-extension-languagetool languagetool-ngrams-es

# Install spotify
yay -S --noconfirm spotify
