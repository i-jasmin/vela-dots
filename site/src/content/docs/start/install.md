---
title: Install
description: Install vela on Fedora with one command, or by hand.
---

## What you need

- **Fedora Workstation, 42 or newer.** Other Fedora editions work if they have a
  login screen (GDM, SDDM); a minimal install can start Hyprland from a console.
- An internet connection, and an account that can use `sudo`.

## The one-liner

```sh wrap
curl -fsSL https://raw.githubusercontent.com/i-jasmin/vela-dots/main/install.sh | bash
```

It asks for your password once, then:

1. **Checks** that it is on Fedora and not running as root.
2. **Clones** vela to `~/.local/share/vela-dots` (or updates it, if it is already there).
3. **Installs the packages** -- Hyprland, Quickshell, matugen and the rest -- after
   enabling the COPR repositories they come from. If one that the desktop
   cannot run without fails to install, it stops here and says which.
4. **Links the configs** into place. Anything already at one of vela's paths is
   moved aside first, never deleted (see below).
5. **Sets a first wallpaper**, so the colour palette exists before you log in.
   Three come with vela; they are copied to `~/Pictures/Wallpapers` only if that
   folder has no images of its own.
6. **Runs [`vela doctor`](../../reference/cli/#vela-doctor)**, which lists anything missing.

Then **log out and choose Hyprland** on the login screen -- on GDM, the gear
button in the corner once you have picked your name.

:::tip
The first thing to press once you are in is **super + <** (or **super + /** on a
US keyboard). It shows every keybind.
:::

## Your old configs are safe

vela owns these paths in your home folder:

| Path | What it is |
| --- | --- |
| `~/.config/hypr` | Hyprland, hypridle, hyprlock |
| `~/.config/quickshell/vela` | the shell itself |
| `~/.config/vela` | vela's settings and colour templates |
| `~/.config/kitty`, `~/.config/fish`, `~/.config/fuzzel` | terminal, shell, fallback launcher |
| `~/.config/starship.toml` | the prompt |
| `~/.local/bin/vela` | the `vela` command |
| `~/.bashrc.d/vela.sh` | the terminal greeting, for bash |

If any of them already exists, it is moved -- whole -- to
`~/.local/state/vela/backup-<date>/` before vela's is linked in. To go back to
yours, see [Update and uninstall](../update/#uninstall).

## Options

Set these in front of `bash` in the one-liner:

| Variable | Does |
| --- | --- |
| `VELA_DIR=~/src/vela-dots` | clone somewhere else (your configs link into it, so it has to stay put) |
| `VELA_BRANCH=main` | install a different branch |
| `VELA_REPO=<url>` | install from a fork |
| `VELA_SKIP_PACKAGES=1` | only link; install nothing |

```sh wrap
curl -fsSL https://raw.githubusercontent.com/i-jasmin/vela-dots/main/install.sh | VELA_DIR=~/src/vela-dots bash
```

## NVIDIA

If your machine has an NVIDIA card and no NVIDIA driver, the installer says so
at the end. The driver comes from RPM Fusion; see [NVIDIA](../../help/nvidia/).

## By hand

The installer is a thin wrapper; everything it does is in the repo:

```sh
git clone https://github.com/i-jasmin/vela-dots ~/.local/share/vela-dots
cd ~/.local/share/vela-dots
./bootstrap.sh                       # packages, then links
vela wallpaper ~/Pictures/Wallpapers/some-image.jpg
```

`./bootstrap.sh --packages` and `./bootstrap.sh --link` do one half each;
`./bootstrap.sh --targets` lists the paths above.
