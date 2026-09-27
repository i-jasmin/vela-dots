-- Monitors
--
-- Names come from `hyprctl monitors all`. This machine has one output, the
-- internal panel, a BOE 1920x1080 60Hz on the Intel card.

hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60",
    position = "0x0",
    scale = 1
})

-- Adding an external display:
--
--   * `hyprctl monitors all` while it is plugged in gives its name. DP-1 to
--     DP-4 are on the iGPU (USB-C / dock), HDMI-A-1 is on the NVIDIA card.
--   * `auto-right` / `auto-left` / `auto-up` place it relative to whatever is
--     already positioned, so you never have to compute pixel offsets.
--   * `preferred` takes the display's own best mode.
--
-- hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto-right", scale = 1 })
--
-- Mirror the laptop panel onto it instead:
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
