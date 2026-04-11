# Arch Linux Dotfiles

Modern Arch Linux setup with Hyprland, Ghostty, Starship, and Catppuccin Macchiato theme.

## Stack

| Component | Tool |
|-----------|------|
| WM | Hyprland |
| Bar | Waybar |
| Terminal | Ghostty |
| Shell | zsh + Zinit + Starship |
| Launcher | Rofi (Wayland) |
| Notifications | SwayNC |
| File Manager | yazi (CLI) / Nemo (GUI) |
| Screenshots | grim + slurp + swappy |
| Clipboard | cliphist + wl-clipboard |
| Lock Screen | hyprlock |
| Idle | hypridle |
| Wallpaper | swww |
| Git | lazygit + delta |
| Theme | Catppuccin Macchiato |
| GPU | AMD (mesa + vulkan-radeon) |

## Install

Fresh Arch Linux installation:

```bash
# Clone the repo
git clone https://github.com/pedroapy/dotfiles.git ~/dotfiles-arch
cd ~/dotfiles-arch
git checkout archlinux

# Run the installer (idempotent — safe to re-run)
chmod +x install.sh
./install.sh
```

## Structure

```
├── install.sh          # Main entry point
├── packages/
│   ├── official.txt    # Pacman packages
│   ├── aur.txt         # AUR packages
│   └── amd-gpu.txt     # AMD GPU drivers
├── stow/               # Config packages (managed by GNU Stow)
│   ├── hyprland/       # Hyprland + hyprlock + hypridle
│   ├── waybar/         # Status bar
│   ├── ghostty/        # Terminal
│   ├── zsh/            # Shell config
│   ├── starship/       # Prompt
│   ├── git/            # Git config + delta
│   ├── rofi/           # App launcher
│   ├── swaync/         # Notifications
│   ├── btop/           # System monitor
│   ├── yazi/           # File manager
│   ├── fastfetch/      # System info
│   ├── ripgrep/        # Search config
│   ├── swappy/         # Screenshot editor
│   ├── fuzzel/         # Alt launcher
│   └── bin/            # Custom scripts
└── scripts/            # Modular install scripts
```

## Keybindings

| Key | Action |
|-----|--------|
| `Super + Return` | Terminal |
| `Super + D` | App launcher (Rofi) |
| `Super + B` | Browser |
| `Super + E` | File manager |
| `Super + Q` | Close window |
| `Super + F` | Fullscreen |
| `Super + Space` | Toggle floating |
| `Super + V` | Clipboard history |
| `Super + L` | Lock screen |
| `Super + 1-0` | Workspaces |
| `Print` | Screenshot (region) |
| `Shift + Print` | Screenshot (full) |
| `Super + hjkl` | Focus (vim keys) |
| `Super + Shift + hjkl` | Move window |

## Post-install

- Edit `~/.config/hypr/monitors.conf` for your display setup
- Run `hyprctl monitors` to detect connected displays
- Run `fastfetch` for system info
