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

## Changing one

**Settings → Keybinds** lists every bind on the keys it is on now. Click a
bind's keys and press the new ones; **esc** cancels. For a row like super +
1..9, hold the new modifiers and press any of its keys: the keys stay, the
modifiers change.

- **Two binds on the same keys** are both shown in red, with what else is on
  them, and **Apply** waits until they differ. (That is also how to swap two:
  give one the other's keys, then give the other new ones.)
- **Nothing changes until Apply**, which saves your changes and reloads
  Hyprland. **Discard** drops them.
- **↺** puts one bind back on its default; **⊘** turns it off. **Reset** puts
  every bind back, and asks first. Your own binds stay.
- Alt + tab and the mouse binds are fixed, marked with a lock: letting go of
  alt is what switches windows, and a mouse button cannot be recorded.

A key on its own, with nothing held, is only allowed for keys nobody types
(F1–F24, the media keys, Print): super + C, not C.

## Your own

At the bottom of the page, **Add a keybind**: a name, a command, and the keys.
The command is anything you would type in a terminal -- `code`, `firefox
--new-window`, a script of yours. The name is how the cheatsheet (super + <)
lists it, under *Custom*.

## Where they are kept

Your changes go to `~/.config/vela/keybinds.json`, not into vela's files, so
an update of the dots never puts your keys back or collides with them. The
defaults are in `~/.config/hypr/conf/binds.lua`; a bind you have not changed
follows it, so an update that moves a default moves it for you too.

The file is plain JSON, and fine to edit by hand; `hyprctl reload` applies it:

```json
{
  "changed": { "shell.launcher": "SUPER + A", "windows.pin": false },
  "custom": [ { "name": "VS Code", "keys": "SUPER + C", "command": "code" } ]
}
```

`changed` is a bind's id and its new keys, or `false` for off. The ids are in
`binds.lua`, the first word of each `K.bind(...)`. If the file cannot be read,
or Hyprland refuses a combination in it, that bind stays on its default and
the Keybinds page says why.
