#!/bin/bash
set -e

DOTFILES="$HOME/dotfiles"

# Helpers
link() { [ "$(readlink "$2" 2>/dev/null)" = "$1" ] || ln -svf "$1" "$2"; }
has() { command -v "$1" &>/dev/null; }

echo "=== dotfiles setup ==="

# 1. Homebrew
if ! has brew; then
    echo "[+] Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "[ok] Homebrew"
fi

# 2. Brew packages (Brewfile)
echo "[*] Checking brew packages..."
brew bundle --file="$DOTFILES/Brewfile" --no-upgrade

# 3. Oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "[+] Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "[ok] oh-my-zsh"
fi

# 4. Zsh as default shell
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "[+] Setting zsh as default shell..."
    chsh -s "$(which zsh)"
else
    echo "[ok] zsh is default shell"
fi

# 5. Zsh config
mkdir -p "$HOME/zsh-custom/config"
link "$DOTFILES/run/.zsh_profile" "$HOME/.zshrc"

# 6. Git config
link "$DOTFILES/git/.gitconfig_base" "$HOME/.gitconfig_base"
link "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"
link "$DOTFILES/git/.gitignore_global" "$HOME/.gitignore_global"

# 7. Starship config
mkdir -p "$HOME/.config"
link "$DOTFILES/config/starship.toml" "$HOME/.config/starship.toml"

# 8. iTerm2 config
defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$DOTFILES/config/iterm2"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile_selection -int 2
echo "[ok] iTerm2 prefs"

# 8b. Ghostty config
mkdir -p "$HOME/.config/ghostty"
link "$DOTFILES/config/ghostty/config" "$HOME/.config/ghostty/config"

# 9. Claude Code config
mkdir -p "$HOME/.claude"
link "$DOTFILES/config/claude-settings.json" "$HOME/.claude/settings.json"

# 10. VS Code config
VSCODE_USER="$HOME/Library/Application Support/Code/User"
if [ -d "$VSCODE_USER" ]; then
    link "$DOTFILES/config/vscode/settings.json" "$VSCODE_USER/settings.json"
    link "$DOTFILES/config/vscode/keybindings.json" "$VSCODE_USER/keybindings.json"
    echo "[ok] VS Code settings"
fi
# Install VS Code extensions
if has code; then
    echo "[*] Checking VS Code extensions..."
    installed=$(code --list-extensions)
    while IFS= read -r ext; do
        echo "$installed" | grep -qi "^${ext}$" || code --install-extension "$ext" --force
    done < "$DOTFILES/config/vscode/extensions.txt"
fi

# 11. SSH config
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
link "$DOTFILES/config/ssh/config" "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config" 2>/dev/null

# 12. npmrc (without tokens)
link "$DOTFILES/config/npmrc" "$HOME/.npmrc"

# 13. Rectangle config
if [ -f "$DOTFILES/config/rectangle/com.knollsoft.Rectangle.plist" ]; then
    defaults import com.knollsoft.Rectangle "$DOTFILES/config/rectangle/com.knollsoft.Rectangle.plist"
    echo "[ok] Rectangle prefs"
fi

# 14. Editorconfig
link "$DOTFILES/config/editorconfig" "$HOME/.editorconfig"

# 15. ripgrep config
link "$DOTFILES/config/ripgreprc" "$HOME/.config/ripgreprc"

# 16. bat config
mkdir -p "$HOME/.config/bat"
link "$DOTFILES/config/bat/config" "$HOME/.config/bat/config"

# 17. fd ignore
link "$DOTFILES/config/fdignore" "$HOME/.fdignore"

# 18. lazygit config
mkdir -p "$HOME/.config/lazygit"
link "$DOTFILES/config/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"

# 19. Custom scripts
mkdir -p "$HOME/bin"
link "$DOTFILES/bin/git-hist" "$HOME/bin/git-hist"

# 20. Workspace
mkdir -p "$HOME/workspace"

# 21. Node setup (corepack)
if has corepack; then
    corepack enable 2>/dev/null && echo "[ok] corepack"
fi

# 22. Global npm packages
if has npm; then
    echo "[*] Checking global npm packages..."
    for pkg in serve yalc cloc; do
        npm ls -g "$pkg" &>/dev/null || npm i -g "$pkg"
    done
fi

echo ""
echo "=== Done! ==="
echo "Run './scripts/macos.sh' to apply macOS preferences (optional)"
echo "Restart your terminal to apply all changes."
