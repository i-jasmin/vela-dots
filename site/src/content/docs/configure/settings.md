---
title: Settings
description: The settings window, and shell.json -- the file behind it.
---

**super + I** opens the settings window. Every change applies at once; there
is nothing to save.

| Page | Covers |
| --- | --- |
| **General** | where you are (for the weather and sunset), units, evening warmth, your picture, the wallpaper / screenshot / recording folders, restoring your session at login, what changed after an update |
| **Appearance** | the palette and its variant, light / dark / auto, corner radius, panel opacity, motion (full, reduced or off) and its speed |
| **Bar** | which edge, floating or attached, autohide, the dock and its pinned apps and stacks |
| **Notifications** | do not disturb, where cards go, how long they stay, how many stack, the focus digest |
| **Calendars** | your accounts, each calendar's colour and whether it shows, reminders, how often they sync |
| **Launcher** | what it searches, how many results, the web search engine |
| **Lock screen** | when the screen dims, locks, goes dark and suspends (on a laptop, on power and on battery), what the lock screen shows, the fingerprint reader |
| **Keybinds** | where the binds live, and a button that opens the file |
| **Modules** | which items each end of the bar carries, and in what order |

## shell.json

The window writes `~/.config/vela/shell.json`, and the shell watches the file:
edit it by hand and the change applies as soon as you save. A few settings
that rarely change are only in the file. The groups, with the keys worth
knowing:

| Key | Default | |
| --- | --- | --- |
| `appearance.mode` | `"auto"` | `"light"`, `"dark"`, or `"auto"` (dark after sunset) |
| `appearance.scheme` | `"scheme-tonal-spot"` | matugen's variant -- how colourful the palette is |
| `appearance.eveningWarmth.*` | on, from sunset, 90 min | the evening warmth; `screen: true` warms the screen too (hyprsunset) |
| `bar.position` | `"top"` | `"top"`, `"bottom"`, `"left"`, `"right"` |
| `bar.floating` | `true` | a gap round the bar; `false` attaches it to its edge |
| `bar.autohide.mode` | `"never"` | when the bar hides |
| `bar.workspaces.count` | `5` | workspaces always shown on the bar |
| `bar.modules.left / centre / right` | | the items at each end, in order |
| `dock.enabled`, `dock.behaviour` | `true`, `"autohide"` | the dock, and whether it hides |
| `dock.pinned`, `dock.stacks` | | desktop entries, and folders |
| `notifications.position` | `"top-right"` | where cards appear |
| `notifications.timeout` | `6000` | how long a card stays, in ms |
| `launcher.wallpaperDir` | `"~/Pictures/Wallpapers"` | where the wallpaper switcher looks |
| `launcher.webSearch` | DuckDuckGo | the search URL; the query is added to the end |
| `capture.saveDir`, `capture.recordDir` | `~/Pictures/Screenshots`, `~/Videos/Recordings` | where captures go |
| `capture.defaultAction` | `"copy"` | what Enter does in capture |
| `clipboard.keep` | `200` | how many entries the history keeps |
| `weather.location` | `"auto"` | `"auto"` (from your connection) or a city |
| `weather.units` | `"metric"` | or `"imperial"` |
| `sessions.restoreOnLogin` | `true` | bring the last layout back at login |
| `dashboard.focusTimer.*` | 25 min, 4 sessions | the focus timer, and its two switches |
| `updates.checkCommand` | `dnf5 check-update --refresh` | how updates are counted |

The file itself carries a comment on most keys.

:::note
The keybinds are not in `shell.json`. They are Hyprland's, in
`~/.config/hypr/conf/binds.lua` -- see [Keybinds](../keybinds/).
:::
