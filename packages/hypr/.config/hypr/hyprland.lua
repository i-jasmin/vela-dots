-- vela -- Hyprland
--
-- Hyprland prefers hyprland.lua over hyprland.conf and warns that the .conf
-- format loses support in 0.57, so this is the Lua config manager. It also
-- re-enables `hyprctl eval`, which is the only documented way to clear a
-- crashed lock screen -- see docs/hyprland-notes.md before removing it.
--
-- This file is nothing but requires. Everything lives in conf/, one file per
-- concern, so a change has an obvious home. colours.lua comes last because it
-- overrides the border and background values general.lua sets.

require("conf.env")
require("conf.monitors")
require("conf.general")
require("conf.input")
require("conf.rules")
require("conf.binds")
require("conf.autostart")
require("conf.colours")

-- Machine-local overrides, loaded last so they win. Create it yourself; unlike
-- hyprlang's `source`, a missing require is an error, hence the guard.
local local_conf = os.getenv("HOME") .. "/.config/hypr/conf/local.lua"
if io.open(local_conf) then
    require("conf.local")
end
