pragma Singleton

import QtQuick
import Quickshell

// Ending the session: lock, log out, suspend, reboot, shut down.
//
// A module may not run a process, and the power menu is five of them. They are
// also not interchangeable -- logging out is a compositor dispatch, not a
// systemctl verb -- so putting them behind one name keeps the menu from having
// to know which is which.
Singleton {
    id: root

    // Straight to the lock module. `loginctl lock-session` only reached it
    // through hypridle's `lock_cmd`, so with hypridle not running the power
    // menu's Lock did nothing at all.
    function lock(): void {
        ShellState.requestLock();
    }

    // Through Hypr, because Hyprland may be running its Lua config manager, and
    // `hyprctl dispatch exit` is silently discarded there. That exact bug
    // shipped once in this project already.
    // Logging out, rebooting and shutting down each wait for the layout
    // being left to be saved first, so "restore last session on login"
    // brings back this one (`Sessions.snapshotThen`).
    function logout(): void {
        Sessions.snapshotThen(() => Hypr.logout());
    }

    function suspend(): void {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function hibernate(): void {
        Quickshell.execDetached(["systemctl", "hibernate"]);
    }

    function reboot(): void {
        Sessions.snapshotThen(() => Quickshell.execDetached(["systemctl", "reboot"]));
    }

    function powerOff(): void {
        Sessions.snapshotThen(() => Quickshell.execDetached(["systemctl", "poweroff"]));
    }

    function run(action: string): void {
        switch (action) {
        case "lock":
            root.lock();
            break;
        case "logout":
            root.logout();
            break;
        case "suspend":
            root.suspend();
            break;
        case "hibernate":
            root.hibernate();
            break;
        case "reboot":
            root.reboot();
            break;
        case "poweroff":
            root.powerOff();
            break;
        default:
            console.warn(`[vela] unknown session action: ${action}`);
        }
    }
}
