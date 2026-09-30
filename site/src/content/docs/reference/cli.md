---
title: The vela command
description: Everything the vela command does.
---

`vela` is on your `PATH` once vela is installed (`~/.local/bin/vela`).

## Wallpaper and colours

```sh
vela wallpaper <image> [--light|--dark]   # set the wallpaper and retheme everything
vela wallpaper                            # print the current one
vela theme [light|dark|toggle]            # switch light and dark, and retheme
vela retint <image> [light|dark] [scheme] # regenerate every palette from an image
vela colours                              # print the current palette
```

## The shell

```sh
vela shell start      # start it (if it is not running)
vela shell stop
vela shell restart    # super + shift + R does the same
vela shell log        # follow its log
```

## vela doctor

```sh
vela doctor
```

Checks what vela needs and says what is missing: the Fedora release,
Hyprland's version, the essential tools (with the versions of Quickshell and
matugen, and a note when matugen is older than 4) and the optional ones (each
with what it is for), the icon font, whether every config is linked from the
repo, the palette, and -- run from inside Hyprland -- whether the shell and
hypridle are running. It exits with 1 when something essential is missing.

## Calendars

```sh
vela calendar list              # your accounts, and how their last sync went
vela calendar sync [id]         # sync all, or one
vela calendar remove <id>       # remove an account
vela calendar keyring           # check the keyring the passwords are in
```

Adding accounts and events is done from the shell; the [calendar
guide](../../features/calendar/#the-command-line) covers the rest.

## Claude Code and Codex

```sh
vela ai status                  # plan usage and what each session is doing (JSON)
vela ai claude-usage            # ask Claude Code for what /usage shows
vela ai icons [--force]         # fetch the Claude Code and Codex logos
vela ai connect claude|codex    # add vela's status line and hooks to that tool (backup first)
vela ai disconnect claude|codex # take them out again
```

`vela ai statusline` and `vela ai hook <tool>` are what the tools run once
connected. See [Claude Code and Codex](../../features/ai-tools/).

## Other

```sh
vela greet                      # the terminal greeting
vela idle on power|battery      # succeeds only on that power source (what hypridle checks)
vela idle dim|undim             # dim the backlight for idle, and restore it
```
