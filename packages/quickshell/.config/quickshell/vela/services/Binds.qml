pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Cheatsheet data: every keybind Hyprland actually has, grouped and labelled.
//
// Read from `hyprctl binds -j` each time the cheatsheet opens, never from a list
// kept here, so it cannot drift from the config. A bind's description -- the
// `description` option of `hl.bind` in binds.lua -- says where it goes:
//
//     "Group: Action"   a row in that group
//     "Group › Action"  a secondary row, drawn a step quieter
//
// Binds that share a group, an action and their modifiers are one row, so
// super + 1 ... super + 5 read "super + 1–5". A bind with no description is
// listed under Unsorted with its raw dispatcher.
Singleton {
    id: root

    // [{ name, icon, rows: [{ keys: ["super", "D"], action, secondary }] }]
    property var groups: []
    // How many Hyprland binds the list was built from.
    property int count: 0
    // The modifier most binds are on -- the header's "mod is super".
    property string mod: "super"
    property bool loaded: false
    property string error: ""

    readonly property var order: ["Shell", "Capture", "Windows", "Sessions", "Workspaces", "Apps", "Media & system"]
    readonly property var icons: ({
            "Shell": "dashboard",
            "Capture": "photo_camera",
            "Windows": "select_window",
            "Sessions": "bookmarks",
            "Workspaces": "grid_view",
            "Apps": "apps",
            "Media & system": "tune",
            "Custom": "bolt",
            "Unsorted": "help"
        })

    // Keys that are not Hyprland binds, so hyprctl cannot report them: keys
    // inside a surface, and the tap of super that binds.lua reads from the raw
    // key stream. Each is placed after the row it belongs to ("" = first).
    readonly property var extras: [
        {
            group: "Workspaces",
            after: "",
            keys: ["super"],
            action: qsTr("Overview · tap"),
            secondary: false
        },
        {
            group: "Capture",
            after: "Region capture",
            keys: ["space"],
            action: qsTr("Full screen"),
            secondary: true
        },
        {
            group: "Capture",
            after: "Region capture",
            keys: ["W"],
            action: qsTr("Window under cursor"),
            secondary: true
        },
        {
            group: "Windows",
            after: "Window picker, backwards",
            keys: ["shift", "↵"],
            action: qsTr("Pull window to this workspace"),
            secondary: true
        }
    ]

    // Modifier bits as Hyprland prints them in `modmask`, in the order the
    // design spells a chord: super + ctrl + alt + shift.
    readonly property var mods: [[64, "super"], [4, "ctrl"], [8, "alt"], [1, "shift"]]

    readonly property var keyNames: ({
            "space": "space",
            "return": "↵",
            "escape": "esc",
            "tab": "tab",
            "grave": "`",
            "slash": "/",
            "less": "<",
            "print": "print",
            "backspace": "⌫",
            "delete": "del",
            "left": "←",
            "right": "→",
            "up": "↑",
            "down": "↓",
            "mouse:272": "drag",
            "mouse:273": "right drag",
            "mouse:274": "middle",
            "mouse_down": "scroll",
            "mouse_up": "scroll",
            "xf86audioraisevolume": "vol ±",
            "xf86audiolowervolume": "vol ±",
            "xf86audiomute": "mute",
            "xf86audiomicmute": "mic",
            "xf86monbrightnessup": "bright ±",
            "xf86monbrightnessdown": "bright ±",
            "xf86kbdbrightnessup": "kbd ±",
            "xf86kbdbrightnessdown": "kbd ±",
            "xf86audioplay": "play",
            "xf86audiopause": "play",
            "xf86audionext": "next",
            "xf86audioprev": "prev",
            "xf86audiostop": "stop"
        })

    // The pairs `keyNames` gives one name, so the cheatsheet can list each
    // pair as one row, told apart again for Settings: there every bind is a
    // row of its own, and two rows that both read "Volume" on "vol ±" could
    // not be told apart.
    readonly property var exactNames: ({
            "xf86audioraisevolume": "vol +",
            "xf86audiolowervolume": "vol −",
            "xf86monbrightnessup": "bright +",
            "xf86monbrightnessdown": "bright −",
            "xf86kbdbrightnessup": "kbd +",
            "xf86kbdbrightnessdown": "kbd −",
            "xf86audiopause": "pause"
        })

    function refresh(): void {
        if (!query.running)
            query.running = true;
    }

    function keyLabel(key: string): string {
        const k = key.toLowerCase();
        if (root.keyNames[k] !== undefined)
            return root.keyNames[k];
        if (k.length === 1 || /^f\d+$/.test(k))
            return k.toUpperCase();
        return key;
    }

    // `keyLabel`, for a key on its own rather than merged with its pair.
    function exactKeyLabel(key: string): string {
        return root.exactNames[key.toLowerCase()] ?? root.keyLabel(key);
    }

    // The keys of one row, merged: a run of digits is a range, arrows sit
    // together, and the rest are listed.
    function mergeKeys(labels: var): string {
        const unique = labels.filter((l, i) => labels.indexOf(l) === i);
        if (unique.length === 1)
            return unique[0];
        if (unique.every(l => /^\d$/.test(l))) {
            const n = unique.map(Number).sort((a, b) => a - b);
            return `${n[0]}–${n[n.length - 1]}`;
        }
        if (unique.every(l => "←→↑↓".includes(l)))
            return unique.join("");
        return unique.join(" ");
    }

    function build(binds: var): void {
        const groups = {};
        const rowIndex = {};
        const modCounts = {};
        let count = 0;

        for (const b of binds) {
            // A submap's binds only exist inside it, a catch-all is a submap's
            // net, and a switch is a lid, not a key.
            if (b.submap || b.catch_all || (b.key ?? "").startsWith("switch:"))
                continue;
            count++;

            const keys = [];
            for (const [bit, name] of root.mods) {
                if (b.modmask & bit) {
                    keys.push(name);
                    modCounts[name] = (modCounts[name] ?? 0) + 1;
                }
            }

            let group = "Unsorted";
            let action = `${b.dispatcher} ${b.arg}`.trim();
            let secondary = false;
            if (b.has_description && b.description) {
                const m = b.description.match(/^\s*([^:›]+?)\s*([:›])\s*(.+?)\s*$/);
                if (m) {
                    group = m[1];
                    secondary = m[2] === "›";
                    action = m[3];
                } else {
                    action = b.description;
                }
            }

            const id = `${group}\u0000${action}\u0000${b.modmask}`;
            if (rowIndex[id] === undefined) {
                groups[group] = groups[group] ?? [];
                rowIndex[id] = groups[group].length;
                groups[group].push({
                    mods: keys,
                    labels: [],
                    action: action,
                    secondary: secondary
                });
            }
            groups[group][rowIndex[id]].labels.push(root.keyLabel(b.key ?? ""));
        }

        for (const name in groups)
            groups[name] = groups[name].map(r => ({
                        keys: r.mods.concat([root.mergeKeys(r.labels)]),
                        action: r.action,
                        secondary: r.secondary
                    }));

        // The keys hyprctl cannot see, each after its anchor.
        const placed = {};
        for (const e of root.extras) {
            const rows = groups[e.group] ?? (groups[e.group] = []);
            const anchor = e.after ? rows.findIndex(r => r.action === e.after) : -1;
            if (e.after && anchor < 0)
                continue;
            const slot = `${e.group}\u0000${e.after}`;
            const at = anchor + 1 + (placed[slot] ?? 0);
            placed[slot] = (placed[slot] ?? 0) + 1;
            rows.splice(at, 0, {
                keys: e.keys,
                action: e.action,
                secondary: e.secondary
            });
        }

        // Known groups in the design's order, then anything else in the order
        // the config first names it, then Unsorted.
        const names = root.order.filter(n => groups[n]?.length > 0);
        for (const n in groups)
            if (!names.includes(n) && n !== "Unsorted" && groups[n].length > 0)
                names.push(n);
        if (groups["Unsorted"]?.length > 0)
            names.push("Unsorted");

        root.groups = names.map(n => ({
                    name: n,
                    icon: root.icons[n] ?? "keyboard",
                    rows: groups[n]
                }));
        root.count = count;

        let best = "super";
        for (const name in modCounts)
            if (modCounts[name] > (modCounts[best] ?? 0))
                best = name;
        root.mod = best;
        root.loaded = true;
    }

    Process {
        id: query

        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.build(JSON.parse(text));
                    root.error = "";
                } catch (e) {
                    root.error = qsTr("hyprctl binds answered with something that is not JSON");
                }
            }
        }

        onExited: code => {
            if (code !== 0)
                root.error = qsTr("hyprctl binds exited %1").arg(code);
        }
    }
}
