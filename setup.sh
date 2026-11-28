#!/bin/bash
set -e

DOTFILES="${DOTFILES:-$HOME/dotfiles}"

# Non-interactive mode (CI, unattended installs): no prompts, no chsh.
#   DOTFILES_NONINTERACTIVE=1                  set automatically when CI=true
#   DOTFILES_GIT_NAME / DOTFILES_GIT_EMAIL     identity for ~/.gitconfig_local
#   DOTFILES_SKIP_CASKS=1                      skip Brewfile casks (GUI apps)
[ "${CI:-}" = "true" ] && DOTFILES_NONINTERACTIVE="${DOTFILES_NONINTERACTIVE:-1}"
NONINTERACTIVE_MODE="${DOTFILES_NONINTERACTIVE:-0}"

# Helpers
link() { [ "$(readlink "$2" 2>/dev/null)" = "$1" ] || ln -svf "$1" "$2"; }
has() { command -v "$1" &>/dev/null; }
interactive() { [ "$NONINTERACTIVE_MODE" != "1" ]; }

# Download an installer to a temp file and run it only once it is complete,
# so a dropped connection never runs half a script.
#   run_remote <shell> <url> [args...]
run_remote() {
    local shell=$1 url=$2 tmp rc=0
    shift 2
    tmp=$(mktemp "${TMPDIR:-/tmp}/dotfiles-install.XXXXXX")
    if ! curl -fsSL --retry 3 --retry-delay 2 -o "$tmp" "$url" || [ ! -s "$tmp" ]; then
        echo "[!] Download failed or empty: $url" >&2
        rm -f "$tmp"
        return 1
    fi
    "$shell" "$tmp" "$@" || rc=$?
    rm -f "$tmp"
    return "$rc"
}

# Brewfile to use: the repo one, or a copy without casks when skipping them
brewfile() {
    if [ "${DOTFILES_SKIP_CASKS:-0}" = "1" ]; then
        local tmp
        tmp=$(mktemp "${TMPDIR:-/tmp}/dotfiles-Brewfile.XXXXXX")
        grep -v '^[[:space:]]*cask ' "$DOTFILES/Brewfile" > "$tmp"
        echo "$tmp"
    else
        echo "$DOTFILES/Brewfile"
    fi
}

echo "=== dotfiles setup ==="

# 1. Homebrew
if ! has brew; then
    echo "[+] Installing Homebrew..."
    if interactive; then
        run_remote /bin/bash https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
    else
        NONINTERACTIVE=1 run_remote /bin/bash https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
    fi
    # shellcheck disable=SC2016 # written literally, expanded by zsh at login
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "[ok] Homebrew"
fi

# 2. Brew packages (Brewfile)
echo "[*] Checking brew packages..."
brew bundle --file="$(brewfile)" --no-upgrade

# 3. Oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "[+] Installing oh-my-zsh..."
    run_remote sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh --unattended
else
    echo "[ok] oh-my-zsh"
fi

# 4. Zsh as default shell
if [ "$SHELL" = "$(which zsh)" ]; then
    echo "[ok] zsh is default shell"
elif ! interactive; then
    echo "[skip] default shell (non-interactive; run: chsh -s $(which zsh))"
else
    echo "[+] Setting zsh as default shell..."
    chsh -s "$(which zsh)"
fi

# 5. Zsh config
mkdir -p "$HOME/zsh-custom"
link "$DOTFILES/run/.zsh_profile" "$HOME/.zshrc"

# 6. Git config
link "$DOTFILES/git/.gitconfig_base" "$HOME/.gitconfig_base"
link "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"
link "$DOTFILES/git/.gitignore_global" "$HOME/.gitignore_global"
# Identity stays out of the public repo, in ~/.gitconfig_local
if ! git config --file "$HOME/.gitconfig_local" user.email &>/dev/null; then
    git_name="${DOTFILES_GIT_NAME:-}"
    git_email="${DOTFILES_GIT_EMAIL:-}"
    if interactive; then
        [ -n "$git_name" ] || read -rp "Git name: " git_name
        [ -n "$git_email" ] || read -rp "Git email: " git_email
    fi
    if [ -n "$git_name" ] && [ -n "$git_email" ]; then
        git config --file "$HOME/.gitconfig_local" user.name "$git_name"
        git config --file "$HOME/.gitconfig_local" user.email "$git_email"
    else
        echo "[skip] ~/.gitconfig_local (set DOTFILES_GIT_NAME and DOTFILES_GIT_EMAIL)"
    fi
fi
# Secret scan before every commit to this repo
git -C "$DOTFILES" config core.hooksPath .githooks

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
# Real local file (tools write to it); shared keys merged from the repo
"$DOTFILES/scripts/merge-claude-settings.sh"
# Agents, skills and scripts from claude/, and the ~/.claude/CLAUDE.md import
"$DOTFILES/scripts/link-claude.sh"

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
    for pkg in serve yalc cloc typescript-language-server; do
        npm ls -g "$pkg" &>/dev/null || npm i -g "$pkg"
    done
    # Claude Code's LSP tool needs tsserver.js, which typescript 7.x no longer
    # ships; npm ls with a version fails when another version is installed
    npm ls -g typescript@5.9.3 &>/dev/null || npm i -g typescript@5.9.3
fi

echo ""
echo "=== Done! ==="
echo "Run './scripts/macos.sh' to apply macOS preferences (optional)"
echo "Restart your terminal to apply all changes."
