-- ── Variables ────────────────────────────────────
local mod         = "SUPER"
local terminal    = "ghostty"
local menu        = "rofi -show drun -show-icons"
local browser     = "brave"
local filemanager = "dolphin"
-- local editor   = "code"

-- ── Applications ─────────────────────────────────
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + B",      hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + E",      hl.dsp.exec_cmd(filemanager))
hl.bind(mod .. " + D",      hl.dsp.exec_cmd(menu))
hl.bind(mod .. " + V",      hl.dsp.exec_cmd('cliphist list | rofi -dmenu -p "Clipboard" | cliphist decode | wl-copy'))
hl.bind(mod .. " + N",      hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind(mod .. " + W",         hl.dsp.exec_cmd("~/bin/wallpaper.sh pick"))
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("~/bin/wallpaper.sh random"))
hl.bind(mod .. " + Escape",    hl.dsp.exec_cmd("~/bin/powermenu.sh"))
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))  -- colour picker, copies the hex
-- Lock moved off SUPER+L so that key can complete the vim focus set below.
hl.bind(mod .. " + SHIFT + L", hl.dsp.exec_cmd("hyprlock"))

-- ── Screenshots (grimblast: copy+save+notify; swappy via stdin pipe) ──
hl.bind("Print",            hl.dsp.exec_cmd("grimblast --notify copysave area ~/captures/$(date +%Y%m%d_%H%M%S).png"))
hl.bind("SHIFT + Print",    hl.dsp.exec_cmd("grimblast --notify copysave screen ~/captures/$(date +%Y%m%d_%H%M%S).png"))
hl.bind(mod .. " + Print",  hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))

-- ── Window Management ───────────────────────────
hl.bind(mod .. " + Q",         hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + Q", hl.dsp.exit())
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + Space",     hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P",         hl.dsp.window.pseudo())
hl.bind(mod .. " + S",         hl.dsp.layout("togglesplit"))

-- ── Groups (modo stacked/tabbed) ────────────────
hl.bind(mod .. " + G",           hl.dsp.group.toggle())
hl.bind(mod .. " + Tab",         hl.dsp.group.next())
hl.bind(mod .. " + SHIFT + Tab", hl.dsp.group.prev())
hl.bind(mod .. " + ALT + left",  hl.dsp.window.move({ into_group = "left" }))
hl.bind(mod .. " + ALT + right", hl.dsp.window.move({ into_group = "right" }))
hl.bind(mod .. " + ALT + up",    hl.dsp.window.move({ into_group = "up" }))
hl.bind(mod .. " + ALT + down",  hl.dsp.window.move({ into_group = "down" }))
hl.bind(mod .. " + ALT + O",     hl.dsp.window.move({ out_of_group = true }))
hl.bind(mod .. " + ALT + L",     hl.dsp.group.lock({ action = "toggle" }))

-- ── Focus ────────────────────────────────────────
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + h",     hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + j",     hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + k",     hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + l",     hl.dsp.focus({ direction = "right" }))

-- ── Move Windows ─────────────────────────────────
hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))
hl.bind(mod .. " + SHIFT + h",     hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + j",     hl.dsp.window.move({ direction = "down" }))
hl.bind(mod .. " + SHIFT + k",     hl.dsp.window.move({ direction = "up" }))
-- No SUPER+SHIFT+l here: that combo now locks the screen. Use SUPER+SHIFT+right
-- to move a window right.

-- ── Resize ───────────────────────────────────────
hl.bind(mod .. " + CTRL + left",  hl.dsp.window.resize({ x = -40, y = 0,   relative = true }))
hl.bind(mod .. " + CTRL + right", hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }))
hl.bind(mod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0,   y = -40, relative = true }))
hl.bind(mod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }))

-- ── Workspaces + Move to Workspace ───────────────
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- ── Scroll through workspaces ───────────────────
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- ── Mouse bindings ──────────────────────────────
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ── Media Keys (swayosd shows the OSD) ──────────
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume raise"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume lower"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness raise"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"), { locked = true, repeating = true })
