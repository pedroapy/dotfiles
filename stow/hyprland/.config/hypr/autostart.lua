-- ── Autostart ────────────────────────────────────

hl.on("hyprland.start", function()
    -- Wallpaper (Bing photo of the day)
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("bash -c 'sleep 3 && ~/bin/get-wallpaper.sh'")

    -- Status bar
    hl.exec_cmd("waybar")

    -- Notifications (managed by systemd user service via D-Bus activation)
    -- hl.exec_cmd("swaync")

    -- Clipboard
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Authentication agent
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")

    -- Network applet
    hl.exec_cmd("nm-applet --indicator")

    -- Bluetooth (managed by waybar bluetooth module)
    -- hl.exec_cmd("blueman-applet")

    -- Idle & lock
    hl.exec_cmd("hypridle")

    -- Set cursor theme
    hl.exec_cmd("hyprctl setcursor catppuccin-macchiato-dark-cursors 24")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme catppuccin-macchiato-dark-cursors")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 24")

    -- GTK theme
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme catppuccin-macchiato-blue-standard+default")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface font-name 'Inter 11'")
end)
