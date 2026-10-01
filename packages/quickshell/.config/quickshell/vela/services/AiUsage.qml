pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Claude Code and Codex: how much of the plan is used, and what each session
// is doing -- for the System tab's cards (`modules/dashboard/AiCards.qml`) and
// the bar's pill (`modules/bar/AiStatus.qml`).
//
// Everything comes from `vela ai status`, which reads what the two tools
// already hand out: Claude Code's status line input, saved by `vela ai
// statusline` once connected, and Codex's own session files. vela never reads
// a login or asks a server anything, so the numbers are exactly as fresh as
// the tool's last reply. The reset countdowns are counted here, between
// replies, and a window whose reset has passed reads empty without waiting for
// the tool.
//
// What a session is doing -- working, needs you, done -- comes from the tools'
// hooks, written to a file in the runtime dir that is watched here. That a
// session is open at all comes from its process, hooks or not: Codex fires
// none until the first prompt. The poll is what catches everything else, and
// it runs faster while anything is live or the System tab is open.
//
// Claude Code's status line reports a 5-hour window and a weekly one, with
// the model and its effort. The rest of what /usage shows -- a model's own
// weekly limit (Fable's), the plan -- comes from asking Claude Code for it
// (`vela ai claude-usage`, scheduled below), and the two are merged. A window
// either adds later comes through under its own key and is drawn beside the
// others, labelled from that key.
Singleton {
    id: root

    property var status: null
    property bool loaded: false
    // Seconds, ticked below; the countdowns and "done" fading read it.
    property real now: Date.now() / 1000

    // The System tab holds this while it is shown.
    property int holds: 0
    readonly property bool fast: root.holds > 0 || root.sessionsLive.some(s => s.state === "working" || s.state === "need")
    // "Done" fades by the clock, so the clock ticks by the second meanwhile.
    readonly property bool ticking: root.fast || root.sessionsLive.some(s => s.state === "done")

    // How long "done" stays on the pill after a reply.
    readonly property int doneSeconds: 6
    // The notification's threshold.
    readonly property real nearLimit: 90

    readonly property string home: Quickshell.env("HOME")
    readonly property string livePath: `${Quickshell.env("XDG_RUNTIME_DIR") || (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/vela/ai"}/vela-ai-live.json`
    readonly property string claudePath: `${Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"}/vela/ai/claude.json`

    function hold(): void {
        root.holds += 1;
        root.refresh();
    }

    function release(): void {
        root.holds = Math.max(0, root.holds - 1);
    }

    function refresh(): void {
        if (!poll.running)
            poll.running = true;
        else
            poll.again = true;
    }

    // ---- sessions (hooks) ------------------------------------------------------

    // [{ key, tool, state, since, cwd, model, pid, chain, app }], "done"
    // turned to "idle" once it has been shown for a moment. One the ChatGPT
    // app runs ("app": "chatgpt") only while it works, needs you or has just
    // replied: the app is open all day for everything else it does, and
    // that is not Codex at work.
    readonly property var sessionsLive: {
        const all = root.status?.sessions ?? {};
        return Object.keys(all).map(k => {
            const s = Object.assign({
                key: k
            }, all[k]);
            if (s.state === "done" && root.now - (s.since ?? 0) >= root.doneSeconds)
                s.state = "idle";
            return s;
        }).filter(s => !s.app || s.state !== "idle");
    }

    readonly property var rank: ({
            need: 0,
            working: 1,
            done: 2,
            idle: 3
        })

    // The bar's pill: each tool while it is open, with what its session is
    // doing, and nothing once it is closed.
    readonly property var pill: ["claude", "codex"].map(id => ({
                id: id,
                name: id === "claude" ? qsTr("Claude") : qsTr("Codex"),
                session: root.sessionOf(id)
            })).filter(i => i.session)

    // The session that most wants you: from the hooks, or else an open one
    // they have said nothing about yet -- not connected, or Codex before its
    // first prompt -- found by its process and simply open.
    function sessionOf(tool: string): var {
        const mine = root.sessionsLive.filter(s => s.tool === tool);
        mine.sort((a, b) => (root.rank[a.state] ?? 9) - (root.rank[b.state] ?? 9) || (b.since ?? 0) - (a.since ?? 0));
        if (mine.length > 0)
            return mine[0];
        const open = root.status?.open?.[tool] ?? [];
        return open.length > 0 ? Object.assign({
            key: `${tool}:${open[0].pid}`,
            tool: tool,
            state: "idle",
            since: 0
        }, open[0]) : null;
    }

    // The window the session runs in: the first process above it that is a
    // Hyprland window -- the terminal.
    function windowOf(session: var): string {
        if (!session)
            return "";
        const chain = session.chain ?? [];
        for (const pid of chain) {
            const w = Hypr.clients.find(c => (c.lastIpcObject?.pid ?? 0) === pid);
            if (w)
                return w.address;
        }
        return "";
    }

    function focus(session: var): void {
        const address = root.windowOf(session);
        if (address)
            Hypr.focusWindow(address);
    }

    // ---- windows ---------------------------------------------------------------

    function capital(s: string): string {
        return s ? s.charAt(0).toUpperCase() + s.slice(1) : s;
    }

    function spanLabel(minutes: int): string {
        if (!minutes)
            return qsTr("Window");
        if (minutes === 10080)
            return qsTr("Week");
        if (minutes % 1440 === 0)
            return qsTr("%1-day").arg(minutes / 1440);
        return qsTr("%1-hour").arg(Math.round(minutes / 60));
    }

    // Claude Code's keys: five_hour, seven_day, spend_limit, and whatever it
    // adds (seven_day_<model>, say, read as "Week · <Model>").
    // Claude Code's windows: five_hour, seven_day, seven_day_sonnet and
    // _opus, spend_limit, "model:Fable" for a model's own weekly limit (from
    // /usage), and whatever the status line adds later (seven_day_<model>,
    // read the same way).
    function claudeLabel(key: string): string {
        const known = {
            five_hour: qsTr("5-hour"),
            seven_day: qsTr("Week"),
            spend_limit: qsTr("Spend limit")
        };
        if (known[key])
            return known[key];
        if (key.startsWith("model:"))
            return qsTr("%1 week").arg(key.slice(6));
        if (key.startsWith("seven_day_"))
            return qsTr("%1 week").arg(root.capital(key.slice(10).replace(/_/g, " ")));
        if (key.startsWith("five_hour_"))
            return qsTr("%1 5-hour").arg(root.capital(key.slice(10).replace(/_/g, " ")));
        return root.capital(key.replace(/_/g, " "));
    }

    // "Fable 5.1 · high", with "· fast" in fast mode.
    function modelText(model: string, effort: string, fast: bool): string {
        return [model, effort, fast ? qsTr("fast") : ""].filter(s => s).join(" · ");
    }

    // A window whose reset has passed is empty until the tool says otherwise.
    function windowSpec(label: string, used: real, resetsAt: int): var {
        const over = resetsAt > 0 && resetsAt <= root.now;
        return {
            label: label,
            used: over ? 0 : used,
            resetsAt: over ? 0 : resetsAt,
            reset: over
        };
    }

    function planLabel(plan: string): string {
        const p = (plan ?? "").toLowerCase();
        if (!p)
            return "";
        if (p.includes("business"))
            return qsTr("Business");
        if (p.startsWith("ent"))
            return qsTr("Enterprise");
        if (p === "promax")
            return qsTr("Pro Max");
        if (p === "prolite")
            return qsTr("Pro Lite");
        if (p.startsWith("edu"))
            return qsTr("Edu");
        return root.capital(p.replace(/_/g, " "));
    }

    // Two sources, merged: the status line (5-hour and week, fresh with every
    // reply, and the model and effort) and /usage (every window, the plan).
    // A window both have comes from whichever is newer.
    readonly property var claude: {
        const line = root.status?.claude ?? null;
        const plan = Config.ai.claudeUsage ? (root.status?.claudePlan ?? null) : null;
        const windows = {};
        for (const [k, w] of Object.entries(plan?.windows ?? {}))
            windows[k] = w;
        for (const [k, w] of Object.entries(line?.windows ?? {}))
            if (!windows[k] || (line.updated ?? 0) >= (plan?.updated ?? 0))
                windows[k] = w;
        const order = ["five_hour", "seven_day", "spend_limit"];
        const keys = Object.keys(windows).sort((a, b) => {
            const ia = order.indexOf(a), ib = order.indexOf(b);
            return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib) || a.localeCompare(b);
        });
        const has = keys.length > 0;
        return {
            id: "claude",
            name: qsTr("Claude Code"),
            shown: Config.ai.claude && !!(root.status?.installed?.claude || line || plan?.available),
            running: (root.status?.running?.claude ?? 0) > 0,
            connected: !!root.status?.connected?.claude,
            plan: root.planLabel(plan?.plan ?? ""),
            chip: root.modelText(line?.model ?? "", line?.effort ?? "", !!line?.fast),
            updated: Math.max(line?.updated ?? 0, plan?.available ? plan.updated : 0),
            windows: keys.map(k => root.windowSpec(root.claudeLabel(k), windows[k].used ?? 0, windows[k].resetsAt ?? 0)),
            session: root.sessionOf("claude"),
            // Nothing to show from either source: connecting is the way.
            needsConnect: !has && !root.status?.connected?.claude
        };
    }

    readonly property var codex: {
        const u = root.status?.codex ?? null;
        const windows = [];
        for (const limit of u?.limits ?? []) {
            // The plan's own limit plainly; another (a model's) by its name.
            const suffix = limit.id === "codex" ? "" : ` · ${limit.name || limit.id}`;
            for (const w of [limit.primary, limit.secondary])
                if (w)
                    windows.push(root.windowSpec(root.spanLabel(w.minutes ?? 0) + suffix, w.used ?? 0, w.resetsAt ?? 0));
            if (limit.spend)
                windows.push(root.windowSpec(qsTr("Spend limit") + suffix, limit.spend.used ?? 0, limit.spend.resetsAt ?? 0));
        }
        return {
            id: "codex",
            name: qsTr("Codex"),
            shown: Config.ai.codex && !!(root.status?.installed?.codex || u),
            running: (root.status?.running?.codex ?? 0) > 0,
            connected: !!root.status?.connected?.codex,
            plan: root.planLabel(u?.plan ?? ""),
            chip: root.modelText(u?.model ?? "", u?.effort ?? "", false),
            updated: u?.updated ?? 0,
            windows: windows,
            session: root.sessionOf("codex"),
            needsConnect: false
        };
    }

    readonly property var tools: [root.claude, root.codex].filter(t => t.shown)
    // The System tab's cards: each tool while it is open, as on the bar's
    // pill. Closed, its numbers wait here for the next time.
    readonly property var cards: root.tools.filter(t => t.running || !!t.session)

    // The 5-hour window each tool counts down, for the bar's pill.
    function sessionOf5h(tool: string): var {
        const t = tool === "claude" ? root.claude : root.codex;
        return t.windows.find(w => w.label === qsTr("5-hour")) ?? null;
    }

    // ---- logos ---------------------------------------------------------------

    // { claude: { viewBox, paths, evenodd }, codex: ... } -- path data the
    // icons draw in the palette's colours (`components/ToolIcon.qml`), or
    // nothing while logos are off or not fetched yet.
    readonly property var icons: Config.ai.logos ? (root.status?.icons ?? {}) : ({})

    // Fetched once per run for a tool that is there without its logo: after
    // an install that was offline, or a tool installed after vela.
    property bool iconsAsked: false
    onToolsChanged: {
        if (!Config.ai.logos || root.iconsAsked || iconFetcher.running || !root.loaded)
            return;
        if (root.tools.some(t => !root.status?.icons?.[t.id])) {
            root.iconsAsked = true;
            iconFetcher.running = true;
        }
    }

    Process {
        id: iconFetcher

        command: ["sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; exec vela ai icons']
        onExited: root.refresh()
    }

    // "2 h 10 min" beside the reset glyph; a reset a day or more away by its
    // day and time, "Mon 09:00".
    function resetText(resetsAt: int): string {
        if (!resetsAt)
            return "";
        const left = Math.max(0, resetsAt - root.now);
        if (left < 60)
            return qsTr("< 1 min");
        if (left < 3600)
            return qsTr("%1 min").arg(Math.ceil(left / 60));
        if (left < 86400) {
            const h = Math.floor(left / 3600), m = Math.ceil((left % 3600) / 60);
            return m === 60 ? qsTr("%1 h").arg(h + 1) : m ? qsTr("%1 h %2 min").arg(h).arg(m) : qsTr("%1 h").arg(h);
        }
        return Qt.formatDateTime(new Date(resetsAt * 1000), "ddd hh:mm");
    }

    function resetPhrase(resetsAt: int): string {
        if (!resetsAt)
            return "";
        return resetsAt - root.now < 86400 ? qsTr("Resets in %1.").arg(root.resetText(resetsAt)) : qsTr("Resets %1.").arg(root.resetText(resetsAt));
    }

    function shortPath(path: string): string {
        if (!path)
            return "";
        return path === root.home ? "~" : path.startsWith(root.home + "/") ? "~" + path.slice(root.home.length) : path;
    }

    // ---- near the limit -------------------------------------------------------

    // The last value seen per window, so the notification fires on the way
    // past the threshold and not again on every poll -- nor on the first one
    // after the shell starts, for a window that was already past it.
    property var seen: ({})

    function checkLimits(): void {
        if (!root.loaded)
            return;
        const next = {};
        for (const tool of root.tools) {
            for (const w of tool.windows) {
                const key = `${tool.id}|${w.label}|${w.resetsAt}`;
                next[key] = w.used;
                const before = root.seen[key];
                if (Config.ai.notifyNearLimit && before !== undefined && before < root.nearLimit && w.used >= root.nearLimit)
                    Quickshell.execDetached(["notify-send", "-a", "vela", "-i", "dialog-warning", qsTr("%1: %2 at %3%").arg(tool.name).arg(w.label).arg(Math.round(w.used)), root.resetPhrase(w.resetsAt)]);
            }
        }
        root.seen = next;
    }

    // ---- Claude Code's /usage ---------------------------------------------------

    // Asking Claude Code for /usage runs it for a second, so not often: every
    // five minutes while it is open, soon after a reply, and when the System
    // tab opens on numbers older than ten -- never twice in ninety seconds.
    readonly property bool claudeAsking: Config.ai.claude && Config.ai.claudeUsage && !!root.status?.installed?.claude
    readonly property int planAge: root.now - (root.status?.claudePlan?.updated ?? 0)

    function askClaude(olderThan: int): void {
        if (root.claudeAsking && !asker.running && root.planAge >= Math.max(90, olderThan))
            asker.running = true;
    }

    Process {
        id: asker

        command: ["sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; exec vela ai claude-usage']
        onExited: root.refresh()
    }

    Timer {
        running: root.claudeAsking && (root.claude.running || !!root.claude.session)
        repeat: true
        triggeredOnStart: true
        interval: 60000
        onTriggered: root.askClaude(300)
    }

    onHoldsChanged: if (root.holds > 0)
        root.askClaude(600)

    // A reply just finished: its usage is worth a look.
    property string lastDone: ""
    onSessionsLiveChanged: {
        const done = root.sessionsLive.find(s => s.tool === "claude" && s.state === "done");
        const key = done ? `${done.key}@${done.since}` : "";
        if (key && key !== root.lastDone) {
            root.lastDone = key;
            root.askClaude(120);
        }
    }

    // ---- plumbing ---------------------------------------------------------------

    Process {
        id: poll

        property bool again: false

        command: ["sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; exec vela ai status']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.status = JSON.parse(text);
                    root.now = Date.now() / 1000;
                    root.loaded = true;
                    root.checkLimits();
                } catch (e) {
                    console.warn(`[vela] vela ai status: ${e}`);
                }
            }
        }
        onExited: if (poll.again) {
            poll.again = false;
            poll.running = true;
        }
    }

    // The pill is on the bar somewhere.
    readonly property bool pillPlaced: [...Config.bar.modules.left, ...Config.bar.modules.centre, ...Config.bar.modules.right].includes("ai")

    // Every few seconds while a tool is there and the pill is on the bar, so
    // it comes and goes with the tool; slowly while neither tool is, only to
    // notice one arriving.
    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: root.fast ? 4000 : root.tools.length === 0 ? 120000 : root.pillPlaced ? 10000 : 30000
        onTriggered: root.refresh()
    }

    // The countdowns and "done" fading; a second is enough while something
    // is live, since "done" lasts six.
    Timer {
        running: true
        repeat: true
        interval: root.ticking ? 1000 : 20000
        onTriggered: root.now = Date.now() / 1000
    }

    // A hook firing or a Claude reply: look now rather than at the next poll.
    Timer {
        id: soon

        interval: 200
        onTriggered: root.refresh()
    }

    FileView {
        path: root.livePath
        watchChanges: true
        printErrors: false
        onFileChanged: soon.restart()
    }

    FileView {
        path: root.claudePath
        watchChanges: true
        printErrors: false
        onFileChanged: soon.restart()
    }

    Component.onDestruction: {
        poll.running = false;
        asker.running = false;
        iconFetcher.running = false;
    }
}
