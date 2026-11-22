-- ══════════════════════════════════════════════════
--  Hyprland Configuration
-- ══════════════════════════════════════════════════

local theme = require("theme")

require("monitors")
require("workspaces")
require("autostart")
require("binds")
require("rules")

-- ── GPU priority (RX 9070 dGPU first, Granite Ridge iGPU second) ─
-- Direct card paths — aquamarine had cold-boot issues with by-path symlinks.
hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")

-- ── Theming env (Rosé Pine cursor, Qt via qt6ct + Kvantum) ─
hl.env("HYPRCURSOR_THEME", "rose-pine-hyprcursor")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "BreezeX-RosePine-Linux")
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
-- KDE apps (Dolphin) outside Plasma: "Open with" menu comes from archlinux-xdg-menu
hl.env("XDG_MENU_PREFIX", "arch-")

-- ── Input ────────────────────────────────────────
hl.config({
    input = {
        kb_layout    = "us,es",
        kb_options   = "grp:alt_shift_toggle",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll = true,
            tap_to_click   = true,
        },
    },
})

-- ── General ──────────────────────────────────────
hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 10,
        border_size = 2,
        col = {
            active_border   = { colors = { theme.rgba("iris", "ff"), theme.rgba("rose", "ff") }, angle = 45 },
            inactive_border = theme.rgba("highlight_med", "aa"),
        },
        layout                  = "dwindle",
        allow_tearing           = false,
        resize_on_border        = true,
        extend_border_grab_area = 15,
    },
})

-- ── Decoration ───────────────────────────────────
hl.config({
    decoration = {
        rounding = 12,
        blur = {
            enabled = true,
            size    = 6,
            passes  = 3,
            xray    = false,
        },
        shadow = {
            enabled      = true,
            range        = 15,
            render_power = 3,
            color        = theme.rgba("base", "cc"),
        },
    },
})

-- ── Animations ───────────────────────────────────
hl.config({ animations = { enabled = true } })

hl.curve("ease",     { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1 } } })
hl.curve("overshot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.1 } } })

hl.animation({ leaf = "windows",     enabled = true, speed = 5,  bezier = "overshot", style = "slide" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 5,  bezier = "ease",     style = "slide" })
hl.animation({ leaf = "fade",        enabled = true, speed = 4,  bezier = "ease" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 4,  bezier = "ease",     style = "slide" })
hl.animation({ leaf = "border",      enabled = true, speed = 10, bezier = "ease" })

-- ── Layout ───────────────────────────────────────
hl.config({
    dwindle = {
        preserve_split = true,
        smart_split    = false,
    },
})

-- ── Groups (stacked/tabbed) ──────────────────────
hl.config({
    group = {
        col = {
            border_active          = { colors = { theme.rgba("iris", "ff"), theme.rgba("rose", "ff") }, angle = 45 },
            border_inactive        = theme.rgba("highlight_med", "aa"),
            border_locked_active   = { colors = { theme.rgba("gold", "ff"), theme.rgba("rose", "ff") }, angle = 45 },
            border_locked_inactive = theme.rgba("overlay", "aa"),
        },

        groupbar = {
            enabled       = true,
            font_family   = "Inter",
            font_size     = 11,
            height        = 18,
            gradients     = false,
            render_titles = true,
            scrolling     = true,
            text_color    = theme.rgba("text", "ff"),
            col = {
                active          = theme.rgba("iris", "cc"),
                inactive        = theme.rgba("overlay", "cc"),
                locked_active   = theme.rgba("gold", "cc"),
                locked_inactive = theme.rgba("highlight_med", "cc"),
            },
        },
    },
})

-- ── Cursor ───────────────────────────────────────
hl.config({
    cursor = {
        inactive_timeout   = 5,
        hide_on_key_press  = true,
    },
})

-- ── Misc ─────────────────────────────────────────
hl.config({
    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms  = true,
        key_press_enables_dpms   = true,
    },
})
