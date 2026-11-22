-- ── Window Rules ─────────────────────────────────

-- Float by default
hl.window_rule({
    name  = "float-pavucontrol",
    match = { class = "^(pavucontrol)$" },
    float = true,
    size  = { 800, 600 },
})

hl.window_rule({
    name  = "float-blueman",
    match = { class = "^(blueman-manager)$" },
    float = true,
    size  = { 800, 600 },
})

hl.window_rule({
    name  = "float-nm",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
})

hl.window_rule({
    name  = "float-dolphin",
    match = { class = "^(org\\.kde\\.dolphin)$" },
    float = true,
    size  = { 1200, 800 },
})

hl.window_rule({
    name  = "float-imv",
    match = { class = "^(imv)$" },
    float = true,
})

hl.window_rule({
    name  = "float-pip",
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
})

hl.window_rule({
    name  = "float-openfile",
    match = { title = "^(Open File)$" },
    float = true,
})

hl.window_rule({
    name  = "float-savefile",
    match = { title = "^(Save File)$" },
    float = true,
})

hl.window_rule({
    name  = "float-1password",
    match = { class = "^(1Password)$" },
    float = true,
})

-- Workspace assignments
hl.window_rule({
    name      = "ws-firefox",
    match     = { class = "^(firefox)$" },
    workspace = "2",
})

hl.window_rule({
    name      = "ws-brave",
    match     = { class = "^(brave-browser)$" },
    workspace = "2",
})

hl.window_rule({
    name      = "ws-chrome",
    match     = { class = "^(Google-chrome)$" },
    workspace = "2",
})

hl.window_rule({
    name      = "ws-vscode",
    match     = { class = "^(Code)$" },
    workspace = "3",
})

hl.window_rule({
    name      = "ws-spotify",
    match     = { class = "^(spotify)$" },
    workspace = "4",
})

-- Opacity
hl.window_rule({
    name    = "opacity-ghostty",
    match   = { class = "^(com\\.mitchellh\\.ghostty)$" },
    opacity = "0.95 0.85",
})

hl.window_rule({
    name    = "opacity-vscode",
    match   = { class = "^(Code)$" },
    opacity = "0.95 0.85",
})

-- Suppress maximize events
hl.window_rule({
    name           = "suppress-maximize",
    match          = { class = ".*" },
    suppress_event = "maximize",
})
