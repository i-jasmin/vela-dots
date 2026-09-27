pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Idle inhibition -- the "keep the screen awake" toggle.
//
// Quickshell 0.3.1 exposes no idle-inhibit protocol handle (its Wayland module
// ships WlSessionLock and nothing else), so this holds a logind inhibitor
// instead. hypridle -- which is what actually dims, locks and suspends this
// session -- honours logind's idle locks unless `ignore_systemd_inhibit` is
// set, so the lock genuinely stops the timers rather than just looking like it.
//
// systemd-inhibit has no daemon mode: it holds the lock for as long as the
// command it wraps lives, so the lock's lifetime is that process's lifetime.
//
// Making that lifetime end with the shell took some care. Quickshell does *not*
// kill its child processes when it is itself terminated: SIGTERM to `qs` leaves
// systemd-inhibit reparented to init, still holding an idle lock that nothing
// can now release, which is the worst outcome available here -- a machine that
// quietly never sleeps again. Two things prevent it:
//
//   * the wrapped command is `cat` reading the stdin pipe Quickshell opens, so
//     when the shell dies for any reason at all -- SIGKILL included -- the
//     write end closes, cat sees EOF, systemd-inhibit exits and logind drops
//     the lock;
//   * `Component.onDestruction` releases it on an orderly quit or reload, so
//     the ordinary case does not depend on the pipe at all.
Singleton {
    id: root

    // Carried for consistency with Power and NightLight, so a toggle can
    // ask every service the same question. systemd-inhibit is always present on
    // this system, so unlike those two there is nothing here that can be absent.
    readonly property bool available: true
    readonly property bool inhibited: wanted && proc.running
    readonly property string icon: inhibited ? "coffee" : "coffee_maker"

    // Distinguishes "we stopped it" from "it fell over", which otherwise land
    // in the same place.
    property bool wanted: false

    function toggle(): void {
        if (inhibited)
            release();
        else
            inhibit();
    }

    function inhibit(): void {
        wanted = true;
        proc.running = true;
    }

    function release(): void {
        wanted = false;
        proc.running = false;
    }

    Process {
        id: proc

        // `--mode=block` is the strong form: delay only defers the idle action,
        // block prevents it.
        command: ["systemd-inhibit", "--what=idle", "--who=vela", "--why=Keep awake requested from the shell", "--mode=block", "cat"]

        // The whole point of `cat` over `sleep infinity`: it ends when the pipe
        // does. Without this the child would read /dev/null, see EOF at once
        // and the lock would never be taken at all.
        stdinEnabled: true

        onExited: code => {
            if (root.wanted) {
                console.warn(`[vela] idle inhibitor exited on its own (${code}); the screen can sleep again`);
                root.wanted = false;
            }
        }
    }

    Component.onDestruction: proc.running = false
}
