rm $HOME/.zshrc
ln -sv $HOME/dotfiles/run/.zsh_profile $HOME/.zshrc

# Root user
sudo rm /root/.zshrc
sudo ln -sv $HOME/dotfiles/run/.root_zshrc_profile /root/.zshrc

ZSH_CUSTOM_ROOT=/root/.zsh_custom
ZSH_CUSTOM=$HOME/.zsh_custom

mkdir -p $ZSH_CUSTOM/{themes,plugins}
sudo mkdir -p $ZSH_CUSTOM_ROOT/{themes,plugins}
touch $ZSH_CUSTOM/config

# Theme
git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt"
ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"

# Autocomplete
git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions
sudo ln -sv $ZSH_CUSTOM/plugins/zsh-autosuggestions $ZSH_CUSTOM_ROOT/plugins/zsh-autosuggestions

# Kubernetes context
git clone https://github.com/superbrothers/zsh-kubectl-prompt.git $ZSH_CUSTOM/plugins/zsh-kubectl-prompt
sudo ln -sv $ZSH_CUSTOM/plugins/zsh-kubectl-prompt $ZSH_CUSTOM_ROOT/plugins/zsh-kubectl-prompt

# wakatime
pip install wakatime
git clone https://github.com/wbingli/zsh-wakatime.git "$ZSH_CUSTOM/plugins/zsh-wakatime"
sudo ln -sv $ZSH_CUSTOM/plugins/zsh-wakatime $ZSH_CUSTOM_ROOT/plugins/zsh-wakatime

# Add to $ZSH_CUSTOM/config DESKTOP_SESSION with i3 or sway based on input
echo "DESKTOP_SESSION=$1" >>$ZSH_CUSTOM/config
