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

Yes -- put them in `~/.config/hypr/conf/local.lua`. It is loaded last and never
committed. See [Hyprland and this machine](../../configure/hyprland/).

## Why does git show changed files after I pick a wallpaper?

The colour files for Hyprland, kitty and fuzzel live in the repo, so they
exist before your first wallpaper, and every retint rewrites them. It is
expected; `git update-index --skip-worktree <file>` hides one if it bothers
you.

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
