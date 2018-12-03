#!/bin/bash

# Add vscode repository
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo /bin/sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

# Install n for npm
curl -L https://git.io/n-install | bash -s -- -y

npm i -g yarn
npm i -g serve
