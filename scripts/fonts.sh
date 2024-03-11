#!/bin/bash

# basic fonts
yay -S --noconfirm powerline-fonts ttf-fira-code ttf-jetbrains-mono fontforge

# google fonts
yay -S --noconfirm ttf-lato ttf-roboto ttf-roboto-mono ttf-roboto-slab

# microsoft fonts
yay -S --noconfirm ttf-ms-fonts ttf-ms-win10-auto ttf-ms-win11-auto

# mac fonts
yay -S --noconfirm ttf-mac-fonts

# nerd fonts
yay -S --noconfirm nerd-fonts-git

# other fonts
yay -S --noconfirm siji-git otf-font-awesome noto-fonts noto-fonts-extra

# emoji fonts
yay -S --noconfirm noto-fonts-emoji ttf-twemoji-color ttf-all-the-icons

# ttf fonts
yay -S --noconfirm ttf-opensans ttf-dejavu ttf-liberation ttf-droid ttf-ubuntu-font-family ttf-croscore ttf-dejavu ttf-droid ttf-fira-mono ttf-fira-sans ttf-font-awesome ttf-hack ttf-inconsolata ttf-opensans ttf-mac-fonts

# regenerate font cache
fc-cache --force
fc-cache-32 --force
