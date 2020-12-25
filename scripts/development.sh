#!/bin/bash

# Install develoment
sudo pacman -S --noconfirm ghc cabal-install stack meld make cmak gcc nvm docker docker-compose jre-openjdk jdk-openjdk gnome-keyring
yay -S --noconfirm visual-studio-code-bin

# Configure Docker
sudo systemctl enable docker  
sudo systemctl start docker  
sudo usermod -aG docker $USER

nvm install --lts
nvm use --lts

npm i -g yarn serve yalc
