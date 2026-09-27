---
title: IPC
description: Driving the shell from scripts and keybinds.
---

Everything the shell does can be asked for from outside it. A keybind, a click
and a terminal command are the same code path.

```sh
qs -c vela ipc show                               # everything, live
qs -c vela ipc call shell toggle launcher         # dashboard, launcher, overview, clipboard,
                                                  # capture, calendar, power, wallpaper,
                                                  # settings, keybinds, ...
qs -c vela ipc call shell altTab 1
qs -c vela ipc call bar popout network            # bluetooth, output, network, power,
                                                  # workspaces, notifications, privacy
qs -c vela ipc call bar toggleStatus              # fold the status items away
qs -c vela ipc call notifs toggleDnd              # or clear
qs -c vela ipc call nightlight toggle             # or resume, or: set 4000
qs -c vela ipc call wallpaper apply <path>        # or revert
qs -c vela ipc call lock lock                     # or isLocked
```

With no shell running these exit with 255. That is what lets hypridle fall
back to hyprlock, so an idle machine still locks if the shell has died.
