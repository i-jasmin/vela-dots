-- Input
--
-- `hyprctl devices` lists everything attached, including the exact name to use
-- for per-device overrides.

-- The keyboard layout is the system's: the one picked when Fedora was
-- installed, or set since with `localectl set-x11-keymap it` -- systemd-localed
-- writes it to 00-keyboard.conf, and newer versions to vconsole.conf as well.
-- US when neither says. A layout for one machine only goes in conf/local.lua,
-- which is loaded last:
--
--     hl.config({ input = { kb_layout = "it" } })
local function systemKeyboard()
    local kb = {}
    local function read(path)
        local f = io.open(path)
        if not f then
            return ""
        end
        local text = f:read("a")
        f:close()
        return text
    end
    local xorg = read("/etc/X11/xorg.conf.d/00-keyboard.conf")
    local vconsole = read("/etc/vconsole.conf")
    for key, name in pairs({ layout = "Layout", variant = "Variant", options = "Options" }) do
        local value = xorg:match('Option%s+"Xkb' .. name .. '"%s+"([^"]*)"')
            or vconsole:match("\nXKB" .. name:upper() .. '="?([^"\n]*)"?')
            or vconsole:match("^XKB" .. name:upper() .. '="?([^"\n]*)"?')
        if value and value ~= "" then
            kb[key] = value
        end
    end
    return kb
end

local kb = systemKeyboard()

hl.config({
    input = {
        kb_layout = kb.layout or "us",
        kb_variant = kb.variant or "",
        kb_options = kb.options or "",

        repeat_rate = 40,
        repeat_delay = 350,

        follow_mouse = 1,
        mouse_refocus = false,
        sensitivity = 0,
        accel_profile = "adaptive",

        numlock_by_default = true,
        -- Scroll factor only applies to external mice; the touchpad has its own.
        scroll_factor = 1.0,

        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
            tap_to_click = true,
            tap_and_drag = true,
            drag_lock = 1,
            scroll_factor = 0.35,
            clickfinger_behavior = true,
            middle_button_emulation = false
        }
    },

    gestures = {
        workspace_swipe_distance = 400,
        workspace_swipe_cancel_ratio = 0.3,
        workspace_swipe_create_new = false
    }
})

-- A second layout you can flip between with Alt+Shift (in conf/local.lua):
-- hl.config({ input = { kb_layout = "it,us", kb_options = "grp:alt_shift_toggle" } })
