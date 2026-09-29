pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Settings, Keybinds: every bind, what it is on, and changing it.
//
// TWO FILES, NEITHER OF THEM OURS TO GUESS. hypr/conf/keybinds.lua writes the
// manifest -- every one of vela's binds, its id, its default and what it is on
// now -- to $XDG_RUNTIME_DIR/vela-keybinds.json each time Hyprland loads the
// config. What you change goes to ~/.config/vela/keybinds.json, which that
// file applies on top of binds.lua. So the defaults are always binds.lua's,
// never a copy kept here, and an update of the dots moves the ones you have
// not touched.
//
// EDITS WAIT FOR APPLY. A change is held here (`pending`) until Apply writes
// the file and reloads Hyprland, so two binds can be put on the same keys for
// a moment -- swapping a pair goes through that -- and the page shows both in
// red, with Apply refusing until they differ. A singleton, so moving to
// another page or closing the window keeps them.
//
// RECORDING. Hyprland acts on a bound combination before any window hears it,
// so while a combination is being recorded Hyprland is put in the
// `vela_capture` submap, where nothing is bound, and the settings window takes
// the keyboard exclusively. Esc is that submap's one bind, which takes
// Hyprland back out; the submap ending is how a recording is cancelled, by esc
// or by anything else.
Singleton {
    id: root

    readonly property string manifestPath: `${Quickshell.env("XDG_RUNTIME_DIR")}/vela-keybinds.json`
    readonly property string userPath: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/vela/keybinds.json`

    // From the manifest: [{ id, default, keys, family?, description, fixed? }]
    property var defaults: []
    property var problems: []
    property bool manifestLoaded: false
    property bool manifestMissing: false

    // keybinds.json as it is on disk, and as it is being edited.
    property var saved: ({
            changed: {},
            custom: []
        })
    property var pending: ({
            changed: {},
            custom: []
        })
    property bool userUnreadable: false

    readonly property bool dirty: JSON.stringify(root.pending) !== JSON.stringify(root.saved)

    // The order the groups are drawn in: the cheatsheet's.
    readonly property var groupOrder: ["Shell", "Capture", "Windows", "Sessions", "Workspaces", "Media & system"]

    // ---- the rows ---------------------------------------------------------

    // Every bind as it would be if Apply were pressed now:
    // [{ id, group, action, secondary, keys, defaultKeys, family, fixed,
    //    changed, off, custom, index, name, command }]
    readonly property var rows: {
        const out = [];
        const changed = root.pending.changed ?? {};
        for (const d of root.defaults) {
            const parsed = root.parseDescription(d.description);
            const chosen = d.fixed ? undefined : changed[d.id];
            const off = chosen === false;
            out.push({
                id: d.id,
                group: parsed.group,
                action: parsed.action,
                secondary: parsed.secondary,
                keys: off ? "" : (typeof chosen === "string" && chosen !== "" ? chosen : d.default),
                defaultKeys: d.default,
                family: d.family ?? null,
                fixed: d.fixed ?? "",
                changed: chosen !== undefined,
                off: off,
                custom: false
            });
        }
        (root.pending.custom ?? []).forEach((c, i) => {
            out.push({
                id: `custom:${i}`,
                group: "Custom",
                action: c.name || c.command || qsTr("New keybind"),
                secondary: false,
                keys: c.keys ?? "",
                defaultKeys: "",
                family: null,
                fixed: "",
                changed: false,
                off: false,
                custom: true,
                index: i,
                name: c.name ?? "",
                command: c.command ?? ""
            });
        });
        return out;
    }

    // Each combination and the rows on it, for the ones two or more share.
    // Families count once per key: super + 1 ... super + 9 are nine.
    readonly property var clashes: {
        const seen = {};
        for (const r of root.rows) {
            for (const combo of root.combosOf(r)) {
                const k = root.normalise(combo);
                (seen[k] = seen[k] ?? []).push(r.id);
            }
        }
        const out = {};
        for (const k in seen) {
            const ids = seen[k].filter((id, i, all) => all.indexOf(id) === i);
            if (ids.length > 1)
                out[k] = ids;
        }
        return out;
    }

    // What a row shares its keys with: [{ combo, others: [action, ...] }].
    function clashesFor(id: string): var {
        const out = [];
        for (const k in root.clashes) {
            const ids = root.clashes[k];
            if (!ids.includes(id))
                continue;
            out.push({
                combo: k,
                others: ids.filter(o => o !== id).map(o => root.actionOf(o))
            });
        }
        return out;
    }

    // Your own binds that cannot be applied yet, and why.
    function incomplete(row: var): string {
        if (!row.custom)
            return "";
        if (!row.keys)
            return qsTr("Needs keys");
        if (!row.command)
            return qsTr("Needs a command to run");
        return "";
    }

    readonly property int clashCount: Object.keys(root.clashes).length
    readonly property int incompleteCount: root.rows.filter(r => root.incomplete(r) !== "").length
    readonly property bool canApply: root.dirty && root.clashCount === 0 && root.incompleteCount === 0 && root.capturing === "" && !root.applying
    readonly property int changedCount: Object.keys(root.pending.changed ?? {}).length

    function actionOf(id: string): string {
        return root.rows.find(r => r.id === id)?.action ?? id;
    }

    // "Group: Action" or "Group › Action", as the cheatsheet reads them.
    function parseDescription(text: string): var {
        const m = (text ?? "").match(/^\s*([^:›]+?)\s*([:›])\s*(.+?)\s*$/);
        if (!m)
            return {
                group: "Other",
                action: text || qsTr("Unnamed"),
                secondary: false
            };
        return {
            group: m[1],
            action: m[3],
            secondary: m[2] === "›"
        };
    }

    // Every combination a row is on: one, a family's one per key, or none.
    function combosOf(row: var): var {
        if (!row.keys)
            return [];
        if (row.family)
            return row.family.map(k => `${row.keys} + ${k}`);
        return [row.keys];
    }

    // The same combination however it is written: "super+shift+s" and
    // "SHIFT + SUPER + S" are one. Modifiers in one order, key names folded to
    // lower case, as Hyprland reads them.
    readonly property var modOrder: ["SUPER", "CTRL", "ALT", "SHIFT"]
    readonly property var modAliases: ({
            "SUPER": "SUPER",
            "MOD4": "SUPER",
            "WIN": "SUPER",
            "LOGO": "SUPER",
            "META": "SUPER",
            "CTRL": "CTRL",
            "CONTROL": "CTRL",
            "ALT": "ALT",
            "MOD1": "ALT",
            "SHIFT": "SHIFT"
        })

    function split(combo: string): var {
        const parts = combo.split("+").map(p => p.trim()).filter(p => p !== "");
        const mods = [];
        const keys = [];
        for (const p of parts) {
            const m = root.modAliases[p.toUpperCase()];
            if (m)
                mods.push(m);
            else
                keys.push(p);
        }
        return {
            mods: root.modOrder.filter(m => mods.includes(m)),
            key: keys.join(" + ")
        };
    }

    function normalise(combo: string): string {
        const s = root.split(combo);
        return [...s.mods, s.key.toLowerCase()].filter(p => p !== "").join(" + ");
    }

    // The keycaps a row draws: ["super", "shift", "S"], or for a family the
    // modifiers and the range ("1–9", "←→↑↓").
    function capsOf(row: var): var {
        if (!row.keys)
            return [];
        const s = root.split(row.keys);
        const mods = s.mods.map(m => m.toLowerCase());
        if (row.family)
            return [...mods, Binds.mergeKeys(row.family.map(k => Binds.keyLabel(k)))];
        return [...mods, Binds.keyLabel(s.key)];
    }

    // What a bind is on now, the way the shell prints a key in its own text
    // ("super + alt + S"), for the surfaces that name their own keys: the
    // sessions panel and the wallpaper switcher. "" for a bind that is off;
    // `fallback` -- shell.json's label -- when Hyprland has written no list.
    function label(id: string, fallback: string): string {
        const d = root.defaults.find(x => x.id === id);
        if (!d)
            return fallback;
        return root.capsOf({
            keys: d.keys,
            family: d.family ?? null
        }).join(" + ");
    }

    // ---- editing ----------------------------------------------------------

    function copy(v: var): var {
        return JSON.parse(JSON.stringify(v));
    }

    function edit(mutate: var): void {
        const next = root.copy(root.pending);
        next.changed = next.changed ?? {};
        next.custom = next.custom ?? [];
        mutate(next);
        root.pending = next;
    }

    // A default's keys. Put back on its default, it leaves the file, so it
    // follows binds.lua from then on.
    function setKeys(id: string, keys: string): void {
        const d = root.defaults.find(x => x.id === id);
        root.edit(next => {
            if (id.startsWith("custom:")) {
                const i = Number(id.slice(7));
                if (next.custom[i])
                    next.custom[i].keys = keys;
            } else if (d && root.normalise(keys) === root.normalise(d.default)) {
                delete next.changed[id];
            } else {
                next.changed[id] = keys;
            }
        });
    }

    function turnOff(id: string): void {
        root.edit(next => next.changed[id] = false);
    }

    function restore(id: string): void {
        root.edit(next => delete next.changed[id]);
    }

    // Reset: every default back. Your own binds are not defaults and stay.
    function restoreAll(): void {
        root.edit(next => next.changed = {});
    }

    function addCustom(): int {
        let at = 0;
        root.edit(next => {
            next.custom.push({
                name: "",
                keys: "",
                command: ""
            });
            at = next.custom.length - 1;
        });
        return at;
    }

    function setCustom(index: int, field: string, value: string): void {
        root.edit(next => {
            if (next.custom[index])
                next.custom[index][field] = value;
        });
    }

    function removeCustom(index: int): void {
        root.edit(next => next.custom.splice(index, 1));
    }

    function discard(): void {
        root.cancelCapture();
        root.pending = root.copy(root.saved);
    }

    // Writes the file and has Hyprland read it. Refused while two binds
    // share keys or one of yours is unfinished: the page says which.
    property bool applying: false

    function apply(): void {
        if (!root.canApply)
            return;
        root.applying = true;
        const doc = {
            changed: root.pending.changed ?? {},
            custom: (root.pending.custom ?? []).map(c => ({
                        name: c.name ?? "",
                        keys: c.keys,
                        command: c.command
                    }))
        };
        userFile.setText(`${JSON.stringify(doc, null, 2)}\n`);
    }

    // ---- recording --------------------------------------------------------

    // The row being recorded, or "".
    property string capturing: ""
    // What is held so far, for the row to show while it waits.
    property string held: ""
    // Why the last key could not be used, until the next.
    property string refusal: ""

    function startCapture(id: string): void {
        if (root.capturing === id)
            return;
        const already = root.capturing !== "";
        root.capturing = id;
        root.held = "";
        root.refusal = "";
        captureTimeout.restart();
        if (!already)
            root.submap("vela_capture");
    }

    function cancelCapture(): void {
        if (root.capturing === "")
            return;
        root.capturing = "";
        root.held = "";
        root.refusal = "";
        captureTimeout.stop();
        root.ownResets++;
        root.submap("reset");
    }

    // Into and out of the submap, one dispatch at a time: two hyprctl calls
    // started together can land either way round, and a reset overtaking the
    // next recording's way in left Hyprland out of the submap mid-recording.
    property var submapQueue: []
    property bool submapBusy: false
    // Resets of our own still to come back as events, so they are not taken
    // for esc ending the next recording.
    property int ownResets: 0

    function submap(name: string): void {
        root.submapQueue = [...root.submapQueue, name];
        root.pumpSubmap();
    }

    function pumpSubmap(): void {
        if (root.submapBusy || root.submapQueue.length === 0)
            return;
        const name = root.submapQueue[0];
        root.submapQueue = root.submapQueue.slice(1);
        root.submapBusy = true;
        Hypr.dispatchThen(`hl.dsp.submap("${name}")`, () => {
            root.submapBusy = false;
            root.pumpSubmap();
        });
    }

    Timer {
        id: captureTimeout

        interval: 15000
        onTriggered: root.cancelCapture()
    }

    // The submap ending while recording: esc, which is bound there, or
    // anything else that took Hyprland out of it.
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name !== "submap" || event.data === "vela_capture")
                return;
            if (root.ownResets > 0) {
                root.ownResets--;
                return;
            }
            if (root.capturing !== "") {
                root.capturing = "";
                root.held = "";
                root.refusal = "";
                captureTimeout.stop();
            }
        }
    }

    // A key from the settings window while recording. Returns true when it
    // was used.
    function keyPressed(event: var): bool {
        if (root.capturing === "")
            return false;
        captureTimeout.restart();
        const mods = [];
        if (event.modifiers & Qt.MetaModifier)
            mods.push("SUPER");
        if (event.modifiers & Qt.ControlModifier)
            mods.push("CTRL");
        if (event.modifiers & Qt.AltModifier)
            mods.push("ALT");
        if (event.modifiers & Qt.ShiftModifier)
            mods.push("SHIFT");

        const key = root.keyName(event);
        if (key === null) {
            // A modifier on its own: shown while it is held.
            root.held = mods.join(" + ");
            return true;
        }

        const row = root.rows.find(r => r.id === root.capturing);
        if (row?.family) {
            // A family keeps its keys; what was pressed says the modifiers.
            if (mods.length === 0) {
                root.refusal = qsTr("Hold at least one modifier -- on their own, these keys would stop typing");
                return true;
            }
            root.setKeys(root.capturing, mods.join(" + "));
        } else {
            if (mods.length === 0 && !root.bareAllowed(key)) {
                root.refusal = qsTr("Add a modifier -- on its own, that key would stop typing");
                return true;
            }
            root.setKeys(root.capturing, [...mods, key].join(" + "));
        }
        root.cancelCapture();
        return true;
    }

    // Keys that are fine to bind with nothing held, because nobody types them.
    function bareAllowed(key: string): bool {
        return /^(F\d+|XF86\w+|Print|Pause|Scroll_Lock|Menu)$/.test(key);
    }

    // The name Hyprland knows a key by, or null for a modifier.
    //
    // Hyprland matches a bind on the key's own symbol, not on what shift turns
    // it into: super + shift + 1 is bound as "1", though Qt reports "!". So a
    // key read with shift held, that is not a letter or a named key, is bound
    // by its keycode (`code:NN`), which is the key itself whatever the layout.
    // The number row is the exception, because it is the one everybody binds:
    // its keycodes are 10 to 19 on every keyboard.
    function keyName(event: var): var {
        const k = event.key;
        if (root.modifierKeys.includes(k))
            return null;
        if (root.namedKeys[k] !== undefined)
            return root.namedKeys[k];
        if (k >= Qt.Key_A && k <= Qt.Key_Z)
            return String.fromCharCode(k);
        const code = event.nativeScanCode;
        if (code >= 10 && code <= 19)
            return code === 19 ? "0" : String(code - 9);
        if (!(event.modifiers & Qt.ShiftModifier)) {
            if (k >= Qt.Key_0 && k <= Qt.Key_9)
                return String.fromCharCode(k);
            if (root.symbolKeys[k] !== undefined)
                return root.symbolKeys[k];
        }
        return code > 0 ? `code:${code}` : null;
    }

    readonly property var modifierKeys: [Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Hyper_L, Qt.Key_Hyper_R, Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr, Qt.Key_CapsLock, Qt.Key_NumLock]

    readonly property var namedKeys: {
        const m = {};
        m[Qt.Key_Space] = "SPACE";
        m[Qt.Key_Return] = "RETURN";
        m[Qt.Key_Enter] = "KP_Enter";
        m[Qt.Key_Escape] = "ESCAPE";
        m[Qt.Key_Tab] = "TAB";
        m[Qt.Key_Backtab] = "TAB";
        m[Qt.Key_Backspace] = "BACKSPACE";
        m[Qt.Key_Delete] = "DELETE";
        m[Qt.Key_Insert] = "INSERT";
        m[Qt.Key_Home] = "HOME";
        m[Qt.Key_End] = "END";
        m[Qt.Key_PageUp] = "Page_Up";
        m[Qt.Key_PageDown] = "Page_Down";
        m[Qt.Key_Left] = "left";
        m[Qt.Key_Right] = "right";
        m[Qt.Key_Up] = "up";
        m[Qt.Key_Down] = "down";
        m[Qt.Key_Print] = "Print";
        m[Qt.Key_Pause] = "Pause";
        m[Qt.Key_ScrollLock] = "Scroll_Lock";
        m[Qt.Key_Menu] = "Menu";
        for (let i = 1; i <= 24; i++)
            m[Qt.Key_F1 + i - 1] = `F${i}`;
        m[Qt.Key_VolumeUp] = "XF86AudioRaiseVolume";
        m[Qt.Key_VolumeDown] = "XF86AudioLowerVolume";
        m[Qt.Key_VolumeMute] = "XF86AudioMute";
        m[Qt.Key_MicMute] = "XF86AudioMicMute";
        m[Qt.Key_MediaPlay] = "XF86AudioPlay";
        m[Qt.Key_MediaPause] = "XF86AudioPause";
        m[Qt.Key_MediaTogglePlayPause] = "XF86AudioPlay";
        m[Qt.Key_MediaNext] = "XF86AudioNext";
        m[Qt.Key_MediaPrevious] = "XF86AudioPrev";
        m[Qt.Key_MediaStop] = "XF86AudioStop";
        m[Qt.Key_MonBrightnessUp] = "XF86MonBrightnessUp";
        m[Qt.Key_MonBrightnessDown] = "XF86MonBrightnessDown";
        m[Qt.Key_KeyboardBrightnessUp] = "XF86KbdBrightnessUp";
        m[Qt.Key_KeyboardBrightnessDown] = "XF86KbdBrightnessDown";
        m[Qt.Key_Calculator] = "XF86Calculator";
        m[Qt.Key_Search] = "XF86Search";
        m[Qt.Key_LaunchMail] = "XF86Mail";
        m[Qt.Key_Explorer] = "XF86Explorer";
        return m;
    }

    // Symbols typed without shift, by their X names: the US layout's, and the
    // Italian keys this config already binds around.
    readonly property var symbolKeys: {
        const m = {};
        m[Qt.Key_QuoteLeft] = "grave";
        m[Qt.Key_Minus] = "minus";
        m[Qt.Key_Equal] = "equal";
        m[Qt.Key_BracketLeft] = "bracketleft";
        m[Qt.Key_BracketRight] = "bracketright";
        m[Qt.Key_Backslash] = "backslash";
        m[Qt.Key_Semicolon] = "semicolon";
        m[Qt.Key_Apostrophe] = "apostrophe";
        m[Qt.Key_Comma] = "comma";
        m[Qt.Key_Period] = "period";
        m[Qt.Key_Slash] = "slash";
        m[Qt.Key_Less] = "less";
        m[Qt.Key_Plus] = "plus";
        m[Qt.Key_Egrave] = "egrave";
        m[Qt.Key_Eacute] = "eacute";
        m[Qt.Key_Agrave] = "agrave";
        m[Qt.Key_Ograve] = "ograve";
        m[Qt.Key_Ugrave] = "ugrave";
        m[Qt.Key_Igrave] = "igrave";
        m[Qt.Key_Ccedilla] = "ccedilla";
        m[Qt.Key_Ntilde] = "ntilde";
        m[Qt.Key_Odiaeresis] = "odiaeresis";
        m[Qt.Key_Adiaeresis] = "adiaeresis";
        m[Qt.Key_Udiaeresis] = "udiaeresis";
        m[Qt.Key_ssharp] = "ssharp";
        return m;
    }

    // ---- files ------------------------------------------------------------

    FileView {
        id: manifest

        path: root.manifestPath
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.defaults = parsed.binds ?? [];
                root.problems = parsed.problems ?? [];
                root.manifestMissing = false;
            } catch (e) {
                root.problems = [qsTr("The list of keybinds Hyprland wrote could not be read")];
            }
            root.manifestLoaded = true;
        }
        onLoadFailed: {
            root.defaults = [];
            root.manifestMissing = true;
            root.manifestLoaded = true;
        }
    }

    FileView {
        id: userFile

        path: root.userPath
        watchChanges: true
        atomicWrites: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: {
            let doc = {
                changed: {},
                custom: []
            };
            try {
                const parsed = JSON.parse(text());
                doc = {
                    changed: parsed.changed ?? {},
                    custom: parsed.custom ?? []
                };
                root.userUnreadable = false;
            } catch (e) {
                root.userUnreadable = true;
            }
            root.adopt(doc);
        }
        // No file is the ordinary state: nothing changed yet.
        onLoadFailed: {
            root.userUnreadable = false;
            root.adopt({
                changed: {},
                custom: []
            });
        }
        onSaved: {
            root.applying = false;
            reloader.running = true;
        }
        onSaveFailed: {
            root.applying = false;
            root.problems = [...root.problems, qsTr("Could not write %1").arg(root.userPath)];
        }
    }

    // The file as read. Edits in progress are kept if they were made on top
    // of what was there; with none, the page simply follows the file.
    function adopt(doc: var): void {
        const clean = !root.dirty;
        root.saved = doc;
        if (clean || JSON.stringify(root.pending) === JSON.stringify(doc))
            root.pending = root.copy(doc);
    }

    // Hyprland reads keybinds.json when it loads the config; the manifest it
    // writes on the way comes back through the FileView above, and the
    // cheatsheet asks hyprctl again next time it opens.
    Process {
        id: reloader

        command: ["hyprctl", "reload"]
        onExited: Binds.refresh()
    }
}
