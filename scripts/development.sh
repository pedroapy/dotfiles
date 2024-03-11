#!/bin/bash

# Install develoment
yay -S --noconfirm visual-studio-code-bin kubectx fzf meld docker docker-compose jdk-openjdk cmake dbeaver docker-buildx neovim nmap robo3t-bin

# Configure Docker
sudo usermod -aG docker $USER


curl -L https://git.io/n-install | bash -s -- -y
source ~/.zshrc

npm i -g yarn serve yalc vtop cloc
