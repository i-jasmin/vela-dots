pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Colour temperature, via hyprsunset.
//
// hyprsunset is a daemon: it holds a wlr-gamma-control handle for as long as it
// runs, and the compositor restores the screen the moment that handle goes
// away. So "off" is simply not running it -- which also means an orphaned
// hyprsunset leaves the user orange with nothing in the UI able to reach it.
// Tying its lifetime to the shell's is therefore the main piece of work here;
// see the wrapper in `setTemperature`.
//
// While it is running the temperature is changed through `hyprctl hyprsunset`
// over its own socket, which is instant and avoids a restart flash.
//
// With `appearance.eveningWarmth.screen` on, it follows the evening: the same
// curve Sun gives the palette, read as a temperature between `fromKelvin` and
// `toKelvin`. A choice made by hand -- `toggle()`, `setTemperature()`, the IPC
// below -- wins until the evening next turns, and then the curve has it back.
Singleton {
    id: root

    // The binary has to exist: without it this toggle is a dead button, and
    // hyprsunset is a separate package from Hyprland on most distributions.
    property bool available: false

    // A daemon somebody else started -- typically from the Hyprland config. It
    // cannot be stopped from here, so in that mode "off" means asking it for
    // neutral daylight instead.
    property bool external: false

    readonly property bool enabled: external ? temperature < neutral : daemon.running
    property int temperature: 6500
    readonly property int warmTemperature: 4000
    readonly property string icon: enabled ? "nightlight" : "wb_sunny"

    // 6500 K is the daylight white point: at this value hyprsunset is applying
    // no visible shift, so it is what "off" means numerically.
    readonly property int neutral: 6500

    // Remembers where a slider was left, so toggling off and on again does not
    // silently snap back to the default warmth.
    property int lastWarm: warmTemperature

    // Whether the daemon below is running because this service asked it to.
    property bool daemonWanted: false

    // Whether the check for somebody else's daemon has answered. Following
    // waits for it: starting a second hyprsunset beside the first would leave
    // two clients fighting over one gamma ramp.
    property bool probed: false

    // ---- following the evening ---------------------------------------------
    //
    // `Sun.kelvin` moves about once a minute during the ramp and not at all
    // otherwise, and each move is one `hyprctl hyprsunset temperature`. At the
    // neutral end the daemon is stopped rather than asked for 6500 K, so the
    // day has no tint running at all.
    readonly property bool follows: available && probed && Config.appearance.eveningWarmth.enabled && Config.appearance.eveningWarmth.screen
    readonly property int evening: Sun.kelvin
    // Sun's warmth is above zero from the start of the ramp to sunrise.
    readonly property bool night: Sun.warmth > 0

    // A hand on the dial. Set at night, it holds until sunrise; set in the
    // day, until the ramp starts. Either way the next turn of the evening
    // lets go of it, and `resume()` lets go at once.
    property bool held: false

    onEveningChanged: follow()
    onNightChanged: {
        root.held = false;
        root.follow();
    }
    onFollowsChanged: {
        // Switched on: the curve takes over from wherever the screen was.
        // Switched off: whatever the curve had put there comes off, and a
        // choice made by hand is left as it is.
        if (!root.held)
            root.apply(root.follows ? root.evening : root.neutral);
        root.held = false;
    }

    function follow(): void {
        if (root.follows && !root.held)
            root.apply(root.evening);
    }

    function resume(): void {
        root.held = false;
        root.follow();
    }

    function toggle(): void {
        setTemperature(enabled ? neutral : lastWarm);
    }

    // A person's choice: remembered as the warmth to toggle back to, and held
    // against the evening curve.
    function setTemperature(kelvin: int): void {
        if (!available)
            return;
        root.held = root.follows;
        root.apply(kelvin);
        if (root.temperature < neutral)
            root.lastWarm = root.temperature;
    }

    function apply(kelvin: int): void {
        if (!available)
            return;
        // hyprsunset's own accepted range.
        const k = Math.max(1000, Math.min(20000, Math.round(kelvin)));
        root.temperature = k;

        if (k < neutral) {
            // Not one that is on its way out: turned back on while the last
            // was still stopping, the new warmth went to a daemon that was
            // about to exit, and the tint ended up off. A new one is started
            // instead, and waits for the old to finish.
            if (root.external || (daemon.running && !daemon.stopping))
                push.exec(["hyprctl", "hyprsunset", "temperature", `${k}`]);
            else {
                // hyprsunset in the background and `cat` on the shell's stdin
                // pipe in the foreground; whichever ends first takes the other
                // with it. That is what ties the tint's lifetime to the
                // shell's: when the shell dies -- SIGTERM, SIGKILL, crash --
                // the pipe closes, cat ends and hyprsunset is killed, so the
                // screen goes back to normal. Quickshell does not kill its
                // children on a signal and does not run QML destruction
                // either, so neither `Process` alone nor
                // `Component.onDestruction` alone is enough. The trap covers
                // the other direction, where this service stops the process.
                //
                // `exec 3<&0` is load-bearing: a non-interactive shell points
                // a background job's stdin at /dev/null unless it is
                // explicitly redirected, so a plain `cat &` would read EOF
                // immediately and switch the tint straight back off.
                daemon.command = ["bash", "-c", `exec 3<&0; hyprsunset -t ${k} & p=$!; cat <&3 >/dev/null & c=$!; trap 'kill $p $c 2>/dev/null; exit 0' TERM INT; wait -n; kill $p $c 2>/dev/null`];
                root.daemonWanted = true;
                daemon.running = true;
            }
        } else if (root.external) {
            push.exec(["hyprctl", "hyprsunset", "temperature", `${neutral}`]);
        } else {
            // Dropping the gamma handle is cleaner than asking for 6500 K: the
            // compositor puts back exactly what was there before.
            root.daemonWanted = false;
            if (daemon.running)
                daemon.stopping = true;
            daemon.running = false;
        }
    }

    Process {
        id: daemon

        // Required: it is the open stdin pipe that the wrapper watches. Without
        // it the child reads /dev/null, sees EOF immediately and shuts the tint
        // off the instant it is turned on.
        stdinEnabled: true

        // Asked to stop and not yet gone.
        property bool stopping: false

        onExited: code => {
            // Stopping it is how this service turns the tint off, so only an
            // exit nobody asked for is worth a word -- and one asked for may
            // come after a new daemon is already wanted.
            if (daemon.stopping) {
                daemon.stopping = false;
                return;
            }
            if (root.daemonWanted) {
                console.warn(`[vela] hyprsunset exited on its own (${code}); colour temperature is back to the compositor's`);
                root.daemonWanted = false;
            }
        }
    }

    Process {
        id: push
    }

    // Belt and braces alongside the stdin watchdog: this is the tidy path, taken
    // on `Qt.quit()` and on every config reload, and it stops the tint rather
    // than leaving it to the pipe closing a moment later. It does not fire on a
    // signal -- Quickshell does not run QML teardown then -- which is exactly
    // why the watchdog exists as well.
    Component.onDestruction: daemon.running = false

    // Is it installed at all? `command -v` rather than a fixed path, because
    // hyprsunset lands in /usr/bin from a package and ~/.local/bin from a
    // manual build.
    Process {
        id: haveBinary

        running: true
        command: ["sh", "-c", "command -v hyprsunset >/dev/null"]
        onExited: code => {
            root.available = code === 0;
            if (code === 0)
                adopt.running = true;
        }
    }

    // A bare `hyprctl hyprsunset temperature` prints the current value if a
    // daemon is listening and fails if none is, which is the only way to tell
    // whether one is already running before starting a second.
    // After a second, not at once: on a reload the outgoing shell stops its
    // own hyprsunset just as this one starts, and one that answered on its
    // way out was taken for somebody else's -- which cannot be stopped from
    // here, so the toggle did nothing from then on.
    Process {
        id: adopt

        command: ["sh", "-c", "sleep 1; hyprctl hyprsunset temperature"]

        // Late, so the answer below has landed before following starts.
        onExited: Qt.callLater(() => root.probed = true)

        stdout: StdioCollector {
            onStreamFinished: {
                const k = parseInt(text.trim());
                if (!k)
                    return;
                root.external = true;
                root.temperature = k;
                if (k < root.neutral)
                    root.lastWarm = k;
            }
        }

        // "Couldn't connect to ... .hyprsunset.sock" is the ordinary answer on
        // a session that is not running it.
        stderr: StdioCollector {}
    }

    // Reachable from Hyprland keybinds and a terminal:
    //   qs -c vela ipc call nightlight toggle
    IpcHandler {
        target: "nightlight"

        function toggle(): void {
            root.toggle();
        }

        function set(kelvin: int): void {
            root.setTemperature(kelvin);
        }

        // Back to the evening curve, without waiting for it to turn.
        function resume(): void {
            root.resume();
        }

        function temperature(): int {
            return root.enabled ? root.temperature : root.neutral;
        }
    }
}
