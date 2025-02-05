brew install zplug

ZSH_CUSTOM=$HOME/zsh-custom
mkdir $ZSH_CUSTOM/config

rm $HOME/.zshrc
ln -sv $HOME/dotfiles/run/.zsh_profile $HOME/.zshrc
