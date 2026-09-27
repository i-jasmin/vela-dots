pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

// The five things the power menu can do, and the one place that does them.
//
// Kept out of the window for the reason every module keeps its shelling out in
// one file: a surface should ask for an action by name, not assemble a command
// line. This belongs in `services/` beside `Power` -- it is a system source, not
// a view -- and has not been moved there yet.
//
// LOG OUT IS THE TRAP. Under Hyprland's Lua config manager, which vela's
// hyprland.lua uses, `hyprctl dispatch exit` is wrapped as `hl.dispatch(exit)`
// where `exit` is an undefined global rather than a dispatcher: the button does
// nothing and says nothing about it. That exact bug shipped once already, so
// logging out goes through `Hypr.logout()`, which states the Lua form once.
//
// LOCK GOES THROUGH LOGIND, deliberately. `loginctl lock-session` raises the
// session's lock signal and whatever lock client is listening answers it; vela's
// own lock module is being built separately and is not wired in, and a power
// menu that called a half-built lock client directly is the one failure that
// can lock the session permanently.
QtObject {
    id: root

    // Order, label, glyph and single-key shortcut, exactly as the design lists
    // them. `tone` is the button's whole appearance: only two of the five carry
    // colour, and both earn it -- the default action and the destructive one.
    readonly property var items: [
        {
            id: "lock",
            icon: "lock",
            label: qsTr("Lock"),
            key: "L",
            tone: "accent"
        },
        {
            id: "suspend",
            icon: "bedtime",
            label: qsTr("Suspend"),
            key: "S",
            tone: "plain"
        },
        {
            id: "logout",
            icon: "logout",
            label: qsTr("Log out"),
            key: "E",
            tone: "plain"
        },
        {
            id: "reboot",
            icon: "restart_alt",
            label: qsTr("Reboot"),
            key: "R",
            tone: "plain"
        },
        {
            id: "poweroff",
            icon: "power_settings_new",
            label: qsTr("Shut down"),
            key: "P",
            tone: "danger"
        }
    ]

    function indexOfKey(key: string): int {
        return root.items.findIndex(a => a.key === key.toUpperCase());
    }

    function run(id: string): void {
        // The menu goes away first: `systemctl poweroff` takes a moment to bite
        // and a power menu still sitting there looks like a dead button.
        ShellState.close("power");

        Session.run(id);
    }
}
