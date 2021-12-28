yay -S powerline-fonts ttf-fira-code ttf-jetbrains-mono ttf-hack ttf-google-fonts-git ttf-droid ttf-dejavu ttf-roboto noto-fonts ttf-ms-win10 ttf-ms-fonts ttf-vista-fonts noto-fonts-emoji ttf-computer-modern-fonts ttf-mac-fonts

git clone https://github.com/ryanoasis/nerd-fonts.git ~/.nerd-fonts
cd ~/.nerd-fonts
./install.sh
cd -
rm -rf ~/.nerd-fonts

git clone https://github.com/stark/siji /tmp/siji
cd /tmp/siji
./install.sh -d ~/.fonts
cd -