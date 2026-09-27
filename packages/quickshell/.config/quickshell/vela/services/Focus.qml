pragma Singleton

import QtQuick
import Quickshell
import qs.config

// The focus timer: one run of sessions, and the two things it changes outside
// the dashboard while it counts.
//
//   holdNotifications  Notifs reads it, with `running`, to hold non-urgent
//                      toasts back for one digest when the session ends.
//   countdownInBar     the bar clock shows `clock` in place of the time while
//                      a session runs.
//
// A singleton rather than state in the Focus tab because it has to outlive
// the tab: the drawer unloads a tab the moment another one is picked, and a
// timer living there would lose its session and silently release the hold.
//
// Both toggles and the chosen length are written back to shell.json, so what
// the tab shows is what the config says. The settings window holds no state of
// its own, and nor does this.
Singleton {
    id: root

    // The dashboard's three lengths. The config picks which one a session
    // starts at; any other value there is honoured and simply has no chip.
    readonly property var presets: [25, 50, 90]

    readonly property int minutes: Math.max(1, Config.dashboard.focusTimer.minutes)
    readonly property int sessionSeconds: root.minutes * 60
    readonly property int sessionCount: Math.max(1, Config.dashboard.focusTimer.sessions)
    readonly property bool holdNotifications: Config.dashboard.focusTimer.holdNotifications
    readonly property bool countdownInBar: Config.dashboard.focusTimer.countdownInBar

    property bool running: false
    // One-based, as the tab prints it: "Session 3 of 4".
    property int session: 1
    property int remaining: root.sessionSeconds

    readonly property bool complete: root.remaining === 0
    // Remaining, as a fraction: what the ring draws.
    readonly property real left: root.remaining / root.sessionSeconds

    readonly property string clock: {
        const m = Math.floor(root.remaining / 60);
        const s = root.remaining % 60;
        return `${m < 10 ? "0" : ""}${m}:${s < 10 ? "0" : ""}${s}`;
    }

    readonly property string stateLabel: {
        if (root.running)
            return qsTr("Focusing");
        if (root.complete)
            return qsTr("Session complete");
        if (root.remaining < root.sessionSeconds)
            return qsTr("Paused");
        return qsTr("Ready");
    }

    // Start, pause, or -- once a session has finished -- start the next one
    // from the top.
    function toggle(): void {
        if (root.complete) {
            root.remaining = root.sessionSeconds;
            root.running = true;
            return;
        }
        root.running = !root.running;
    }

    // Back to the top of this session. Pressed again with nothing to undo, it
    // clears the run as well, so the dots can be reset without a restart.
    function reset(): void {
        if (!root.running && root.remaining === root.sessionSeconds)
            root.session = 1;
        root.running = false;
        root.remaining = root.sessionSeconds;
    }

    function choose(minutes: int): void {
        root.running = false;
        Config.dashboard.focusTimer.minutes = minutes;
        Config.save();
        // Set here as well as by the binding below: the config round-trip is
        // what makes it stick, but the tab should not wait for it.
        root.remaining = minutes * 60;
    }

    function setHoldNotifications(on: bool): void {
        Config.dashboard.focusTimer.holdNotifications = on;
        Config.save();
    }

    function setCountdownInBar(on: bool): void {
        Config.dashboard.focusTimer.countdownInBar = on;
        Config.save();
    }

    // A length changed from shell.json while nothing is counting starts the
    // session over at the new length; mid-session it would read as a negative
    // arc.
    onSessionSecondsChanged: if (!root.running)
        root.remaining = root.sessionSeconds

    Timer {
        running: root.running
        interval: 1000
        repeat: true

        onTriggered: {
            if (root.remaining > 1) {
                root.remaining -= 1;
                return;
            }
            root.remaining = 0;
            root.running = false;
            root.session = Math.min(root.sessionCount, root.session + 1);
        }
    }
}
