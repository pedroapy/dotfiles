touch $HOME/.custom_alias
mkdir -p $HOME/workspace
rm $HOME/.zshrc
ln -sv $HOME/dotfiles/run/.zsh_profile $HOME/.zshrc

ZSH_CUSTOM=$HOME/.zsh_custom
mkdir -p $ZSH_CUSTOM/{themes,plugins}

# Theme
git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt"
ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"

# Autocomplete
git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions

pip install wakatime
git clone https://github.com/wbingli/zsh-wakatime.git "$ZSH_CUSTOM/plugins/zsh-wakatime"