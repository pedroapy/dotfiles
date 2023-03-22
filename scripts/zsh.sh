touch $HOME/.custom_alias
mkdir -p $HOME/workspace
rm $HOME/.zshrc
ln -sv $HOME/dotfiles/run/.zsh_profile $HOME/.zshrc

ZSH_CUSTOM=$HOME/.zsh_custom
mkdir -p $ZSH_CUSTOM/{themes,plugins}

# zgenom
git clone https://github.com/jandamm/zgenom.git "${HOME}/.zgenom"

# Autocomplete
git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions

# wakatime
pip install wakatime
git clone https://github.com/wbingli/zsh-wakatime.git "$ZSH_CUSTOM/plugins/zsh-wakatime"
