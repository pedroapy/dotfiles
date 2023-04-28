#!/bin/bash

# basic fonts
yay -S --noconfirm powerline-fonts ttf-fira-code ttf-jetbrains-mono

# google fonts
yay -S --noconfirm ttf-google-fonts-git

# microsoft fonts
yay -S --noconfirm ttf-ms-fonts ttf-ms-win10-auto ttf-ms-win11-auto

# mac fonts
yay -S --noconfirm ttf-mac-fonts

# nerd fonts
yay -S --noconfirm nerd-fonts-git

# other fonts
yay -S --noconfirm siji-git

# regenerate font cache
fc-cache --force
fc-cache-32 --force
