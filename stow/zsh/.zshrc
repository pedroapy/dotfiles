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

# ── Completion definitions (load before compinit) ──
zinit ice blockf
zinit light zsh-users/zsh-completions

# ── Oh-my-zsh snippets (compdefs replayed after compinit) ──
zinit snippet OMZP::git
zinit snippet OMZP::docker
zinit snippet OMZP::docker-compose
zinit snippet OMZP::kubectl
zinit snippet OMZP::sudo
zinit snippet OMZP::npm

# ── Completion system ───────────────────────────
autoload -Uz compinit && compinit
zinit cdreplay -q

# Case-insensitive + flexible Tab completion (matches case variations,
# partial words on . _ - boundaries, and substrings)
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# Grouped, colorized completions. menu=no is REQUIRED by fzf-tab, which
# captures the completion list instead of zsh's built-in menu.
zstyle ':completion:*' menu no
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{yellow}%B-- %d --%b%f'
zstyle ':completion:*:warnings' format '%F{red}-- no matches --%f'

# Cache completions for speed
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"

# ── fzf-tab: fuzzy Tab menu ─────────────────────
# Must load AFTER compinit but BEFORE the widget-wrapping plugins below.
zinit light Aloxaf/fzf-tab
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --level=1 --icons --color=always $realpath'
zstyle ':fzf-tab:complete:*:*' fzf-preview \
  '[[ -d $realpath ]] && eza --tree --level=1 --icons --color=always $realpath || bat --color=always --style=numbers --line-range=:200 $realpath 2>/dev/null'

# ── Widget-wrapping plugins (load AFTER fzf-tab) ──
# fast-syntax-highlighting before history-substring-search; the latter
# integrates with the highlighter and must be loaded last.
zinit light-mode for \
  zsh-users/zsh-autosuggestions \
  djui/alias-tips \
  zdharma-continuum/fast-syntax-highlighting \
  zsh-users/zsh-history-substring-search

# ── Keybindings (emacs-style line editing) ──────
# Force emacs mode. Otherwise zsh auto-selects vi-mode because $EDITOR is
# "nvim" (contains "vi") — that's what made Ctrl+Left flip into a modal/
# overwrite state instead of moving by word.
bindkey -e

# Word motions (Ctrl/Alt+arrows) stop at / and . too, not just whitespace
WORDCHARS=${WORDCHARS//[\/.]}

# History substring search: type a prefix, then Up/Down
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Move by word — Ctrl/Alt + Left/Right
bindkey '^[[1;5D' backward-word    # Ctrl+Left
bindkey '^[[1;5C' forward-word     # Ctrl+Right
bindkey '^[[1;3D' backward-word    # Alt+Left
bindkey '^[[1;3C' forward-word     # Alt+Right

# Jump to line start/end — Home / End (two terminal encodings each)
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[OH' beginning-of-line
bindkey '^[OF' end-of-line

# Deletion
bindkey '^[[3~'   delete-char          # Delete
bindkey '^[[3;5~' kill-word            # Ctrl+Delete
bindkey '^H'      backward-kill-word   # Ctrl+Backspace
bindkey '^[^?'    backward-kill-word   # Alt+Backspace

# Shift+Tab cycles the completion menu backwards
bindkey '^[[Z' reverse-menu-complete

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

# fzf sources after fzf-tab and rebinds Tab to its own widget. Make plain
# Tab fall through to fzf-tab, while keeping fzf's `**<Tab>` trigger.
fzf_default_completion=fzf-tab-complete

# ── direnv ──────────────────────────────────────
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# ── atuin (better shell history, Ctrl+R) ───────
if command -v atuin &>/dev/null; then
    eval "$(atuin init zsh --disable-up-arrow)"
fi
