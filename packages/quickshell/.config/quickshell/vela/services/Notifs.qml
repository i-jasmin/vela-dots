pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

// vela's notification daemon. NotificationServer on its own only ever exposes
// what is live on the bus: the moment a notification is closed -- by its app,
// by a timeout or by the user -- the object is destroyed. This adds the three
// things the UI needs on top of it: a capped history that outlives the popups,
// a do-not-disturb switch, and the focus digest.
//
// Notifications are Retainable, so every entry owns a RetainableLock. That lock
// is what keeps a closed notification readable for as long as vela still has to
// draw it -- sitting in the history list, or animating out of the popup stack.
Singleton {
    id: root

    // Newest first. Capped because a shell that has been up for a week should
    // not still be holding a thousand D-Bus objects alive.
    readonly property int maxHistory: 50

    // Plain JS arrays rather than list<Notif>: ScriptModel takes JS values,
    // and array semantics here are exactly what the filtering below wants.
    property var list: []

    // What the popup stack is currently drawing. Overlaps `list` except while a
    // popup animates away after its entry was already dismissed.
    property var popups: []

    // A runtime switch driven by the dashboard and by IPC. shell.json has no
    // key for it -- see the note on maxVisible below -- so it starts off and
    // does not survive a restart.
    property bool doNotDisturb: false

    // When the notification centre was last opened. Everything filed after it
    // is unread: what the bar's bell dots for, what the lock screen counts,
    // and what the centre marks as new. A session value, like the history
    // itself -- nothing survives a restart to be unread about.
    property date seenAt: new Date(0)
    readonly property int unread: root.list.filter(e => e.time > root.seenAt).length

    function markSeen(): void {
        root.seenAt = new Date();
    }

    // How many notification *cards* -- which, since grouping, means apps -- the
    // popup stack shows at once. shell.json has no notifications.maxVisible,
    // so the number lives here until the schema grows one.
    readonly property int maxVisible: Config.notifications.maxVisible
    readonly property real swipeThreshold: Config.notifications.swipeThreshold

    // How long a popup stays up, for the module that draws it.
    readonly property int timeout: Config.notifications.timeout
    readonly property string position: Config.notifications.position

    readonly property bool popupsEnabled: !doNotDisturb

    // Grouping.
    //
    // Both views draw one card per application rather than one per
    // notification, the way a phone does: five messages from one chat are one
    // card that says five, not five cards that push everything else off the
    // screen. The two halves are kept apart on purpose -- `apps` is a list of
    // plain strings and `groups` a map keyed by them.
    //
    // A list of strings is what makes this animate. ScriptModel diffs its
    // values, and strings compare by value, so a group whose contents changed
    // keeps its delegate and only the delegate's own bindings retick. Handing
    // it freshly built group objects instead would destroy and rebuild every
    // card on every arrival, restarting animations that were mid-flight.
    // Urgent first -- the design heads the stack with it, and "urgent pops, the
    // rest digests" only means anything if the urgent card is the one read
    // first. `popupApps[0]` is the card nearest the edge the stack grows from
    // at either anchor, so this puts it there whichever way the stack runs.
    // Arrival order otherwise; the sort is stable, so two urgent apps keep
    // theirs. Only the popups are reordered -- the history stays chronological,
    // because a list you scroll is a record and a record is not ranked.
    readonly property var popupApps: root.urgentFirst(appsOf(popups), popupGroups)
    readonly property var popupGroups: groupsOf(popups)
    readonly property var apps: appsOf(list)
    readonly property var groups: groupsOf(list)

    // The digest.
    //
    // While the dashboard's focus timer holds notifications, anything that is
    // not urgent stops popping and collects here instead. It is still filed in
    // the history the moment it arrives; `held` is a second view of the same
    // entries, not a second copy, and it is what the one grouped card is built
    // from: a count, a time range, and per-app rows.
    //
    // Urgency is the exception the rule exists for. A critical notification
    // pops through focus untouched, because a failing disk is not something to
    // read about in an hour.
    property var held: []

    readonly property bool digestEnabled: Config.notifications.digest.enabled
    // The focus timer's "Hold notifications", while a session runs.
    readonly property bool focusHolds: Focus.running && Focus.holdNotifications
    readonly property bool holding: root.focusHolds && digestEnabled

    // True once the collected batch is ready to be shown -- the interval
    // elapsed, or focus ended. The card stays visible while focus is on;
    // this is what the module uses to decide whether to raise it.
    property bool digestDue: false

    // Start of the window currently being collected. Reset whenever the batch
    // is shown or cleared, so "13:41 — 14:32" always describes this batch.
    property date digestSince: new Date()

    readonly property var heldApps: appsOf(held)
    readonly property var heldGroups: groupsOf(held)
    readonly property int heldCount: held.length
    readonly property bool heldUrgent: held.some(e => e.critical)

    readonly property date heldFrom: held.length > 0 ? held[held.length - 1].time : digestSince
    readonly property date heldTo: held.length > 0 ? held[0].time : digestSince
    // "13:41 — 14:32". An em dash, as the design draws it.
    readonly property string heldRange: `${at(heldFrom)} — ${at(heldTo)}`

    readonly property date nextDigestAt: new Date(digestSince.getTime() + Config.notifications.digest.intervalMinutes * 60000)
    readonly property string nextDigestLabel: at(nextDigestAt)

    function at(t: date): string {
        return Qt.formatDateTime(t, "hh:mm");
    }

    // Called by the interval timer and by focus ending. Raising the card is the
    // module's business; all this does is say the batch is ready.
    function releaseDigest(): void {
        if (held.length > 0)
            digestDue = true;
    }

    // "Stay in focus" -- put the card away, keep holding, push the next digest
    // out by a full interval. The batch keeps collecting.
    function stayInFocus(): void {
        digestDue = false;
        digestSince = new Date();
    }

    // "Mark all read" -- the batch is gone from the digest. The entries stay in
    // the history, because the user read the card, not the notifications.
    function markAllRead(): void {
        held = [];
        digestDue = false;
        digestSince = new Date();
    }

    // Everything the digest collected, dropped for good.
    function dismissDigest(): void {
        const batch = [...held];
        held = [];
        digestDue = false;
        digestSince = new Date();
        for (const entry of batch)
            dismiss(entry);
    }

    function unhold(entry: Notif): void {
        held = held.filter(e => e !== entry);
    }

    // Focus ending is what the whole mechanism waits for.
    onFocusHoldsChanged: {
        if (!root.focusHolds)
            root.releaseDigest();
        else
            root.digestSince = new Date();
    }

    // "Next digest at 15:41, or when focus ends" -- the second half of the
    // promise the digest's footer makes.
    // Polled rather than armed for the exact moment: an interval bound to
    // `nextDigestAt - now` would be rewritten every second by the clock, and a
    // Timer restarts whenever its interval changes, so it would never fire.
    Timer {
        running: root.holding && root.held.length > 0 && !root.digestDue
        interval: 20000
        repeat: true

        onTriggered: {
            if (Date.now() >= root.nextDigestAt.getTime())
                root.releaseDigest();
        }
    }

    // Relative age, for every view that shows one. Reads Time.now rather than
    // Date.now(), so the binding reticks with the clock instead of going stale
    // at whatever "now" meant when the row was first drawn.
    function ago(t: date): string {
        const mins = Math.floor((Time.now - t) / 60000);
        if (mins < 1)
            return "now";
        if (mins < 60)
            return `${mins}m`;
        const hours = Math.floor(mins / 60);
        return hours < 24 ? `${hours}h` : `${Math.floor(hours / 24)}d`;
    }

    // Newest group first: the order the apps last spoke in, not alphabetical.
    function appsOf(entries: var): var {
        const seen = [];
        for (const entry of entries)
            if (!seen.includes(entry.group))
                seen.push(entry.group);
        return seen;
    }

    function urgentFirst(apps: var, groups: var): var {
        const urgent = app => (groups[app] ?? []).some(entry => entry.critical);
        return [...apps].sort((a, b) => (urgent(b) ? 1 : 0) - (urgent(a) ? 1 : 0));
    }

    function groupsOf(entries: var): var {
        const byApp = {};
        for (const entry of entries) {
            if (!byApp[entry.group])
                byApp[entry.group] = [];
            byApp[entry.group].push(entry);
        }
        return byApp;
    }

    // Everything one app has sent, gone at once -- the card is a single object
    // to the user, so its close button and its swipe have to be too.
    function dismissGroup(app: string): void {
        for (const entry of groups[app] ?? [])
            dismiss(entry);
        for (const entry of popupGroups[app] ?? [])
            entry.closing = true;
    }

    // Retires a group's popups without touching the history: what a timeout
    // and a swipe both mean. The card calls popupClosed() once it has animated.
    function closePopupGroup(app: string): void {
        for (const entry of popupGroups[app] ?? [])
            entry.closing = true;
    }

    // Never yank a popup off screen mid-frame; let it play its exit animation.
    // An urgent one that was let through quiet hours stays: turning them on
    // should not take down what they would have let in.
    onPopupsEnabledChanged: {
        if (!popupsEnabled)
            for (const entry of popups)
                if (!(entry.critical && Config.notifications.urgentBypassesFocus))
                    entry.closing = true;
    }

    // Drops an entry for good: it leaves the history and the app is told the
    // notification is closed. A popup still showing it animates away first.
    function dismiss(entry: Notif): void {
        entry.gone = true;
        list = list.filter(e => e !== entry);
        held = held.filter(e => e !== entry);
        entry.closing = true;
        release(entry);
    }

    // The app closed it (a call that ended, a download that finished) --
    // taken down everywhere, the way a dismissal is. Left up, its card
    // stayed until swiped away and its buttons did nothing: Quickshell
    // refuses to invoke a notification that has been closed.
    function withdrawn(entry: Notif): void {
        entry.gone = true;
        list = list.filter(e => e !== entry);
        held = held.filter(e => e !== entry);
        entry.closing = true;
        release(entry);
    }

    // The app sent new text in place of the old (`replaces_id`: a progress
    // update, `notify-send -r`, an edited message). The server updates the
    // notification where it is and announces nothing, so this is where it
    // is treated as the news it is: newest again, unread again, and back on
    // screen by the same rules as an arrival.
    signal refreshed(Notif entry)

    function replaced(entry: Notif): void {
        if (entry.gone)
            return;
        entry.time = new Date();
        if (list.includes(entry))
            list = [entry, ...list.filter(e => e !== entry)];
        if (popups.includes(entry) && !entry.closing) {
            popups = [entry, ...popups.filter(e => e !== entry)];
            root.refreshed(entry);
            return;
        }
        if (entry.notification?.transient && !popups.includes(entry))
            return;
        const bypass = entry.critical && Config.notifications.urgentBypassesFocus;
        if (root.holding && !bypass) {
            if (!held.includes(entry))
                held = [entry, ...held];
        } else if (root.popupsEnabled || bypass) {
            entry.closing = false;
            popups = [entry, ...popups.filter(e => e !== entry)];
        }
    }

    // Every monitor draws its own copy of a card, each with its own
    // countdown, and any of them timing out retires the group everywhere.
    // So a card being read on one monitor holds its app's cards on all of
    // them: { "<app>": how many copies are hovered or held }.
    property var paused: ({})

    function pause(app: string, on: bool): void {
        const next = Object.assign({}, root.paused);
        next[app] = Math.max(0, (next[app] ?? 0) + (on ? 1 : -1));
        root.paused = next;
    }

    function clear(): void {
        const all = [...list];
        list = [];
        held = [];
        digestDue = false;
        digestSince = new Date();
        for (const entry of all) {
            entry.gone = true;
            entry.closing = true;
            release(entry);
        }
    }

    // Called by a popup once its exit animation has finished.
    function popupClosed(entry: Notif): void {
        popups = popups.filter(e => e !== entry);
        release(entry);
    }

    // Lets go of an entry once nothing is drawing it any more. Destroying it
    // takes its RetainableLock with it, which is what finally frees the
    // notification.
    function release(entry: Notif): void {
        if (list.includes(entry) || popups.includes(entry) || held.includes(entry))
            return;

        // An already-retained notification was closed by its own app; telling
        // the bus again would be a second, bogus CloseNotification.
        entry.gone = true;
        if (!entry.lock.retained)
            entry.notification.dismiss();

        entry.destroy();
    }

    // One entry: a notification, plus the state vela keeps about it.
    component Notif: QtObject {
        id: entry

        required property Notification notification

        // Wall clock at arrival -- the server records only the expiry, not when
        // the notification came in, and the history list shows relative ages.
        // Moved on when the app replaces the text (`replaced`).
        property date time: new Date()

        // Set once the shell has let go of it, or its app has: from then on
        // its closing is the shell's own doing and not news.
        property bool gone: false

        // Summary and body both change in one replacement; one call for both.
        property bool replacing: false

        // The app closing it, or replacing its text, is news the server only
        // tells the notification itself.
        Component.onCompleted: {
            const n = entry.notification;
            if (!n)
                return;
            n.closed.connect(() => {
                if (!entry.gone)
                    root.withdrawn(entry);
            });
            n.summaryChanged.connect(entry.replacedLater);
            n.bodyChanged.connect(entry.replacedLater);
        }

        function replacedLater(): void {
            if (entry.replacing)
                return;
            entry.replacing = true;
            Qt.callLater(() => {
                entry.replacing = false;
                root.replaced(entry);
            });
        }

        // What the sending application asked for, in milliseconds: 0 means
        // "never expire on your own" -- a progress bar or a warning meant to
        // stay until acted on -- and -1 means "you decide". Without this a
        // popup retires everything on the shell's own timeout, which silently
        // throws away the one thing the app was explicit about.
        readonly property int expireTimeout: entry.notification?.expireTimeout ?? -1

        // Set when a popup showing this entry should animate away. The popup
        // calls popupClosed() once it has.
        property bool closing: false

        // Keeps `notification` readable after it is closed. Without it the
        // object dies the instant the app or the user closes it, and both the
        // history row and the exiting popup would blank out mid-animation.
        readonly property RetainableLock lock: RetainableLock {
            object: entry.notification
            locked: true
        }

        readonly property string appName: notification?.appName ?? ""
        readonly property string appIcon: notification?.appIcon ?? ""
        readonly property string image: notification?.image ?? ""
        readonly property string summary: notification?.summary ?? ""
        readonly property string body: notification?.body ?? ""
        readonly property bool resident: notification?.resident ?? false
        readonly property int urgency: notification?.urgency ?? NotificationUrgency.Normal
        readonly property bool critical: urgency === NotificationUrgency.Critical
        readonly property bool low: urgency === NotificationUrgency.Low

        // What the popup stack groups on. Apps that send no name at all would
        // otherwise all land in one nameless pile, so they stay separate.
        readonly property string group: (notification?.appName ?? "") || "Notification"

        // The freedesktop "default" action is the whole-card click target
        // rather than a button of its own.
        readonly property var actions: notification?.actions ?? []
        readonly property var defaultAction: actions.find(a => a.identifier === "default") ?? null
        readonly property var buttons: actions.filter(a => a.identifier !== "default")
        readonly property bool actionIcons: notification?.hasActionIcons ?? false
    }

    Component {
        id: notifComponent

        Notif {}
    }

    NotificationServer {
        keepOnReload: false
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true

        onNotification: n => {
            // The server discards anything not claimed before this returns.
            n.tracked = true;

            const entry = notifComponent.createObject(root, {
                notification: n
            });

            // Transient notifications are volume blips and progress bars:
            // worth a popup, never worth filing.
            if (!n.transient) {
                const kept = [entry, ...root.list];
                root.list = kept.slice(0, root.maxHistory);
                for (const evicted of kept.slice(root.maxHistory))
                    root.release(evicted);
            }

            // Focus mode and do not disturb. Urgent is the one thing that
            // still gets through either -- a battery about to die, a call --
            // and only because the config says so; turning
            // notifications.urgentBypassesFocus off means quiet really does
            // mean everything.
            const bypass = entry.critical && Config.notifications.urgentBypassesFocus;

            if (root.holding && !bypass && !n.transient) {
                root.held = [entry, ...root.held];
            } else if ((root.popupsEnabled || bypass) && (!root.holding || bypass)) {
                root.popups = [entry, ...root.popups];

                // A burst should leave the newest on screen rather than make
                // them queue behind four stale ones, so the oldest step aside.
                // The cap counts *cards*, which since grouping means apps: ten
                // messages from one chat are one card and evict nothing, while
                // a fifth app pushes the app that spoke longest ago off.
                const live = root.popups.filter(e => !e.closing);
                for (const app of root.appsOf(live).slice(root.maxVisible))
                    root.closePopupGroup(app);
            }

            // Suppressed and unfiled -- nothing will ever draw it.
            root.release(entry);
        }
    }

    // Reachable from Hyprland keybinds and the `vela` CLI:
    //   qs -c vela ipc call notifs toggleDnd
    IpcHandler {
        target: "notifs"

        function clear(): void {
            root.clear();
        }

        function dnd(enabled: bool): void {
            root.doNotDisturb = enabled;
        }

        function toggleDnd(): void {
            root.doNotDisturb = !root.doNotDisturb;
        }

        function digest(): void {
            root.releaseDigest();
        }

        function markAllRead(): void {
            root.markAllRead();
        }
    }
}
