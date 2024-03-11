#!/bin/bash

yay -S --noconfirm systemd-boot-pacman-hook systemd-ui

# enable bluetooth service and start it
sudo systemctl --now enable bluetooth.service

# enable pipewire service and start it
sudo systemctl --user --now enable pipewire pipewire-pulse

# enable networkmanager service and start it
sudo systemctl --now enable NetworkManager.service

# spotify listener and start it
sudo systemctl --user --now enable spotify-listener.service

# enable docker service and start it
sudo systemctl --now enable docker

# enable and start timesyncd
sudo systemctl --now enable systemd-timesyncd.service

sudo /usr/bin/fix-bt-a2dp set-user $USER
