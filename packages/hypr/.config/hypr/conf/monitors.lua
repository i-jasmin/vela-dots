-- Monitors
--
-- Every screen gets its own best mode, placed automatically -- the rule at the
-- bottom. Anything for one machine only (a scale, a position, a refresh rate)
-- belongs in conf/local.lua, which is loaded last and not committed, so the
-- same config fits every machine. Names come from `hyprctl monitors all`.
--
-- One screen at 1.25x -- eDP-1 is a laptop's own; a PC's monitors are DP-1,
-- HDMI-A-1, ...:
--
-- hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1.25 })

-- Adding another display:
--
--   * `hyprctl monitors all` while it is plugged in gives its name (DP-1,
--     HDMI-A-1, ...).
--   * `auto-right` / `auto-left` / `auto-up` place it relative to whatever is
--     already positioned, so you never have to compute pixel offsets.
--   * `preferred` takes the display's own best mode.
--
-- hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto-right", scale = 1 })
--
-- Mirror the first screen onto it instead:
-- hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = 1, mirror = "eDP-1" })
--
-- Laptop lid closed, external attached -- disable the internal panel:
-- hl.monitor({ output = "eDP-1", disabled = true })
--
-- Pin workspaces to an output so they do not migrate when it is unplugged:
-- hl.workspace_rule({ workspace = "1", monitor = "eDP-1", default = true })

-- Catch-all for anything not named above: best mode, placed automatically.
-- An exact name match always beats this, so its position in the file is
-- irrelevant -- it sits last because it reads as the default case.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1
})
