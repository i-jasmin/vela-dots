pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Hyprland: state, and the one place that dispatches to it.
//
// Dispatching first, because it is the trap this file exists for.
//
// Under the Lua config manager -- which is what vela ships, and what Hyprland
// prefers when hyprland.lua exists -- the IPC `dispatch` command evaluates its
// argument as **Lua**, not as a legacy dispatcher line. `dispatch workspace 2`
// comes back with a parse error, silently, because nothing in QML checks the
// reply. Every call has to be a Lua expression instead:
//
//     hl.dsp.focus({workspace = "2"})
//
// Routing every dispatch through here means the syntax is stated once, and a
// future move back to hyprlang is one file rather than a hunt.
//
// State second. Everything the shell reads about windows, workspaces and
// monitors comes from here so that the awkward parts -- the initial-query gap,
// the events that move a window without changing the toplevel list -- are
// handled once rather than in each of the six surfaces that need them.
Singleton {
    id: root

    // Which config manager Hyprland loaded. Getting this wrong breaks every
    // dispatch in the shell *silently*, so it is not taken on one source's
    // word.
    //
    // `Hyprland.usingLua` has reported **false** while
    // `~/.config/hypr/hyprland.lua` is very much what is loaded -- measured
    // with a probe, and the consequence was that focusing a workspace, moving a
    // window between workspaces, focusing a window, closing one and logging out
    // all took the legacy branch and were discarded by the compositor without
    // an error anywhere. So the file is checked too, the same way Hyprland
    // itself decides: hyprland.lua wins over hyprland.conf when it exists.
    //
    // Either source saying yes is enough. A false negative is silent breakage;
    // a false positive would at least produce a Lua error on the socket.
    readonly property bool lua: Hyprland.usingLua || root.luaConfigFound

    // NOT `luaConfig.loaded`, and this cost a second round of the same bug.
    // Quickshell's FileView carries a *property* named `loaded` and a *signal*
    // named `loaded`. A binding on the property latches at whatever it read
    // during construction -- false, because nothing has been read off disk yet
    // -- and never updates, even though `onLoaded` does fire. Measured: inside
    // this singleton `luaConfig.loaded` bound to false and `luaConfig.text()`
    // bound to length 0, while an imperative read of the same FileView in the
    // same process returned the file's 1015 bytes.
    //
    // So the answer is taken imperatively, in a plain bool that does notify.
    property bool luaConfigFound: false

    FileView {
        id: luaConfig

        path: `${Quickshell.env("HOME")}/.config/hypr/hyprland.lua`
        // Synchronous, so the answer is right before the first dispatch rather
        // than a few frames later.
        blockLoading: true
        preload: true
        // Missing is the answer, not a problem: it means hyprlang.
        printErrors: false

        onLoaded: root.luaConfigFound = true
        onLoadFailed: root.luaConfigFound = false
    }

    Component.onCompleted: root.luaConfigFound = luaConfig.text().length > 0

    // --- windows --------------------------------------------------------
    //
    // These are the live `HyprlandToplevel` objects, deliberately, not a
    // projection into plain JS objects. A delegate binding `text: client.title`
    // re-renders when that one window is renamed; a projection would only
    // re-run when the *list* changed, so every title in the window picker would
    // freeze at whatever it said when the panel opened. The cost is that the
    // IPC shape leaks, which is what `classOf`/`iconOf` below are for.
    readonly property list<HyprlandToplevel> clients: Hyprland.toplevels.values

    // `Hyprland.activeToplevel` is null for any window that already existed when
    // the shell started: Quickshell learns the active window from the `activewindow`
    // event, and no event is replayed for windows that were open before it
    // connected. After a config reload that is every window on screen, which is
    // why the bar's title read "Desktop" over a focused window.
    //
    // The initial query does populate `focusHistoryID`, and 0 means most recently
    // focused, so that is the reliable answer until the first real event arrives.
    // Stated here once rather than in each of the three places that need it.
    readonly property var activeToplevel: Hyprland.activeToplevel ?? (Hyprland.toplevels.values.find(t => t.lastIpcObject?.focusHistoryID === 0) ?? null)
    readonly property string activeTitle: activeToplevel?.title ?? ""
    readonly property string activeClass: classOf(activeToplevel)
    readonly property string activeAddress: activeToplevel?.address ?? ""

    // --- workspaces -----------------------------------------------------
    //
    // Ordered by id: Hyprland hands them back in creation order, which is the
    // order they were first visited rather than the order the bar draws them.
    readonly property var workspaces: [...Hyprland.workspaces.values].sort((a, b) => a.id - b.id)
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    // Bar pills bind to this rather than to `focusedWorkspace?.id`, so a null
    // during the first second reads as workspace 1 and not as "no pill active".
    readonly property int focusedWorkspaceId: Hyprland.focusedWorkspace?.id ?? 1

    // The workspaces there are, as the bar's rail and the overview both draw
    // them -- one list, so the two never disagree. `bar.workspaces.count` of
    // them always, and past that every number up to the highest workspace
    // Hyprland has: one with windows on it, or on screen.
    //
    // Every number up to it, not only the ones that exist. Hyprland drops an
    // empty workspace the moment you leave it, so going from an empty 6 to a
    // new 7 took 6 away and left the run reading 5, 7. Filled in, 6 stays
    // until 7 goes too; an empty one at the end still goes when you leave it.
    //
    // Filled only as far as a number reaches (1-9). A workspace past that --
    // a stray 47 from a script -- is added on its own, not with the
    // thirty-eight empty ones before it.
    //
    // Special workspaces are negative and are not in it: they are not
    // somewhere you switch to by number.
    readonly property var workspaceIds: {
        const cfg = Config.bar.workspaces;
        let top = Math.min(cfg.count, cfg.hideEmptyAfter);
        for (const w of root.workspaces)
            if (w.id > top && w.id <= root.numbered)
                top = w.id;
        const ids = [];
        for (let i = 1; i <= top; i++)
            ids.push(i);
        for (const w of root.workspaces)
            if (w.id > root.numbered && !ids.includes(w.id))
                ids.push(w.id);
        return ids.sort((a, b) => a - b);
    }

    // How far a number reaches: super + 1-9, and 1-9 in the overview.
    readonly property int numbered: 9

    // The workspace the overview's new-workspace card makes: the number after
    // the run, which has no gaps, or 0 once 1-9 are all in it.
    readonly property int nextWorkspace: {
        for (let i = 1; i <= root.numbered; i++)
            if (!root.workspaceIds.includes(i))
                return i;
        return 0;
    }

    // { "<id>": <window count> }, for the bar's pill badges and the
    // "Workspace 2 · 3 windows" header on its popout.
    //
    // Recomputed on events rather than bound, because the obvious binding is
    // wrong: moving a window between workspaces changes one toplevel's
    // `workspace` property and leaves `Hyprland.toplevels.values` identical, so
    // a binding over the list never re-runs and the counts drift apart from
    // what is on screen. `movewindow` is in the event list below for exactly
    // that reason.
    property var windowCounts: ({})

    // { "<workspace id>": "<address>" } -- the window last focused on each
    // workspace, from the activewindowv2 events. `focusHistoryID` would say the
    // same, but it only refreshes on a full toplevel query, so it stops
    // following focus the moment the shell has started.
    property var lastFocused: ({})

    // Every window focused since the shell started, the most recent first,
    // from the same events: alt-tab's order. `focusHistoryID` says the same
    // only as of the last full toplevel query, a round trip a quick alt + tab
    // is over before -- and it then switched to whatever had been second when
    // that query last answered.
    property var focusOrder: []

    // Where a window stands in focus order, 0 being the focused one. Windows
    // not focused since the shell started follow all those that were, in the
    // order the last query gave: none of them has been focused since, so the
    // order among them still holds, however stale the numbers are.
    function focusRank(t: var): real {
        const i = root.focusOrder.indexOf(t?.address ?? "");
        return i >= 0 ? i : root.focusOrder.length + (t?.lastIpcObject?.focusHistoryID ?? 9999);
    }

    function windowsOn(id: int): list<HyprlandToplevel> {
        return Hyprland.toplevels.values.filter(t => t.workspace?.id === id);
    }

    function countOn(id: int): int {
        return windowCounts[id] ?? 0;
    }

    function recount(): void {
        const counts = {};
        for (const t of Hyprland.toplevels.values) {
            const id = t.workspace?.id;
            if (id !== undefined && id !== null)
                counts[id] = (counts[id] ?? 0) + 1;
        }
        root.windowCounts = counts;
    }

    // --- monitors -------------------------------------------------------
    readonly property list<HyprlandMonitor> monitors: Hyprland.monitors.values
    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor
    // The bar dims on every monitor but this one. Comparing names rather than
    // objects: `Variants` hands a module a `ShellScreen`, which is a different
    // object to the `HyprlandMonitor` with the same name.
    readonly property string focusedMonitorName: Hyprland.focusedMonitor?.name ?? ""

    function monitorFor(name: string): HyprlandMonitor {
        return Hyprland.monitors.values.find(m => m.name === name) ?? null;
    }

    function activeWorkspaceOn(name: string): int {
        return monitorFor(name)?.activeWorkspace?.id ?? root.focusedWorkspaceId;
    }

    // Emitted whenever focus moves -- window, workspace or monitor. A surface
    // that only needs to know *that* focus moved (the per-monitor dim, the
    // overview's close-on-focus-change) listens here instead of watching three
    // properties and de-duplicating them itself.
    signal focusMoved

    // --- identity -------------------------------------------------------
    //
    // A window's class is the only handle the shell has on "which app is this",
    // and it arrives from three places with three spellings, so resolving it is
    // done once here.

    function classOf(client: var): string {
        const o = client?.lastIpcObject;
        return o?.class ?? o?.initialClass ?? "";
    }

    // The real application icon, for the dock and the window picker. Hyprland's
    // class is usually but not always the desktop-entry id -- `heuristicLookup`
    // is Quickshell's own matcher for the cases where it is not.
    function entryFor(appClass: string): DesktopEntry {
        if (!appClass)
            return null;
        return DesktopEntries.heuristicLookup(appClass) ?? null;
    }

    // A Material Symbols ligature, for the places that draw a monochrome glyph
    // rather than an app icon: the bar's focused-window chip and the workspace
    // popout's rows. Kept beside `entryFor` because both answer "which app is
    // this" and a second copy in the bar would drift.
    function symbolFor(appClass: string): string {
        const c = (appClass ?? "").toLowerCase();
        if (!c)
            return "web_asset";
        if (/kitty|foot|alacritty|wezterm|ghostty|term|konsole/.test(c))
            return "terminal";
        if (/firefox|chrome|chromium|zen|brave|librewolf|epiphany/.test(c))
            return "public";
        if (/code|vscode|zed|jetbrains|idea|pycharm/.test(c))
            return "code";
        if (/nautilus|thunar|dolphin|nemo|files/.test(c))
            return "folder";
        if (/discord|slack|telegram|signal|element/.test(c))
            // chat_bubble, not forum: the design draws a single bubble for the
            // messaging cluster, and this answer is also what the notification
            // digest labels a group with.
            return "chat_bubble";
        // Package managers announce themselves by name when a transaction ends,
        // and a finished download is what that notification means.
        if (/^(dnf5?|pacman|paru|yay|apt|zypper|flatpak|packagekit|gnome-software|discover)$/.test(c))
            return "download_done";
        if (/spotify|music|rhythmbox|audacious/.test(c))
            return "music_note";
        if (/mpv|vlc|celluloid|video/.test(c))
            return "movie";
        if (/thunderbird|geary|mail/.test(c))
            return "mail";
        if (/gimp|inkscape|krita|blender|image/.test(c))
            return "palette";
        if (/steam|lutris|heroic/.test(c))
            return "sports_esports";
        if (/nvim|vim|emacs|obsidian|writer/.test(c))
            return "edit_note";
        if (/settings|control|config/.test(c))
            return "settings";
        return "web_asset";
    }

    function iconOf(client: var): string {
        return symbolFor(classOf(client));
    }

    // --- dispatch -------------------------------------------------------

    // The `address:` selector Hyprland matches a window by. Quickshell's
    // `HyprlandToplevel.address` is bare hex ("55d0c3a1b2c0") while Hyprland
    // compares against "0x55d0c3a1b2c0", so an address passed through as-is
    // matches no window: focus logs "window not found", and close and move
    // do nothing at all.
    function windowSelector(address: string): string {
        return `address:${address.startsWith("0x") ? address : "0x" + address}`;
    }

    function focusWorkspace(id: var): void {
        Hyprland.dispatch(lua ? `hl.dsp.focus({workspace = "${id}"})` : `workspace ${id}`);
    }

    // The same, from a surface that holds the keyboard and is closing -- the
    // overview. Sent at once, the switch happened and was then undone: when
    // the surface lets go of the keyboard, Hyprland's `refocusLastWindow`
    // finds the closing surface still under the cursor, cannot give it focus,
    // and focuses the last window instead -- which is on the workspace just
    // left, so Hyprland goes back to it. After the release there is nothing
    // to go back to.
    function focusWorkspaceAfterRelease(id: var): void {
        root.dispatchAfterRelease(lua ? `hl.dsp.focus({workspace = "${id}"})` : `workspace ${id}`);
    }

    // Anything that moves keyboard focus to a window goes out a moment late.
    //
    // Hyprland gives no window keyboard focus while a layer surface holds it
    // exclusively -- "Refusing a keyboard focus to a window because of an
    // exclusive ls", in the 0.56 binary -- and every vela surface that focuses
    // a window (the window picker, the overview, the workspace popout) holds it
    // up to the moment it closes. Closing only asks for that to be dropped on
    // the surface's next frame, while a dispatch reaches Hyprland at once. So
    // alt-tab's focus got there first and was refused whole: a window on
    // another workspace was never reached. `releaseDelay` outlasts that frame.
    readonly property int releaseDelay: 120
    property list<string> afterRelease: []

    // Window operations go out through `hyprctl`, not `Hyprland.dispatch()`.
    // Hyprland answers every dispatch -- "ok", or what was wrong -- and
    // Quickshell's dispatch() drops the answer, so a refused move or focus
    // looked exactly like a drag or an alt-tab that did nothing. hyprctl
    // prints it, and anything but "ok" goes to the shell log (`vela shell
    // log`) with the command that earned it. Workspace switches stay on the
    // socket: the bar's scroll wheel sends those by the dozen.
    function dispatchChecked(command: string): void {
        root.dispatchThen(command, null);
    }

    // The same, calling `done(reply)` once Hyprland has answered -- for work
    // that has to happen in order. Each dispatch is its own hyprctl, and two
    // started back to back can arrive either way round.
    function dispatchThen(command: string, done: var): void {
        checkedDispatch.createObject(root, {
            request: command,
            done: done
        });
    }

    Component {
        id: checkedDispatch

        Process {
            id: proc

            required property string request
            property var done: null
            property string reply: ""

            command: ["hyprctl", "dispatch", proc.request]
            running: true

            stdout: StdioCollector {
                onStreamFinished: {
                    proc.reply = text.trim();
                    if (proc.reply !== "ok")
                        console.warn(`[vela] Hyprland refused ${proc.request}: ${proc.reply || "no answer"}`);
                }
            }

            onExited: {
                const done = proc.done;
                const reply = proc.reply;
                Qt.callLater(proc.destroy);
                if (done)
                    done(reply);
            }
        }
    }

    function dispatchAfterRelease(command: string): void {
        root.afterRelease = [...root.afterRelease, command];
        releaseTimer.restart();
    }

    Timer {
        id: releaseTimer

        interval: root.releaseDelay
        onTriggered: {
            // Copied: a `list<string>` read is a live reference to the
            // property, so clearing the property emptied `queued` with it.
            const queued = [...root.afterRelease];
            root.afterRelease = [];
            for (const command of queued)
                root.dispatchChecked(command);
        }
    }

    function focusWindow(address: string): void {
        if (!address)
            return;
        const w = windowSelector(address);
        root.dispatchAfterRelease(lua ? `hl.dsp.focus({window = "${w}"})` : `focuswindow ${w}`);
    }

    // `follow = false` is what keeps the current workspace put, so dragging a
    // window away in the overview does not drag you after it. `done`, when
    // given, runs once Hyprland has answered.
    function moveWindowToWorkspace(address: string, id: var, done: var): void {
        if (!address)
            return;
        const w = windowSelector(address);
        root.dispatchThen(lua ? `hl.dsp.window.move({workspace = "${id}", follow = false, window = "${w}"})` : `movetoworkspacesilent ${id},${w}`, done ?? null);
    }

    // A floating window to a place on screen, in layout coordinates -- the
    // global space `at` is reported in.
    function moveWindowTo(address: string, x: real, y: real, done: var): void {
        if (!address)
            return;
        const w = windowSelector(address);
        const px = Math.round(x);
        const py = Math.round(y);
        root.dispatchThen(lua ? `hl.dsp.window.move({x = ${px}, y = ${py}, window = "${w}"})` : `movewindowpixel exact ${px} ${py},${w}`, done ?? null);
    }

    // Two tiled windows trade places. Hyprland then moves the pointer onto the
    // one it moved, which from the overview threw it across the screen, so
    // the Lua form puts it back where it was in the same dispatch, before a
    // frame is drawn. hyprlang has no swap by address; there it does nothing.
    function swapWindows(address: string, other: string, done: var): void {
        if (!address || !other || !lua) {
            if (done)
                done("");
            return;
        }
        const a = windowSelector(address);
        const b = windowSelector(other);
        root.dispatchThen(`function() local c = hl.get_cursor_pos(); hl.dispatch(hl.dsp.window.swap({window = "${a}", target = "${b}"})); if c then hl.dispatch(hl.dsp.cursor.move({x = c.x, y = c.y})) end end`, done ?? null);
    }

    // The window picker's shift+return: bring the window here rather than
    // going to it, so the follow *is* wanted and the window lands on the
    // current workspace.
    function pullWindowHere(address: string): void {
        if (!address)
            return;
        const w = windowSelector(address);
        // Following the window is a focus change, so it waits like one.
        root.dispatchAfterRelease(lua ? `hl.dsp.window.move({workspace = "${root.focusedWorkspaceId}", follow = true, window = "${w}"})` : `movetoworkspace ${root.focusedWorkspaceId},${w}`);
    }

    function closeWindow(address: string): void {
        if (!address)
            return;
        const w = windowSelector(address);
        root.dispatchChecked(lua ? `hl.dsp.window.close({window = "${w}"})` : `closewindow ${w}`);
    }

    // Start a command through Hyprland, with window rules for what it opens:
    //   { workspace: 3, float: true, size: [w, h], move: [x, y], tile: true }
    // Hyprland applies them to the window as it maps, so a relaunched window
    // opens on its workspace -- quietly, without pulling focus there -- and
    // a floating one at its size and place. The rule names are the ones
    // Hyprland 0.56's parser accepts for exec_cmd (it names any it does not).
    // The command goes to `sh -c`, so it may carry a `cd`.
    function launch(command: string, rules: var): void {
        if (command)
            root.dispatchChecked(root.launchCommand(command, rules));
    }

    // The dispatch `launch` sends.
    function launchCommand(command: string, rules: var): string {
        const r = rules ?? {};
        const n = v => Math.round(v);
        if (lua) {
            const bits = [];
            if (r.workspace)
                bits.push(`workspace = "${r.workspace} silent"`);
            if (r.float)
                bits.push("float = true");
            if (r.tile)
                bits.push("tile = true");
            if (r.size)
                bits.push(`size = { ${n(r.size[0])}, ${n(r.size[1])} }`);
            if (r.move)
                bits.push(`move = { ${n(r.move[0])}, ${n(r.move[1])} }`);
            // A Lua long string, so the command needs no escaping; its level
            // is raised past anything the command itself contains.
            let eq = "==";
            while (command.includes(`]${eq}]`))
                eq += "=";
            return `hl.dsp.exec_cmd([${eq}[${command}]${eq}], { ${bits.join(", ")} })`;
        } else {
            const bits = [];
            if (r.workspace)
                bits.push(`workspace ${r.workspace} silent`);
            if (r.float)
                bits.push("float");
            if (r.tile)
                bits.push("tile");
            if (r.size)
                bits.push(`size ${n(r.size[0])} ${n(r.size[1])}`);
            if (r.move)
                bits.push(`move ${n(r.move[0])} ${n(r.move[1])}`);
            return bits.length > 0 ? `exec [${bits.join("; ")}] ${command}` : `exec ${command}`;
        }
    }

    // End the session by exiting the compositor.
    //
    // This is the trap the whole file exists for, and it was live in two session
    // menus: `hyprctl dispatch exit` is wrapped as `hl.dispatch(exit)` under the
    // Lua config manager, where `exit` is an undefined global rather than a
    // dispatcher, so the logout button did nothing at all and said nothing about
    // it. The Lua form is `hl.dsp.exit()`, confirmed against
    // /usr/share/hypr/stubs/hl.meta.lua.
    function logout(): void {
        Hyprland.dispatch(lua ? "hl.dsp.exit()" : "exit");
    }

    // A toplevel's `lastIpcObject` is only filled by a full toplevel query, and
    // nothing runs one after startup -- so every window opened during the
    // session has no class, and anything asking `iconOf()` for it gets the
    // fallback glyph. Refresh on open rather than making each caller remember.
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "openwindow" || event.name === "closewindow")
                Hyprland.refreshToplevels();
        }
    }

    // Where the pointer is, in global coordinates. Queried on demand rather
    // than tracked: nothing needs it continuously, and polling a cursor is a
    // wakeup every frame for a number that is almost always unread.
    property point cursor: Qt.point(0, 0)

    function refreshCursor(): void {
        cursorQuery.running = true;
    }

    Process {
        id: cursorQuery

        command: ["hyprctl", "cursorpos", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = JSON.parse(text);
                    root.cursor = Qt.point(p.x ?? 0, p.y ?? 0);
                } catch (e) {
                    // Not fatal: a transition that cannot find the pointer
                    // starts from the centre instead.
                }
            }
        }
    }

    // Re-query everything. Call this when a panel opens, never at
    // `Component.onCompleted`: refreshing before the socket has finished its
    // initial query leaves `Hyprland.workspaces` holding a workspace of id -1
    // and `focusedWorkspace` null, and it stays that way -- measured over an
    // eleven-second probe. The stale answer is better than the poisoned one.
    function refresh(): void {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        root.recount();
    }

    // Only the windows: their positions and sizes live in `lastIpcObject`,
    // and nothing but this query fills it -- not moving a window, not the
    // layout rearranging round it. What the overview asks for after every
    // change it makes and every event that moves one.
    function refreshWindows(): void {
        Hyprland.refreshToplevels();
        root.recount();
    }

    Connections {
        target: Hyprland.toplevels

        // Opening and closing windows moves the list itself, which is the cheap
        // half of keeping the counts honest.
        function onValuesChanged(): void {
            root.recount();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            switch (event.name) {
            case "activewindowv2":
                {
                    // Quickshell has already updated activeToplevel from this
                    // event by the time it is re-emitted here.
                    const t = Hyprland.activeToplevel;
                    const ws = t?.workspace?.id;
                    if (ws !== undefined && ws !== null) {
                        const next = Object.assign({}, root.lastFocused);
                        next[ws] = t.address;
                        root.lastFocused = next;
                    }
                    // Closed windows drop out here rather than on their own
                    // event, which names them in a different form.
                    if (t?.address) {
                        const open = new Set(Hyprland.toplevels.values.map(w => w.address));
                        root.focusOrder = [t.address, ...root.focusOrder.filter(a => a !== t.address && open.has(a))];
                    }
                }
                root.focusMoved();
                break;
            case "activewindow":
            case "focusedmon":
            case "focusedmonv2":
                root.focusMoved();
                break;
            // Recounted a turn later, once Quickshell has applied the event
            // too. Measured on a move: at `movewindow` the toplevel still
            // names its old workspace, and only by `movewindowv2` has it
            // moved, so a count taken inside the handler depends on which of
            // the pair it is. After the turn, both read the window where it is.
            case "workspace":
            case "workspacev2":
                root.focusMoved();
                Qt.callLater(root.recount);
                break;
            case "movewindow":
            case "movewindowv2":
            case "openwindow":
            case "closewindow":
                Qt.callLater(root.recount);
                break;
            }
        }
    }

    // The counts cannot be computed at `Component.onCompleted` for the reason
    // `refresh` documents -- the socket has not answered its initial query yet
    // and every service is empty on the first frame. One late pass fills them
    // in for the windows that were already open, after which the events above
    // keep them current.
    Timer {
        running: true
        interval: 1500
        onTriggered: root.recount()
    }

    // ---- motion -------------------------------------------------------------
    //
    // Hyprland's window and workspace animations follow the shell's motion
    // setting: hypr/conf/general.lua reads it from shell.json whenever the
    // config loads. So a change in Settings is followed by a reload, once
    // shell.json has been written -- not at startup, when Hyprland has just
    // read the same file, and not for every step of a slider being dragged.
    readonly property string motionSetting: `${Config.appearance.animations}/${Config.appearance.reduceMotion}/${Config.appearance.animationSpeed}`
    property string motionApplied: ""

    onMotionSettingChanged: motionReload.restart()

    Timer {
        interval: 3000
        running: true
        onTriggered: root.motionApplied = root.motionSetting
    }

    Timer {
        id: motionReload

        // Persist's save debounce, and a little over.
        interval: 700
        onTriggered: {
            if (root.motionApplied === "" || root.motionApplied === root.motionSetting)
                return;
            root.motionApplied = root.motionSetting;
            motionReloader.running = true;
        }
    }

    Process {
        id: motionReloader

        command: ["hyprctl", "reload"]
    }
}
