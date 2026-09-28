pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Clipboard history, from cliphist.
//
// cliphist stores two fields per entry -- an id and a one-line preview -- and
// nothing else. The design asks for four things it does not have: what kind of
// thing each entry is, a thumbnail for the image ones, which application put it
// there, and when. The first two are derived from the preview and from
// `cliphist decode`; the last two cannot be, because cliphist records neither,
// so vela keeps its own sidecar beside the history and stamps each entry as it
// appears. Entries that predate the sidecar have no provenance and say so.
//
// The whole service degrades to an empty, available: false list when cliphist
// is not installed.
Singleton {
    id: root

    readonly property string cacheDir: `${Quickshell.env("HOME")}/.cache/vela/clipboard`
    readonly property string statePath: `${Quickshell.env("HOME")}/.local/state/vela/clipboard.json`

    // False until the first successful `cliphist list`. Consumers draw an
    // explanatory empty state rather than an empty list.
    property bool available: false
    property bool loaded: false

    // Newest first, capped at Config.clipboard.keep. Plain JS objects rather
    // than QObjects: two hundred entries is two hundred allocations either way,
    // and nothing here needs change notification of its own -- the list is
    // rebuilt whole whenever cliphist changes.
    property var entries: []

    property string search: ""

    readonly property int count: entries.length

    readonly property var results: {
        const needle = search.trim().toLowerCase();
        if (!needle)
            return entries;
        return entries.filter(e => e.text.toLowerCase().includes(needle) || e.app.toLowerCase().includes(needle));
    }

    // The clipboard panel's left column: Pinned, then Today, Yesterday, and
    // everything whose arrival time vela never saw.
    readonly property var pinnedEntries: results.filter(e => e.pinned)
    readonly property var today: results.filter(e => !e.pinned && e.day === 0)
    readonly property var yesterday: results.filter(e => !e.pinned && e.day === 1)
    readonly property var earlier: results.filter(e => !e.pinned && e.day > 1)

    // --- Type detection -----------------------------------------------------
    //
    // Config.clipboard.detectTypes gates every rule below: dropping "colour"
    // from it means a hex string is filed as plain text, which is what somebody
    // who never copies colours would want.

    readonly property var detect: Config.clipboard.detectTypes

    // The preview cliphist prints for binary data carries everything the image
    // row needs: "[[ binary data 123 KiB png 1182x725 ]]".
    readonly property var imageRe: /^\[\[\s*binary data\s+([\d.]+\s*\w+)\s+(\w+)\s+(\d+)x(\d+)\s*\]\]$/
    // A bare hex string needs at least one letter in it, or every six-digit
    // number copied out of a spreadsheet would be filed as a colour. With a
    // leading # the intent is unambiguous and digits alone are allowed.
    readonly property var colourRe: /^(?:#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})|(?=[0-9]*[a-fA-F])(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8}))$/
    readonly property var funcColourRe: /^(?:rgb|rgba|hsl|hsla)\(\s*[\d.%,\s/]+\)$/
    readonly property var urlRe: /^(?:https?|ftp|file|magnet):\/\/\S+$/i
    // A bare host with a path and no spaces -- "wiki.hyprland.org/Configuring".
    // Requires a dot and a plausible TLD so that "git rebase -i HEAD~4" is not
    // mistaken for one.
    readonly property var bareUrlRe: /^[\w-]+(?:\.[\w-]+)+\.[a-z]{2,}(?:\/\S*)?$/i
    readonly property var keyRe: /^(?:ssh-(?:rsa|ed25519|dss)|ecdsa-sha2-|-----BEGIN )/

    function wants(kind: string): bool {
        return detect.includes(kind);
    }

    // --- Actions ------------------------------------------------------------

    function copy(entry: var): void {
        if (!entry)
            return;
        // wl-copy guesses text; an image has to be told, or it lands on the
        // clipboard as the literal bytes of a PNG rendered as text.
        const type = entry.kind === "image" ? `image/${entry.imageFormat || "png"}` : "text/plain";
        actionProc.exec(["sh", "-c", "cliphist decode \"$1\" | wl-copy --type \"$2\"", "vela-clip", `${entry.id}`, type]);
    }

    // Text the shell made rather than found -- the launcher's answer to a sum.
    // It lands in the history like anything else copied.
    function copyText(text: string): void {
        actionProc.exec(["wl-copy", "--", text]);
    }

    // Put the entry on the clipboard and paste it into the focused window:
    // once wl-copy has taken the selection and the panel has let go of the
    // keyboard, the paste shortcut is typed with wtype -- ctrl+shift+v for a
    // terminal, ctrl+v for everything else. Without wtype it is a copy.
    function paste(entry: var): void {
        if (!entry)
            return;
        const type = entry.kind === "image" ? `image/${entry.imageFormat || "png"}` : "text/plain";
        const terminal = /kitty|foot|alacritty|wezterm|ghostty|konsole|terminal/i.test(Hypr.activeClass);
        const keys = terminal ? "wtype -M ctrl -M shift -k v -m shift -m ctrl" : "wtype -M ctrl -k v -m ctrl";
        actionProc.exec(["sh", "-c", `cliphist decode "$1" | wl-copy --type "$2" && command -v wtype >/dev/null && sleep 0.2 && ${keys}`, "vela-clip", `${entry.id}`, type]);
    }

    // cliphist's delete reads the list line it printed, not the id, so the line
    // is fed back exactly as it came out.
    function remove(entry: var): void {
        if (!entry)
            return;
        root.entries = root.entries.filter(e => e.id !== entry.id);
        actionProc.exec(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "vela-clip", entry.raw]);
    }

    // Everything but the pinned entries: Clear all in the panel, and
    // `qs -c vela ipc call clipboard wipe`. Pinned means kept, so those stay
    // -- `cliphist wipe` would take them too, and adding them back would give
    // them new ids and lose the pins. From the whole listing, not `entries`,
    // which stops at `clipboard.keep`: what is past that is cleared as well.
    // `cliphist delete` takes as many list lines on stdin as it is given.
    function wipe(): void {
        const doomed = root.unpinnedLines();
        if (doomed.length === 0)
            return;
        root.entries = root.entries.filter(e => e.pinned);
        actionProc.exec(["sh", "-c", "printf '%s\\n' \"$@\" | cliphist delete", "vela-clip", ...doomed]);
    }

    // What `wipe` would clear, for the panel's "Clear 24 items?". Read through
    // `entries`, which every refresh and every pin rebuilds: a pin changes
    // `state.pins` in place, which no binding hears.
    readonly property int clearable: {
        root.entries;
        return root.unpinnedLines().length;
    }

    function unpinnedLines(): var {
        const pins = root.state.pins;
        return root.listing.split("\n").filter(line => {
            const tab = line.indexOf("\t");
            return tab > 0 && !pins.includes(line.slice(0, tab));
        });
    }

    // Open a link in the browser, or an image in the image viewer: whatever
    // xdg-open picks for it. An image goes from its preview file, which the
    // list has already decoded, or is decoded into that place first. A bare
    // host ("wiki.hyprland.org/…") is given https:// to open at all.
    //
    // Detached rather than on `actionProc`: xdg-open can stay running as long
    // as the browser it started, and every copy and paste queued behind it.
    function open(entry: var): void {
        if (!entry)
            return;
        if (entry.kind === "link") {
            const url = /^[a-z][\w+.-]*:\/\//i.test(entry.text) ? entry.text : `https://${entry.text}`;
            Quickshell.execDetached(["xdg-open", url]);
        } else if (entry.kind === "image") {
            const file = `${root.cacheDir}/${entry.id}.${entry.imageFormat || "png"}`;
            Quickshell.execDetached(["sh", "-c", "mkdir -p \"${2%/*}\" && { [ -s \"$2\" ] || cliphist decode \"$1\" > \"$2\"; } && exec xdg-open \"$2\"", "vela-clip", `${entry.id}`, file]);
        }
    }

    function opens(entry: var): bool {
        return !!entry && (entry.kind === "link" || entry.kind === "image");
    }

    function togglePin(entry: var): void {
        if (!entry)
            return;
        const id = `${entry.id}`;
        state.pins = state.pins.includes(id) ? state.pins.filter(p => p !== id) : [...state.pins, id];
        saveState();
        rebuild();
    }

    function isPinned(entry: var): bool {
        return !!entry && state.pins.includes(`${entry.id}`);
    }

    // --- Presentation helpers ----------------------------------------------

    // The panel draws a swatch for a colour and a thumbnail for an image; every
    // other row gets a Material Symbols ligature.
    function icon(entry: var): string {
        if (!entry)
            return "notes";
        if (entry.kind === "link")
            return "link";
        if (entry.kind === "image")
            return "image";
        if (entry.kind === "colour")
            return "palette";
        return keyRe.test(entry.text) ? "key" : "notes";
    }

    // The mono second line: "PNG · 1204 × 760 · 412 KB" for an image, the hex
    // for a colour, nothing for plain text.
    function detail(entry: var): string {
        if (!entry)
            return "";
        if (entry.kind === "image")
            return `${entry.imageFormat.toUpperCase()} · ${entry.imageWidth} × ${entry.imageHeight} · ${entry.imageSize}`;
        if (entry.kind === "colour")
            return entry.colour;
        return "";
    }

    // "2m", "14m", "1h", "19h" -- the right-hand column of every row. Reads
    // Time.now so it reticks with the clock rather than going stale.
    function ago(entry: var): string {
        if (!entry || !entry.stamped)
            return "";
        const mins = Math.floor((Time.now - entry.time) / 60000);
        if (mins < 1)
            return "now";
        if (mins < 60)
            return `${mins}m`;
        const hours = Math.floor(mins / 60);
        return hours < 24 ? `${hours}h` : `${Math.floor(hours / 24)}d`;
    }

    // --- The sidecar --------------------------------------------------------
    //
    // { "pins": ["573"], "meta": { "573": { "app": "kitty", "at": 176... } } }
    //
    // Pins live here rather than in shell.json because a service cannot write
    // Config's adapter back to disk -- Config owns that FileView. Config's
    // clipboard.pinned seeds this file once and is honoured on every load, so
    // a pin set in the settings window still arrives.
    property var state: ({
            pins: [],
            meta: {}
        })

    // Set by the clipboard watcher the instant the selection changes, and
    // consumed by the refresh that follows, so a new entry is attributed to
    // whatever was focused when the copy happened rather than to whatever is
    // focused ~300ms later.
    property string pendingApp: ""

    function activeApp(): string {
        const ipc = Hypr.activeToplevel?.lastIpcObject ?? null;
        return ipc?.class || ipc?.initialClass || "";
    }

    function saveState(): void {
        stateFile.setText(JSON.stringify(root.state, null, 2));
    }

    // --- Parsing ------------------------------------------------------------

    function classify(text: string): string {
        if (wants("image") && imageRe.test(text))
            return "image";
        if (wants("colour") && (colourRe.test(text) || funcColourRe.test(text)))
            return "colour";
        if (wants("link") && (urlRe.test(text) || bareUrlRe.test(text)))
            return "link";
        return "text";
    }

    // Calendar days between a stamp and today, so "Today" means today and not
    // "within the last twenty-four hours".
    function dayOf(when: date): int {
        const start = new Date(Time.now);
        start.setHours(0, 0, 0, 0);
        const then = new Date(when.getTime());
        then.setHours(0, 0, 0, 0);
        return Math.max(0, Math.round((start.getTime() - then.getTime()) / 86400000));
    }

    function build(id: string, preview: string, raw: string): var {
        const kind = classify(preview);
        const meta = state.meta[id] ?? null;
        const stamped = meta !== null && meta.at > 0;
        const when = stamped ? new Date(meta.at) : new Date(0);

        const entry = {
            id: parseInt(id),
            raw: raw,
            kind: kind,
            text: preview,
            colour: "",
            imageFormat: "",
            imageWidth: 0,
            imageHeight: 0,
            imageSize: "",
            previewPath: "",
            pinned: state.pins.includes(id),
            app: meta?.app ?? "",
            stamped: stamped,
            time: when,
            // 0 today, 1 yesterday, 2+ earlier; unstamped entries sort last.
            day: stamped ? dayOf(when) : 9999
        };

        if (kind === "colour")
            entry.colour = preview.startsWith("#") ? preview.toUpperCase() : `#${preview.toUpperCase()}`;

        if (kind === "image") {
            const m = imageRe.exec(preview);
            entry.imageSize = m[1].replace("KiB", "KB").replace("MiB", "MB");
            entry.imageFormat = m[2];
            entry.imageWidth = parseInt(m[3]);
            entry.imageHeight = parseInt(m[4]);
            // A URL, not a path: Image.source resolves a bare path relative to
            // the QML file it was written in. Empty until the decode below has
            // written the file: an Image pointed at it before then fails, and
            // the same URL again once the file is there is no change to it, so
            // a just-copied image's preview stayed blank.
            entry.previewPath = root.decoded.includes(id) ? `file://${root.cacheDir}/${id}.${m[2]}` : "";
        }

        return entry;
    }

    // Raw `cliphist list` output, kept so a pin or a clock tick can rebuild the
    // entry objects without shelling out again.
    property string listing: ""

    function rebuild(): void {
        const built = [];
        const undecoded = [];

        for (const line of listing.split("\n")) {
            if (!line)
                continue;
            const tab = line.indexOf("\t");
            if (tab < 1)
                continue;
            const id = line.slice(0, tab);
            const entry = build(id, line.slice(tab + 1), line);
            built.push(entry);
            if (built.length >= Config.clipboard.keep)
                break;
        }

        // Anything never seen before is stamped now. On the very first run that
        // is the whole history, which would be a lie, so only entries that
        // arrive while vela is watching get a time -- `pendingApp` is set by
        // the watcher and is empty for a bulk first load.
        if (loaded && pendingApp !== "") {
            let stampedAny = false;
            for (const entry of built) {
                if (state.meta[`${entry.id}`])
                    continue;
                state.meta[`${entry.id}`] = {
                    app: pendingApp,
                    at: Date.now()
                };
                stampedAny = true;
            }
            pendingApp = "";
            if (stampedAny) {
                saveState();
                rebuild();
                return;
            }
        } else if (!loaded) {
            // First load: record every id as seen-but-unstamped, and write that
            // out. Without the write, the next launch would find an empty
            // sidecar and the watcher's first fire would stamp the entire
            // history as if it had all just been copied.
            for (const entry of built)
                if (!state.meta[`${entry.id}`])
                    state.meta[`${entry.id}`] = {
                        app: "",
                        at: 0
                    };
            loaded = true;
            prune();
            saveState();
        }

        for (const entry of built)
            if (entry.kind === "image" && !decoded.includes(`${entry.id}`))
                undecoded.push(`${entry.id}:${entry.imageFormat}`);

        root.entries = built;

        if (undecoded.length > 0)
            decodeProc.decode(undecoded);
    }

    // Entries cliphist has forgotten -- wiped, deleted, or pushed out of its own
    // store -- leave their provenance behind, and the sidecar would otherwise
    // grow for the life of the machine. Pruned against the *whole* listing, not
    // the capped one, so an entry sitting below Config.clipboard.keep keeps its
    // stamp for the day it comes back into view.
    function prune(): void {
        const live = {};
        for (const line of listing.split("\n")) {
            const tab = line.indexOf("\t");
            if (tab > 0)
                live[line.slice(0, tab)] = true;
        }
        const kept = {};
        for (const id in state.meta)
            if (live[id])
                kept[id] = state.meta[id];
        state.meta = kept;
        state.pins = state.pins.filter(id => live[id]);
    }

    // cliphist keeps one copy of anything: copying an entry again -- a paste
    // from this panel is one -- deletes it and stores it afresh under a new
    // id. Pins are kept by id, so the pin stayed with the id that had gone and
    // the entry came back unpinned. A pinned id that has left the listing
    // hands its pin to an entry new in this one that reads the same.
    function carryPins(before: string, after: string): void {
        if (!before || state.pins.length === 0)
            return;
        const parse = text => {
            const lines = new Map();
            for (const line of text.split("\n")) {
                const tab = line.indexOf("\t");
                if (tab > 0)
                    lines.set(line.slice(0, tab), line.slice(tab + 1));
            }
            return lines;
        };
        const was = parse(before);
        const now = parse(after);
        let moved = false;
        const pins = state.pins.map(id => {
            if (now.has(id) || !was.has(id))
                return id;
            for (const [fresh, text] of now) {
                if (!was.has(fresh) && text === was.get(id) && !state.pins.includes(fresh)) {
                    moved = true;
                    return fresh;
                }
            }
            return id;
        });
        if (moved) {
            state.pins = pins;
            saveState();
        }
    }

    // Image ids already written into the cache directory this session.
    property var decoded: []

    function refresh(): void {
        listProc.running = true;
    }

    // --- Processes ----------------------------------------------------------

    Process {
        id: listProc

        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.available = true;
                root.carryPins(root.listing, text);
                root.listing = text;
                root.rebuild();
            }
        }

        onExited: code => {
            if (code !== 0) {
                root.available = false;
                root.entries = [];
                console.warn(`[vela] cliphist unavailable (exit ${code}); clipboard history is empty`);
            }
        }
    }

    // One process for the whole batch rather than one per image: a first load
    // with a dozen screenshots in it should not fork a dozen times.
    Process {
        id: decodeProc

        property var pending: []

        function decode(ids: var): void {
            if (running)
                return;
            pending = ids;
            // The find(1) clause is the cache's only bound: a thumbnail whose
            // entry has long since left the history is deleted after a month
            // rather than kept for the life of the machine.
            command = ["sh", "-c", "d=\"$1\"; shift; mkdir -p \"$d\"; find \"$d\" -type f -mtime +30 -delete 2>/dev/null; for e in \"$@\"; do id=${e%%:*}; f=\"$d/${e%%:*}.${e#*:}\"; [ -s \"$f\" ] || cliphist decode \"$id\" > \"$f\"; done", "vela-clip", root.cacheDir, ...ids];
            running = true;
        }

        // Marked decoded whether or not the decode worked: a broken entry that
        // stayed on the retry list would be re-forked on every rebuild forever.
        onExited: code => {
            root.decoded = [...root.decoded, ...pending.map(e => e.split(":")[0])];
            pending = [];
            root.rebuild();
        }
    }

    // One at a time and in order. Setting `command` on a process that is
    // still running only replaces what it will run next, so of three quick
    // deletes the middle one used to be lost, and came back on the next
    // refresh; each waits its turn here instead.
    Process {
        id: actionProc

        property var queue: []

        function exec(cmd: var): void {
            if (running) {
                queue = [...queue, cmd];
                return;
            }
            command = cmd;
            running = true;
        }

        onExited: {
            if (queue.length > 0) {
                const next = queue[0];
                queue = queue.slice(1);
                command = next;
                running = true;
            }
            refreshDelay.restart();
        }
    }

    // --- Watching -----------------------------------------------------------

    // `wl-paste --watch` fires the moment the selection changes, which is the
    // only moment at which "which application copied this" is answerable --
    // polling would attribute a copy to whatever the user alt-tabbed to next.
    //
    // Quickshell does not kill child processes on signal and does not run QML
    // teardown, so a bare watcher would outlive the shell and reparent to init
    // -- one more every restart, all of them holding a Wayland connection.
    // setpriv asks the kernel to signal the child when its parent dies, which
    // survives the shell being SIGKILLed; a wrapper script that waits on a
    // stdin pipe does not, because the wrapper is killed before its trap can
    // run. Players starts cava the same way, for the same reason.
    //
    // `running` is assigned last on purpose: Quickshell starts the process the
    // moment that property is set, and QML assigns in declaration order, so a
    // parser declared after it would be attached to a process that has already
    // produced output. Measured, not theoretical.
    Process {
        id: watcher

        command: ["setpriv", "--pdeathsig", "TERM", "--", "wl-paste", "--watch", "echo", "changed"]

        stdout: SplitParser {
            onRead: data => {
                // Read the focused window now; cliphist has not necessarily
                // stored the entry yet, so the refresh waits a moment.
                root.pendingApp = root.activeApp() || "Unknown";
                refreshDelay.restart();
            }
        }

        onExited: code => {
            if (code !== 0)
                console.warn(`[vela] clipboard watcher exited (${code}); entries will still be listed by the poll below, but without provenance`);
        }

        running: true
    }

    Timer {
        id: refreshDelay

        interval: 300
        onTriggered: root.refresh()
    }

    // A slow safety net: entries stored while the watcher was down, or by
    // another machine writing the same history, still show up eventually --
    // without a stamp, because nothing saw them arrive.
    Timer {
        running: true
        interval: 30000
        repeat: true
        onTriggered: root.refresh()
    }

    FileView {
        id: stateFile

        path: root.statePath
        watchChanges: false
        atomicWrites: true
        printErrors: false

        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.state = {
                    pins: parsed.pins ?? [],
                    meta: parsed.meta ?? {}
                };
            } catch (e) {
                console.warn(`[vela] clipboard sidecar unreadable, starting fresh: ${e}`);
            }
            root.seedPins();
            root.refresh();
        }

        // No sidecar yet: seed the pins from shell.json and start recording.
        onLoadFailed: {
            root.seedPins();
            root.refresh();
        }
    }

    function seedPins(): void {
        const configured = Config.clipboard.pinned.map(p => `${p}`);
        const merged = [...state.pins];
        for (const pin of configured)
            if (!merged.includes(pin))
                merged.push(pin);
        state.pins = merged;
    }

    // Seeding only on the sidecar's first load made `clipboard.pinned` a
    // start-up key: adding one by hand did nothing until the shell restarted.
    // Re-seeding on every change fixes that, and it is safe to run repeatedly
    // because seedPins only ever adds -- a pin the user removed inside the
    // panel is not re-added unless it is in shell.json, which is the file
    // saying so.
    readonly property var configuredPins: Config.clipboard.pinned
    onConfiguredPinsChanged: root.seedPins()

    // Reachable from Hyprland keybinds and the `vela` CLI:
    //   qs -c vela ipc call clipboard wipe
    IpcHandler {
        target: "clipboard"

        function refresh(): void {
            root.refresh();
        }

        function wipe(): void {
            root.wipe();
        }
    }
}
