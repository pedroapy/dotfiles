#!/bin/bash
# Read-only health check of what setup.sh installs. Prints OK/FAIL/SKIP per
# item and exits 1 if anything fails. Changes nothing.
#   DOTFILES_SKIP_CASKS=1  check the Brewfile without its casks (as setup.sh)

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
VSCODE_USER="$HOME/Library/Application Support/Code/User"
fails=0

ok() { printf '  OK    %s\n' "$1"; }
skip() { printf '  SKIP  %s (%s)\n' "$1" "$2"; }
# Paths are shown with ~ so pasted output does not reveal the user name
fail() {
    printf '  FAIL  %s: %s\n' "$1" "${2//$HOME/~}"
    fails=$((fails + 1))
}
has() { command -v "$1" &>/dev/null; }

echo "=== dotfiles doctor (${DOTFILES/#$HOME/~}) ==="
if [ ! -f "$DOTFILES/setup.sh" ] || [ ! -f "$DOTFILES/Brewfile" ]; then
    fail "dotfiles repo" "$DOTFILES has no setup.sh or Brewfile (set DOTFILES)"
    exit 1
fi

# Symlinks: every `link "<src>" "<dst>"` line in setup.sh, so the list never
# drifts from what setup.sh creates.
echo "[symlinks]"
while IFS= read -r line; do
    args=${line#*link \"}
    src=${args%%\" \"*}
    dst=${args#*\" \"}
    dst=${dst%\"*}
    for var in src dst; do
        val=${!var}
        val=${val//\$VSCODE_USER/$VSCODE_USER}
        val=${val//\$DOTFILES/$DOTFILES}
        val=${val//\$HOME/$HOME}
        printf -v "$var" '%s' "$val"
    done
    name=${dst/#$HOME/\~}
    if [[ $dst == "$VSCODE_USER"/* ]] && [ ! -d "$VSCODE_USER" ]; then
        skip "$name" "VS Code not installed"
    elif [ ! -L "$dst" ]; then
        fail "$name" "not a symlink"
    elif [ "$(readlink "$dst")" != "$src" ]; then
        fail "$name" "points to $(readlink "$dst"), expected $src"
    elif [ ! -e "$src" ]; then
        fail "$name" "target $src is missing"
    else
        ok "$name"
    fi
done < <(grep -E '^[[:space:]]*link "' "$DOTFILES/setup.sh")

echo "[packages]"
if ! has brew; then
    fail "Homebrew" "brew not found"
else
    ok "Homebrew"
    brewfile="$DOTFILES/Brewfile"
    label="Brewfile"
    if [ "${DOTFILES_SKIP_CASKS:-0}" = "1" ]; then
        brewfile=$(mktemp "${TMPDIR:-/tmp}/dotfiles-Brewfile.XXXXXX")
        trap 'rm -f "$brewfile"' EXIT
        grep -v '^[[:space:]]*cask ' "$DOTFILES/Brewfile" > "$brewfile"
        label="Brewfile (without casks)"
    fi
    if out=$(HOMEBREW_NO_AUTO_UPDATE=1 brew bundle check --file="$brewfile" --no-upgrade --verbose 2>&1); then
        ok "$label"
    else
        fail "$label" "$(echo "$out" | grep -v '^Satisfy' | tr '\n' ' ')"
    fi
fi

echo "[shell]"
if [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
    ok "oh-my-zsh"
else
    fail "oh-my-zsh" "$HOME/.oh-my-zsh/oh-my-zsh.sh not found"
fi
zplug_home="$(brew --prefix 2>/dev/null || echo /opt/homebrew)/opt/zplug"
if [ -f "$zplug_home/init.zsh" ]; then
    ok "zplug"
else
    fail "zplug" "$zplug_home/init.zsh not found"
fi

echo "[git]"
# Values are not printed: CI logs of this repo are public
for key in user.name user.email; do
    if [ -n "$(git config --file "$HOME/.gitconfig_local" --get "$key" 2>/dev/null)" ]; then
        ok ".gitconfig_local $key"
    else
        fail ".gitconfig_local $key" "not set"
    fi
done
hooks=$(git -C "$DOTFILES" config --get core.hooksPath)
if [ "$hooks" != ".githooks" ]; then
    fail "gitleaks pre-commit hook" "core.hooksPath is '${hooks:-unset}', expected .githooks"
elif [ ! -x "$DOTFILES/.githooks/pre-commit" ]; then
    fail "gitleaks pre-commit hook" ".githooks/pre-commit is not executable"
elif ! has gitleaks; then
    fail "gitleaks pre-commit hook" "gitleaks not installed"
else
    ok "gitleaks pre-commit hook"
fi

echo "[claude]"
if out=$("$DOTFILES/scripts/merge-claude-settings.sh" --check 2>&1); then
    ok "Claude settings in sync with config/claude-settings.json"
else
    fail "Claude settings" "$out (run scripts/merge-claude-settings.sh)"
fi
# config/claude-settings.json runs the guard hook from this fixed path
guard="$HOME/dotfiles/claude/hooks/guard-main-and-merge.py"
if [ -f "$guard" ]; then
    ok "Claude guard hook at ~/dotfiles/claude/hooks"
else
    fail "Claude guard hook" "$guard is missing; until it exists every Bash command asks for approval"
fi
# Agent, skill and script links and the CLAUDE.md import; link-claude.sh
# prints its own OK/SKIP/FAIL lines
out=$("$DOTFILES/scripts/link-claude.sh" --check 2>&1)
rc=$?
printf '%s\n' "$out"
if [ "$rc" -ne 0 ]; then
    n=$(printf '%s\n' "$out" | grep -c '^  FAIL')
    fails=$((fails + (n > 0 ? n : 1)))
fi

echo ""
if [ "$fails" -gt 0 ]; then
    echo "=== $fails check(s) failed ==="
    exit 1
fi
echo "=== All checks passed ==="
