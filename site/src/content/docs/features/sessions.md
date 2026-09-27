---
title: Sessions
description: Save the windows you work with and bring them back, at login if you like.
---

**super + alt + S** (or **R**) opens the sessions panel.

- **Save current** records each window's app, workspace, position, size and
  working directory.
- **Restore** brings a layout back. Windows of the right app that are already
  open are moved into place, and anything missing is started straight onto its
  saved workspace. Floating windows come back at their size and position, and
  terminals come back in the folder they were left in.

## At login

The layout as it last stood is kept automatically. With **Restore last
session on login** on (Settings → General), it comes back the first time the
shell starts after you log in. Restarting the shell during a session does not
reopen anything.

## Good to know

- An app needs a desktop entry to be relaunched; one without is skipped, and
  named in `vela shell log`.
- Saved sessions are in `~/.local/state/vela/sessions.json`.
