#!/bin/bash
set -e

DOTFILES="$HOME/dotfiles"

echo "=== dotfiles setup ==="

# 1. Homebrew
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# 2. Brew packages (Brewfile)
echo "Installing brew packages..."
brew bundle --file="$DOTFILES/Brewfile"

# 3. Oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# 4. Zsh as default shell
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Setting zsh as default shell..."
    chsh -s "$(which zsh)"
fi

# 5. Zsh config
ZSH_CUSTOM=$HOME/zsh-custom
mkdir -p "$ZSH_CUSTOM/config"
ln -svf "$DOTFILES/run/.zsh_profile" "$HOME/.zshrc"

# 6. Git config
ln -svf "$DOTFILES/git/.gitconfig_base" "$HOME/.gitconfig_base"
ln -svf "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"

# 7. Starship config
mkdir -p "$HOME/.config"
ln -svf "$DOTFILES/config/starship.toml" "$HOME/.config/starship.toml"

# 8. Custom scripts
mkdir -p "$HOME/bin"
ln -svf "$DOTFILES/bin/git-hist" "$HOME/bin/git-hist"

# 9. Workspace
mkdir -p "$HOME/workspace"

# 10. Node setup (corepack for yarn/pnpm)
if command -v corepack &>/dev/null; then
    echo "Enabling corepack..."
    corepack enable
fi

# 11. Global npm packages
if command -v npm &>/dev/null; then
    echo "Installing global npm packages..."
    npm i -g serve yalc cloc
fi

echo ""
echo "=== Done! ==="
echo "Run './scripts/macos.sh' to apply macOS preferences (optional)"
echo "Restart your terminal to apply all changes."
