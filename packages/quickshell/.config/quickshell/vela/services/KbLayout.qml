pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Active keyboard layout, from Hyprland.
//
// `code` is the two-letter xkb form a bar chip shows, lowercase as xkb spells
// it ("it", "us"); `name` is the full xkb description ("Italian").
//
// Hyprland's event socket announces `activelayout` on every change but says
// nothing at startup and never lists the configured layouts, so the state is
// read from `hyprctl devices` and the event is only used as a trigger to read
// it again.
//
// Switching goes through `hyprctl switchxkblayout`, which is a top-level
// hyprctl command rather than a dispatcher -- so it is not the raw
// `Hyprland.dispatch("...")` that the Lua config manager silently discards, and
// there is nothing here for `Hypr` to route.
Singleton {
    id: root

    property bool available: false
    property string name: ""
    property var layouts: []
    property int index: 0
    readonly property string code: layouts[index] ?? ""
    readonly property bool multiple: layouts.length > 1

    function next(): void {
        if (!available || !multiple)
            return;
        // `all` rather than a device name: an external keyboard that kept the
        // old layout while the built-in one moved is the classic way for a
        // layout chip to start lying.
        switcher.exec(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    function setLayout(i: int): void {
        if (!available || i < 0 || i >= layouts.length || i === index)
            return;
        switcher.exec(["hyprctl", "switchxkblayout", "all", `${i}`]);
    }

    function refresh(): void {
        devices.running = true;
    }

    Process {
        id: switcher

        // hyprctl answers before Hyprland has emitted activelayout, so this
        // asks rather than waiting for an event that may be a frame away.
        onExited: root.refresh()
    }

    Process {
        id: devices

        running: true
        command: ["hyprctl", "-j", "devices"]

        stdout: StdioCollector {
            onStreamFinished: {
                let keyboards = [];
                try {
                    // Hyprland prints `"active_layout_index": none`, bare
                    // and invalid JSON, for a keyboard with no active layout
                    // -- a virtual one, say -- which failed the whole parse.
                    keyboards = JSON.parse(text.replace(/:\s*none\b/g, ": null")).keyboards ?? [];
                } catch (e) {
                    root.available = false;
                    return;
                }

                // Every keyboard reports the same configured layout list, but
                // only the main one follows the user: power buttons and lid
                // switches are keyboards too as far as libinput is concerned.
                const kb = keyboards.find(k => k.main) ?? keyboards.find(k => k.layout) ?? null;
                if (!kb) {
                    root.available = false;
                    return;
                }

                root.layouts = (kb.layout ?? "").split(",").map(l => l.trim()).filter(l => !!l);
                root.index = Math.max(0, Math.min(root.layouts.length - 1, kb.active_layout_index ?? 0));
                root.name = kb.active_keymap ?? "";
                root.available = root.layouts.length > 0;
            }
        }

        stderr: StdioCollector {}

        onExited: code => {
            // Not running under Hyprland, or hyprctl is not on PATH.
            if (code !== 0)
                root.available = false;
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            // activelayout>>KEYBOARDNAME,LAYOUTNAME. The payload names only the
            // keyboard that moved, so the index still has to be read back.
            if (event.name === "activelayout")
                root.refresh();
        }
    }
}
