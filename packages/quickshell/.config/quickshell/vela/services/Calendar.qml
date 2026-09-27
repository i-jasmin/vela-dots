pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.tokens

// Events, from khal over whatever vdirsyncer has pulled down.
//
// THE ACCOUNTS. Settings, Calendars adds calendars without anybody writing a
// khal or vdirsyncer config: `vela calendar` keeps the accounts in a private
// folder, syncs each with its own vdirsyncer pair, and writes the khal
// calendar blocks for them, which the wrapper below splices into its copy of
// the user's khal config -- or makes a config of, where there is none. This
// service reads the accounts back from `state.json`, which has no secrets in
// it, and asks the command for every change.
//
// Where neither khal nor vdirsyncer is installed, this service spends its life
// reporting `available: false` with `reason` saying why -- and that is the
// point. The dashboard and the calendar month must render an honest empty
// state, not invented events; a calendar that shows a meeting nobody has is
// worse than a calendar that shows nothing. The moment khal appears on PATH the
// probe below picks it up on its next run and the same properties fill in.
//
// KHAL SPEAKS THE USER'S LOCALE, BOTH WAYS. Measured against khal 0.14: it
// parses the dates it is given with the `dateformat` in its config, so ISO
// dates are refused outright ("Could not parse") on any machine whose format
// is not ISO -- and it prints times in the same local format. So khal is run
// with a copy of the user's own config, identical but for the five format
// keys, which are set to ISO. Calendars, paths and timezones are theirs.
//
// Its `--json` is one array per day, one per line, and an event spanning
// several days appears on each of them; see `applyOutput`.
Singleton {
    id: root

    readonly property string backend: Config.calendar.backend

    // False until a backend has been found AND has answered a query. A khal
    // that is installed but cannot read its config is not a working calendar.
    readonly property bool available: present && !failed
    property bool present: false
    property bool failed: false
    property string reason: qsTr("Looking for a calendar backend…")
    property string version: ""

    property bool loading: false
    property real lastLoaded: 0

    // [{ uid, title, start, end, allDay, source, role, location, url,
    //    description }], start-ascending. Covers [rangeStart, rangeEnd).
    // Without the calendars switched off in Settings, and coloured as it
    // says, so a change there shows at once without asking khal again.
    readonly property var events: {
        const off = root.sources.filter(s => !s.enabled).map(s => s.name.toLowerCase());
        const out = [];
        for (const e of root.allEvents) {
            if (off.indexOf(e.source.toLowerCase()) >= 0)
                continue;
            out.push(Object.assign({}, e, {
                role: root.roleFor(e.source)
            }));
        }
        return out;
    }

    // Every event khal listed, hidden calendars included. `events` is what
    // the rest of the shell reads.
    property var allEvents: []

    // Five weeks back and five forward covers Home's month and its day
    // without a second query.
    // Today, five weeks either side -- widened to take in whatever the
    // calendar has asked for (`load`), without letting go of today. Assigning
    // the range outright stopped it following the clock, so after a few weeks
    // of uptime today fell outside it and the agenda went empty.
    property var asked: null
    readonly property date rangeStart: {
        const base = shiftDays(startOfDay(clock.date), -35);
        return root.asked && root.asked.from.getTime() < base.getTime() ? root.asked.from : base;
    }
    readonly property date rangeEnd: {
        const base = shiftDays(startOfDay(clock.date), 35);
        return root.asked && root.asked.to.getTime() > base.getTime() ? root.asked.to : base;
    }
    // Asked for while a query was running: run again once it is done, or the
    // new range would never be queried at all.
    property bool again: false

    // The "events" stat on the lock screen.
    readonly property var nextEvent: {
        const now = clock.date.getTime();
        return events.find(e => e.start.getTime() > now) ?? null;
    }
    readonly property var currentEvent: {
        const now = clock.date.getTime();
        return events.find(e => e.start.getTime() <= now && e.end.getTime() > now) ?? null;
    }
    readonly property real msUntilNext: nextEvent ? nextEvent.start.getTime() - clock.date.getTime() : 0
    readonly property var todayEvents: eventsOn(clock.date)

    // The colours a calendar can take: the scheme's three accents, and grey.
    // Nothing outside the scheme -- a decorative colour of its own is exactly
    // what the design rejects -- so a fourth calendar left to itself wraps
    // round to `primary`, and one that should step back can be grey.
    readonly property var roles: ["primary", "tertiary", "secondary", "outline"]
    readonly property var autoRoles: ["primary", "tertiary", "secondary"]

    // A role as shell.json may spell it; "outlineVariant" is the grey it
    // used to be called.
    function normalRole(r: var): string {
        const v = `${r ?? ""}`;
        if (v === "outlineVariant")
            return "outline";
        return root.roles.indexOf(v) >= 0 ? v : "";
    }

    function colourOf(role: string): color {
        if (role === "tertiary")
            return Colours.tertiary;
        if (role === "secondary")
            return Colours.secondary;
        if (role === "outline")
            return Colours.outline;
        return Colours.primary;
    }

    // [{ name, role, enabled }]: every calendar khal knows, with the colour
    // and the switch shell.json gives it by name -- any case -- and the next
    // accent for one it does not mention. A calendar shell.json names that
    // khal does not have is not shown: it would be a key to nothing.
    property var sources: []
    property var calendarNames: []

    property bool syncing: false
    property real lastSync: 0
    // The last sync's failure, kept apart from `reason`. A sync that fails
    // says nothing about the calendar khal already has -- and before
    // vdirsyncer is set up it fails every time, with "critical: Error during
    // reading config", which is not something the dashboard should print.
    property string syncError: ""
    readonly property string syncLabel: {
        if (!root.syncCommand)
            return "";
        return qsTr("every %1 min").arg(Config.calendar.syncMinutes);
    }

    // What is asked of khal, newest last. An older khal refuses a field it
    // does not know, and then the next set down is tried: each drops the
    // newest fields, so one missing field costs that field and not the rest.
    // khal has had the last set's four since 0.10.
    readonly property var fieldTiers: [["title", "start", "end", "start-long-full", "end-long-full", "all-day", "calendar", "location", "url", "uid", "description", "repeat-pattern", "alarms-list"], ["title", "start", "end", "start-long-full", "end-long-full", "all-day", "calendar", "location", "url", "uid", "description"], ["title", "start", "end", "calendar"]]
    property int fieldTier: 0
    readonly property var fields: root.fieldTiers[root.fieldTier]

    // Where the ISO copy of the user's khal config is written.
    readonly property string isoConfig: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/vela/khal.conf`

    // Copies the user's khal config with ISO formats, then runs khal on the
    // copy with the rest of its arguments. `$1` is the copy's path. A [locale]
    // section keeps its other keys (timezones, first weekday); one is added if
    // there was none, because configobj refuses a second.
    readonly property string isoWrapper: `
src=""
for f in "\${XDG_CONFIG_HOME:-$HOME/.config}/khal/config" "$HOME/.khal/khal.conf"; do
    [ -f "$f" ] && { src="$f"; break; }
done
extra="\${XDG_DATA_HOME:-$HOME/.local/share}/vela/calendar/khal-calendars.conf"
[ -s "$extra" ] || extra=""
[ -n "$src$extra" ] || { echo "khal has no config file" >&2; exit 3; }
out="$1"; shift
mkdir -p "\${out%/*}"
if [ -n "$src" ]; then cat "$src"; fi | awk -v extra="$extra" -v db="\${out%/*}/khal.db" '
function iso() {
    print "timeformat = %H:%M"
    print "dateformat = %Y-%m-%d"
    print "longdateformat = %Y-%m-%d"
    print "datetimeformat = %Y-%m-%d %H:%M"
    print "longdatetimeformat = %Y-%m-%d %H:%M"
}
function splice(line) {
    if (extra != "") {
        while ((getline line < extra) > 0) print line
        close(extra)
    }
    spliced = 1
}
/^[[:space:]]*(timeformat|dateformat|longdateformat|datetimeformat|longdatetimeformat)[[:space:]]*=/ { next }
{ bare = $0; gsub(/[[:space:]]/, "", bare) }
bare ~ /^\\[[^\\[]/ { insqlite = (bare == "[sqlite]") }
insqlite { next }
bare == "[locale]" { print; iso(); found = 1; next }
bare == "[calendars]" { print; splice(); next }
{ print }
END {
    if (!spliced) { print "[calendars]"; splice() }
    if (!found) { print "[locale]"; iso() }
    print "[sqlite]"
    print "path = " db
}' > "$out" || exit 4
exec khal -c "$out" "$@"`

    // A tool's first line of complaint, without the "critical:" or "error:"
    // it opens with -- the label it goes on already says something is wrong.
    function firstLine(text: string): string {
        const line = text.trim().split("\n")[0] ?? "";
        const bare = line.replace(/^(critical|error|warning):\s*/i, "");
        return bare.charAt(0).toUpperCase() + bare.slice(1);
    }

    function startOfDay(d: date): date {
        const out = new Date(d);
        out.setHours(0, 0, 0, 0);
        return out;
    }

    function shiftDays(d: date, n: int): date {
        const out = new Date(d);
        out.setDate(out.getDate() + n);
        return out;
    }

    function iso(d: date): string {
        return Qt.formatDateTime(d, "yyyy-MM-dd");
    }

    // Home asks this for the picked day, so it walks the array
    // rather than re-querying the backend.
    function eventsOn(d: date): var {
        const from = startOfDay(d).getTime();
        // The next midnight, not 24 hours on: the day the clocks go back has
        // 25, and an event in its last hour belonged to neither day.
        const to = shiftDays(startOfDay(d), 1).getTime();
        return events.filter(e => e.start.getTime() < to && e.end.getTime() > from);
    }

    function hasEventsOn(d: date): bool {
        return eventsOn(d).length > 0;
    }

    // Case aside: shell.json names a calendar "Work" where khal calls it
    // "work", and the two are the same calendar.
    function roleFor(source: string): string {
        const key = (source ?? "").toLowerCase();
        const s = sources.find(x => (x.name ?? "").toLowerCase() === key);
        return s ? s.role : "outlineVariant";
    }

    function load(from: date, to: date): void {
        asked = {
            from: startOfDay(from),
            to: startOfDay(to)
        };
        refresh();
    }

    function refresh(): void {
        if (!present)
            return;
        if (loading) {
            again = true;
            return;
        }
        loading = true;
        list.command = listCommand(rangeStart, rangeEnd);
        list.running = true;
    }

    // One place to fix if khal's CLI is not what this expects. ISO dates,
    // because khal parses them regardless of the locale `dateformat` its own
    // config sets. Deliberately no `--notstarted`: Home's day shows the
    // whole of today, including the meeting that started ten minutes ago.
    function listCommand(from: date, to: date): var {
        const cmd = ["sh", "-c", root.isoWrapper, "vela-khal", root.isoConfig, "list"];
        for (let i = 0; i < fields.length; i++)
            cmd.push("--json", fields[i]);
        cmd.push(iso(from), iso(to));
        return cmd;
    }

    // Under the ISO config a timed stamp is "2026-09-25 09:30" and an all-day
    // one a bare "2026-09-25". Taken apart by hand: `Date` is not required to
    // parse a space-separated stamp, and one that fails reads as NaN, not as
    // an error.
    function parseStamp(v: var): var {
        const m = `${v ?? ""}`.trim().match(/^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?/);
        if (!m)
            return null;
        return {
            at: new Date(+m[1], +m[2] - 1, +m[3], +(m[4] ?? 0), +(m[5] ?? 0)),
            allDay: m[4] === undefined
        };
    }

    // One JSON array per line, one line per day. Parsed line by line so one
    // bad line costs its own day and not the rest.
    function applyOutput(raw: string): bool {
        const rows = [];
        let bad = 0;
        for (const line of raw.split("\n")) {
            const l = line.trim();
            if (!l)
                continue;
            try {
                const doc = JSON.parse(l);
                if (Array.isArray(doc))
                    rows.push(...doc);
            } catch (e) {
                bad++;
            }
        }
        if (bad > 0 && rows.length === 0)
            return false;
        root.applyEvents(rows);
        return true;
    }

    function applyEvents(rows: var): bool {
        const out = [];
        const seen = {};
        let unreadable = 0;
        for (let i = 0; i < rows.length; i++) {
            const r = rows[i];
            const bare = parseStamp(r.start);
            const allDay = /^true$/i.test(`${r["all-day"] ?? ""}`) || (bare?.allDay ?? false);
            // All-day: the bare dates. Timed: the "-full" stamps, which carry
            // the date even on the day the event starts.
            const s = allDay ? bare : parseStamp(r["start-long-full"] ?? r.start);
            if (!s) {
                unreadable++;
                continue;
            }
            const source = r.calendar ?? "";
            const uid = r.uid || `${source}:${s.at.getTime()}:${r.title ?? ""}`;
            // A multi-day event is listed under every day it touches.
            if (seen[uid])
                continue;
            seen[uid] = true;
            let e = parseStamp(allDay ? r.end : (r["end-long-full"] ?? r.end));
            // khal's all-day end date is inclusive; this service's ends are not.
            if (e && allDay)
                e = {
                    at: root.shiftDays(e.at, 1),
                    allDay: true
                };
            if (e && e.at.getTime() <= s.at.getTime())
                e = null;
            out.push({
                uid: uid,
                title: (r.title ?? "").trim(),
                start: s.at,
                // A missing end is a point in time, not a zero-length bug:
                // all-day runs to midnight, timed defaults to an hour.
                end: e ? e.at : new Date(s.at.getTime() + (allDay ? 86400000 : 3600000)),
                allDay: allDay,
                source: source,
                location: (r.location ?? "").trim(),
                url: (r.url ?? "").trim(),
                description: (r.description ?? "").trim(),
                // A repeating event is one file for the whole series, and is
                // not changed from here.
                recurring: `${r["repeat-pattern"] ?? ""}`.trim() !== "",
                // Its own reminders, in seconds from its start (negative is
                // before): "15 minutes before" set on a phone is -900.
                alarms: (Array.isArray(r["alarms-list"]) ? r["alarms-list"] : []).map(a => Number(a.delta)).filter(n => !isNaN(n))
            });
        }
        out.sort((a, b) => a.start.getTime() - b.start.getTime());
        root.allEvents = out;
        const first = root.lastLoaded === 0;
        root.lastLoaded = Date.now();
        if (first)
            Qt.callLater(root.checkReminders);
        if (unreadable > 0)
            root.reason = qsTr("%1 events had dates this shell could not read").arg(unreadable);
        else
            root.reason = "";
        return unreadable < rows.length || rows.length === 0;
    }

    // ~/.local/bin first: a session started from a display manager often
    // has no user bin on PATH, and that is where `vela` lives.
    readonly property string userPath: 'PATH="$HOME/.local/bin:$PATH"; '

    // shell.json's sync command. The old default, a bare `vdirsyncer sync`,
    // knew nothing of the accounts; `vela calendar sync` syncs them and then
    // runs a vdirsyncer set up by hand as well, so it stands in for it.
    readonly property string syncCommand: {
        const cmd = (Config.calendar.syncCommand ?? "").trim();
        return cmd === "vdirsyncer sync" ? "vela calendar sync" : cmd;
    }

    // "Synced 3m ago", or "just now" for the first minute rather than "0m".
    function syncedAgo(at: real): string {
        const ms = Time.now.getTime() - at;
        return ms < 60000 ? qsTr("Synced just now") : qsTr("Synced %1 ago").arg(Time.span(ms));
    }

    // Asked for while one was running: run again once it is done, so an
    // event written mid-sync is not left waiting for the next quarter-hour.
    property bool syncQueued: false

    function sync(): void {
        if (!present || !root.syncCommand)
            return;
        if (syncing) {
            syncQueued = true;
            return;
        }
        syncing = true;
        syncProc.command = ["sh", "-c", root.userPath + root.syncCommand];
        syncProc.running = true;
    }

    // One account, straight after it is added, whatever the sync command
    // is: this is the moment somebody is watching for their events.
    function syncAccount(id: string): void {
        if (syncing)
            return;
        syncing = true;
        syncProc.command = ["sh", "-c", root.userPath + 'exec vela calendar sync "$1"', "vela", id];
        syncProc.running = true;
    }

    function applySources(names: var): void {
        root.calendarNames = names;
        const configured = Config.calendar.sources ?? [];
        const find = n => configured.find(s => `${s.name ?? s.calendar ?? ""}`.toLowerCase() === n.toLowerCase());
        let next = 0;
        root.sources = names.map(n => {
            const c = find(n);
            const role = root.normalRole(c?.colour ?? c?.role ?? c?.color) || root.autoRoles[next++ % root.autoRoles.length];
            return {
                name: n,
                role: role,
                enabled: c ? c.enabled !== false : true
            };
        });
    }

    // Written to shell.json by the settings window: one calendar's colour or
    // switch, kept by name. The whole list is written back, so a calendar
    // that was only ever coloured automatically keeps its colour once any
    // other is changed.
    function setSource(name: string, role: string, enabled: bool): void {
        const list = root.sources.map(s => ({
                    name: s.name,
                    colour: s.name === name ? role : s.role,
                    enabled: s.name === name ? enabled : s.enabled
                }));
        // Keep what shell.json says about calendars khal has not listed
        // this time -- an account mid-sync, a laptop offline.
        for (const c of Config.calendar.sources ?? []) {
            const n = `${c.name ?? c.calendar ?? ""}`;
            if (n && !list.some(s => s.name.toLowerCase() === n.toLowerCase()))
                list.push(c);
        }
        Config.calendar.sources = list;
    }

    // ---- accounts -------------------------------------------------------
    //
    // [{ id, provider, kind, name, host, username, calendars: [names], ok,
    //    error, synced }] -- `vela calendar`'s state.json, secrets left out.
    readonly property string accountsDir: `${Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share"}/vela/calendar`
    property var accounts: []
    property bool adding: false
    property string addError: ""
    property string removing: ""
    // Said when an account has been added, with its id, so the settings
    // window can clear its form.
    signal accountAdded(string id)

    // `provider` is one of google, outlook, link (read-only calendar links)
    // or icloud, nextcloud, caldav (an account with all its calendars). The
    // details reach the command through its environment, never its
    // arguments, which any process on the machine can read.
    function addAccount(provider: string, name: string, url: string, user: string, password: string): void {
        if (root.adding)
            return;
        root.adding = true;
        root.addError = "";
        addProc.environment = {
            VELA_CAL_PROVIDER: provider,
            VELA_CAL_NAME: name,
            VELA_CAL_URL: url,
            VELA_CAL_USER: user,
            VELA_CAL_PASS: password
        };
        addProc.command = ["sh", "-c", root.userPath + 'exec vela calendar add'];
        addProc.running = true;
    }

    // "" while the keyring answers; otherwise what is wrong with it. The
    // passwords and links are kept there, so without it nothing can be
    // added. Asked for by the settings page when it opens.
    property string keyringProblem: ""

    function checkKeyring(): void {
        keyringProc.running = true;
        stateFile.reload();
    }

    function removeAccount(id: string): void {
        if (root.removing)
            return;
        root.removing = id;
        removeProc.command = ["sh", "-c", root.userPath + 'exec vela calendar remove "$1"', "vela", id];
        removeProc.running = true;
    }

    // ---- events ---------------------------------------------------------
    //
    // [{ name, path, account, accountName }] -- the calendars events can be
    // written to: a CalDAV account's, but for those its server keeps
    // read-only (Nextcloud's contact birthdays, one shared with you to read:
    // `vela calendar` asks), and only those switched on in Settings -- an
    // event saved into a hidden calendar would vanish as it was made. A link
    // calendar is read-only.
    readonly property var writable: {
        const off = root.sources.filter(s => !s.enabled).map(s => s.name.toLowerCase());
        const out = [];
        for (const a of root.accounts)
            for (const c of a.writable ?? [])
                if (off.indexOf(c.name.toLowerCase()) < 0)
                    out.push({
                        name: c.name,
                        path: c.path,
                        account: a.id,
                        accountName: a.name
                    });
        return out;
    }

    // Where a new event goes: the calendar starred in Settings, or, with
    // none starred (or that one switched off), the first that takes one.
    readonly property var defaultWritable: {
        const key = Config.calendar.newEvents.toLowerCase();
        return root.writable.find(w => w.name.toLowerCase() === key) ?? root.writable[0] ?? null;
    }

    function writableFor(source: string): var {
        const key = `${source ?? ""}`.toLowerCase();
        return root.writable.find(w => w.name.toLowerCase() === key) ?? null;
    }

    // Whether this event can be changed here: in a writable calendar, and
    // not one of a repeating series.
    function isWritable(e: var): bool {
        return e !== null && !e.recurring && root.writableFor(e.source) !== null;
    }

    // What is waiting to upload, and whether the reason is a server out of
    // reach rather than something wrong.
    readonly property int pending: root.accounts.reduce((n, a) => n + (a.pending ?? 0), 0)
    readonly property var unreachable: root.accounts.filter(a => a.offline).map(a => a.host)

    property bool saving: false
    property string eventError: ""
    signal eventSaved

    // `ev`: { uid ("" for a new one), path, title, start, end, location },
    // start and end as "2026-09-28T15:00", or "2026-09-28" for all day with
    // end inclusive. Written at once, shown at once, uploaded by the sync
    // that follows -- or the first one to get through.
    function saveEvent(ev: var): void {
        if (root.saving)
            return;
        root.saving = true;
        root.eventError = "";
        eventProc.environment = {
            VELA_EV_PATH: ev.path,
            VELA_EV_TITLE: ev.title,
            VELA_EV_START: ev.start,
            VELA_EV_END: ev.end,
            VELA_EV_LOCATION: ev.location ?? ""
        };
        eventProc.command = ev.uid ? ["sh", "-c", root.userPath + 'exec vela calendar event edit "$1"', "vela", ev.uid] : ["sh", "-c", root.userPath + 'exec vela calendar event add'];
        eventProc.running = true;
    }

    function deleteEvent(uid: string): void {
        if (root.saving)
            return;
        root.saving = true;
        root.eventError = "";
        eventProc.environment = {};
        eventProc.command = ["sh", "-c", root.userPath + 'exec vela calendar event delete "$1"', "vela", uid];
        eventProc.running = true;
    }

    Process {
        id: eventProc

        stderr: StdioCollector {
            id: eventErr
        }

        onExited: code => {
            root.saving = false;
            if (code !== 0) {
                root.eventError = root.firstLine(eventErr.text.replace(/^vela:\s*/, "")) || qsTr("Could not save it");
                return;
            }
            stateFile.reload();
            root.eventSaved();
            root.refresh();
            root.sync();
        }
    }

    // ---- reminders --------------------------------------------------------
    //
    // A notification for each event, when its own reminders say (the
    // "15 minutes before" set in the calendar app, which khal reports), or,
    // for a timed event with none, `calendar.reminderMinutes` before it
    // starts. Checked every twenty seconds against the moment of the last
    // check, so each fires once; one whose moment passed while the laptop
    // slept still fires on waking if its event has not ended. What has been
    // sent, when it was last checked and what is snoozed are kept in
    // ~/.local/state/vela/reminders.json, so a restart neither sends one
    // again nor loses a snooze -- and one due while the shell was down (up
    // to an hour back) is sent when it comes up.
    property real reminderChecked: 0
    property var reminded: ({})
    property var snoozed: []
    property bool remindersReady: false

    readonly property string reminderState: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/vela/reminders.json`

    function startReminders(saved: var): void {
        const now = Date.now();
        root.reminderChecked = Math.max(saved?.checked ?? 0, now - 3600000);
        root.reminded = saved?.reminded ?? {};
        root.snoozed = saved?.snoozed ?? [];
        root.remindersReady = true;
        root.checkReminders();
    }

    function saveReminders(): void {
        // Nothing older than two days is worth remembering.
        const keep = {};
        const cutoff = Date.now() - 2 * 86400000;
        for (const k in root.reminded)
            if (root.reminded[k] > cutoff)
                keep[k] = root.reminded[k];
        root.reminded = keep;
        reminderFile.setText(JSON.stringify({
            checked: root.reminderChecked,
            reminded: keep,
            snoozed: root.snoozed
        }));
    }

    FileView {
        id: reminderFile

        path: root.reminderState
        watchChanges: false
        atomicWrites: true
        printErrors: false
        onLoaded: {
            let saved = null;
            try {
                saved = JSON.parse(text());
            } catch (e) {}
            root.startReminders(saved);
        }
        onLoadFailed: root.startReminders(null)
        // A fresh install has no ~/.local/state/vela yet.
        onSaveFailed: reminderDir.running = true
    }

    Process {
        id: reminderDir

        command: ["mkdir", "-p", `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/vela`]
        onExited: code => {
            if (code === 0)
                root.saveReminders();
        }
    }

    function remindersBetween(from: real, to: real): var {
        const lead = Config.calendar.reminderMinutes;
        const own = Config.calendar.eventAlarms;
        const out = [];
        for (const e of root.events) {
            if (e.end.getTime() <= to)
                continue;
            const start = e.start.getTime();
            const times = [];
            if (own && e.alarms && e.alarms.length > 0)
                for (const d of e.alarms)
                    times.push(start + d * 1000);
            else if (lead >= 0 && !e.allDay)
                times.push(start - lead * 60000);
            for (const t of times)
                if (t > from && t <= to)
                    out.push({
                        event: e,
                        at: t
                    });
        }
        return out;
    }

    function checkReminders(): void {
        // Not before the events have been read once: checking an empty
        // list would move the check on past reminders that were due.
        if (!root.remindersReady || root.lastLoaded === 0)
            return;
        const now = Date.now();
        const from = root.reminderChecked;
        root.reminderChecked = now;
        let changed = false;
        for (const r of root.remindersBetween(from, now)) {
            const key = `${r.event.uid}|${r.at}`;
            if (root.reminded[key])
                continue;
            root.reminded[key] = r.at;
            changed = true;
            root.remind(r.event);
        }
        const keep = [];
        for (const s of root.snoozed) {
            if (s.at > now) {
                keep.push(s);
                continue;
            }
            const e = root.events.find(x => x.uid === s.uid);
            if (e && e.end.getTime() > now)
                root.remind(e);
        }
        if (keep.length !== root.snoozed.length) {
            root.snoozed = keep;
            changed = true;
        }
        // The check time itself is kept too, but only written with a change
        // or once a few minutes, not every twenty seconds.
        if (changed || now - root.reminderSaved > 300000) {
            root.reminderSaved = now;
            root.saveReminders();
        }
    }

    property real reminderSaved: 0

    function linkOf(e: var): string {
        const url = e.url || e.location || "";
        return /^https?:\/\//.test(url) ? url : "";
    }

    // "In 10m · 15:00 – 16:00 · Room 4", "Now", "Started 5m ago", or
    // "Tomorrow, all day".
    function reminderBody(e: var): string {
        const now = Date.now();
        let when;
        if (e.allDay) {
            const day = root.startOfDay(e.start).getTime();
            const today = root.startOfDay(new Date(now)).getTime();
            when = day <= today ? qsTr("Today, all day") : day === root.shiftDays(new Date(today), 1).getTime() ? qsTr("Tomorrow, all day") : qsTr("%1, all day").arg(Qt.formatDateTime(e.start, "dddd"));
        } else {
            const ms = e.start.getTime() - now;
            when = ms > 60000 ? qsTr("In %1").arg(Time.span(ms)) : ms > -60000 ? qsTr("Now") : qsTr("Started %1 ago").arg(Time.span(-ms));
        }
        const time = e.allDay ? "" : `${Qt.formatDateTime(e.start, "hh:mm")} – ${Qt.formatDateTime(e.end, "hh:mm")}`;
        // A meeting link is what Join opens, not a place worth reading out.
        const place = e.location && e.location !== root.linkOf(e) ? e.location : "";
        return [when, time, place].filter(t => t).join(" · ");
    }

    function remind(e: var, tries = 0): void {
        reminderNote.createObject(root, {
            event: e,
            link: root.linkOf(e),
            tries: tries
        });
    }

    // Reminders that found no one to show them -- at login, the shell's own
    // notifications can still be starting when the first one is due -- tried
    // again a few seconds on, three times at most.
    property var retrying: []

    Timer {
        id: retryTimer

        interval: 5000
        onTriggered: {
            const due = root.retrying;
            root.retrying = [];
            for (const r of due)
                root.remind(r.event, r.tries);
        }
    }

    // A made-up event a few minutes out, so Settings can show what a
    // reminder looks like and that notifications get through.
    function testReminder(): void {
        const start = new Date(Date.now() + 10 * 60000);
        root.remind({
            uid: "",
            title: qsTr("A test reminder"),
            start: start,
            end: new Date(start.getTime() + 30 * 60000),
            allDay: false,
            location: qsTr("vela"),
            url: ""
        });
    }

    Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: root.checkReminders()
    }

    // One reminder: a notification that stays to hear which button was
    // pressed (`notify-send -A` prints it), for fifteen minutes. The card is
    // the calendar; Join opens the meeting's link; Snooze brings it back in
    // five minutes.
    Component {
        id: reminderNote

        Process {
            id: note

            required property var event
            required property string link
            required property int tries

            command: ["timeout", "900", "notify-send", "-a", qsTr("Calendar"), "-i", "appointment-soon"].concat(note.link ? ["-A", `join=${qsTr("Join")}`] : []).concat(note.event.uid ? ["-A", `snooze=${qsTr("Snooze 5 min")}`] : []).concat(["-A", `default=${qsTr("Open calendar")}`, note.event.title || qsTr("Event"), root.reminderBody(note.event)])

            stdout: StdioCollector {
                onStreamFinished: {
                    const picked = text.trim();
                    if (picked === "join")
                        Files.openUrl(note.link);
                    else if (picked === "snooze") {
                        root.snoozed = root.snoozed.concat([
                            {
                                uid: note.event.uid,
                                at: Date.now() + 5 * 60000
                            }
                        ]);
                        root.saveReminders();
                    } else if (picked === "default")
                        ShellState.openCalendarOn("");
                }
            }

            // 0 is a button or the card closed, 124 the fifteen minutes up;
            // anything else, nothing was shown.
            onExited: code => {
                if (code !== 0 && code !== 124 && note.tries < 3) {
                    root.retrying = root.retrying.concat([
                        {
                            event: note.event,
                            tries: note.tries + 1
                        }
                    ]);
                    retryTimer.restart();
                }
                note.destroy();
            }

            running: true
        }
    }

    // Home again: a network that comes back, or a different one, is the
    // moment a server at home can be reached -- so sync then, rather than
    // at the next quarter-hour. After a moment, for the address to settle.
    Connections {
        target: Net

        function onConnectedChanged(): void {
            if (Net.connected && root.accounts.length > 0)
                netSettle.restart();
        }

        function onSsidChanged(): void {
            if (Net.connected && root.accounts.length > 0)
                netSettle.restart();
        }
    }

    Timer {
        id: netSettle

        interval: 5000
        onTriggered: root.sync()
    }

    // Everything khal has changed under it: the calendars there are, and
    // their events.
    function reread(): void {
        if (!root.present)
            return;
        calendars.running = true;
        root.refresh();
    }

    // Watched, and also read again by hand after everything that writes it:
    // a watch set up on a file that does not exist yet -- the first account
    // on a machine, added after the shell started -- never sees it appear,
    // and the new account waited for a restart.
    FileView {
        id: stateFile

        path: `${root.accountsDir}/state.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.accounts = JSON.parse(text()).accounts ?? [];
            } catch (e) {
                root.accounts = [];
            }
        }
        onLoadFailed: root.accounts = []
    }

    Process {
        id: addProc

        stdout: StdioCollector {
            id: addOut
        }

        stderr: StdioCollector {
            id: addErr
        }

        onExited: code => {
            root.adding = false;
            if (code !== 0) {
                root.addError = root.firstLine(addErr.text.replace(/^vela:\s*/, "")) || qsTr("Could not add it");
                root.checkKeyring();
                return;
            }
            const id = addOut.text.trim();
            stateFile.reload();
            root.accountAdded(id);
            root.syncAccount(id);
        }
    }

    Process {
        id: keyringProc

        command: ["sh", "-c", root.userPath + 'exec vela calendar keyring']

        stdout: StdioCollector {
            id: keyringOut
        }

        onExited: code => root.keyringProblem = code === 0 ? "" : (keyringOut.text.trim() || qsTr("No keyring answered"))
    }

    Process {
        id: removeProc

        stderr: StdioCollector {
            id: removeErr
        }

        onExited: code => {
            root.removing = "";
            stateFile.reload();
            root.reread();
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // The range is relative to today, so it has to move when today does.
    onRangeStartChanged: refresh()

    Component.onCompleted: {
        applySources([]);
        checkKeyring();
    }

    // Re-reading shell.json must not need a restart, and the chips are the
    // visible half of it.
    Connections {
        target: Config.calendar

        function onSourcesChanged(): void {
            root.applySources(root.calendarNames);
        }
    }

    // --- backend probe ---------------------------------------------------
    //
    // Re-run on a timer rather than once at startup: khal arriving on PATH is
    // exactly the case this service is written for, and a shell restart is not
    // an acceptable price for installing a package.
    Process {
        id: probe

        running: true
        // Through `sh` rather than exec'ing khal directly: Quickshell reports a
        // binary it cannot find by failing to start the process, and a process
        // that never started never emits `exited`, so the probe would hang on
        // "looking for a backend" forever on a machine without khal. Measured.
        command: ["sh", "-c", "command -v khal >/dev/null && khal --version"]

        stdout: StdioCollector {
            onStreamFinished: root.version = text.trim()
        }

        stderr: StdioCollector {}

        onExited: code => {
            const wasPresent = root.present;
            root.present = code === 0;
            if (!root.present) {
                root.failed = false;
                root.allEvents = [];
                root.reason = qsTr("khal is not installed");
            } else if (!wasPresent) {
                root.reason = "";
                calendars.running = true;
                root.refresh();
            }
        }
    }

    Timer {
        running: !root.present
        interval: 60000
        repeat: true
        onTriggered: probe.running = true
    }

    // Through the wrapper, so the accounts' calendars are listed with the
    // user's own.
    Process {
        id: calendars

        command: ["sh", "-c", root.isoWrapper, "vela-khal", root.isoConfig, "printcalendars"]

        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.trim().split("\n").map(l => l.trim()).filter(l => l.length > 0);
                root.applySources(names);
            }
        }

        stderr: StdioCollector {}
    }

    Process {
        id: list

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                // Nothing in the range is a working calendar with an empty
                // stretch -- a new account's first minutes, say -- not a
                // missing one; it must not keep "No calendar set up yet".
                if (!raw) {
                    root.failed = false;
                    return void root.applyEvents([]);
                }
                if (root.applyOutput(raw)) {
                    root.failed = false;
                } else {
                    root.failed = true;
                    root.reason = qsTr("khal returned something that is not JSON");
                }
            }
        }

        stderr: StdioCollector {
            id: listErr
        }

        onExited: code => {
            root.loading = false;
            if (root.again) {
                root.again = false;
                root.refresh();
                return;
            }
            if (code === 0)
                return;
            // Most likely an unknown `--json` field on an older khal. Drop to
            // the next set of fields and try again before calling the
            // backend unusable.
            if (root.fieldTier < root.fieldTiers.length - 1) {
                root.fieldTier++;
                root.refresh();
                return;
            }
            root.failed = true;
            // 3 is the wrapper above finding no khal config: the ordinary
            // state of a machine nobody has set a calendar up on yet.
            root.reason = code === 3 ? qsTr("No calendar set up yet") : root.firstLine(listErr.text) || qsTr("khal exited with %1").arg(code);
        }
    }

    Process {
        id: syncProc

        stderr: StdioCollector {
            id: syncErr
        }

        onExited: code => {
            root.syncing = false;
            if (code === 0) {
                root.lastSync = Date.now();
                root.syncError = "";
            } else {
                root.syncError = root.firstLine(syncErr.text.replace(/^vela:\s*/, "")) || qsTr("sync exited with %1").arg(code);
            }
            // A new account's calendars exist from its first sync on, and a
            // failed sync may still have fetched some accounts.
            stateFile.reload();
            root.reread();
            if (root.syncQueued) {
                root.syncQueued = false;
                root.sync();
            }
        }
    }

    Timer {
        running: root.present && Config.calendar.syncMinutes > 0
        interval: Math.max(1, Config.calendar.syncMinutes) * 60000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sync()
    }
}
