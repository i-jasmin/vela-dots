pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.tokens

// THE POPOUT ANCHOR API -- the surface `modules/popouts/` binds to.
//
// The bar owns *which* popout is open and *where* it is anchored, because only
// the bar knows which item was clicked and where that item ended up after the
// flow laid it out. The popouts module owns what is drawn inside. Neither
// imports the other: the bar writes this singleton, the popouts module reads
// it.
//
// It is a singleton rather than per-monitor state because the design's rule is
// that popouts never stack -- one is open, shell-wide, or none is. Opening a
// second closes the first for free, including across monitors. Every
// monitor's shell window has a `modules/popouts/Popout.qml`, and the one on
// `screenName` draws it, hanging an AttachedDrawer off the bar at `anchor`.
//
// WHAT IS PUBLISHED
//
//   current      "" when nothing is open, otherwise one of
//                "output" | "network" | "bluetooth" | "power" | "workspaces" |
//                "notifications" | "privacy" | "tray". The first four are the
//                bar's control popouts. "workspaces" is the workspace window
//                list, "notifications" the notification centre off the bell,
//                "privacy" who has the microphone, camera or screen, and
//                "tray" a tray app's own menu -- popouts on the same anchor
//                machinery, outside those four.
//   payload      free-form detail for the open popout. The workspace popout
//                puts the workspace id here, a tray menu the tray item whose
//                menu it is; the four control popouts leave it undefined.
//   screenName   the name of the ShellScreen the anchor is on. Compared by
//                name, never by object: `Variants` hands each module its own
//                ShellScreen instance and two of them for the same output are
//                not `===`.
//   anchor       the rect of the bar item that opened it, in that screen's
//                coordinates -- which are also its shell window's. The popout
//                centres itself on it along the bar.
//   position     the bar's edge. The drawer works out which way to grow from
//                it; the popout window only watches it change, and puts
//                itself away when it does.
//
// Everything here is screen-relative, because the popout is drawn in the bar's
// own window, which covers the screen from its origin.
Singleton {
    id: root

    readonly property list<string> names: ["output", "network", "bluetooth", "power", "workspaces", "notifications", "privacy", "tray"]

    property string current: ""
    property var payload: undefined
    property string screenName: ""
    property rect anchor: Qt.rect(0, 0, 0, 0)

    readonly property string position: Config.bar.position

    // Emitted when a popout closes, so the popout window can run its exit
    // before it stops being visible.
    signal closed(string name)

    Connections {
        target: ShellState

        function onAnyChanged(): void {
            if (ShellState.any)
                root.close();
        }

        // Locking closes every surface, and a popout is not one of them.
        // One left open would be drawn over the lock screen: the popout's
        // window is on the Overlay layer while it is out.
        function onLockedChanged(): void {
            if (ShellState.locked)
                root.close();
        }
    }

    // A popout open on a monitor that is unplugged is put away, or it would
    // reopen by itself when the monitor came back, taking the keyboard.
    Connections {
        target: Quickshell

        function onScreensChanged(): void {
            if (root.current !== "" && !Quickshell.screens.some(s => s.name === root.screenName))
                root.close();
        }
    }

    function open(name: string, screen: string, rect: var, detail: var): void {
        if (!root.names.includes(name)) {
            console.warn(`[vela] unknown popout: ${name}`);
            return;
        }
        // The IPC path can ask while the session is locked; see above.
        if (ShellState.locked)
            return;
        // One surface hangs off the bar at a time: a popout puts away the
        // dashboard, the launcher or the power menu, and opening any surface
        // at all puts a popout away (below).
        ShellState.closeAttached();
        if (root.current !== "" && root.current !== name)
            root.closed(root.current);
        root.screenName = screen;
        root.anchor = rect;
        root.payload = detail;
        root.current = name;
    }

    function close(): void {
        if (root.current === "")
            return;
        const was = root.current;
        root.current = "";
        root.payload = undefined;
        root.closed(was);
    }

    function toggle(name: string, screen: string, rect: var, detail: var): void {
        // Same item, same screen, same subject -- a second click puts it away.
        if (root.current === name && root.screenName === screen && root.payload === detail)
            root.close();
        else
            root.open(name, screen, rect, detail);
    }

    function isOpen(name: string, screen: string): bool {
        return root.current === name && root.screenName === screen;
    }

    // The keyboard path. Hyprland binds call this; the popout opens on whatever
    // bar item owns it, on the focused monitor.
    //
    //     qs -c vela ipc call bar popout network
    //
    // The bar item itself answers, through `requested` -- it is the only thing
    // that knows its own geometry.
    signal requested(string name)

    IpcHandler {
        target: "bar"

        function popout(name: string): void {
            if (name === "" || name === "close")
                root.close();
            else if (!root.names.includes(name))
                console.warn(`[vela] unknown popout: ${name}`);
            else if (ShellState.barCollapsed && root.folded.includes(name) && !(name === "notifications" && Notifs.unread > 0))
                root.unfoldFor(name);
            else
                root.requested(name);
        }

        function close(): void {
            root.close();
        }

        // The arrow at the head of the status run, for a keybind:
        //   qs -c vela ipc call bar toggleStatus
        function toggleStatus(): void {
            if (!ShellState.barCollapsed)
                root.close();
            ShellState.setBarCollapsed(!ShellState.barCollapsed);
        }
    }

    // The popouts whose bar item folds away with the status run (see
    // BarExpander). Asked for by keybind while folded, the run opens first:
    // the popout is anchored on the item, and a hidden item has nowhere to be.
    // The bell stays while anything is unread, and then needs no unfolding.
    readonly property list<string> folded: ["output", "network", "bluetooth", "power", "notifications"]
    property string pending: ""

    function unfoldFor(name: string): void {
        root.pending = name;
        ShellState.setBarCollapsed(false);
        unfold.restart();
    }

    // Long enough for the bar to lay the run out again, so the item the
    // popout hangs from is where it will stay.
    Timer {
        id: unfold

        interval: Appearance.bar.unfoldSettle
        onTriggered: {
            const name = root.pending;
            root.pending = "";
            if (name !== "")
                root.requested(name);
        }
    }
}
