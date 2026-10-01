---
title: FAQ
description: Short answers to common questions.
---

## Does it work on other distributions?

vela is written for Fedora and installs with dnf. The shell itself is plain
Quickshell and would run elsewhere, but the installer, the package list and
some defaults (the update check, for one) are Fedora's.

## Will it overwrite my configs?

No. Anything already at one of vela's paths is moved to
`~/.local/state/vela/backup-<date>/` first. See
[Install](../../start/install/#your-old-configs-are-safe).

## Can I keep my own keybinds, monitors or keyboard layout?

Yes. Keybinds: change them in **Settings → Keybinds**, which keeps them in
`~/.config/vela/keybinds.json`, a file no update touches -- see
[Keybinds](../../configure/keybinds/). Monitors and the keyboard layout go in
`~/.config/hypr/conf/local.lua`, which is loaded last and lives only in your
home. See [Hyprland and this machine](../../configure/hyprland/).

## Will an update undo my settings?

No. Your settings, keybinds, palette, idle times and `conf/local.lua` live in
your home, in folders vela only links its own files into; the repo never has
them, so an update cannot change them. See
[Your files](../../start/update/#your-files).

## Why does git show changed files after I pick a wallpaper?

On an install from before your files were moved out of the repo, the colour
files lived in it, and every retint rewrote them. Run the installer once more:
it moves them into your home, and `git status` stays clean from then on.

## Why does kitty open fish? Can I have bash?

kitty opens fish (`shell fish` in `~/.config/kitty/kitty.conf`); your login
shell stays what it was -- bash on a stock Fedora -- so a console or SSH is
still bash, with the same prompt and greeting. For bash in kitty too, comment
that line out. For fish everywhere, make it your login shell:
`chsh -s /usr/bin/fish`.

## How do I turn the terminal greeting off?

`VELA_GREETING=off` in your environment; in fish, `set -Ux VELA_GREETING off`.

## How do I go back to GNOME?

Log out and pick GNOME on the login screen. vela does not change GNOME; to take
it off entirely, see [Uninstall](../../start/update/#uninstall).
