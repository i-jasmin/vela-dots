---
title: Keybinds
description: Every shortcut, and how to add or change one.
---

**super + <** -- or **super + /** on a US keyboard -- shows all of these,
searchable, built from what Hyprland actually has bound at that moment.

## The shell

| Keys | Opens |
| --- | --- |
| super + < | this list (super + / on US) |
| tap super, or super + tab | the [workspace overview](../../features/windows/#the-overview) |
| super + space | the [launcher](../../features/launcher/) (super + shift + space: fuzzel) |
| super + D / super + shift + D | the [dashboard](../../features/dashboard/) / with the month out |
| super + V | [clipboard history](../../features/capture/#clipboard-history) |
| super + W / super + shift + W | the [wallpaper switcher](../../features/theming/) / previous wallpaper |
| super + shift + S | [capture](../../features/capture/) (again while recording: stop) |
| super + N | the notification history |
| super + ctrl + N / super + shift + N | do not disturb / clear notifications |
| super + alt + S (or R) | [sessions](../../features/sessions/) |
| super + escape | the [power menu](../../features/lock/#the-power-menu) |
| super + L | lock |
| super + I | settings |
| super + shift + R | restart the shell |

## Windows

| Keys | Does |
| --- | --- |
| alt + tab (+ shift) | the window picker; let go of alt to switch |
| super + return / E / B | terminal / files / your default browser |
| super + Q | close |
| super + F / super + shift + F | fullscreen / maximise |
| super + shift + V | float, or tile again |
| super + arrows / super + shift + arrows | focus / move a window |
| super + 1..9 / super + shift + 1..9 | go to / move the window to a workspace |
| super + R | resize mode (arrows or hjkl; escape to leave) |
| super + S / super + shift + X | the scratchpad / send a window to it |

## Adding or changing one

The binds live in `~/.config/hypr/conf/binds.lua` (**Settings → Keybinds**
opens it). Save, and Hyprland reloads. Give every bind a description -- it is
what places it in the list above:

```lua
hl.bind("SUPER + M", hl.dsp.exec_cmd("gnome-calculator"), { description = "Apps: Calculator" })
```

`"Group: Action"` is a row in that group; `"Group › Action"` a quieter
secondary one. A bind without a description is listed under *Unsorted*.
