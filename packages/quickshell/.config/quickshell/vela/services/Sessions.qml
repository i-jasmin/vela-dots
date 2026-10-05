pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import "SessionLayout.js" as Layout

// The sessions overlay's data and its two verbs: save a window layout, and
// bring one back.
//
// Kept in `~/.local/state/vela/sessions.json`:
//   { sessions: [{ name, saved, windows: [...] }],
//     active:   the layout last saved, updated or restored,
//     last:     { saved, windows } -- the layout as it last stood, for
//               "Restore last session on login",
//     restoredFor: the Hyprland instance the login restore last ran for }
//
// A window records { appClass, title, workspace, workspaceName, monitor,
// x, y, w, h, floating, fullscreen, focused, cwd }.
//
// RESTORING REOPENS APPS, NOT JUST FRAMES. For each saved window, a window of
// the same app that is already open is reused; anything left is started
// through Hyprland.
//
// AND PUTS THEM BACK WHERE THEY WERE. Where dwindle puts a new tiled window
// depends on which window has focus and, failing that, on the pointer -- and
// every window used to be started at once onto workspaces nobody was looking
// at, 300 ms apart whether the last had opened or not, so each restore came
// out differently. Now each workspace is rebuilt in turn, one window at a
// time: `SessionLayout.plan` works out from the saved rectangles which window
// each new one splits, which way and at what ratio; the runner below focuses
// that window, preselects the direction, opens the new one, waits until it
// has actually appeared, and sets the ratio. Floating windows get their saved
// size and place, and fullscreen windows go back to fullscreen, once they are
// open -- after, not by exec rules alone, because an app that is already
// running (a second Firefox window, a single-instance terminal) opens its
// window from the old process, which no exec rule matches.
//
// TERMINALS COME BACK IN THE FOLDER THEY WERE LEFT IN. A terminal's working
// directory belongs to the shell inside it, not to the terminal, so saving
// walks /proc from each window's process down its newest children to the
// foreground process and reads that one's cwd (`cwdProbe`); restoring starts
// the app in that folder. A terminal server that owns several windows under
// one process (`foot --server`, a single-instance kitty) has one cwd for all
// of them -- its newest shell's.
Singleton {
    id: root

    readonly property string path: `${Quickshell.env("HOME")}/.local/state/vela/sessions.json`

    property var sessions: []
    property string activeName: ""
    property var last: null
    property string restoredFor: ""
    property bool loaded: false

    // The name of the session being restored, while it is.
    property string restoring: ""
    readonly property bool busy: root.restoring !== ""

    // How long a relaunched app gets to open its window before the restore
    // gives up on it and carries on without.
    readonly property int openTimeout: 15000
    // Reused windows wait here, out of sight, until their turn comes, so a
    // workspace is rebuilt from empty rather than around them.
    readonly property string staging: "special:vela-restore"
    // How long the layout must sit still before it is snapshotted as "last".
    readonly property int snapshotDelay: 15000

    // ---- names ---------------------------------------------------------------

    // "Code + Files" -- the one or two apps the layout is mostly made of.
    function suggestName(windows: var): string {
        const counts = {};
        for (const w of windows)
            if (w.appClass)
                counts[w.appClass] = (counts[w.appClass] ?? 0) + 1;
        const names = Object.keys(counts).sort((a, b) => counts[b] - counts[a]).slice(0, 2).map(c => Hypr.appName(c));
        const base = names.length > 0 ? names.join(" + ") : qsTr("Session");
        let name = base;
        let n = 2;
        while (root.sessions.some(s => s.name === name))
            name = `${base} ${n++}`;
        return name;
    }

    // ---- what is on screen ---------------------------------------------------

    function capture(): var {
        const active = Hypr.activeAddress;
        return Hypr.clients.map(c => {
            const o = c.lastIpcObject ?? {};
            return {
                "appClass": Hypr.classOf(c),
                "title": c.title ?? "",
                "workspace": c.workspace?.id ?? o.workspace?.id ?? 1,
                // Kept beside the id: a special workspace's id is a negative
                // number that means nothing to anything but this Hyprland.
                "workspaceName": c.workspace?.name ?? o.workspace?.name ?? "",
                "monitor": c.monitor?.name ?? "",
                "x": o.at ? o.at[0] : 0,
                "y": o.at ? o.at[1] : 0,
                "w": o.size ? o.size[0] : 0,
                "h": o.size ? o.size[1] : 0,
                "floating": !!o.floating,
                // 0 none, 1 maximised, 2 fullscreen.
                "fullscreen": o.fullscreen ?? 0,
                "focused": !!active && c.address === active,
                "pid": o.pid ?? 0,
                "cwd": ""
            };
        }).filter(w => w.appClass && w.workspaceName !== root.staging);
    }

    // `capture`, after asking Hyprland again. A window's geometry, floating
    // and fullscreen state live in `lastIpcObject`, which only a full query
    // refreshes and nothing but a window opening or closing runs -- so a
    // layout rearranged since the last window opened was saved as it had
    // been, and restored that way.
    property var afterRefresh: []

    function captureFresh(done: var): void {
        root.afterRefresh = [...root.afterRefresh, done];
        Hypr.refresh();
        refreshed.restart();
    }

    Timer {
        id: refreshed

        interval: 500
        onTriggered: {
            const waiting = root.afterRefresh;
            root.afterRefresh = [];
            const windows = root.capture();
            for (const done of waiting)
                done(windows);
        }
    }

    // Which apps are open and how many of each. Titles and pixels change
    // constantly; the set of apps is what "am I in this layout" means.
    function signature(windows: var): string {
        return windows.map(w => w.appClass).sort().join("|");
    }

    readonly property string currentSignature: {
        Hypr.windowCounts;
        return root.signature(root.capture());
    }

    // One layout is active at a time: the one last saved, updated or restored,
    // for as long as the apps on screen are still the ones it holds.
    function isActive(session: var): bool {
        return !!session && session.name === root.activeName && session.windows.length > 0 && root.signature(session.windows) === root.currentSignature;
    }

    // ---- saving --------------------------------------------------------------
    //
    // Capturing is instant; the working directories take one process. Each
    // write waits for its probe, then lands through `commit`.

    property var pending: []
    // The pids the running probe was started with.
    property var probing: []

    function withCwds(windows: var, done: var): void {
        const pids = [...new Set(windows.map(w => w.pid).filter(p => p > 0))];
        if (!Config.sessions.captureWorkingDirectory || pids.length === 0) {
            done(windows.map(root.strip));
            return;
        }
        root.pending = [...root.pending,
            {
                windows: windows,
                pids: pids,
                done: done
            }
        ];
        root.probe();
    }

    // One probe at a time, for every pid still waiting.
    function probe(): void {
        if (cwdProbe.running || root.pending.length === 0)
            return;
        // By hand: an array held in a property has no flatMap.
        const pids = new Set();
        for (const job of root.pending)
            for (const pid of job.pids)
                pids.add(pid);
        root.probing = [...pids];
        cwdProbe.command = ["sh", "-c", root.cwdScript, "vela-cwd", ...root.probing.map(String)];
        cwdProbe.running = true;
    }

    // What is stored: everything but the pid, which means nothing next login.
    function strip(w: var): var {
        const out = Object.assign({}, w);
        delete out.pid;
        return out;
    }

    // `done(name)` once it is written, with the name it was given; "" if
    // there was nothing on screen to save.
    function save(done: var): void {
        root.captureFresh(windows => {
            if (windows.length === 0) {
                if (done)
                    done("");
                return;
            }
            root.withCwds(windows, ws => {
                // Named here rather than before the probe, so two saves in
                // quick succession cannot both take the same free name.
                const name = root.suggestName(ws);
                root.sessions = [...root.sessions,
                    {
                        "name": name,
                        "saved": Date.now(),
                        "windows": ws
                    }
                ];
                root.activeName = name;
                root.persist();
                if (done)
                    done(name);
            });
        });
    }

    function update(index: int): void {
        const target = root.sessions[index];
        if (!target)
            return;
        root.captureFresh(windows => {
            if (windows.length === 0)
                return;
            root.withCwds(windows, ws => {
                root.sessions = root.sessions.map(s => s.name !== target.name ? s : {
                        "name": s.name,
                        "saved": Date.now(),
                        "windows": ws
                    });
                root.activeName = target.name;
                root.persist();
            });
        });
    }

    function rename(index: int, name: string): void {
        const trimmed = name.trim();
        const target = root.sessions[index];
        if (!trimmed || !target || root.sessions.some((s, i) => i !== index && s.name === trimmed))
            return;
        if (root.activeName === target.name)
            root.activeName = trimmed;
        root.sessions = root.sessions.map((s, i) => i !== index ? s : {
                "name": trimmed,
                "saved": s.saved,
                "windows": s.windows
            });
        root.persist();
    }

    function forget(index: int): void {
        const target = root.sessions[index];
        if (target && root.activeName === target.name)
            root.activeName = "";
        root.sessions = root.sessions.filter((s, i) => i !== index);
        root.persist();
    }

    function persist(): void {
        file.setText(JSON.stringify({
            "sessions": root.sessions,
            "active": root.activeName,
            "last": root.last,
            "restoredFor": root.restoredFor
        }, null, 2));
    }

    // ---- restoring -----------------------------------------------------------

    function restore(index: int): void {
        const s = root.sessions[index];
        if (!s || root.busy)
            return;
        root.activeName = s.name;
        root.persist();
        root.restoreWindows(s.windows, s.name);
    }

    function restoreWindows(windows: var, label: string): void {
        if (!windows || windows.length === 0 || root.busy)
            return;
        root.restoring = label || qsTr("session");
        // Fresh geometry first: which windows are open, and where, decides
        // which get reused.
        root.captureFresh(() => root.begin(windows));
    }

    // Saved windows without a workspace name (sessions from before it was
    // kept) are on the workspace their id names.
    function workspaceOf(w: var): string {
        return w.workspaceName || String(w.workspace);
    }

    function begin(windows: var): void {
        // Reuse what is open: for each saved window, an unclaimed window of
        // the same app, preferring one already on its workspace, then one
        // with its title.
        const open = Hypr.clients.filter(c => Hypr.classOf(c) && c.workspace?.name !== root.staging);
        const used = new Set();
        const reuse = new Map();
        for (const w of windows) {
            let best = null;
            let bestScore = -1;
            for (const c of open) {
                if (used.has(c.address) || Hypr.classOf(c) !== w.appClass)
                    continue;
                const score = (c.workspace?.name === root.workspaceOf(w) ? 2 : 0) + ((c.title ?? "") === w.title ? 1 : 0);
                if (score > bestScore) {
                    best = c;
                    bestScore = score;
                }
            }
            if (best) {
                used.add(best.address);
                reuse.set(w, best.address);
            }
        }

        const steps = [];
        const placed = new Map();
        const run = fn => steps.push(fn);
        const dispatch = command => run(next => Hypr.dispatchThen(command, () => next()));

        // Out of the way first, so no workspace is rebuilt around them.
        for (const address of reuse.values())
            dispatch(root.cmd.toWorkspace(address, root.staging));

        let focusAt = null;
        for (const group of Layout.plan(windows)) {
            if (!group.special) {
                const home = group.monitor && Hypr.monitorFor(group.monitor) ? group.monitor : "";
                // A workspace that does not exist yet is made on the focused
                // monitor; one that does is fetched from wherever it is.
                if (home)
                    dispatch(root.cmd.focusMonitor(home));
                dispatch(root.cmd.focusWorkspace(group.name));
                if (home && Hypr.monitors.length > 1) {
                    dispatch(root.cmd.workspaceToMonitor(group.name, home));
                    dispatch(root.cmd.focusWorkspace(group.name));
                }
            }
            for (const step of group.steps) {
                if (step.split)
                    run(next => {
                        const at = placed.get(step.split);
                        if (!at)
                            return next();
                        Hypr.dispatchThen(root.cmd.focusWindow(at), () => Hypr.dispatchThen(root.cmd.preselect(step.dir), () => next()));
                    });
                run(next => root.place(step.item, group, reuse, placed, next));
                if (step.split)
                    run(next => {
                        const at = placed.get(step.item);
                        if (!at)
                            return next();
                        Hypr.dispatchThen(root.cmd.focusWindow(at), () => Hypr.dispatchThen(root.cmd.splitRatio(step.ratio), () => next()));
                    });
            }
            for (const w of group.loose)
                run(next => root.place(w, group, reuse, placed, next));
        }
        for (const w of windows)
            if (w.focused)
                focusAt = w;

        // Nothing is left in staging: a reused window whose turn never came
        // goes back to its own workspace.
        run(next => {
            const done = new Set(placed.values());
            const left = [...reuse.entries()].filter(([w, address]) => !done.has(address));
            root.chain(left.map(([w, address]) => root.cmd.toWorkspace(address, root.workspaceOf(w))), next);
        });

        // Back to where the session left off.
        run(next => {
            const at = focusAt ? placed.get(focusAt) : "";
            if (at)
                Hypr.dispatchThen(root.cmd.focusWindow(at), () => next());
            else if (focusAt && !String(root.workspaceOf(focusAt)).startsWith("special:"))
                Hypr.dispatchThen(root.cmd.focusWorkspace(root.workspaceOf(focusAt)), () => next());
            else
                next();
        });
        run(next => {
            root.restoring = "";
            next();
        });

        root.steps = steps;
        root.advance();
    }

    // Put one saved window on screen, on `group`'s workspace, and record
    // its address in `placed`: a reused one moved in from staging, or a new
    // one started and waited for. Then its floating, size, place and
    // fullscreen, as saved.
    function place(w: var, group: var, reuse: var, placed: var, next: var): void {
        const target = group.name;
        const settle = address => {
            if (!address)
                return next();
            placed.set(w, address);
            const after = [];
            if (w.floating) {
                after.push(root.cmd.setFloating(address, true));
                const mon = Hypr.monitorFor(w.monitor);
                if (w.w > 0 && w.h > 0)
                    after.push(root.cmd.resize(address, w.w, w.h));
                // Global coordinates, as saved -- only where the monitor
                // they were on is still there.
                if (mon)
                    after.push(root.cmd.move(address, w.x, w.y));
            }
            if (w.fullscreen > 0)
                after.push(root.cmd.fullscreen(address, w.fullscreen === 1));
            root.chain(after, next);
        };

        const reused = reuse.get(w);
        if (reused) {
            // Tiled or floating before it goes in, so it lands in the
            // layout, or out of it, as saved.
            root.chain([root.cmd.setFloating(reused, !!w.floating), root.cmd.toWorkspace(reused, target)], () => settle(reused));
            return;
        }

        const command = root.commandFor(w);
        if (!command) {
            console.warn(`[vela] session "${root.restoring}": no desktop entry to start ${w.appClass}`);
            return next();
        }
        root.awaitWindow(w.appClass, target, (address, on) => {
            if (!address)
                return next();
            // Opened by an app that was already running, and so on whatever
            // workspace had focus rather than the one its rules named.
            if (on && on !== target)
                Hypr.dispatchThen(root.cmd.toWorkspace(address, target), () => settle(address));
            else
                settle(address);
        });
        Hypr.dispatchChecked(Hypr.launchCommand(command, root.rulesFor(w, target)));
    }

    // Dispatches one after another, then `done`.
    function chain(commands: var, done: var): void {
        if (commands.length === 0)
            return done();
        Hypr.dispatchThen(commands[0], () => root.chain(commands.slice(1), done));
    }

    property var steps: []

    function advance(): void {
        if (root.steps.length === 0)
            return;
        const step = root.steps[0];
        root.steps = root.steps.slice(1);
        step(() => Qt.callLater(root.advance));
    }

    // ---- waiting for a window --------------------------------------------------

    // The window being waited for: its app's class, the workspace it is
    // going to, what to call, and the other windows that opened meanwhile.
    property var awaiting: null

    function awaitWindow(appClass: string, workspace: string, done: var): void {
        root.awaiting = {
            appClass: appClass.toLowerCase(),
            workspace: workspace,
            done: done,
            others: []
        };
        openWait.restart();
    }

    function arrived(address: string, workspace: string): void {
        const waiting = root.awaiting;
        root.awaiting = null;
        openWait.stop();
        if (waiting)
            waiting.done(address, workspace);
    }

    Timer {
        id: openWait

        interval: root.openTimeout
        onTriggered: {
            // Some apps name their window only after it has opened (Spotify,
            // Steam), so no window of the class ever arrived. The newest one
            // that opened where this one was going is taken to be it.
            const other = (root.awaiting?.others ?? []).filter(o => o.workspace === root.awaiting.workspace).pop();
            if (other) {
                root.arrived(other.address, other.workspace);
                return;
            }
            console.warn(`[vela] session "${root.restoring}": ${root.awaiting?.appClass ?? "a window"} did not open in time`);
            root.arrived("", "");
        }
    }

    Connections {
        target: Hyprland

        // openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE -- the address without
        // its 0x, and a title that may hold commas of its own.
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name !== "openwindow" || !root.awaiting)
                return;
            const parts = event.data.split(",");
            if (parts.length < 3)
                return;
            if (parts[2].toLowerCase() !== root.awaiting.appClass) {
                root.awaiting.others.push({
                    address: `0x${parts[0]}`,
                    workspace: parts[1]
                });
                return;
            }
            root.arrived(`0x${parts[0]}`, parts[1]);
        }
    }

    // ---- the dispatches a restore sends ----------------------------------------

    readonly property QtObject cmd: QtObject {
        function sel(address: string): string {
            return Hypr.windowSelector(address);
        }

        function focusWorkspace(name: string): string {
            return Hypr.lua ? `hl.dsp.focus({workspace = "${name}"})` : `workspace ${name}`;
        }

        function focusMonitor(name: string): string {
            return Hypr.lua ? `hl.dsp.focus({monitor = "${name}"})` : `focusmonitor ${name}`;
        }

        function focusWindow(address: string): string {
            return Hypr.lua ? `hl.dsp.focus({window = "${sel(address)}"})` : `focuswindow ${sel(address)}`;
        }

        // The next window on this workspace splits the focused one this
        // way, and goes second -- right or below.
        function preselect(dir: string): string {
            return Hypr.lua ? `hl.dsp.layout("preselect ${dir}")` : `layoutmsg preselect ${dir}`;
        }

        // The focused window's split, exactly.
        function splitRatio(ratio: real): string {
            const r = ratio.toFixed(4);
            return Hypr.lua ? `hl.dsp.layout("splitratio ${r} exact")` : `layoutmsg splitratio ${r} exact`;
        }

        function workspaceToMonitor(name: string, monitor: string): string {
            return Hypr.lua ? `hl.dsp.workspace.move({workspace = "${name}", monitor = "${monitor}"})` : `moveworkspacetomonitor ${name} ${monitor}`;
        }

        function toWorkspace(address: string, name: string): string {
            return Hypr.lua ? `hl.dsp.window.move({workspace = "${name}", follow = false, window = "${sel(address)}"})` : `movetoworkspacesilent ${name},${sel(address)}`;
        }

        function setFloating(address: string, on: bool): string {
            return Hypr.lua ? `hl.dsp.window.float({action = "${on ? "enable" : "disable"}", window = "${sel(address)}"})` : `${on ? "setfloating" : "settiled"} ${sel(address)}`;
        }

        function resize(address: string, w: real, h: real): string {
            return Hypr.lua ? `hl.dsp.window.resize({x = ${Math.round(w)}, y = ${Math.round(h)}, window = "${sel(address)}"})` : `resizewindowpixel exact ${Math.round(w)} ${Math.round(h)},${sel(address)}`;
        }

        function move(address: string, x: real, y: real): string {
            return Hypr.lua ? `hl.dsp.window.move({x = ${Math.round(x)}, y = ${Math.round(y)}, window = "${sel(address)}"})` : `movewindowpixel exact ${Math.round(x)} ${Math.round(y)},${sel(address)}`;
        }

        function fullscreen(address: string, maximised: bool): string {
            return Hypr.lua ? `hl.dsp.window.fullscreen({mode = "${maximised ? "maximized" : "fullscreen"}", action = "set", window = "${sel(address)}"})` : `fullscreenstate ${maximised ? 1 : 2} -1,${sel(address)}`;
        }
    }

    function shellQuote(s: string): string {
        return `'${s.replace(/'/g, "'\\''")}'`;
    }

    // The command line that brings an app back, in its saved folder.
    function commandFor(w: var): string {
        const entry = Hypr.entryFor(w.appClass);
        if (!entry || !entry.command || entry.command.length === 0)
            return "";
        const argv = entry.runInTerminal ? [Apps.terminal, "-e", ...entry.command] : [...entry.command];
        const dir = w.cwd || entry.workingDirectory || "";
        const run = `exec ${argv.map(root.shellQuote).join(" ")}`;
        return dir ? `cd ${root.shellQuote(dir)} 2>/dev/null; ${run}` : run;
    }

    // Window rules for a relaunched window: its workspace, quietly, and a
    // floating one's size and place on its monitor. The runner sets all of
    // this again once the window is open (see `place`); the rules are what
    // keep it from being drawn somewhere else first.
    function rulesFor(w: var, target: string): var {
        const rules = {
            workspace: target
        };
        if (w.floating && w.w > 0 && w.h > 0) {
            const mon = Hypr.monitors.find(m => m.name === w.monitor);
            rules.float = true;
            rules.size = [w.w, w.h];
            rules.move = [w.x - (mon?.x ?? 0), w.y - (mon?.y ?? 0)];
        } else {
            rules.tile = true;
        }
        return rules;
    }

    // ---- the last session, and bringing it back at login -----------------------
    //
    // "Last session" is the layout as it last stood: snapshotted a little
    // after windows stop opening, closing or moving. Never snapshotted empty,
    // so the windows closing on the way out of a session cannot wipe it.
    //
    // At login -- the first time the shell starts under a Hyprland instance --
    // it is restored if the setting is on. Once per instance: restarting the
    // shell mid-session reopens nothing.

    // Re-query first: geometry is only as fresh as the last full query.
    function snapshot(): void {
        if (root.busy || !root.loaded)
            return;
        Hypr.refresh();
        snapshotCapture.restart();
    }

    Timer {
        id: snapshotCapture

        interval: 750
        onTriggered: root.snapshotNow()
    }

    function snapshotNow(): void {
        if (root.busy)
            return;
        const windows = root.capture();
        if (windows.length === 0)
            return;
        root.withCwds(windows, ws => {
            // Written only when the layout changed: `recheck` asks every
            // few minutes, and the file need not be rewritten each time.
            if (JSON.stringify(root.last?.windows ?? null) === JSON.stringify(ws))
                return;
            root.last = {
                "saved": Date.now(),
                "windows": ws
            };
            root.persist();
        });
    }

    Timer {
        id: settle

        interval: root.snapshotDelay
        onTriggered: root.snapshot()
    }

    // Only when the counts are really different. `recount` hands out a new
    // object every time it runs, equal or not, and `snapshot` runs it itself
    // through `Hypr.refresh` -- so each snapshot restarted the wait for the
    // next one, and with nothing on screen changing the shell probed every
    // terminal's folder every sixteen seconds, for as long as it ran.
    property string countsSeen: ""

    Connections {
        target: Hypr

        function onWindowCountsChanged(): void {
            const counts = Hypr.windowCounts;
            const seen = Object.keys(counts).sort().map(id => `${id}:${counts[id]}`).join(",");
            if (seen === root.countsSeen)
                return;
            root.countsSeen = seen;
            if (root.loaded)
                settle.restart();
        }
    }

    // A window dragged, floated or made fullscreen changes no count, so
    // those events restart the wait too. Resizing a split raises no event
    // at all; `recheck` is what catches that.
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (root.loaded && ["movewindowv2", "changefloatingmode", "fullscreen", "moveworkspacev2", "swapwindow"].includes(event.name))
                settle.restart();
        }
    }

    Timer {
        id: recheck

        interval: 180000
        running: root.loaded
        repeat: true
        onTriggered: root.snapshot()
    }

    // Right before logging out, rebooting or shutting down, so the layout
    // brought back at the next login is the one being left, not the one of
    // the last quiet moment. `done` runs once it is on disk -- or after a
    // few seconds regardless, so a stuck probe cannot hold the machine up.
    property var leaving: []

    function snapshotThen(done: var): void {
        if (!root.loaded || root.busy)
            return done();
        root.leaving = [...root.leaving, done];
        leaveGuard.restart();
        root.captureFresh(windows => {
            if (windows.length === 0)
                return root.left();
            root.withCwds(windows, ws => {
                root.last = {
                    "saved": Date.now(),
                    "windows": ws
                };
                // `left` runs from the file's saved signal.
                root.persist();
            });
        });
    }

    function left(): void {
        leaveGuard.stop();
        const waiting = root.leaving;
        root.leaving = [];
        for (const done of waiting)
            done();
    }

    Timer {
        id: leaveGuard

        interval: 3000
        onTriggered: root.left()
    }

    readonly property string instance: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? ""

    // Hyprland answers nothing for the first second or so, and a restore
    // against an empty client list would relaunch windows that are open.
    Timer {
        id: loginCheck

        interval: 3000
        onTriggered: {
            if (!root.instance || root.restoredFor === root.instance)
                return;
            root.restoredFor = root.instance;
            root.persist();
            if (Config.sessions.restoreOnLogin && root.last?.windows?.length > 0)
                root.restoreWindows(root.last.windows, qsTr("last session"));
        }
    }

    // ---- working directories -------------------------------------------------

    // For each pid: follow the newest child down to the foreground process,
    // and print "<pid> <that process's cwd>".
    readonly property string cwdScript: `
for pid in "$@"; do
    leaf="$pid"
    depth=0
    while [ "$depth" -lt 12 ]; do
        next=$(cat /proc/"$leaf"/task/*/children 2>/dev/null | tr ' ' '\\n' | grep -v '^$' | tail -n 1)
        [ -n "$next" ] || break
        leaf="$next"
        depth=$((depth + 1))
    done
    printf '%s %s\\n' "$pid" "$(readlink /proc/"$leaf"/cwd 2>/dev/null)"
done`

    Process {
        id: cwdProbe

        stdout: StdioCollector {
            onStreamFinished: {
                const cwds = {};
                for (const line of text.split("\n")) {
                    const at = line.indexOf(" ");
                    if (at > 0)
                        cwds[line.slice(0, at)] = line.slice(at + 1).trim();
                }
                // A job asked for while this probe ran may hold pids it was
                // not started with; those wait for the next one.
                const covered = new Set(root.probing);
                const ready = root.pending.filter(j => j.pids.every(p => covered.has(p)));
                root.pending = root.pending.filter(j => !ready.includes(j));
                for (const job of ready)
                    job.done(job.windows.map(w => {
                        const out = root.strip(w);
                        out.cwd = cwds[String(w.pid)] ?? "";
                        return out;
                    }));
            }
        }

        onExited: Qt.callLater(root.probe)
    }

    // ---- the file ------------------------------------------------------------

    FileView {
        id: file

        path: root.path
        watchChanges: true
        atomicWrites: true
        printErrors: false

        onFileChanged: reload()
        onSaved: if (root.leaving.length > 0)
            root.left()
        onSaveFailed: if (root.leaving.length > 0)
            root.left()

        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.sessions = parsed.sessions ?? [];
                root.activeName = parsed.active ?? "";
                root.last = parsed.last ?? null;
                root.restoredFor = parsed.restoredFor ?? "";
            } catch (e) {
                console.warn(`[vela] sessions.json unreadable, starting empty: ${e}`);
                root.sessions = [];
            }
            if (!root.loaded) {
                root.loaded = true;
                loginCheck.start();
            }
        }

        // No file yet is the ordinary first-run case, not an error.
        onLoadFailed: {
            root.sessions = [];
            if (!root.loaded) {
                root.loaded = true;
                loginCheck.start();
            }
        }
    }

    // From keybinds and the `vela` CLI:
    //   qs -c vela ipc call sessions save
    //   qs -c vela ipc call sessions restore "Code + Files"
    //   qs -c vela ipc call sessions restoreLast
    IpcHandler {
        target: "sessions"

        // Saves and says so: from a keybind there is no panel to show it.
        function save(): void {
            root.save(name => {
                if (!name)
                    return;
                const keys = BindEditor.label("sessions.restore", Config.keybinds.sessionRestore);
                root.announce(qsTr("Session saved"), keys ? qsTr("%1 — %2 opens the sessions panel").arg(name).arg(keys) : name);
            });
        }

        function restore(name: string): void {
            const index = root.sessions.findIndex(s => s.name === name);
            if (index >= 0)
                root.restore(index);
            else
                console.warn(`[vela] no session called "${name}"`);
        }

        function restoreLast(): void {
            if (root.last?.windows?.length > 0)
                root.restoreWindows(root.last.windows, qsTr("last session"));
        }

        function list(): string {
            return root.sessions.map(s => s.name).join("\n");
        }
    }

    // A notification that opens the panel when it is clicked, and names the
    // key that does. It used to be sent with a bare D-Bus call that exited at
    // once: the shell is the notification server, so a click on the card had
    // nobody to go back to, and the panel it pointed at could only be found
    // by knowing its key. `notify-send -A` stays to hear the answer and
    // prints the action picked; "default" is the card itself. Five minutes,
    // then it stops waiting -- the card stays in the history either way.
    function announce(summary: string, body: string): void {
        announcement.createObject(root, {
            summary: summary,
            body: body
        });
    }

    Component {
        id: announcement

        Process {
            id: proc

            required property string summary
            required property string body

            command: ["timeout", "300", "notify-send", "-a", "vela", "-i", "view_quilt", "-A", `default=${qsTr("Open sessions")}`, proc.summary, proc.body]

            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.trim() === "default")
                        ShellState.open("sessions");
                }
            }

            onExited: proc.destroy()

            running: true
        }
    }
}
