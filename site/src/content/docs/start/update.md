---
title: Update and uninstall
description: Keep vela up to date, or take it off again.
---

## Update

Run the installer again -- it pulls the latest version and re-links:

```sh wrap
curl -fsSL https://vela.ijasmin.it/install.sh | bash
```

Or, by hand -- the second line links anything the update added:

```sh
git -C ~/.local/share/vela-dots pull
~/.local/share/vela-dots/bootstrap.sh --link
```

The shell reloads itself when its files change. After a larger update, restart
it with **super + shift + R** or `vela shell restart`.

## Your files

What you change stays yours. `~/.config/vela`, `~/.config/hypr`,
`~/.config/kitty`, `~/.config/fuzzel` and `~/.config/fish` are real folders in
your home with vela's own files linked into them, one by one. Everything else
in them is yours and never goes near the repo, so an update cannot change it
or trip over it:

- `~/.config/vela/shell.json`, your settings, and `keybinds.json`, your keybinds
- the palette made from your wallpaper: Hyprland's, hyprlock's, kitty's and
  fuzzel's colour files
- `~/.config/hypr/hypridle.conf`, when the screen dims, locks and sleeps
- `~/.config/hypr/conf/local.lua`, this machine's monitors and keyboard
- fish's variables and functions, and anything another program keeps there

The first copy of the settings, the idle times and the palette comes from
`defaults/` in the repo, once, when you install. A setting vela adds later
takes its default until you change it.

:::note
Installs from before this layout had those folders linked whole into the
repo, so your settings and palette were written into it and an update could
refuse to run. The installer moves them out the first time it runs: your files
stay where they are, byte for byte, and only what is around them changes. Use
the installer for that first update, not `git pull`, which would stop on them.
:::

If an update still stops, git names the file: one of vela's own, changed
in place. Put the change somewhere of your own -- `conf/local.lua`, for
Hyprland -- or undo it with `git -C ~/.local/share/vela-dots checkout -- <file>`,
and run the installer again.

## Uninstall

```sh
~/.local/share/vela-dots/bootstrap.sh --unlink     # remove every link vela made
```

Your own files stay where they are, in `~/.config/vela`, `~/.config/hypr` and
the rest; delete those folders if you want them gone. Your old configs, if
there were any, are in `~/.local/state/vela/backup-<date>/`; move them back
into `~/.config`. Then delete `~/.local/share/vela-dots` and
`~/.local/state/vela`.

The packages stay installed. Hyprland, Quickshell and the rest are ordinary
Fedora packages; remove the ones you do not want with `sudo dnf remove`.
