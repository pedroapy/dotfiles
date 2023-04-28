#!/bin/bash

# Install develoment
yay -S --noconfirm visual-studio-code-bin kubectx fzf meld docker docker-compose jre-openjdk jdk-openjdk

# Configure Docker
sudo usermod -aG docker $USER


curl -L https://git.io/n-install | bash -s -- -y
source ~/.zshrc

npm i -g yarn serve yalc vtop cloc
