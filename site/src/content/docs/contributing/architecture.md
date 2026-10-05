---
title: How it is built
description: A map of the repo, for anyone reading or changing the code.
---

## The repo

```
packages/          one stow package per target, each mirroring $HOME
  vela/            ~/.config/vela        matugen.toml, templates/
  quickshell/      ~/.config/quickshell/vela   the shell itself
  bin/             ~/.local/bin/vela     the `vela` command
  hypr/            ~/.config/hypr        hyprland.lua + conf/*.lua, hyprlock
  kitty/ fish/ fuzzel/ starship/ bash/   terminal, shells, prompt, fallback launcher
defaults/          the first copy of the files that are then the user's:
                   shell.json, hypridle.conf, the palette files
install.sh         the one-line install
bootstrap.sh       packages and linking
packaging/fedora/  the matugen build vela installs (Fedora's is too old)
wallpapers/        the three that come with vela
site/              this documentation
docs/              notes on Quickshell and Hyprland behaviour
```

## The shell

Quickshell QML, in `packages/quickshell/.config/quickshell/vela`:

| Directory | Holds | Imported as |
| --- | --- | --- |
| `config/` | `Config`, the live view of `shell.json` | `qs.config` |
| `tokens/` | `Appearance` (sizes, radii, motion) and `Colours` (the palette) | `qs.tokens` |
| `services/` | singletons wrapping the system: `Hypr`, `Audio`, `Net`, `Bt`, `Power`, `Notifs`, `Wallpaper`, `ShellState`, ... | `qs.services` |
| `components/` | building blocks: `Panel`, `Pill`, `Row`, `Slider`, `Toggle`, `Segmented`, and the motion pieces | `qs.components` |
| `modules/` | what you see, one directory per surface | `qs.modules.bar` etc. |

Quickshell writes the `qmldir` files itself, so a directory is a module with
no registration step.

A few rules the code keeps:

- **Nothing hard-codes a colour, size or duration.** They come from `Colours` and
  `Appearance`.
- **A surface asks a service; it does not run a process.** Anything that shells
  out lives in `services/`.
- **Every key in `shell.json` applies live**, without restarting the shell.

## Drawers on the bar

The dashboard, the status popouts, the launcher and the power menu are one
drawer, `modules/attached/AttachedDrawer.qml`, that grows out of the bar on
whichever edge it is. Opening a popout while another is out slides the drawer
along the bar and crosses the contents over. A tray app's menu is drawn by
`modules/popouts/TrayMenu.qml` from what the app sends.

The dashboard's tabs read these services:

| Tab | Services |
| --- | --- |
| Home | `Time`, `Weather`, `Calendar` (khal) |
| Media | `Players` (MPRIS; cava or the PipeWire peak meter for the visualiser) |
| System | `SysInfo`, `Updates`, `AiUsage` |
| Focus | `Focus` |

## The palette

There is one matugen config, `~/.config/vela/matugen.toml`, and one command
that runs it, `vela retint`: the wallpaper switcher, the settings window and
the CLI all go through it. It passes `--source-color-index 0` when matugen has
it -- without a terminal attached, matugen 4 will not choose a source colour
and exits -- and when matugen cannot choose either way, it works out the
image's dominant colour itself and builds the palette from that.

| Target | Written to | Picks it up |
| --- | --- | --- |
| the shell | `~/.local/state/vela/scheme.json` | live, no reload -- `tokens/Colours.qml` watches it, and every colour eases across |
| Hyprland | `~/.config/hypr/conf/colours.lua` | live -- Hyprland reloads when a required file changes |
| hyprlock | `~/.config/hypr/colours.conf` | next lock |
| kitty | `~/.config/kitty/colours.conf` | live -- `vela retint` sends `set-colors` to every instance |
| fuzzel | `~/.config/fuzzel/colours.ini` | next launch |
| GTK | `~/.config/gtk-{3,4}.0/gtk.css` | next start of each app (GTK has no reload) |
| fastfetch | `~/.config/fastfetch/config.jsonc` | next run |
| cava | `~/.config/cava/config` | live -- `vela retint` sends a running cava `SIGUSR2` |

- Switching light and dark sets the preference browsers and libadwaita apps
  follow first, then runs the retint, so the other apps follow the shell.
- Just before a retint the shell holds a frozen frame over every window and
  fades it away on its own palette curve once the apps have repainted
  underneath (`modules/overlays/Recolour.qml`).
- fastfetch and cava have no include mechanism, so, like GTK, those files are
  written whole.
- The colour files are written into the user's own folders, never the repo,
  so a retint does not show in `git status`. Their first copies come from
  `defaults/`, so the configs are valid before a first wallpaper.
- The terminal greeting (`vela greet`) draws in kitty's palette slots -- 250
  to 255 for the accents, 249 for the separator -- rather than fixed colours,
  so a greeting already on screen recolours with the rest. It runs once per
  terminal window, from fish (`functions/fish_greeting.fish`) or from bash on
  a console or over SSH (`~/.bashrc.d/vela.sh`).

## Keybinds

The defaults are in `packages/hypr/.config/hypr/conf/binds.lua`, each under a
stable id: `K.bind("shell.launcher", ...)`. `conf/keybinds.lua` applies the
user's `keybinds.json` on top of them. The cheatsheet is built from
`hyprctl binds` each time it opens, and a bind's description places it there:
`"Group: Action"` is a row in that group, `"Group › Action"` a quieter
secondary row, and a bind without one is listed under Unsorted with its raw
dispatcher. Give new binds a description.

## Before writing QML or config

The repo's `docs/` folder records how Quickshell and Hyprland actually behave
here, found by trying rather than from their documentation:

- [`docs/quickshell-notes.md`](https://github.com/i-jasmin/vela-dots/blob/main/docs/quickshell-notes.md) -- Quickshell's gotchas
- [`docs/hyprland-notes.md`](https://github.com/i-jasmin/vela-dots/blob/main/docs/hyprland-notes.md) -- Hyprland 0.56 and the Lua config
- [`docs/motion.md`](https://github.com/i-jasmin/vela-dots/blob/main/docs/motion.md) -- how things move, and the tokens for it

## This site

Built with [Starlight](https://starlight.astro.build) from `site/`:

```sh
cd site
npm install
npm run dev        # http://localhost:4321/
```
