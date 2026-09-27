---
title: Update and uninstall
description: Keep vela up to date, or take it off again.
---

## Update

Run the installer again -- it pulls the latest version and re-links:

```sh wrap
curl -fsSL https://raw.githubusercontent.com/i-jasmin/vela-dots/main/install.sh | bash
```

Or, by hand:

```sh
git -C ~/.local/share/vela-dots pull
```

The shell reloads itself when its files change. After a larger update, restart
it with **super + shift + R** or `vela shell restart`.

:::note
Some of vela's files are rewritten whenever the palette changes (Hyprland's,
kitty's and fuzzel's colours), and `shell.json` whenever you change a setting.
They live in the repo, so `git status` shows them as changed; that is expected,
and a pull still works while they are only yours.
:::

## Uninstall

```sh
~/.local/share/vela-dots/bootstrap.sh --unlink     # remove every link vela made
```

Your old configs, if there were any, are in `~/.local/state/vela/backup-<date>/`;
move them back into `~/.config`. Then delete `~/.local/share/vela-dots` and
`~/.local/state/vela`.

The packages stay installed. Hyprland, Quickshell and the rest are ordinary
Fedora packages; remove the ones you do not want with `sudo dnf remove`.
