//@ pragma UseQApplication
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.tokens
import qs.modules.background
import qs.modules.dock
import qs.modules.lock
import qs.modules.notifications
import qs.modules.osd
import qs.modules.overlays
import qs.modules.overview
import qs.modules.settings
import qs.modules.shell
import qs.modules.wallpaper

// vela -- entry point.
//
// Each module owns its own windows, reads shared state from qs.services and its
// metrics from qs.tokens. Nothing here holds state.
//
// The bar is not a window of its own: `Shell` draws it, and the dashboard, the
// popouts, the launcher and the power menu that hang off it, in one window per
// monitor, so a drawer and the bar it grows from are always in the same frame.
ShellRoot {
    // The settings window writes shell.json and holds no state of its own, so
    // something has to carry those keys onto the token singletons or every
    // control on the Appearance page would write a file and move nothing. This
    // is that something, and it is here rather than inside `Appearance` because
    // tokens are supposed to be read by the shell, not to reach back into its
    // config.
    Binding {
        target: Appearance
        property: "radiusScale"
        value: Config.appearance.radiusScale
    }

    Binding {
        target: Appearance
        property: "panelOpacity"
        value: Config.appearance.panelOpacity
    }

    Binding {
        target: Appearance
        property: "reduceMotion"
        value: Config.appearance.reduceMotion
    }

    Binding {
        target: Appearance
        property: "motionOff"
        value: !Config.appearance.animations
    }

    Binding {
        target: Appearance
        property: "motionSpeed"
        value: Config.appearance.animationSpeed
    }

    // "auto" is deliberately left unbound: the Sun service drives it from
    // sunset, and a binding here would fight it every frame.
    Binding {
        target: Colours
        property: "light"
        value: Config.appearance.mode === "light"
        when: Config.appearance.mode !== "auto"
    }

    // The Sun service drives the palette's evening warmth, and auto light and
    // dark, through bindings of its own. Asked for here, it starts with the
    // shell rather than whenever something first wants a sunset time, so the
    // palette can open at the right warmth (Colours.sunKnown).
    readonly property bool sunStarted: Sun.available

    // The wallpaper goes first: it is the only thing on the background layer,
    // and everything else is drawn over it.
    Background {}
    Shell {}
    Dock {}
    Notifications {}
    Osd {}
    Overview {}
    Overlays {}
    Settings {}
    WallpaperSwitcher {}

    // Wired in after being proven in a nested compositor. A lock client that
    // dies while the session is locked still leaves it locked -- that is the
    // protocol, and it reproduces here -- but it is no longer unrecoverable:
    //
    //     hyprctl eval 'hl.clear_crashed_lockscreen()'
    //
    // Measured end to end on a nested Hyprland running the Lua config manager:
    // locked, client SIGKILLed, screen stuck at a bare #0b0b0b with a new shell
    // unable to draw, then that one command released it and the next shell came
    // up normally. `hyprland.lua` is what makes `eval` available, which is why
    // its header says not to go back to hyprland.conf.
    //
    // There is still no auto-lock: nothing engages a lock the user did not ask
    // for, and `Lock` refuses to engage at all unless PAM is usable.
    Lock {}
}
