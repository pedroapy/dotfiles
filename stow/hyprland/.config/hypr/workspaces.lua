-- ── Workspaces ─────────────────────────────────────
-- Assign workspaces to monitors. Persistent makes the workspace
-- always visible in waybar even when empty.
--
-- Setup: HDMI-A-1 (primary, left) | DP-3 (right)

-- Primary monitor (left) — workspaces 1..5
hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", default = true, persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "HDMI-A-1", persistent = true })

-- Secondary monitor (right) — workspaces 6..10
hl.workspace_rule({ workspace = "6",  monitor = "DP-3", default = true, persistent = true })
hl.workspace_rule({ workspace = "7",  monitor = "DP-3", persistent = true })
hl.workspace_rule({ workspace = "8",  monitor = "DP-3", persistent = true })
hl.workspace_rule({ workspace = "9",  monitor = "DP-3", persistent = true })
hl.workspace_rule({ workspace = "10", monitor = "DP-3", persistent = true })
