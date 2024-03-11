rm $HOME/.zshrc
ln -sv $HOME/dotfiles/run/.zsh_profile $HOME/.zshrc

# Root user
sudo ln -sv $HOME/dotfiles/run/.root_zshrc_profile /root/.zshrc

ZSH_CUSTOM=$HOME/.zsh_custom

mkdir -p $ZSH_CUSTOM/{themes,plugins}
touch $ZSH_CUSTOM/config

# Theme
git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt"
ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"

# Autocomplete
git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions

# Kubernetes context
git clone https://github.com/superbrothers/zsh-kubectl-prompt.git $ZSH_CUSTOM/plugins/zsh-kubectl-prompt

# Autoupdate
git clone https://github.com/TamCore/autoupdate-oh-my-zsh-plugins $ZSH_CUSTOM/plugins/autoupdate

# wakatime
yay -S wakatime
pipx install wakatime
git clone https://github.com/wbingli/zsh-wakatime.git "$ZSH_CUSTOM/plugins/zsh-wakatime"
