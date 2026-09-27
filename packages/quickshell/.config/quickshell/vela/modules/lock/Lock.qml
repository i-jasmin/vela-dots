import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.tokens
import qs.services

// The session lock. Owns the ext-session-lock surfaces and PAM, and is the only
// thing in the shell allowed to engage a lock.
//
// READ THIS BEFORE INSTANTIATING IT. ext-session-lock-v1 says a compositor must
// not unlock when the lock client dies, and Hyprland honours that to the
// letter: a quickshell that crashes while the lock is up leaves the session
// locked with no password prompt on it, `loginctl unlock-session` does nothing,
// and the only way back is `hl.dsp.exit()` from a TTY, which ends the session
// and loses whatever was open. Everything below is built around that one fact:
//
//   * the lock refuses to engage unless PAM is known to be usable;
//   * it lets go by itself if authentication stops working while it is up;
//   * `unlock` over IPC bypasses the password, because that call can only be
//     made from inside a session the lock is not covering;
//   * there is no idle timer. Auto-lock needs a `Config.lock.autoLock` key
//     that does not exist yet, and until this module has run on a real session
//     without incident, the shell should never engage a lock the user did not
//     ask for.
//
// It is instantiated in shell.qml and bound to super + L.
Scope {
    id: root

    // Not read back off WlSessionLock: that property reports no change when the
    // session is released, so a binding to it latches true forever -- measured
    // in a nested compositor. This is the shell's copy and the only writer.
    property bool engaged: false

    readonly property bool locked: root.engaged

    // Publish it, so every other surface can refuse to open over the lock.
    // ShellState is the one thing the whole shell already reads.
    onLockedChanged: ShellState.locked = root.locked
    readonly property bool available: authenticator.available

    // True from the moment a correct password is accepted until the session is
    // actually released, which is what lets the surface play an exit instead of
    // blinking out. It is a hint to the surface and nothing more: the release
    // below does not wait for any animation to report that it has finished.
    property bool releasing: false

    function lock(): void {
        if (root.engaged)
            return;

        // A lock with no way to authenticate is a lockout. Refusing here is the
        // difference between a broken feature and a lost session -- but a
        // refusal must still end in a locked screen, or idle, lid-close and
        // before-sleep locking silently do nothing. hyprlock is the fallback
        // hypridle.conf already names.
        if (!authenticator.available) {
            console.warn(`[vela] lock: no PAM stack at ${authenticator.configPath}, handing over to hyprlock`);
            root.fallback();
            return;
        }

        releaseTimer.stop();
        root.releasing = false;
        authenticator.reset();
        // Every drawer in this shell is a wlr-layer-shell Overlay surface, and
        // Hyprland draws those ABOVE a session lock surface. One left open
        // would be readable -- and screenshot-able -- over a locked screen.
        ShellState.closeAll();
        root.engaged = true;
    }

    function fallback(): void {
        Quickshell.execDetached(["sh", "-c", "pidof hyprlock >/dev/null || exec hyprlock"]);
    }

    // Drop the session lock now. Every path that must not be able to fail ends
    // here, and it touches nothing that could be waiting on something else.
    function release(): void {
        releaseTimer.stop();
        root.releasing = false;
        authenticator.reset();
        root.engaged = false;
    }

    // Let the surface leave, then release. The timer is what releases, not the
    // animation: an exit that stalled, or a surface that never ran one, would
    // otherwise leave the session locked with no password prompt on it. A Timer
    // cannot be starved that way, and the worst case is that the lock stays up
    // for a fraction of a second longer than it looks like it should.
    function unlock(): void {
        if (!root.engaged || root.releasing)
            return;

        root.releasing = true;
        releaseTimer.restart();
    }

    Timer {
        id: releaseTimer

        // Long enough for the surface's fade, short enough that it never reads
        // as the password not having been accepted.
        interval: Appearance.anim.normal + Appearance.anim.fast
        onTriggered: root.release()
    }

    // Not named `auth`: the surface has a property of that name, and inside the
    // surface component the property would shadow this id.
    Auth {
        id: authenticator

        onAuthenticated: root.unlock()

        // PAM can no longer judge a password at all. At that point the lock is
        // protecting nothing -- an attacker cannot break a PAM stack from a
        // locked screen, so a broken one only traps the person who owns the
        // machine. Released immediately: this is the emergency path and it does
        // not get to wait behind an animation.
        onUnusable: reason => {
            console.warn(`[vela] lock: releasing, authentication is broken (${reason})`);
            root.release();
        }
    }

    Connections {
        target: ShellState

        function onLockRequested(): void {
            root.lock();
        }
    }

    WlSessionLock {
        id: sessionLock

        locked: root.engaged

        // The compositor can end the lock itself (it refused it, or another
        // locker holds the session). Quickshell lets go and reports it here;
        // without reading it back, `engaged` stayed true, every panel refused
        // to open for good and the next `lock` returned early.
        onLockedChanged: {
            if (!sessionLock.locked && root.engaged) {
                console.warn("[vela] lock: the compositor ended the session lock");
                root.release();
            }
        }

        // One surface per screen, created only once the compositor has locked
        // the session. Nothing but the wrapper lives here: a mistake inside
        // this component would not surface until the lock is already up.
        surface: WlSessionLockSurface {
            // The deeper ground the lock draws on. Dark scheme only -- in light
            // mode `surface` is already the right colour to bloom over.
            color: Colours.light ? Colours.surface : Qt.darker(Colours.surface, Appearance.lock.groundDarken)

            LockSurface {
                anchors.fill: parent
                auth: authenticator
                releasing: root.releasing
            }
        }
    }

    // Reachable from Hyprland keybinds and the `vela` CLI:
    //   qs -c vela ipc call lock lock
    //
    // `unlock` bypasses the password by design. It is only reachable from
    // inside the running session, which a locked screen does not give anyone,
    // and it is the escape hatch if the surface itself ever misbehaves -- so it
    // releases straight away rather than going through the exit.
    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function unlock(): void {
            root.release();
        }

        // Whether a lock is actually held, not just asked for -- false when
        // the compositor has no ext-session-lock or another locker got there
        // first.
        function isLocked(): bool {
            return root.engaged && sessionLock.locked;
        }

        function canLock(): bool {
            return root.available;
        }
    }
}
