#!/usr/bin/env zsh
DOTFILES="$HOME/dotfiles-arch"

# ── Environment ─────────────────────────────────
source "$HOME/.zsh/env"

# ── History ─────────────────────────────────────
HISTSIZE=100000
SAVEHIST=100000
HISTFILE=~/.zsh_history
[[ -f "$HISTFILE" ]] && chmod 600 "$HISTFILE"
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt AUTO_CD

# ── Zinit ───────────────────────────────────────
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# ── Plugins ────────���────────────────────────────
zinit light-mode for \
  zdharma-continuum/fast-syntax-highlighting \
  zsh-users/zsh-autosuggestions \
  zsh-users/zsh-completions \
  zsh-users/zsh-history-substring-search \
  djui/alias-tips

# Bind up/down to substring search
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Oh-my-zsh snippets (lightweight, no full omz)
zinit snippet OMZP::git
zinit snippet OMZP::docker
zinit snippet OMZP::docker-compose
zinit snippet OMZP::kubectl
zinit snippet OMZP::sudo
zinit snippet OMZP::npm

# ── Completions ─────────────────────────────────
autoload -Uz compinit && compinit
zinit cdreplay -q

# ── Aliases & Functions ─────────────────────────
source "$HOME/.zsh/alias"
source "$HOME/.zsh/functions"

# ── Starship Prompt ─────────────────────────────
eval "$(starship init zsh)"

# ── Zoxide (smart cd) ──────────────────────────
eval "$(zoxide init zsh)"

# ── fzf ─────────────────────────────────────────
source <(fzf --zsh)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range :500 {}'"

# ── direnv ──────────────────────────────────────
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# ── atuin (better shell history, Ctrl+R) ───────
if command -v atuin &>/dev/null; then
    eval "$(atuin init zsh --disable-up-arrow)"
fi
