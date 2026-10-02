# Quickshell 0.3.1 notes (verified on Fedora)

Findings from probing the actual installed runtime, not from documentation.
Re-verify after a Quickshell upgrade.

## Module system

Quickshell **synthesises `qmldir` files automatically** for every directory under
the config root. Do not write `qmldir` files.

- The config root is the module `qs`.
- Subdirectories are `qs.<dir>`, nested ones `qs.modules.bar`.
- A file with `pragma Singleton` + a `Singleton` root is auto-registered as a singleton.
- A file without it is registered as a *type*; you must instantiate it.

```qml
import qs.services     // singletons: Time.timeStr
import qs.components   // types: StyledText { ... }
```

## Logging

`console.log` maps to **DEBUG**, which is hidden by default. `console.warn` maps to
WARN and is visible. During development:

```sh
qs -c vela --log-rules 'qml.debug=true'
```

Logs are also written to `/run/user/1000/quickshell/by-id/<id>/log.qslog`,
readable with `qs log <file>`.

## Services are async — nothing is populated at startup

Every D-Bus/IPC-backed singleton is **empty at `Component.onCompleted`** and fills
in roughly 1-3 seconds later. Measured:

| Singleton | at t=0 | at t=4s |
|---|---|---|
| `Hyprland.monitors` | 0 | 1 (eDP-1) |
| `Hyprland.workspaces` | 0 | 2 |
| `UPower.displayDevice.isLaptopBattery` | false | true |
| `Networking.devices` | 0 | 2 (eno1, wlp4s0) |
| `Bluetooth.defaultAdapter` | null | present |

**Consequence:** never read a service imperatively in `Component.onCompleted`.
Always bind declaratively, and give every widget a sensible empty/loading state.

## Gotchas

- `UPower.displayDevice.percentage` is **fractional 0-1**, not 0-100.
  72% battery reads as `0.7`. Multiply by 100 for display.
- `Quickshell.exit()` does not exist. Use `Qt.quit()`.
- `ShellScreen` has no `scale`; use `devicePixelRatio`.
- `Networking` has no `.wifi` shortcut. Filter `Networking.devices.values` by
  `type === DeviceType.Wifi`, then read `device.networks`.
- Enum-to-string helpers exist and are useful in logs:
  `UPowerDeviceState.toString()`, `NetworkConnectivity.toString()`,
  `DeviceType.toString()`.

## Available natively (no C++ plugin, no CLI scraping needed)

`Quickshell.Networking` (NetworkManager), `Quickshell.Bluetooth` (BlueZ),
`Services.UPower`, `Services.Pipewire`, `Services.Notifications`,
`Services.SystemTray`, `Services.Mpris`, `Services.Pam`, `Services.Polkit`,
`Wayland.WlSessionLock`, `Wayland.IdleMonitor`, `Hyprland.GlobalShortcut`,
`ColorQuantizer`.

## System specifics

- `power-profiles-daemon` is **not** installed; Fedora 43 uses `tuned-ppd`, which
  serves the same `org.freedesktop.UPower.PowerProfiles` interface. Quickshell's
  `PowerProfiles` works, but `hasPerformanceProfile` is false.

## QML naming: never use `on` + uppercase

QML parses any member whose name starts with `on` followed by an uppercase
letter as a **signal handler**, even when written as a property declaration.
This bites hard when modelling Material 3, where a third of the palette is
named `onSurface`, `onPrimary` and so on.

```qml
property color onSurface: "#222"           // ERROR: Cannot assign a value to a signal
readonly property color onSurface: "#222"  // same, readonly makes no difference
```

Worse, the snake_case workaround fails *silently*:

```qml
JsonAdapter { property string on_surface: "#cac4d0" }   // reads back undefined
// undefined assigned to a `color` renders as #000000 -- a black widget, no warning
```

That silent failure is what made half the palette render black while `primary`
and `outline` were fine.

vela handles this two ways:

1. `Colours` parses the palette with `JSON.parse(fileView.text())` into a plain
   JS object instead of binding through a `JsonAdapter`. Plain object keys are
   not QML identifiers, so any name is safe.
2. The roles are exposed nested, as `Colours.on.surface` and `Colours.on.primary`,
   which keeps the Material 3 names readable without tripping the parser.

## Positioners: never size a child from its own positioner

A `Row` derives its height from its children. A child that binds
`implicitHeight: row.height` closes the loop, and Qt does not merely zero the
height -- the positioner's layout pass goes stale and **`implicitWidth` stays 0
forever**, so the whole Row collapses even though every child has a correct
width.

```qml
Row { id: row
    Repeater { Item { implicitHeight: row.height } } }   // Row collapses to 0 wide
```

Size children from something outside the positioner instead, e.g. the widget
root's height. The symptom is an empty container with no binding-loop warning,
so it is easy to misread as a model or visibility problem.

## Session lock: a crashed lock client locks you out permanently

Verified in a nested Hyprland. If the process holding a
`WlSessionLock` dies while locked, the session stays locked:

- Restarting the shell does not recover it. A fresh instance reports
  `isLocked: false` and cannot take the existing lock over.
- Hyprland's documented escape, `hyprctl eval 'hl.clear_crashed_lockscreen()'`,
  **failed on the install these notes were written on**: "eval is only supported with the lua config manager".
- `loginctl unlock-session` does nothing, because Quickshell does not listen to
  logind.
- The only verified escape is `hyprctl dispatch exit` from a TTY, which ends the
  Hyprland session.

This is ext-session-lock-v1 behaving as specified: *"If the client dies while the
session is locked, the compositor must not unlock the session in response. It is
acceptable for the session to be permanently locked."*

Everything in `modules/lock` is built around that. The lock refuses to engage if
it cannot read its PAM stack, times out a hung PAM conversation, and releases the
lock after three consecutive *unjudgeable* attempts -- an attacker at a locked
screen cannot break a PAM stack, so a broken one only traps the owner.
`Config.lock.autoLock` ships `false` for the same reason.

## Overlay layer surfaces draw above the session lock

On Hyprland, a wlr-layer-shell surface on `WlrLayer.Overlay` renders **above** an
ext-session-lock surface. It cannot take keyboard focus -- the lock outranks it --
but it is visible, so a drawer or launcher opened while locked would paint its
contents (network names, media, session buttons) over a locked screen.

vela closes this from both sides: `Lock.lock()` calls `ShellState.closeAll()`
before engaging, and `ShellState.open()` refuses while `ShellState.locked`. The
flag lives in `services/ShellState.qml` precisely so every surface can read it
without `qs.services` depending on `qs.modules`.

## PAM

`PamContext` has no `onMessage` or `onResponseRequired` signal -- assigning to
either is a load error. The real handlers are `onPamMessage`,
`onResponseRequiredChanged`, `onCompleted` and `onError`.

No root is needed to use PAM from the shell. `PamContext.configDirectory` maps to
`pam_start_confdir(3)`, so the stack ships inside the repo at
`assets/pam.d/vela` and installs with an ordinary `stow`. `pam_unix` reaches
`/etc/shadow` through the setuid `unix_chkpwd` helper, which works unprivileged.

One trap: with a confdir set, a bare `include system-auth` resolves *inside the
confdir* rather than `/etc/pam.d`, and fails as `PAM_PERM_DENIED` without ever
prompting. The include path must be absolute.

## A component with an error in it loads silently until something uses it

QML compiles a component the first time something instantiates one. A config
that loads cleanly therefore proves nothing about any component nothing has
created yet.

This bit twice in one session. `Elevation.qml` declared

```qml
readonly property real dp: ...
Behavior on dp { ... }          // Invalid property assignment: "dp" is read-only
```

which is a **load error**, not a warning -- and the whole shell still started
clean, because at that point no module drew a shadow. Two separate agents then
hit it independently and worked around it.

So: after writing a component, instantiate it in the harness. Loading the
config is not a test of it.

```qml
ShellRoot {
    Item {
        Elevation { level: 3 }
        StateLayer {}
    }
}
```

## More reserved identifiers

Beyond properties, QML also rejects:

- a **function** whose name starts with `on` + uppercase --
  `function onAccentContainer()` fails with "Illegal method name"
- a function named `escape`
- `??=` is parsed but rejected by `qmlformat`, so it cannot be used in a
  codebase that is kept formatted

The same rule as the palette: treat `on` + uppercase as reserved everywhere,
not just in property declarations.

## ListView.currentIndex cannot be bound

`ListView` writes `currentIndex` itself whenever the model changes, which
destroys any binding on it. A bound `currentIndex` works until the first model
update and then silently stops tracking -- in a launcher, the highlight strands
itself on the last row after one keystroke.

Assign it from a handler (`onSelectedChanged`, `onCountChanged`) instead of
binding it.

## Qt resolves no icon theme under a bare `qs -p`

There is no platform theme plugin to set `QIcon::themeName`, so
`Quickshell.iconPath("folder", true)` returns an empty string in a test
harness even for icons that exist on the system. Blank tray or launcher icons
while testing are the harness, not the widget -- check against a file path
before concluding the code is wrong.

## The icon theme is fixed when Quickshell starts

`QS_ICON_THEME` (or `//@ pragma IconTheme`) is applied once, with
`QIcon::setThemeName`, as Quickshell launches (`src/launch/launch.cpp` in
0.3.1), and nothing reachable from QML changes it afterwards. That is why
Settings, Appearance, App icons restarts the shell (`vela icon-theme`) rather
than applying live, and why `vela shell start` -- which autostart goes
through -- passes the chosen theme on.

Ask for an app's icon with `Quickshell.iconPath(name, true)`: it answers ""
for a name the theme does not have. The bare `image://icon/<name>` answers
with a placeholder that reports itself as loaded (`services/SysTray.qml`).

## Quickshell does not kill its children, and does not run QML teardown

Verified by signalling a running shell: a process started with `Process` and
left running **survives `SIGTERM` to `qs`**, is reparented to init, and keeps
whatever it was holding. `Component.onDestruction` does not fire either, so a
cleanup handler written there never runs on a signal -- only on a tidy
`Qt.quit()` or a config reload.

This is worse than an orphan. An idle inhibitor leaked this way holds a logind
lock that nothing can then release: the machine quietly stops sleeping, and
nothing in the UI can say why.

The fix used by `services/Idle.qml` and `services/NightLight.qml` is to tie the
child's lifetime to the shell's file descriptors rather than to QML:

```qml
// `cat` exits when Quickshell's stdin pipe closes, which happens the moment the
// shell dies for any reason, signal or not -- so the inhibitor dies with it.
command: ["sh", "-c", "systemd-inhibit --what=idle --who=vela ... cat"]
```

Verified clean under both `SIGTERM` and `SIGKILL`. Keep `Component.onDestruction`
as well for the tidy path; it is the reload case that it covers.

**Any service that spawns a long-lived process has this problem.** Assume the
process outlives the shell unless its lifetime is tied to a pipe.

## Quickshell 0.3.1 has no generic D-Bus module

`Quickshell.Dbus` does not exist. The QML modules shipped are Bluetooth,
DBusMenu, Hyprland, I3, Io, Networking, Services, Wayland, Widgets, WindowManager
and X11 -- and nothing else. A service that needs an arbitrary bus interface has
to shell out to `busctl`.

`Quickshell.Services.UPower.PowerProfiles` reports `Balanced` whether or not a
daemon is running, so it cannot answer "does this machine have power profiles".
`services/Power.qml` asks `busctl` once at startup for the profile list and
treats the absence of the `net.hadess.PowerProfiles` interface as unavailable.
On Fedora 43 the provider is **tuned-ppd**, not power-profiles-daemon, so the
check has to be for the interface, never for a service name.

## Naming a singleton after a Quickshell type shadows it silently

A file `services/PowerProfiles.qml` wins the import race against
`Quickshell.Services.UPower`'s `PowerProfiles` in any file that imports both,
because the later import wins. No warning: reads just start returning the wrong
type, and writes to a `readonly` property in the shadowing singleton go nowhere.

`services/Bt.qml` and `services/Net.qml` are named the way they are for exactly
this reason, and `Power` is named to avoid both `PowerProfiles` and the
`PowerProfile` enum.
