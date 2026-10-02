-- Keybinds
--
-- `hyprctl binds` lists what is actually registered, and `wev` tells you the
-- name of a key you cannot guess.
--
-- THESE ARE THE DEFAULTS. Change a bind in Settings, Keybinds rather than
-- here: that goes to ~/.config/vela/keybinds.json, which an update of the dots
-- does not replace, and conf/keybinds.lua applies it on top of this file. So
-- every bind is declared with a stable id -- `K.bind("shell.launcher", ...)`,
-- or `K.family(...)` for a row like super + 1 ... 9 -- which is what the file
-- names it by. An id, once shipped, stays: a changed one would drop somebody's
-- change to it without a word.
--
-- THE DESCRIPTIONS ARE THE CHEATSHEET. super + < is built from `hyprctl binds`
-- every time it opens, and each bind's description says where it goes:
--
--     "Group: Action"   a row in that group
--     "Group › Action"  a secondary row, drawn a step quieter
--
-- Binds sharing a group, an action and their modifiers become one row (the
-- five `super + N` binds read "super + 1–5"), rows keep the order they are
-- bound in here, and a bind with no description is listed under Unsorted.
-- The groups the screen draws: Shell, Capture, Windows, Sessions, Workspaces,
-- Media & system. (The app launchers are Shell rows: a seventh card would push
-- the list past the height of a 1080p screen.)

local K = require("conf.keybinds")

local mod = "SUPER"
local term = "kitty"
local files = "nautilus"
-- Whatever the system's default browser is (Settings in GNOME, or
-- `xdg-settings set default-web-browser firefox.desktop`), not one by name.
local browser = [[sh -c 'gtk-launch "$(xdg-settings get default-web-browser)"']]

-- Everything the shell does goes through its IPC, so a keybind, a click on the
-- bar and a terminal command are one code path. `qs -c vela ipc show` lists
-- the live handlers; with no instance running these exit 255, which is what
-- lets hypridle fall back to hyprlock. Alt-tab is the exception, as global
-- shortcuts into the same handler, for the reason given where it is bound.
local vela = "qs -c vela ipc call"

-- ------------------------------------------------------------------- shell --
-- The keybinds named in shell.json, which the shell also prints in its own UI
-- (the launcher footer, the overview legend, the dashboard header). Keep the
-- two in step: shell.json is a label, this file is the behaviour.
--
-- Every surface goes through one handler, `shell`, which owns the mutual
-- exclusion.
K.bind("shell.launcher", mod .. " + SPACE", hl.dsp.exec_cmd(vela .. " shell toggle launcher"), { description = "Shell: Launcher" })
-- fuzzel in the apps' icon theme, read as it opens: Settings (Appearance, App
-- icons) sets it for GTK, and fuzzel.ini can only name one theme for good.
K.bind("shell.fallback-launcher", mod .. " + SHIFT + SPACE",
    hl.dsp.exec_cmd("t=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d \"'\"); exec fuzzel --icon-theme=\"${t:-Adwaita}\""),
    { description = "Shell › Fallback launcher" })
K.bind("shell.dashboard", mod .. " + D", hl.dsp.exec_cmd(vela .. " shell toggle dashboard"), { description = "Shell: Dashboard" })
K.bind("shell.calendar", mod .. " + SHIFT + D", hl.dsp.exec_cmd(vela .. " shell toggle calendar"), { description = "Shell: Calendar" })
K.bind("shell.clipboard", mod .. " + V", hl.dsp.exec_cmd(vela .. " shell toggle clipboard"), { description = "Shell: Clipboard history" })
K.bind("shell.wallpaper", mod .. " + W", hl.dsp.exec_cmd(vela .. " shell toggle wallpaper"), { description = "Shell: Wallpaper switcher" })
K.bind("shell.wallpaper-revert", mod .. " + SHIFT + W", hl.dsp.exec_cmd(vela .. " wallpaper revert"), { description = "Shell › Revert wallpaper" })
K.bind("shell.settings", mod .. " + I", hl.dsp.exec_cmd(vela .. " shell toggle settings"), { description = "Shell: Settings" })

-- The cheatsheet, on a key neither layout needs shift for. On an Italian
-- layout `/` is shift + 7, and the cheatsheet used to be bound
-- there as well -- until super + shift + 7 also meant "move the window to
-- workspace 7", and did both. `<` is a key of its own there, left of Z; on a
-- US layout it is shift + comma, but `/` is unshifted, so each layout has one.
K.bind("shell.cheatsheet", mod .. " + less", hl.dsp.exec_cmd(vela .. " shell toggle keybinds"), { description = "Shell: This cheatsheet" })
K.bind("shell.cheatsheet-us", mod .. " + slash", hl.dsp.exec_cmd(vela .. " shell toggle keybinds"), { description = "Shell › This cheatsheet, US layout" })

K.bind("shell.power", mod .. " + ESCAPE", hl.dsp.exec_cmd(vela .. " shell toggle power"), { description = "Shell: Power menu" })

-- Super+L. The lock refuses to engage without a usable PAM stack (it starts
-- hyprlock instead), and closes every overlay first so that nothing paints
-- over a locked screen.
--
-- If the shell dies while the session is locked, the session stays locked --
-- that is ext-session-lock-v1. It is recoverable from a TTY (ctrl+alt+F3):
--
--     hyprctl eval 'hl.clear_crashed_lockscreen()'
--
-- That command only exists because hyprland.lua uses the Lua config manager;
-- see its header.
K.bind("shell.lock", mod .. " + L", hl.dsp.exec_cmd(vela .. " lock lock"), { description = "Shell: Lock" })
K.bind("shell.restart", mod .. " + SHIFT + R", hl.dsp.exec_cmd("vela shell restart"), { description = "Shell › Restart the shell" })

-- ----------------------------------------------------------------- capture --
K.bind("capture.region", mod .. " + SHIFT + S", hl.dsp.exec_cmd(vela .. " shell open capture"), { description = "Capture: Region capture" })
K.bind("capture.copy-region", "Print", hl.dsp.exec_cmd("grim -g \"$(slurp -d -b 00000040 -c ffffffcc -w 2)\" - | wl-copy"),
    { description = "Capture: Copy a region" })
K.bind("capture.copy-screen", "SHIFT + Print", hl.dsp.exec_cmd("grim - | wl-copy"), { description = "Capture: Copy screen immediately" })
K.bind("capture.save-region", mod .. " + Print",
    hl.dsp.exec_cmd("sh -c 'mkdir -p ~/Pictures/Screenshots; f=~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png; grim -g \"$(slurp -d)\" \"$f\" && wl-copy < \"$f\"'"),
    { description = "Capture › Save a region" })
K.bind("capture.save-screen", mod .. " + SHIFT + Print",
    hl.dsp.exec_cmd("sh -c 'mkdir -p ~/Pictures/Screenshots; f=~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png; grim \"$f\" && wl-copy < \"$f\"'"),
    { description = "Capture › Save the screen" })
K.bind("capture.pick-colour", mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Capture: Pick a colour" })

-- ----------------------------------------------------------------- windows --
-- Alt-tab: the first press opens the picker, later ones move through it, and
-- letting go of alt switches.
--
-- Global shortcuts, not `qs ipc call`: a global is an event on the shell's own
-- Wayland connection, where the IPC call started a whole `qs` process for
-- every press. That was a lag you could feel, and it lost alt's release: the
-- picker only hears keys once it has the keyboard, so letting go of alt
-- before that process had opened it left the picker up, waiting for a release
-- that had already happened. So alt's release comes from here as well, seen
-- whoever has the keyboard and sent in order behind the presses.
-- Fixed, so Settings does not offer to move them: the release below is
-- watched for by Alt's keycodes, and would never come for another key.
local alt_fixed = "letting go of alt is what switches, so it stays on alt"
K.bind("windows.picker", "ALT + TAB", hl.dsp.global("vela:altTab"), { description = "Windows: Window picker", fixed = alt_fixed })
K.bind("windows.picker-back", "ALT + SHIFT + TAB", hl.dsp.global("vela:altTabBack"),
    { description = "Windows › Window picker, backwards", fixed = alt_fixed })

local alt_keys = { [64] = true, [108] = true } -- xkb keycodes of Alt_L, Alt_R
local tab_key = 23
local alts_held = {}
local alt_tabbing = false
local alt_released = hl.dsp.global("vela:altTabRelease")

hl.on("input.keyboard.key", function(keycode, time_ms, state)
    if alt_keys[keycode] then
        alts_held[keycode] = state == 1 or nil
        if alt_tabbing and next(alts_held) == nil then
            alt_tabbing = false
            hl.dispatch(alt_released)
        end
    elseif keycode == tab_key and state == 1 and next(alts_held) ~= nil then
        alt_tabbing = true
    end
end)

K.bind("windows.close", mod .. " + Q", hl.dsp.window.close(), { description = "Windows: Close window" })
K.bind("windows.fullscreen", mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Windows: Fullscreen" })
K.bind("windows.maximise", mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Windows: Maximise" })
-- Float, and back to a whole tile. Pseudotiling (super + P, below) outlives a
-- trip through floating: a window that had been pseudotiled at any point came
-- back from floating centred in its tile at the size it had floated at --
-- tiled, but not filling the space, which read as the float not having let
-- go. So the toggle clears it on the way, in either direction.
K.bind("windows.float", mod .. " + SHIFT + V", function()
    hl.dispatch(hl.dsp.window.pseudo({ action = "disable" }))
    return hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
end, { description = "Windows: Float" })

-- Focus, move and resize by arrow key.
--
-- A resize step needs `relative = true`. Without it Hyprland 0.56 reads
-- { x, y } as the window's new size, not a change to it, so super + ctrl +
-- left asked for a window -40 px wide and got the minimum size instead.
local arrows = { "left", "right", "up", "down" }
local dirs = { "l", "r", "u", "d" }
local steps = { { -40, 0 }, { 40, 0 }, { 0, -40 }, { 0, 40 } }
local arrow = {}
for i = 1, 4 do arrow[arrows[i]] = i end
K.family("windows.focus", mod, arrows, function(key)
    return hl.dsp.focus({ direction = dirs[arrow[key]] })
end, { description = "Windows: Move focus" })
K.family("windows.swap", mod .. " + SHIFT", arrows, function(key)
    return hl.dsp.window.move({ direction = dirs[arrow[key]] })
end, { description = "Windows: Swap window" })
K.family("windows.resize", mod .. " + CTRL", arrows, function(key)
    local step = steps[arrow[key]]
    return hl.dsp.window.resize({ x = step[1], y = step[2], relative = true })
end, { repeating = true, description = "Windows: Resize" })

-- Resize by keyboard, held. A dedicated submap avoids holding three keys.
K.bind("windows.resize-mode", mod .. " + R", hl.dsp.submap("resize"), { description = "Windows › Resize mode · esc leaves" })
hl.define_submap("resize", function()
    -- hjkl here rather than as global binds: h and l would collide with the
    -- lock bind, and j with toggle-split.
    local keys = { "left", "right", "up", "down", "H", "L", "K", "J" }
    local deltas = { { -40, 0 }, { 40, 0 }, { 0, -40 }, { 0, 40 }, { -40, 0 }, { 40, 0 }, { 0, -40 }, { 0, 40 } }
    for i = 1, #keys do
        hl.bind(keys[i], hl.dsp.window.resize({ x = deltas[i][1], y = deltas[i][2], relative = true }), { repeating = true })
    end
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("return", hl.dsp.submap("reset"))
end)


K.bind("windows.pseudotile", mod .. " + P", hl.dsp.window.pseudo(), { description = "Windows: Pseudotile" })
K.bind("windows.toggle-split", mod .. " + J", hl.dsp.layout("togglesplit"), { description = "Windows: Toggle split" })
K.bind("windows.pin", mod .. " + X", hl.dsp.window.pin(), { description = "Windows: Pin above others" })

-- ---------------------------------------------------------------- sessions --
-- Saving needs no panel and says so in a notification; restoring picks from
-- the panel. super + shift + S belongs to capture.
K.bind("sessions.save", mod .. " + ALT + S", hl.dsp.exec_cmd(vela .. " sessions save"), { description = "Sessions: Save current layout" })
K.bind("sessions.restore", mod .. " + ALT + R", hl.dsp.exec_cmd(vela .. " shell open sessions"), { description = "Sessions: Restore a session" })

-- -------------------------------------------------------------- workspaces --
-- Overview on a *tap* of Super: pressed and released on its own, quickly.
--
-- A `SUPER + SUPER_L` release bind cannot do this. Hyprland fires a release bind
-- when the key comes up no matter what was pressed while it was held, so every
-- Super+<key> combo -- Super+Return, Super+1, Super+Q -- opened the overview on
-- the way out. The raw key stream can tell the difference: any other key pressed
-- in between disarms the tap, and so does holding Super for longer than a tap.
-- (end-4's dots solve the same problem with a catchall bind; the Lua config
-- manager only allows catchall inside a submap.)
--
-- Not a bind, so hyprctl cannot report it: the cheatsheet adds this row itself.
local super_keys = { [133] = true, [134] = true } -- xkb keycodes of Super_L, Super_R
local tap_ms = 350
local tap_started = nil

hl.on("input.keyboard.key", function(keycode, time_ms, state)
    if state == 1 then
        tap_started = super_keys[keycode] and time_ms or nil
    elseif tap_started and super_keys[keycode] then
        local held = time_ms - tap_started
        tap_started = nil
        if held < tap_ms then
            hl.exec_cmd(vela .. " shell toggle overview")
        end
    end
end)

-- Super + scroll and Super + a mouse button are not keys, so they disarm the
-- tap here instead: a quick Super + drag used to open the overview as Super
-- came up.
local function no_tap(dispatcher)
    return function()
        tap_started = nil
        return hl.dispatch(dispatcher)
    end
end

-- Move and resize with the mouse. Run through `no_tap` like any Lua bind: the
-- drag is ended by the same bind firing again on the button's release, which
-- it still does.
local mouse_fixed = "a mouse button, which Settings cannot record"
K.bind("windows.drag", mod .. " + mouse:272", no_tap(hl.dsp.window.drag()),
    { mouse = true, description = "Windows: Move with the mouse", fixed = mouse_fixed })
K.bind("windows.drag-resize", mod .. " + mouse:273", no_tap(hl.dsp.window.resize()),
    { mouse = true, description = "Windows: Resize with the mouse", fixed = mouse_fixed })

K.bind("workspaces.overview", mod .. " + TAB", hl.dsp.exec_cmd(vela .. " shell toggle overview"), { description = "Workspaces: Overview" })

-- One to nine. The bar and the overview always show the first
-- bar.workspaces.count of them (five, in ~/.config/vela/shell.json) and every
-- number up to the highest one in use, so going to 6 here -- or making it
-- from the overview's New workspace card -- puts it on the bar as well.
local digits = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }
K.family("workspaces.go", mod, digits, function(key)
    return hl.dsp.focus({ workspace = key })
end, { description = "Workspaces: Go to workspace" })
K.family("workspaces.move", mod .. " + SHIFT", digits, function(key)
    return hl.dsp.window.move({ workspace = key })
end, { description = "Workspaces: Move window there" })
K.family("workspaces.move-silent", mod .. " + CTRL + SHIFT", digits, function(key)
    return hl.dsp.window.move({ workspace = key, follow = false })
end, { description = "Workspaces › Move window there silently" })

K.bind("workspaces.previous", mod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }), { description = "Workspaces: Previous workspace" })
-- The key left of 1 is grave on a US layout, but backslash on an Italian one,
-- where grave is AltGr + apostrophe and so, like `slash` above, can never
-- fire. Both spellings are bound.
K.bind("workspaces.next", mod .. " + GRAVE", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces: Next workspace" })
K.bind("workspaces.next-it", mod .. " + backslash", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces › Next workspace, Italian layout" })
K.family("workspaces.scroll", mod, { "mouse_down", "mouse_up" }, function(key)
    return no_tap(hl.dsp.focus({ workspace = key == "mouse_down" and "e+1" or "e-1" }))
end, { description = "Workspaces › Cycle workspaces", fixed = "the scroll wheel, which Settings cannot record" })

K.bind("workspaces.scratchpad", mod .. " + S", hl.dsp.workspace.toggle_special("scratch"), { description = "Workspaces: Scratchpad" })
K.bind("workspaces.to-scratchpad", mod .. " + SHIFT + X", hl.dsp.window.move({ workspace = "special:scratch", follow = false }),
    { description = "Workspaces › Send window to the scratchpad" })

-- -------------------------------------------------------------------- apps --
-- Listed under Shell, after the launcher rows the cheatsheet shows first.
K.bind("apps.terminal", mod .. " + RETURN", hl.dsp.exec_cmd(term), { description = "Shell: Terminal" })
K.bind("apps.files", mod .. " + E", hl.dsp.exec_cmd(files), { description = "Shell: Files" })
K.bind("apps.browser", mod .. " + B", hl.dsp.exec_cmd(browser), { description = "Shell: Browser" })

-- ---------------------------------------------------------- media & system --
-- `locked` so they still work on the lock screen; `repeating` so holding the
-- key ramps rather than stepping once.
K.bind("media.volume-up", "XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true, description = "Media & system: Volume · shows OSD" })
K.bind("media.volume-down", "XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true, description = "Media & system: Volume · shows OSD" })
K.bind("media.mute", "XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true, description = "Media & system: Mute" })
K.bind("media.mic-mute", "XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true, description = "Media & system › Mute the microphone" })

K.bind("media.brightness-up", "XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),
    { locked = true, repeating = true, description = "Media & system: Brightness · shows OSD" })
K.bind("media.brightness-down", "XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),
    { locked = true, repeating = true, description = "Media & system: Brightness · shows OSD" })
K.bind("media.keyboard-light-up", "XF86KbdBrightnessUp", hl.dsp.exec_cmd("brightnessctl -d '*::kbd_backlight' set 33%+"),
    { locked = true, repeating = true, description = "Media & system › Keyboard backlight" })
K.bind("media.keyboard-light-down", "XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d '*::kbd_backlight' set 33%-"),
    { locked = true, repeating = true, description = "Media & system › Keyboard backlight" })

K.bind("media.play", "XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media & system: Play / pause" })
K.bind("media.pause", "XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media & system: Play / pause" })
K.bind("media.next", "XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Media & system: Next track" })
K.bind("media.previous", "XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Media & system: Previous track" })
K.bind("media.stop", "XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true, description = "Media & system › Stop" })

K.bind("system.notifications", mod .. " + N", hl.dsp.exec_cmd(vela .. " bar popout notifications"), { description = "Media & system: Notification centre" })
K.bind("system.dnd", mod .. " + CTRL + N", hl.dsp.exec_cmd(vela .. " notifs toggleDnd"), { description = "Media & system: Do not disturb" })
K.bind("system.clear-notifications", mod .. " + SHIFT + N", hl.dsp.exec_cmd(vela .. " notifs clear"), { description = "Media & system › Clear notifications" })

K.bind("system.logout", mod .. " + SHIFT + E", hl.dsp.exec_cmd("wlogout"), { description = "Media & system: Log out menu" })
K.bind("system.exit", mod .. " + SHIFT + M", hl.dsp.exit(), { description = "Media & system › Exit Hyprland" })

-- Closing the lid locks: a closed lid is an unambiguous "I have walked away".
-- A switch, not a key, so the cheatsheet and Settings leave it out.
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("loginctl lock-session"), { locked = true })

-- Recording a keybind in Settings. While it listens the shell puts Hyprland in
-- this submap, where nothing above is bound, so the combination pressed
-- reaches Settings instead of doing what it does now. Esc is the one bind:
-- the way out if the shell is not there to take Hyprland back.
hl.define_submap("vela_capture", function()
    hl.bind("escape", hl.dsp.submap("reset"))
end)

-- Your own binds from keybinds.json, and the list Settings reads.
K.finish()
