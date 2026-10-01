---
title: Hyprland and this machine
description: vela's Hyprland config, and where to put what is true of one machine only -- keyboard, monitors, scaling.
---

vela's Hyprland config is Lua: `~/.config/hypr/hyprland.lua` loads one file
per topic from `~/.config/hypr/conf/`:

| File | Holds |
| --- | --- |
| `env.lua` | environment variables for apps Hyprland starts |
| `monitors.lua` | monitors -- every screen at its best mode by default |
| `general.lua` | gaps, borders, animations (they follow the motion setting) |
| `input.lua` | keyboard, mouse, touchpad |
| `rules.lua` | window rules |
| `binds.lua` | [keybinds](../keybinds/) |
| `autostart.lua` | what starts with the session: the shell, hypridle, the clipboard watcher |
| `colours.lua` | generated from the wallpaper; do not edit |

It needs Hyprland 0.56 or newer (the Lua config). `vela doctor` checks.

## This machine only: local.lua

The config is shared -- one repo for every machine you install it on. What is
true of one machine only goes in **`~/.config/hypr/conf/local.lua`**. It is
loaded last, so it wins, and it lives only in your home: the repo never has it,
so no update touches it. Create it yourself:

```lua
-- ~/.config/hypr/conf/local.lua

-- A different keyboard layout, or two to switch between with Alt + Shift:
hl.config({ input = { kb_layout = "it,us", kb_options = "grp:alt_shift_toggle" } })

-- A laptop's own screen (eDP-1) at 1.25x, and a monitor to its right. On a
-- PC, both are monitors: DP-1, HDMI-A-1, ...
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1.25 })
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto-right", scale = 1 })
```

`hyprctl monitors all` gives your outputs' names.

## Keyboard layout

By default the layout is the one Fedora was set up with -- the one chosen when
it was installed:

```sh
localectl status                    # shows it
localectl set-x11-keymap it         # changes it for the whole system
```

If neither says, it is US. For this machine only, set it in `local.lua` as
above.

## Checking the config

```sh
Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
```

checks keys, rules and animation names without applying anything.

:::caution[hyprctl dispatch takes Lua]
Under the Lua config, `hyprctl dispatch` evaluates its argument as Lua:
`hyprctl dispatch 'hl.dsp.focus({ workspace = "2" })'`, not
`hyprctl dispatch workspace 2`.
:::
