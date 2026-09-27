-- Keybinds
--
-- `hyprctl binds` lists what is actually registered, and `wev` tells you the
-- name of a key you cannot guess.
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
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd(vela .. " shell toggle launcher"), { description = "Shell: Launcher" })
hl.bind(mod .. " + SHIFT + SPACE", hl.dsp.exec_cmd("fuzzel"), { description = "Shell › Fallback launcher" })
hl.bind(mod .. " + D", hl.dsp.exec_cmd(vela .. " shell toggle dashboard"), { description = "Shell: Dashboard" })
hl.bind(mod .. " + SHIFT + D", hl.dsp.exec_cmd(vela .. " shell toggle calendar"), { description = "Shell: Calendar" })
hl.bind(mod .. " + V", hl.dsp.exec_cmd(vela .. " shell toggle clipboard"), { description = "Shell: Clipboard history" })
hl.bind(mod .. " + W", hl.dsp.exec_cmd(vela .. " shell toggle wallpaper"), { description = "Shell: Wallpaper switcher" })
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd(vela .. " wallpaper revert"), { description = "Shell › Revert wallpaper" })
hl.bind(mod .. " + I", hl.dsp.exec_cmd(vela .. " shell toggle settings"), { description = "Shell: Settings" })

-- The cheatsheet, on a key neither layout needs shift for. On an Italian
-- layout `/` is shift + 7, and the cheatsheet used to be bound
-- there as well -- until super + shift + 7 also meant "move the window to
-- workspace 7", and did both. `<` is a key of its own there, left of Z; on a
-- US layout it is shift + comma, but `/` is unshifted, so each layout has one.
hl.bind(mod .. " + less", hl.dsp.exec_cmd(vela .. " shell toggle keybinds"), { description = "Shell: This cheatsheet" })
hl.bind(mod .. " + slash", hl.dsp.exec_cmd(vela .. " shell toggle keybinds"), { description = "Shell › This cheatsheet, US layout" })

hl.bind(mod .. " + ESCAPE", hl.dsp.exec_cmd(vela .. " shell toggle power"), { description = "Shell: Power menu" })

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
hl.bind(mod .. " + L", hl.dsp.exec_cmd(vela .. " lock lock"), { description = "Shell: Lock" })
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("vela shell restart"), { description = "Shell › Restart the shell" })

-- ----------------------------------------------------------------- capture --
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(vela .. " shell open capture"), { description = "Capture: Region capture" })
hl.bind("Print", hl.dsp.exec_cmd("grim -g \"$(slurp -d -b 00000040 -c ffffffcc -w 2)\" - | wl-copy"),
    { description = "Capture: Copy a region" })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("grim - | wl-copy"), { description = "Capture: Copy screen immediately" })
hl.bind(mod .. " + Print",
    hl.dsp.exec_cmd("sh -c 'mkdir -p ~/Pictures/Screenshots; f=~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png; grim -g \"$(slurp -d)\" \"$f\" && wl-copy < \"$f\"'"),
    { description = "Capture › Save a region" })
hl.bind(mod .. " + SHIFT + Print",
    hl.dsp.exec_cmd("sh -c 'mkdir -p ~/Pictures/Screenshots; f=~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png; grim \"$f\" && wl-copy < \"$f\"'"),
    { description = "Capture › Save the screen" })
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Capture: Pick a colour" })

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
hl.bind("ALT + TAB", hl.dsp.global("vela:altTab"), { description = "Windows: Window picker" })
hl.bind("ALT + SHIFT + TAB", hl.dsp.global("vela:altTabBack"), { description = "Windows › Window picker, backwards" })

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

hl.bind(mod .. " + Q", hl.dsp.window.close(), { description = "Windows: Close window" })
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Windows: Fullscreen" })
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Windows: Maximise" })
-- Float, and back to a whole tile. Pseudotiling (super + P, below) outlives a
-- trip through floating: a window that had been pseudotiled at any point came
-- back from floating centred in its tile at the size it had floated at --
-- tiled, but not filling the space, which read as the float not having let
-- go. So the toggle clears it on the way, in either direction.
hl.bind(mod .. " + SHIFT + V", function()
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
for i = 1, 4 do
    hl.bind(mod .. " + " .. arrows[i], hl.dsp.focus({ direction = dirs[i] }), { description = "Windows: Move focus" })
end
for i = 1, 4 do
    hl.bind(mod .. " + SHIFT + " .. arrows[i], hl.dsp.window.move({ direction = dirs[i] }), { description = "Windows: Swap window" })
end
for i = 1, 4 do
    hl.bind(mod .. " + CTRL + " .. arrows[i], hl.dsp.window.resize({ x = steps[i][1], y = steps[i][2], relative = true }),
        { repeating = true, description = "Windows: Resize" })
end

-- Resize by keyboard, held. A dedicated submap avoids holding three keys.
hl.bind(mod .. " + R", hl.dsp.submap("resize"), { description = "Windows › Resize mode · esc leaves" })
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


hl.bind(mod .. " + P", hl.dsp.window.pseudo(), { description = "Windows: Pseudotile" })
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"), { description = "Windows: Toggle split" })
hl.bind(mod .. " + X", hl.dsp.window.pin(), { description = "Windows: Pin above others" })

-- ---------------------------------------------------------------- sessions --
-- Saving needs no panel and says so in a notification; restoring picks from
-- the panel. super + shift + S belongs to capture.
hl.bind(mod .. " + ALT + S", hl.dsp.exec_cmd(vela .. " sessions save"), { description = "Sessions: Save current layout" })
hl.bind(mod .. " + ALT + R", hl.dsp.exec_cmd(vela .. " shell open sessions"), { description = "Sessions: Restore a session" })

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
hl.bind(mod .. " + mouse:272", no_tap(hl.dsp.window.drag()), { mouse = true, description = "Windows: Move with the mouse" })
hl.bind(mod .. " + mouse:273", no_tap(hl.dsp.window.resize()), { mouse = true, description = "Windows: Resize with the mouse" })

hl.bind(mod .. " + TAB", hl.dsp.exec_cmd(vela .. " shell toggle overview"), { description = "Workspaces: Overview" })

-- One to nine. The bar and the overview always show the first
-- bar.workspaces.count of them (five, in ~/.config/vela/shell.json) and every
-- number up to the highest one in use, so going to 6 here -- or making it
-- from the overview's New workspace card -- puts it on the bar as well.
for i = 1, 9 do
    hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = tostring(i) }), { description = "Workspaces: Go to workspace" })
end
for i = 1, 9 do
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }), { description = "Workspaces: Move window there" })
end
for i = 1, 9 do
    hl.bind(mod .. " + CTRL + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i), follow = false }),
        { description = "Workspaces › Move window there silently" })
end

hl.bind(mod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }), { description = "Workspaces: Previous workspace" })
-- The key left of 1 is grave on a US layout, but backslash on an Italian one,
-- where grave is AltGr + apostrophe and so, like `slash` above, can never
-- fire. Both spellings are bound.
hl.bind(mod .. " + GRAVE", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces: Next workspace" })
hl.bind(mod .. " + backslash", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces › Next workspace, Italian layout" })
hl.bind(mod .. " + mouse_down", no_tap(hl.dsp.focus({ workspace = "e+1" })), { description = "Workspaces › Cycle workspaces" })
hl.bind(mod .. " + mouse_up", no_tap(hl.dsp.focus({ workspace = "e-1" })), { description = "Workspaces › Cycle workspaces" })

hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("scratch"), { description = "Workspaces: Scratchpad" })
hl.bind(mod .. " + SHIFT + X", hl.dsp.window.move({ workspace = "special:scratch", follow = false }),
    { description = "Workspaces › Send window to the scratchpad" })

-- -------------------------------------------------------------------- apps --
-- Listed under Shell, after the launcher rows the cheatsheet shows first.
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd(term), { description = "Shell: Terminal" })
hl.bind(mod .. " + E", hl.dsp.exec_cmd(files), { description = "Shell: Files" })
hl.bind(mod .. " + B", hl.dsp.exec_cmd(browser), { description = "Shell: Browser" })

-- ---------------------------------------------------------- media & system --
-- `locked` so they still work on the lock screen; `repeating` so holding the
-- key ramps rather than stepping once.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true, description = "Media & system: Volume · shows OSD" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true, description = "Media & system: Volume · shows OSD" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true, description = "Media & system: Mute" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true, description = "Media & system › Mute the microphone" })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),
    { locked = true, repeating = true, description = "Media & system: Brightness · shows OSD" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),
    { locked = true, repeating = true, description = "Media & system: Brightness · shows OSD" })
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd("brightnessctl -d '*::kbd_backlight' set 33%+"),
    { locked = true, repeating = true, description = "Media & system › Keyboard backlight" })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d '*::kbd_backlight' set 33%-"),
    { locked = true, repeating = true, description = "Media & system › Keyboard backlight" })

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media & system: Play / pause" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media & system: Play / pause" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Media & system: Next track" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Media & system: Previous track" })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true, description = "Media & system › Stop" })

hl.bind(mod .. " + N", hl.dsp.exec_cmd(vela .. " bar popout notifications"), { description = "Media & system: Notification centre" })
hl.bind(mod .. " + CTRL + N", hl.dsp.exec_cmd(vela .. " notifs toggleDnd"), { description = "Media & system: Do not disturb" })
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd(vela .. " notifs clear"), { description = "Media & system › Clear notifications" })

hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("wlogout"), { description = "Media & system: Log out menu" })
hl.bind(mod .. " + SHIFT + M", hl.dsp.exit(), { description = "Media & system › Exit Hyprland" })

-- Closing the lid locks: a closed lid is an unambiguous "I have walked away".
-- A switch, not a key, so the cheatsheet leaves it out.
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("loginctl lock-session"), { locked = true })
