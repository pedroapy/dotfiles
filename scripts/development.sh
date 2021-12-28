#!/bin/bash

# Install develoment
sudo pacman -S --noconfirm ghc cabal-install stack meld make cmake gcc docker docker-compose jre-openjdk jdk-openjdk gnome-keyring
yay -S --noconfirm nvm visual-studio-code-bin kubectx fzf

# Configure Docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

nvm install --lts
nvm use --lts

npm i -g yarn serve yalc
