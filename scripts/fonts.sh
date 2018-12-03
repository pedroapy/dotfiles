git clone https://github.com/ryanoasis/nerd-fonts.git ~/.nerd-fonts
cd ~/.nerd-fonts
./install.sh
cd -
rm -rf ~/.nerd-fonts

git clone https://github.com/stark/siji /tmp/siji
cd /tmp/siji
./install.sh -d ~/.fonts
cd -