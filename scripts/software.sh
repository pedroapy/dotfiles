#!/bin/bash

# Add chrome repository
sudo dnf install fedora-workstation-repositories
sudo dnf config-manager --set-enabled google-chrome

# Add rpm fusion repositories
sudo rpm -Uvh http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
sudo rpm -Uvh http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Add other repos
sudo dnf copr enable -y taw/joplin
sudo dnf copr enable -y atim/ytop
sudo dnf copr enable jdoss/github-cli

# Update
sudo dnf -y update

# Install fonts
sudo dnf install -y powerline-fonts fira-code-fonts jetbrains-mono-fonts-all

# Install system software
sudo dnf install -y terminator gnome-tweaks vim jq pavucontrol network-manager-applet joplin ytop

# Install other software
sudo dnf install -y vlc google-chrome-stable flameshot albert poppler-utils pdfmod pdfshuffler github-cli

# Install spotify
sudo dnf install -y lpf-spotify-client
lpf  approve spotify-client
sudo -u pkg-build lpf build spotify-client
sudo dnf install -y /var/lib/lpf/rpms/spotify-client/spotify-client-*.rpm