---
title: First steps
description: Your first five minutes in vela -- the keys worth knowing, and what to set up.
---

## The keys worth knowing first

| Keys | Opens |
| --- | --- |
| **super + <** (super + / on US) | every keybind, searchable |
| **super + space** | the launcher: apps, sums, unit conversions, emoji, the clipboard |
| **super + D** | the dashboard |
| **tap super** | the workspace overview |
| **alt + tab** | the window picker |
| **super + W** | the wallpaper switcher |
| **super + I** | settings |
| **super + escape** | the power menu |
| **super + L** | lock |

The full list is on [Keybinds](../../configure/keybinds/).

## Pick a wallpaper

**super + W** opens the switcher. Move with the arrows; the panel on the left
shows the palette each image would give, and a small bar shows it on. **Tab**
chooses light, dark or auto (auto follows sunset), and **Enter** applies both.
Put your own images in `~/Pictures/Wallpapers`.

## Set up the things that are yours

Open **settings** (super + I):

- **General** -- where you are, for the weather and for sunset (found from your
  connection, or a city you type), and units.
- **Calendars** -- add your accounts; they appear on the dashboard's month. See
  [Calendar](../../features/calendar/).
- **Lock screen** -- when the screen dims, locks and the machine suspends. A
  laptop gets one set of times on power and another on battery.
- **Bar** -- which edge it sits on, and whether it hides.

## Your keyboard

vela uses the keyboard layout Fedora was set up with. `localectl status`
shows it; to use a different one on this machine only, see
[Hyprland and this machine](../../configure/hyprland/#keyboard-layout).

## If something looks wrong

```sh
vela doctor
```

lists what is missing, not linked or not running. More in
[Troubleshooting](../../help/troubleshooting/).
