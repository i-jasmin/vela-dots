---
title: Dashboard
description: The drawer on the bar's clock -- your day, the music, the system, and a focus timer.
---

Click the bar's clock, or press **super + D**. The dashboard is a drawer that
grows out of the bar: it drops from a top bar, rises from a bottom one, and
slides out of a left or right rail, laid out again for the tall shape rather
than squashed.

Four tabs, one job each. **Tab** or the number keys move between them.

| Tab | Shows |
| --- | --- |
| **Home** | the clock, the weather with the next five hours, the day's events, and a month that folds out under them |
| **Media** | what is playing, a spinning cover inside a visualiser that moves with the sound, and the controls |
| **System** | live CPU, memory and GPU rings, the CPU's last minute, the busiest processes, [pending updates](#updates), and a card for [Claude Code and Codex](../ai-tools/) while they are open |
| **Focus** | a focus timer, its lengths, and two switches |

## The month

Home's month is the calendar. Fold it out with the arrow on the day's card,
by right-clicking the bar clock, or with **super + shift + D**. Pick a day and
the timeline follows it. Everything about it -- accounts, events, reminders --
is on [Calendar](../calendar/).

## Updates

The System tab has a line for package updates, once vela has checked:
**5 updates · 2 security**, or **Up to date**. When a newer kernel is
installed than the one running, it says **Reboot recommended**.

Click it for the list. Updates that need something from you come first --
a new kernel wants a reboot, a new Hyprland a fresh login -- and the rest
follow as old and new versions.

vela checks two minutes after you log in, then every six hours, with
`dnf5 check-update` (`updates.checkCommand` in
[settings](../../configure/settings/#shelljson)). It checks again when you
open the tab after installing or updating anything, so the line does not go
on counting what you have just installed. Updating is up to you: vela only
looks.

To stop the checks, switch off **Check for updates** in Settings → General.

## The focus timer

Start a session on the Focus tab; the timer keeps running when the drawer
closes.

- **Hold notifications** keeps anything that is not urgent back until the
  session ends, then shows it all at once as one digest.
- **Countdown in the bar** swaps the bar's clock for the time left.

## The other drawers

The status popouts, the launcher and the power menu hang off the bar the same
way. Only one is out at a time: opening any of them puts away whichever was
open, and the bar stays solid through the change.
