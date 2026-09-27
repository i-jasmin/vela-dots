---
title: Troubleshooting
description: Finding out what is wrong, and the fixes for the usual problems.
---

## Start here

```sh
vela doctor
```

It lists what is missing, not linked or not running, with the command that
fixes most of them.

## The shell

```sh
vela shell log                                  # its log, live
vela shell restart                              # or super + shift + R
qs -c vela --log-rules 'qml.debug=true'         # run it in the foreground, chattily
```

## Nothing appears after logging in

- **Is it Hyprland?** On the login screen, the session must be *Hyprland*.
- **Is the shell running?** From a terminal (super + return): `vela shell start`,
  then `vela shell log`.
- **Is Hyprland new enough?** vela's config needs 0.56 or newer; `vela doctor`
  says which you have.
- **Icons show as words?** The Material Symbols font is missing; run the
  installer again, or see `vela doctor`.

## Hyprland's config

```sh
Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
```

checks it without applying anything.

## Stuck on a locked screen

If the password is not accepted, or the lock screen is blank, switch to a
console with **ctrl + alt + F3** and log in. Then, in order:

1. **The shell is still running** -- release the lock:

   ```sh
   export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1
   qs -c vela ipc call lock unlock
   ```

2. **The shell has died** -- the compositor keeps the session locked (that is
   how screen locking is meant to work). Clear it:

   ```sh
   for d in /run/user/$(id -u)/hypr/*/; do
       s=$(basename "$d")
       HYPRLAND_INSTANCE_SIGNATURE=$s hyprctl eval 'hl.clear_crashed_lockscreen()' && break
   done
   ```

3. **Neither works** -- end the session: `hyprctl dispatch exit`, or reboot.

Switch back with **ctrl + alt + F1** (or F2).

## Colours did not change in an app

GTK apps take a new palette the next time they start; fuzzel and hyprlock the
next time they open. The shell, Hyprland, kitty and cava change at once. If
none of them changed, run `vela wallpaper <image>` in a terminal and read what
it says.

## Calendar problems

See [the calendar guide's troubleshooting](../../features/calendar/#troubleshooting).
