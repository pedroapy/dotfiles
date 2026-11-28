# Dotfiles

Personal dotfiles. Branch `macos` (this one) is for macOS; branch `archlinux` is the Arch Linux setup.

## Install (macOS)

```bash
git clone git@github.com:pedroapy/dotfiles.git ~/dotfiles
cd ~/dotfiles && git checkout macos
./setup.sh               # Homebrew, Brewfile, oh-my-zsh, symlinks, VS Code, git hooks
./scripts/macos.sh       # optional: macOS defaults
./scripts/doctor.sh      # read-only check: symlinks, Brewfile, shell, git, Claude settings
```

Unattended install (CI uses this): `DOTFILES_NONINTERACTIVE=1` skips prompts and `chsh`, `DOTFILES_GIT_NAME` / `DOTFILES_GIT_EMAIL` fill `~/.gitconfig_local`, `DOTFILES_SKIP_CASKS=1` leaves out the GUI casks. The `dotfiles` GitHub Actions workflow runs shellcheck, `setup.sh` and the doctor on a clean macOS runner on every push and PR to `macos`.

## Local, untracked files

This repo is public, so machine-specific or private settings live outside it:

| File | Holds |
| --- | --- |
| `~/.gitconfig_local` | git `user.name` / `user.email` (setup.sh asks for them) |
| `~/.zshrc.local` | machine-specific shell config, PATH lines added by installers |
| `~/.npmrc` | npm registries and tokens (work registries stay here, not in the repo) |
| `~/.claude/settings.json` | real file; `scripts/merge-claude-settings.sh` merges `config/claude-settings.json` into it, permissions and tool hooks stay local |

A `gitleaks` pre-commit hook (`.githooks/`) blocks commits that contain secrets.
