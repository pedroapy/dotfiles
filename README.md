# Dotfiles

Personal dotfiles. Branch `macos` (this one) is for macOS; branch `archlinux` is the Arch Linux setup.

## Install (macOS)

```bash
git clone git@github.com:pedroapy/dotfiles.git ~/dotfiles
cd ~/dotfiles && git checkout macos
./setup.sh               # Homebrew, Brewfile, oh-my-zsh, symlinks, VS Code, git hooks
./scripts/macos.sh       # optional: macOS defaults
```

## Local, untracked files

This repo is public, so machine-specific or private settings live outside it:

| File | Holds |
| --- | --- |
| `~/.gitconfig_local` | git `user.name` / `user.email` (setup.sh asks for them) |
| `~/.zshrc.local` | machine-specific shell config, PATH lines added by installers |
| `~/.npmrc` | copied from `config/npmrc`; `npmrc_update` writes the registry token here |
| `~/.claude/settings.json` | real file; `scripts/merge-claude-settings.sh` merges `config/claude-settings.json` into it, permissions and tool hooks stay local |

A `gitleaks` pre-commit hook (`.githooks/`) blocks commits that contain secrets.
