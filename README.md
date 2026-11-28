# Dotfiles

Personal dotfiles. Branch `macos` (this one) is for macOS; branch `archlinux` is the Arch Linux setup.

## Install (macOS)

```bash
git clone git@github.com:pedroapy/dotfiles.git ~/dotfiles
cd ~/dotfiles && git checkout macos
./setup.sh               # Homebrew, Brewfile, oh-my-zsh, symlinks, VS Code, git hooks
./scripts/macos.sh       # optional: macOS defaults
./scripts/doctor.sh      # read-only check: symlinks, Brewfile, shell, git, Claude settings and links
```

Unattended install (CI uses this): `DOTFILES_NONINTERACTIVE=1` skips prompts and `chsh`, `DOTFILES_GIT_NAME` / `DOTFILES_GIT_EMAIL` fill `~/.gitconfig_local`, `DOTFILES_SKIP_CASKS=1` leaves out the GUI casks. The `dotfiles` GitHub Actions workflow runs shellcheck, the Claude tests, `setup.sh` and the doctor on a clean macOS runner on every push and PR to `macos`.

## Local, untracked files

This repo is public, so machine-specific or private settings live outside it:

| File | Holds |
| --- | --- |
| `~/.gitconfig_local` | git `user.name` / `user.email` (setup.sh asks for them) |
| `~/.zshrc.local` | machine-specific shell config, PATH lines added by installers |
| `~/.npmrc` | npm registries and tokens (work registries stay here, not in the repo) |
| `~/.claude/settings.json` | real file; `scripts/merge-claude-settings.sh` merges `config/claude-settings.json` (shared settings and the guard hook) into it and removes nothing but older copies of the guard hook, so permissions, `env` and the machine's own hooks stay local |

A `gitleaks` pre-commit hook (`.githooks/`) blocks commits that contain secrets.

## Claude Code (`claude/`)

The generic Claude Code material shared by every machine:

| Path | Holds |
| --- | --- |
| `claude/CLAUDE.md` | instructions for every machine (code navigation, model routing, review rounds, sessions, replies) |
| `claude/agents/` | subagents: `implementer`, `personal-reviewer`, `worker`, `scribe`, `scout` |
| `claude/skills/` | the handoff skills `/pausa`, `/pendientes` and `/retoma` |
| `claude/scripts/handoff.sh` | the script behind those skills; handoffs themselves stay in `~/.claude/handoffs` |
| `claude/hooks/` | the guard hook for Bash and the desktop app's auto-merge tool, wired from `config/claude-settings.json` at `~/dotfiles/claude/hooks/` |

`scripts/link-claude.sh`, run by `setup.sh`, links each agent, skill and script into `~/.claude` at the same relative path. It moves what it replaces (a real file or directory, or a broken link) to `~/.dotfiles-backups/claude-<time>/`, outside `~/.claude`, whose `backups/` folder Claude Code rotates, and leaves alone a working link that points somewhere else or a group directory (`~/.claude/agents`, `skills`, `scripts`) that is itself a symlink, so another config repo can own those names. `--check` changes nothing; `doctor.sh` runs it.

Each machine's `~/.claude/CLAUDE.md` is a local file that starts with `@~/dotfiles/claude/CLAUDE.md` and adds that machine's own rules below. `link-claude.sh` creates it with that line when it is missing and only warns when an existing one lacks the import. Review checks that belong to one machine go in `~/.claude/agent-extras/personal-reviewer.md`, which the `personal-reviewer` agent reads when it exists.

The guard hook denies any push to main and asks before merging a PR unless `CLAUDE_GUARD_ALLOW_MERGE=1` is set. A machine that may merge on its own sets that variable in the `env` of its own `~/.claude/settings.json`, never in `config/claude-settings.json`, which every machine shares. The settings run the hook from `~/dotfiles`, whatever `DOTFILES` says; if the file is missing there or the hook exits with anything but 0, the wrapper in the settings asks before each guarded call instead of blocking or allowing it.

Tests: `bash claude/hooks/tests/guard-main-and-merge-test.sh`, `bash scripts/tests/link-claude-test.sh` and `bash scripts/tests/merge-claude-settings-test.sh`.
