# Hyprland 0.56 config notes

Verified against the installed binary (0.56.1) with `Hyprland --verify-config`,
and against `src/config/legacy/ConfigManager.cpp` in the 0.56.1 source.

`Hyprland --verify-config -c <file>` parses a config without running it, and it
does catch real mistakes -- bad dispatchers, unknown options, bad gesture
directions, unknown animation names, malformed `size`/`move` values. It is the
safe way to check a config without applying it. It does **not** validate keysym
names, lid-switch binds, or whether window rules match real app classes.

## Syntax that changed, and now errors

Hyprlang is deprecated in favour of Lua as of 0.55 but still works. Several
things every older config and guide still uses are now hard errors:

- **Window rules**: `windowrule = <effect> <value>, match:<prop> <value>`.
  Effects are snake_case (`suppress_event`, `no_focus`, `keep_aspect_ratio`),
  match conditions take a `match:` prefix, and each field splits at its *first
  space*. `windowrulev2` errors out explicitly.
- **Layer rule effects**: `blur`, `ignore_alpha`, `no_anim`, `animation`,
  `order`, `xray`, `above_lock`, `blur_popups`, `dim_around`, `no_screen_share`.
  There is no `ignorezero`.
- **Removed**: `dwindle:pseudotile`, `misc:vfr` (now `debug:vfr`, on by
  default), `misc:new_window_takes_over_fullscreen`, `render:explicit_sync`,
  `render:explicit_sync_kms`, `gestures:workspace_swipe` (now
  `gesture = 3, horizontal, workspace`), the `togglesplit` dispatcher (now
  `layoutmsg, togglesplit`), and hyprlock's `general:grace` (now `--grace` on
  the command line).

## Hybrid graphics (an Intel + NVIDIA laptop)

From `/sys/class/drm`: **card1 = i915 drives eDP-1 and DP-1..4; card0 =
nvidia-drm drives HDMI-A-1 only.** The internal panel physically cannot be driven
by the dGPU and HDMI cannot be driven by the iGPU, so both cards must stay
available to the compositor.

`AQ_DRM_DEVICES` is deliberately **not** set. Aquamarine already elects the right
primary unaided -- the log shows it starting on card1 (i915), making it primary,
then bringing up card0 with card1 still primary. Setting the variable would pin
an ordering we already get, while hardcoding card numbers that are assigned at
boot. `/dev/dri/by-path/` names are stable but unusable here: they contain
colons, which is the list separator.

Also deliberately unset, each for a reason recorded in `conf/env.lua`:
`GBM_BACKEND=nvidia-drm` (sends Mesa/Intel clients into NVIDIA's GBM),
`__GLX_VENDOR_LIBRARY_NAME=nvidia` (wakes the dGPU for everything and breaks
screen sharing -- PRIME offload is offered per-app instead),
`LIBVA_DRIVER_NAME=nvidia` and `NVD_BACKEND` (no `nvidia_drv_video.so` is
installed; leaving them unset lets libva pick iHD), and
`WLR_NO_HARDWARE_CURSORS` (wlroots-era; the modern equivalent
`cursor:no_hardware_cursors` defaults to auto).

## IPC exit codes

`qs -c vela ipc call ...` exits **255** when no instance is running. That is what
lets hypridle fall back to hyprlock when the shell is not up.

## Under the Lua config manager, `dispatch` takes Lua, not a dispatcher line

This is the one that breaks a shell silently.

With `hyprland.lua` in use, the IPC `dispatch` command evaluates its argument
as **Lua**. The legacy form is a parse error:

```
$ hyprctl dispatch "workspace 2"
error: [string "return hl.dispatch(workspace 2)"]:1: ')' expected near '2'
```

The working form is a Lua expression:

```sh
hyprctl dispatch 'hl.dsp.focus({workspace = "2"})'
hyprctl dispatch 'hl.dsp.window.move({workspace = "4", follow = false, window = "address:0x..."})'
```

**This applies to Quickshell's `Hyprland.dispatch()` too** -- it writes to the
same socket. Nothing in QML checks the reply, so every workspace click in the
bar failed without a single warning after the port to Lua. The symptom is a
control that looks right and does nothing.

vela routes every dispatch through `services/Hypr.qml` so the syntax is stated
once. Add new dispatches there, not inline.

Verified against the running compositor: legacy errors, Lua form returns `ok`
and the workspace actually changes.

## Getting out of a locked session

vela's lock is wired into `shell.qml` and bound to super + L. If something goes
wrong while the session is locked, there are three escapes, in order. All of
them are run from a TTY: **ctrl + alt + F3**, log in as normal.

`hyprctl` does not discover the running compositor by itself -- it needs
`HYPRLAND_INSTANCE_SIGNATURE`, and `/run/user/1000/hypr/` is full of stale
directories from old nested instances, so guessing the newest is not safe. Find
the live one by asking each until one answers:

```sh
export XDG_RUNTIME_DIR=/run/user/1000
for d in "$XDG_RUNTIME_DIR"/hypr/*/; do
    s=$(basename "$d")
    HYPRLAND_INSTANCE_SIGNATURE=$s hyprctl monitors >/dev/null 2>&1 \
        && export HYPRLAND_INSTANCE_SIGNATURE=$s && break
done
```

**1. The shell is still running and the password is not being accepted.**
Release the lock over IPC. This bypasses the password by design -- it can only
be reached from inside the session, which a locked screen does not hand to
anybody:

```sh
WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 qs -c vela ipc call lock unlock
```

`qs` also needs `WAYLAND_DISPLAY`; without it, it looks on `x11/:0`, finds
nothing, and helpfully prints the instance it did find.

**2. The shell died while the session was locked.** The compositor keeps the
session locked -- that is ext-session-lock-v1, not a bug, and a freshly started
shell cannot take the lock over. Clear it:

```sh
hyprctl eval 'hl.clear_crashed_lockscreen()'
```

Verified end to end on a nested compositor: locked, client SIGKILLed, screen
stuck at a bare `#0b0b0b`, then this released it and the next shell drew
normally. **`eval` only exists because of the Lua config manager** -- the same
test against a `hyprland.conf` instance fails with "eval is only supported with
the lua config manager". This is the reason `hyprland.lua` must stay.

**3. Last resort: end the session.** Note that the legacy form does *not* work
here, for the same reason `dispatch` takes Lua above:

```sh
hyprctl dispatch exit                  # error: expected a dispatcher
hyprctl eval 'hl.dsp.exit()'           # this one
```

Unsaved work is lost, so it is genuinely last.
