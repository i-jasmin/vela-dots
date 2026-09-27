---
title: How it is built
description: A map of the repo, for anyone reading or changing the code.
---

## The repo

```
packages/          one stow package per target, each mirroring $HOME
  vela/            ~/.config/vela        shell.json, matugen.toml, templates/
  quickshell/      ~/.config/quickshell/vela   the shell itself
  bin/             ~/.local/bin/vela     the `vela` command
  hypr/            ~/.config/hypr        hyprland.lua + conf/*.lua, hypridle, hyprlock
  kitty/ fish/ fuzzel/ starship/ bash/   terminal, shells, prompt, fallback launcher
install.sh         the one-line install
bootstrap.sh       packages and linking
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

A few rules the code keeps:

- **Nothing hard-codes a colour, size or duration.** They come from `Colours` and
  `Appearance`.
- **A surface asks a service; it does not run a process.** Anything that shells
  out lives in `services/`.
- **Every key in `shell.json` applies live**, without restarting the shell.

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
npm run dev        # http://localhost:4321/vela-dots/
```
