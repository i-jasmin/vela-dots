# vela

A Hyprland desktop shell and dotfiles for Fedora, built on
[Quickshell](https://quickshell.org). Material 3 throughout, retinted from the
current wallpaper.

Written from scratch, with [caelestia-dots/shell](https://github.com/caelestia-dots/shell)
and [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) as references.

Targets **Hyprland 0.56** (Lua config manager), **Quickshell 0.3.1** and
**matugen 4**.

**Documentation: [i-jasmin.github.io/vela-dots](https://i-jasmin.github.io/vela-dots/)**

## Layout

```
packages/          one stow package per target, each mirroring $HOME
  vela/            ~/.config/vela        shell.json, matugen.toml, templates/
  quickshell/      ~/.config/quickshell/vela   the shell itself
  bin/             ~/.local/bin/vela     the `vela` command
  hypr/            ~/.config/hypr        hyprland.lua + conf/*.lua, hypridle, hyprlock
  kitty/ fish/ fuzzel/ starship/ bash/   terminal, shells, prompt, fallback runner
install.sh         the one-line install: clone, then bootstrap.sh
bootstrap.sh       packages + linking
packaging/fedora/  the matugen 4 build vela installs, since Fedora's is 3.1
                   (built by .github/workflows/packages.yml)
wallpapers/        the three that come with it
site/              the documentation site (Starlight), published to GitHub Pages
docs/              verified Quickshell and Hyprland behaviour -- read these
                   before writing QML or config
```

Inside the shell (`packages/quickshell/.config/quickshell/vela`):

| Directory | Holds | Imported as |
|---|---|---|
| `config/` | `Config`, the live view of `~/.config/vela/shell.json` | `qs.config` |
| `tokens/` | `Appearance` (sizes, radii, motion -- see [`docs/motion.md`](docs/motion.md)) and `Colours` (the palette) | `qs.tokens` |
| `services/` | Singletons wrapping system state: `Hypr`, `Audio`, `Net`, `Bt`, `Power`, `Players`, `Notifs`, `Wallpaper`, `ShellState`, ... | `qs.services` |
| `components/` | Primitives: `Panel`, `Pill`, `Row`, `Slider`, `Toggle`, `Segmented`, `Icon`, ..., and the motion pieces `Morph`, `MorphBox`, `Stagger`, `Crossfade`, `Reveal` | `qs.components` |
| `modules/` | Screen furniture, one directory per surface | `qs.modules.bar` etc. |

Quickshell synthesises `qmldir` files, so directories are modules with no
registration step.

## Install

On Fedora (Workstation, 42 or newer), in a terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/i-jasmin/vela-dots/main/install.sh | bash
```

It clones the repo to `~/.local/share/vela-dots`, enables the COPRs and
installs the packages (with vela's own build of matugen 4 in place of
Fedora's older one), links the configs into place, sets a first wallpaper
so the palette exists, and ends with `vela doctor`, which lists anything
missing; `~/.local/state/vela/install.log` keeps a record of the run, with
dnf's warnings. Then log out and pick **Hyprland** on the login screen;
`hyprland.lua` starts the shell, hypridle, the polkit agent and the clipboard
watcher.

- **Your old configs are kept.** Anything already at one of vela's paths
  (`~/.config/hypr`, `kitty`, `fish`, `fuzzel`, `quickshell/vela`, `vela`,
  `starship.toml`) is moved, whole, to `~/.local/state/vela/backup-<date>/`.
- **Updating** is the same line again, or `git pull` in
  `~/.local/share/vela-dots`.
- **From a clone of your own:** `./bootstrap.sh` does the packages and the
  links; `--packages` and `--link` do one each, `--unlink` removes every link,
  `--matugen` installs vela's matugen if the one there is older.
- **kitty opens fish**; the login shell stays bash, so a console or SSH is
  still bash, with the same prompt and greeting.
- **NVIDIA:** the installer says so if the card has no driver; the driver
  comes from RPM Fusion (`akmod-nvidia`).

**Keyboard and monitors:** the keyboard layout is the one Fedora was set up
with (`localectl status` shows it; `localectl set-x11-keymap it` changes it).
Anything for one machine only -- a different layout, monitor positions,
scaling -- goes in `~/.config/hypr/conf/local.lua`, which is loaded last and
never committed:

```lua
hl.config({ input = { kb_layout = "it" } })
```

Wallpapers are read from `launcher.wallpaperDir` in `shell.json`
(`~/Pictures/Wallpapers` by default). Three come with vela, in `wallpapers/`,
and are copied there if the folder has no images of its own.

## Using it

```sh
vela wallpaper <path> [--light|--dark]   # set the wallpaper and retheme everything
vela wallpaper                           # print the current one
vela theme [light|dark|toggle]           # switch mode and retheme
vela retint <image> [light|dark] [scheme] # regenerate every palette from an image
vela shell start|stop|restart|log
vela colours                             # dump the generated palette
vela calendar [list|sync [id]|remove <id>] # the calendar accounts (added in Settings)
vela doctor                              # what is installed, linked and running
vela idle on power|battery               # true only on that power source (hypridle's check)
```

Configuration is `~/.config/vela/shell.json`, watched and applied live. The
settings window (super + I) writes the same file. A few rarely-changed keys
(clipboard history size, the calendar and update commands, the wallpaper
transition) are only in the file; everything else has a control:

| Page | Covers |
|---|---|
| General | location for the weather and sunset (found from your connection, or a city you name), units, evening warmth (the colours, and with hyprsunset the screen as well, on the same curve), profile picture, the wallpaper / screenshot / recording folders, restore at login, what changed after an update |
| Appearance | palette source and variant, light / dark / auto, corner radius, panel opacity, motion (full, reduced or off) and how fast it is -- windows included |
| Bar | edge, autohide, the dock and its pinned apps and stacks |
| Notifications | do not disturb, where the cards go, how long they stay, how many stack, the focus digest |
| Calendars | the accounts Home's month shows (Google, Outlook, iCloud, Nextcloud, any CalDAV server, any calendar link; as many as you like), each calendar's colour and whether it shows, reminders, how often they sync |
| Launcher | what it searches, how many results, the shortcuts in its field, the web search engine |
| Lock screen | when the screen dims, locks, goes dark and suspends (hypridle's timeouts, written into `hypridle.conf` and hypridle restarted) -- on a laptop, one set on power and one on battery, picked with the tabs over the sliders; the stats, media and audio ring it shows, the fingerprint reader |
| Keybinds | where the binds live (`binds.lua`, not shell.json) and a button that opens it |
| Modules | which items each end of the bar carries, in what order (including the privacy capsule) |

### Theming

There is one matugen config, `~/.config/vela/matugen.toml`, and one command
that runs it, `vela retint` -- the wallpaper switcher, the settings window and
the CLI all go through it. It passes `--source-color-index 0` when matugen has
it -- without a terminal attached, matugen 4 refuses to choose a source colour
and exits -- and when matugen cannot choose either way, it works out the
image's dominant colour itself and generates the palette from that. The
installer puts in vela's own matugen 4 (`packaging/fedora`), so the fallback
is only for a Fedora release vela has no build for yet.

| Target | Written to | Picks it up |
|---|---|---|
| the shell | `~/.local/state/vela/scheme.json` | **live**, no reload -- `tokens/Colours.qml` watches it, and every colour eases across to the new palette |
| Hyprland | `~/.config/hypr/conf/colours.lua` | **live** -- Hyprland reloads when a required file changes |
| hyprlock | `~/.config/hypr/colours.conf` | next lock |
| kitty | `~/.config/kitty/colours.conf` | **live** -- `vela retint` sends `set-colors` to every instance |
| fuzzel | `~/.config/fuzzel/colours.ini` | next launch |
| GTK | `~/.config/gtk-{3,4}.0/gtk.css` | **next start** of each app (GTK has no reload) |
| fastfetch | `~/.config/fastfetch/config.jsonc` | next run -- the terminal greeting, and plain `fastfetch`; a greeting already on screen follows **live**, because it is drawn in kitty's palette slots (see below) |
| cava | `~/.config/cava/config` | **live** -- `vela retint` sends a running cava `SIGUSR2`; the bars run from the primary container through primary to tertiary |

Switching light/dark (settings, the wallpaper switcher, `vela theme`, or sunset
under `"mode": "auto"`) recolours the shell by itself and re-runs the retint at once
so the other apps follow; the light/dark preference browsers and libadwaita
apps listen to is set first, before the palette is regenerated.

**The windows crossfade.** Apps repaint in one jump when their colours
change, each whenever it hears. So just before a retint the shell takes a
frozen frame of every window on screen and holds it over the window while the
apps recolour underneath, then fades the frames away on the shell's own
palette curve: every window crosses over to the new colours together, with the
shell (`modules/overlays/Recolour.qml`).

fastfetch and cava have no include mechanism, so like GTK those entries own
the whole file.

### Terminal greeting

A new terminal opens with `vela greet`: fastfetch in the palette, information
only -- no logo, no picture -- and never on a Linux console. Its colours are
kitty's palette slots (250-255 the accents, 249 the separator), not fixed
colour codes, so a greeting already on screen recolours with a new wallpaper
or a switch to light instead of keeping the old palette. It runs once per
terminal window, from fish, which kitty opens
(`functions/fish_greeting.fish`), or bash, on a console or over SSH
(`~/.bashrc.d/vela.sh`); `VELA_GREETING=off` in the environment turns it off
(`set -Ux VELA_GREETING off` in fish).

The Hyprland, hyprlock, kitty and fuzzel files live in the repo (so the configs
are valid before a first wallpaper), which means a retint shows up in
`git status`. `git update-index --skip-worktree <file>` hides that if it grates.

## Dashboard

The dashboard is a drawer attached to the bar, opened by clicking the bar clock or
super + D. It follows `bar.position`: it drops from a top bar, rises from a
bottom one, and slides out of a left or right rail, re-laid out for the tall
shape rather than squashed. Four tabs, one job each:

| Tab | Shows | From |
|---|---|---|
| Home | clock, weather with the next five hours, the day's events, and a month that folds out under them | `Time`, `Weather`, `Calendar` (khal) |
| Media | the playing track, a spinning cover in a radial visualiser, controls | `Players` (MPRIS, cava or the PipeWire peak meter) |
| System | live CPU, memory and GPU rings, the CPU's last 60 s, busiest processes | `SysInfo` |
| Focus | the session timer, its lengths, hold notifications, countdown in the bar | `Focus` |

The focus timer outlives the drawer. "Hold notifications" keeps non-urgent
toasts for one digest when the session ends, and "Countdown in the bar"
swaps the bar clock for the time left. Both are saved to `shell.json`
(`dashboard.focusTimer`).

The dashboard is not the only thing that hangs off the bar. The status
popouts, the launcher and the power menu use the same drawer
(`modules/attached/AttachedDrawer.qml`):

- **Popouts** grow out of the bar item that opened them. Opening another
  while one is open slides the drawer along the bar to the new item and
  crosses the contents over, rather than closing one and opening the other.
- **The launcher** is centred on a horizontal bar and a little way down a
  vertical one. Its height follows the results as you type, and the search
  field stays next to the bar, so on a bottom bar it is the bottom row.
- **The power menu** hangs off the power button's end of the bar, over a dim
  that leaves the bar itself lit.

One thing hangs off the bar at a time: opening any of them puts away
whichever was out, and the bar stays solid through the hand-over.


### Calendar

Home's month is the calendar: it folds out under the day (right-click the bar
clock, super + shift + D, or the arrow on the day's card), and the timeline or
agenda follows the day you pick. It shows any number of calendar accounts
together, added in Settings, Calendars:

- **Google, Outlook and any `.ics` link**: read-only, from the calendar's
  secret or published link.
- **iCloud, Nextcloud and any CalDAV server**: every calendar on the account,
  and events can be added, changed and deleted from the month.

Changes are written on the laptop first and uploaded by the next sync that
gets through, so a server at home catches up when you are back; a sync also
runs whenever the network comes back. Passwords and links are kept encrypted
in the keyring, never in a file. Each calendar can be coloured or switched
off.

Events remind you with a notification, at the reminder set on the event in
its calendar app or 10 minutes before by default, with **Join** for a
meeting link and **Snooze 5 min**; Settings, Calendars, *Reminders* changes
the default.

**The full guide, per-provider setup and troubleshooting:
[the calendar guide](https://i-jasmin.github.io/vela-dots/features/calendar/).**

## Notifications

Toasts pop up in a stack, one card per app, and the bell at the end of the
tray (super + N) opens the history. Both work like a phone's:

- **Open one out.** A notification that says more than fits has a chevron;
  it opens the card to the whole text, and a screenshot or photo it carries
  is drawn large. Clicking a notification does what its app asked; one that
  asked for nothing opens out instead.
- **Swipe it away.** Drag it sideways, or swipe with two fingers on the
  touchpad; a quick flick is enough, and scrolling up and down still
  scrolls. A swiped toast goes into the history; one swiped in the history
  is dismissed, and the list closes up behind it. Middle-click dismisses
  either outright, as × does in the history.

## Sessions

super + alt + S (or R) opens the sessions panel. **Save current**
records each window's app, workspace, position, size and working directory
to `~/.local/state/vela/sessions.json`. **Restore** brings a layout back:
windows of the right app that are already open are moved into place, and
anything missing is started through Hyprland with window rules, so it opens
straight onto its saved workspace. Floating windows come back at their size
and position, and terminals come back in the folder they were left in.

The layout as it last stood is kept automatically. With **Restore last
session on login** on (`sessions.restoreOnLogin`), it is brought back the
first time the shell starts after you log in. Restarting the shell during a
session does not reopen anything. An app needs a desktop entry to be
relaunched; one without is skipped and named in `vela shell log`.

## Keybinds

`packages/hypr/.config/hypr/conf/binds.lua`. **super + <** opens the cheatsheet,
which is built from `hyprctl binds` each time it opens, so it always shows
what is live. A bind's `description` places it: `"Group: Action"` is a row in
that group, `"Group › Action"` a quieter secondary row, and a bind without one
is listed under Unsorted with its raw dispatcher. Give new binds a description.

| Keys | Action |
|---|---|
| super + < | This list, filterable (super + / on a US layout, where `<` needs shift) |
| tap super / super + tab | Workspace overview: the bar's workspaces and a New workspace card after them. Drag a window to another card to move it there (onto New workspace to make one for it); within a card, drop a tiled window on another to swap them, or a floating one where you want it |
| super + space | Launcher (super + shift + space: fuzzel). In it: a sum or `5 km in mi` answers first, `=` for any sum, `:` for emoji, `;` for the clipboard |
| super + D / super + shift + D | Dashboard / the dashboard with the month out (right-click the bar clock for the same) |
| super + V | Clipboard history |
| super + W / super + shift + W | Wallpaper switcher (Tab picks light, dark or auto; Enter applies it with the wallpaper) / revert to the previous one |
| super + shift + S | Capture: screenshot, record, GIF, OCR (again while recording: stop) |
| super + escape | Power menu |
| super + L | Lock |
| super + I | Settings |
| super + N | Notification centre (the bell at the end of the tray; right-click it for do not disturb) |
| super + ctrl + N / super + shift + N | Do not disturb / clear notifications |
| alt + tab (+ shift) | Window picker; release alt to switch |
| super + return / E / B | Terminal / files / browser |
| super + Q / F / shift + F / shift + V | Close / fullscreen / maximise / float |
| super + 1..9, super + shift + 1..9 | Go to / move window to workspace. The bar shows the first `bar.workspaces.count` always, and every number up to the highest workspace in use |
| super + arrows, super + shift + arrows | Focus / move window |
| super + R | Resize mode (arrows or hjkl, escape to leave) |
| super + S / super + shift + X | Scratchpad / send window to it |
| super + shift + R | Restart the shell |

### IPC

A keybind, a click and a terminal command are the same code path:

```sh
qs -c vela ipc show                               # everything below, live
qs -c vela ipc call shell toggle launcher         # dashboard, launcher, overview, clipboard,
                                                  # capture, calendar, power, wallpaper, settings,
                                                  # keybinds, ...
qs -c vela ipc call shell altTab 1
qs -c vela ipc call bar popout network            # bluetooth, output, network, power, workspaces,
                                                  # notifications, privacy
qs -c vela ipc call bar toggleStatus              # fold the status run away behind its arrow
qs -c vela ipc call notifs toggleDnd|clear
qs -c vela ipc call nightlight toggle|resume|set 4000   # held by hand until the evening turns
qs -c vela ipc call wallpaper apply <path>|revert
qs -c vela ipc call lock lock|isLocked
```

With no shell running these exit 255, which is what lets hypridle fall back to
hyprlock.

## When something goes wrong

- **First:** `vela doctor` lists what is missing, unlinked or not running.
- **Shell log:** `vela shell log`, or run it in the foreground with
  `qs -c vela --log-rules 'qml.debug=true'`.
- **Hyprland config:** `Hyprland --verify-config -c ~/.config/hypr/hyprland.lua`
  checks keys, keysyms, rules and animation names without applying anything.
- **Under the Lua config, `hyprctl dispatch` takes Lua:**
  `hyprctl dispatch 'hl.dsp.focus({ workspace = "2" })'`, not
  `hyprctl dispatch workspace 2`. See `docs/hyprland-notes.md`.
- **Stuck on a locked screen:** from a TTY (ctrl + alt + F3), see
  "Getting out of a locked session" in `docs/hyprland-notes.md`. In short:
  `qs -c vela ipc call lock unlock` if the shell is alive,
  `hyprctl eval 'hl.clear_crashed_lockscreen()'` if it died.

## Status

Working: bar (workspaces, focused window, tray with menus, media, resources,
an arrow that folds everything up to the clock away -- the bell stays while
something is unread --
a privacy capsule while the mic, camera or screen is in use, battery (and
low-battery warnings at 20, 10 and 5%), status popouts for audio, network
with Wi-Fi passwords, Bluetooth with pairing, power), dock, dashboard (all four bar positions), sessions (save
and restore), launcher (with sums, unit conversion, emoji and clipboard search),
overview, window picker, clipboard
history, capture (screenshot / annotate / record / GIF / OCR), notifications
with a history centre and do-not-disturb, evening warmth that follows your
sunset (the palette, and the screen through hyprsunset if you ask), OSD,
wallpaper switcher with live retint, a calendar from any number of accounts,
power menu, lock screen (PAM, password), keybinds cheatsheet, and settings for
general, appearance, bar, notifications, calendars, launcher, lock screen,
keybinds and modules.

Not built yet, or only partly:

- Events are written only to CalDAV calendars. Google's two-way sync (which
  needs an OAuth app of your own) and Outlook's (which has no CalDAV) are not
  offered; their links cover reading. Repeating events, locations and notes
  are not edited from the shell yet.
- Clipboard pins are keyed by cliphist id, so pasting a pinned entry (which
  cliphist stores again under a new id) unpins it.
- Multi-monitor: surfaces open on the focused monitor and follow it; this has
  not been lived with on two screens.

## License

GPL-3.0. See [`LICENSE`](LICENSE).
