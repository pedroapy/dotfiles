-- ── Autostart ────────────────────────────────────

hl.on("hyprland.start", function()
    -- Wallpaper: a different image per monitor, rotating every 30 min (SUPER+W to pick)
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("bash -c 'sleep 1 && exec ~/bin/wallpaper.sh rotate 1800'")

    -- Volume / brightness OSD
    hl.exec_cmd("swayosd-server")

    -- Status bar
    hl.exec_cmd("waybar")

    -- Notifications (managed by systemd user service via D-Bus activation)
    -- hl.exec_cmd("swaync")

    -- Clipboard
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    -- Keep the clipboard after the source app closes
    hl.exec_cmd("wl-clip-persist --clipboard regular")

    -- Authentication agent
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")

    -- Network applet
    hl.exec_cmd("nm-applet --indicator")

    -- Bluetooth (managed by waybar bluetooth module)
    -- hl.exec_cmd("blueman-applet")

    -- Idle & lock
    hl.exec_cmd("hypridle")

    -- Cursor (hyprcursor for Hyprland, XCursor for GTK/X11 apps)
    hl.exec_cmd("hyprctl setcursor rose-pine-hyprcursor 24")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme BreezeX-RosePine-Linux")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 24")

    -- GTK theme
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme rose-pine-moon-gtk")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface font-name 'Inter 11'")

    -- KDE apps (Dolphin) outside Plasma ignore kdeglobals' scheme and fall back to
    -- Breeze light unless the app is told which scheme to use.
    hl.exec_cmd("kwriteconfig6 --file dolphinrc --group UiSettings --key ColorScheme 'Rosé Pine Moon'")
end)
