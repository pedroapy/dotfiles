#!/bin/bash

touch $HOME/.custom_scripts
chmod u+x $HOME/.custom_scripts
sudo dnf copr enable -y yaroslav/i3desktop
sudo dnf copr enable -y saleone/suckless
sudo dnf -y update
sudo dnf install -y i3-gaps dmenu perl-open mozilla-fira-mono-fonts rofi rofi-themes feh maim arandr i3status dmenu dwm slock st ImageMagick xdpyinfo i3lock --allowerasing xautolock xbacklight python3-tkinter python-netifaces python-psutil xkb-switch dunst maim xclip numlockx scrot

ln -sv $HOME/dotfiles/config/i3 $HOME/.config/i3
ln -sv $HOME/dotfiles/config/dunst $HOME/.config/dunst

sudo dnf install -y "https://github.com/rpmsphere/noarch/raw/master/r/rpmsphere-release-32-1.noarch.rpm"
sudo dnf install -y gsimplecal

git clone https://github.com/jeffmhubbard/multilockscreen ~/.multilockscreen
cd ~/.multilockscreen
sudo install -Dm 755 multilockscreen /usr/bin/multilockscreen
cd -
rm -rf ~/.multilockscreen

sudo pip install --user datetime
sudo pip install --user xkbgroup
sudo pip install --user docker
pip install --user i3ipc
