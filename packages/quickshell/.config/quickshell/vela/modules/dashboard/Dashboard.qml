pragma ComponentBehavior: Bound

import QtQuick
import qs.tokens
import qs.config
import qs.services
import qs.components
import qs.modules.attached

// The dashboard -- a drawer that grows out of the bar's inner edge, opened from
// the bar clock or `super + D`.
//
// ONE DRAWER, EVERY EDGE. Everything that differs between a top, bottom, left
// and right bar is worked out from `Config.bar.position` -- which way the
// drawer grows, which corners round and where the two fillets sit, in
// AttachedDrawer. The tabs get one flag, `side`, and reflow themselves; there
// is no file per orientation. Changing the position in shell.json re-lays the
// drawer live, because every one of those is a binding.
//
// ATTACHED, NOT FLOATING. The drawer starts exactly at the bar's inner edge and
// meets it on two concave 28px fillets; while it is out, the bar paints the
// same opaque `surfaceBarAttached` with no border (BarState.attached), so the
// two read as one shape. The drawer itself -- growing, fillets, shadow, the
// bar going solid -- is `AttachedDrawer`, which the popouts, the launcher and
// the power menu hang from too; this file is what goes in it.
//
// Drawn in each monitor's shell window (modules/shell/Shell.qml), with the bar
// it hangs from; the one on `ShellState.drawerScreen` is the one that opens.
// The window does click-away, and hands this the keyboard while it is shown.
Item {
    id: root

    // The monitor whose shell window this is in, and the BarState of its
    // bar, whose colour the drawer takes.
    required property string screenName
    required property var bar

    readonly property bool shown: ShellState.dashboard && ShellState.drawerScreen === root.screenName
    readonly property bool live: drawer.live

    readonly property string edge: Config.bar.position
    readonly property bool side: Config.bar.vertical

    readonly property var tabs: [
        {
            key: "home",
            label: qsTr("Home"),
            icon: "home"
        },
        {
            key: "media",
            label: qsTr("Media"),
            icon: "graphic_eq"
        },
        {
            key: "system",
            label: qsTr("System"),
            icon: "monitoring"
        },
        {
            key: "focus",
            label: qsTr("Focus"),
            icon: "timer"
        }
    ]
    property int tabIndex: 0
    readonly property string tab: root.tabs[root.tabIndex].key

    // Home's month (MonthFold): out or not, and the day picked in it, which
    // Home's day follows. Kept here rather than on the page, so a trip to
    // another tab and back finds it as it was; both go back once the drawer
    // has gone, with the tab.
    property bool monthOpen: false
    readonly property date today: new Date(`${Time.iso}T00:00:00`)
    property date day: root.today
    readonly property bool monthShown: root.shown && root.tab === "home" && root.monthOpen

    // The event being written in the month (EventForm), or null: { uid ("" for
    // a new one), title, path, allDay, start, end ("hh:mm"), span (days it
    // runs past its first), location }. Its day is `day`.
    property var editor: null

    // Home with the month out: taller by the month and the gap before it,
    // but never longer than the bar leaves room for -- off a vertical bar
    // the drawer keeps clear of the bar's rounded ends, and a short screen
    // takes the difference out of the agenda.
    readonly property int homeHeight: (root.side ? Appearance.dashboard.heightsSide : Appearance.dashboard.heightsTop).home
    readonly property int homeOpenHeight: {
        const wanted = root.homeHeight + (root.side ? Appearance.dashboard.foldSide + Appearance.dashboard.gapHomeSide : Appearance.dashboard.foldTop + Appearance.dashboard.gapHome + Appearance.dashboard.foldTail);
        if (root.height <= 0)
            return wanted;
        const ends = Config.bar.floating ? Config.bar.margin : 0;
        const along = root.side ? root.height - 2 * (ends + Appearance.radius.barV + Appearance.dashboard.fillet) : root.height - Config.bar.footprint - Appearance.space.overlayMargin;
        return Math.max(root.homeHeight, Math.min(wanted, along - Appearance.dashboard.stripHeight));
    }

    // System with the AI tools' cards under it: taller by them, worked out
    // with the cards' own formula (`AiCards.qml`) since they size nothing
    // until they exist. Side by side off a horizontal bar, stacked off a
    // vertical one.
    readonly property int aiHeight: {
        const tools = AiUsage.tools;
        if (tools.length === 0)
            return 0;
        const d = Appearance.dashboard;
        const inner = root.side ? d.widthSide - 2 * d.padSide : d.widthTop - 2 * d.padTop;
        const pair = !root.side && tools.length > 1;
        const width = pair ? (inner - d.gap) / 2 : inner;
        const stacked = d.aiStacked(tools, width);
        const rows = t => d.aiRows(t, width, stacked);
        if (pair)
            return d.gap + d.aiCardHeight(Math.max(...tools.map(rows)), stacked);
        return tools.reduce((sum, t) => sum + d.gap + d.aiCardHeight(rows(t), stacked), 0);
    }

    readonly property int contentHeight: root.tab === "home" && root.monthOpen ? root.homeOpenHeight : (root.side ? Appearance.dashboard.heightsSide : Appearance.dashboard.heightsTop)[root.tab] + (root.tab === "system" ? root.aiHeight : 0)
    readonly property int pageWidth: root.side ? Appearance.dashboard.widthSide : Appearance.dashboard.widthTop
    readonly property int pageHeight: Appearance.dashboard.stripHeight + root.contentHeight

    visible: root.live

    onShownChanged: {
        if (!root.shown)
            return;
        ShellState.dashboardTab = root.tab;
        // Worked out here rather than read from `monthShown`, whose binding
        // may not have heard about `shown` yet.
        const onMonth = root.tab === "home" && root.monthOpen;
        ShellState.dashboardMonth = onMonth;
        // Opened on the month, the arrows are the month's (`takeKeys`).
        if (onMonth)
            page.forceActiveFocus();
        else
            keys.forceActiveFocus();
        // On open the content travels the way the drawer grows: up into a
        // top drawer as the design draws it, and away from a vertical bar.
        content.direction = root.edge === "right" ? 1 : root.side ? -1 : 1;
        content.enter();
    }

    onTabChanged: if (root.shown)
        ShellState.dashboardTab = root.tab
    onMonthShownChanged: if (root.shown)
        ShellState.dashboardMonth = root.monthShown

    // Back to Home once the drawer has gone, so the clock and super + D
    // always open on it, with the month folded away and on today. Changed
    // while nothing is on screen, so nothing is seen crossing over. A bar
    // item asks for its own tab before the drawer opens, so the media chip
    // and cpu/ram still open on theirs, and the calendar on the month.
    onLiveChanged: {
        if (root.live)
            return;
        root.tabIndex = 0;
        root.monthOpen = false;
        root.editor = null;
        root.day = Qt.binding(() => root.today);
    }

    function hhmm(minutes: int): string {
        return `${String(Math.floor(minutes / 60)).padStart(2, "0")}:${String(minutes % 60).padStart(2, "0")}`;
    }

    // A new event on the picked day: the next hour if that is today, nine
    // otherwise, for an hour, in the calendar new events go to.
    function newEvent(): void {
        const w = Calendar.defaultWritable;
        if (!w)
            return;
        const n = Time.now;
        const start = root.day.getTime() === root.today.getTime() ? Math.min(23 * 60, (n.getHours() + 1) * 60) : 9 * 60;
        root.editor = {
            uid: "",
            title: "",
            path: w.path,
            allDay: false,
            start: root.hhmm(start),
            end: root.hhmm(Math.min(23 * 60 + 59, start + 60)),
            span: 0,
            location: ""
        };
        root.monthOpen = true;
    }

    // One of the day's events, on the day it starts.
    function editEvent(e: var): void {
        const w = Calendar.writableFor(e.source);
        if (!w || e.recurring)
            return;
        const first = new Date(e.start.getTime());
        first.setHours(0, 0, 0, 0);
        // All-day ends are the midnight after; a timed one ends on the day
        // of its last minute.
        const last = new Date(e.allDay ? e.end.getTime() - 86400000 : e.end.getTime() - 1);
        last.setHours(0, 0, 0, 0);
        root.pick(first);
        root.editor = {
            uid: e.uid,
            title: e.title,
            path: w.path,
            allDay: e.allDay,
            start: Qt.formatDateTime(e.start, "hh:mm"),
            end: Qt.formatDateTime(e.end, "hh:mm"),
            span: Math.max(0, Math.round((last.getTime() - first.getTime()) / 86400000)),
            location: e.location ?? ""
        };
        root.monthOpen = true;
    }

    function closeEditor(): void {
        root.editor = null;
        root.takeKeys();
    }

    function toggleMonth(): void {
        root.monthOpen = !root.monthOpen;
        if (!root.monthOpen)
            root.editor = null;
        // Folding it away is done looking: the day goes back to today.
        if (!root.monthOpen)
            root.day = Qt.binding(() => root.today);
        root.takeKeys();
    }

    // The keys back from the tab strip, which keeps them once a tab has been
    // clicked, so the arrows move the month's day rather than the tab. To the
    // page, not the scope: the scope would hand them straight back to the
    // strip, its last focused child, while the page passes every key up to
    // the handler below.
    function takeKeys(): void {
        if (root.shown)
            page.forceActiveFocus();
    }

    function pick(d: date): void {
        root.takeKeys();
        const next = new Date(d.getTime());
        next.setHours(0, 0, 0, 0);
        if (next.getTime() === root.today.getTime())
            root.day = Qt.binding(() => root.today);
        else
            root.day = next;
    }

    function moveDays(days: int): void {
        const d = new Date(root.day.getTime());
        d.setDate(d.getDate() + days);
        root.pick(d);
    }

    // The same day of the month, or the last one where the month is shorter.
    function moveMonths(months: int): void {
        const d = new Date(root.day.getTime());
        const day = d.getDate();
        d.setDate(1);
        d.setMonth(d.getMonth() + months);
        d.setDate(Math.min(day, new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()));
        root.pick(d);
    }

    // The month's keys, while it is out on Home: the arrows move the day,
    // Page Up and Page Down the month, Home or T go back to today.
    function monthKey(key: int): bool {
        if (root.tab !== "home" || !root.monthOpen)
            return false;
        switch (key) {
        case Qt.Key_Left:
            root.moveDays(-1);
            return true;
        case Qt.Key_Right:
            root.moveDays(1);
            return true;
        case Qt.Key_Up:
            root.moveDays(-7);
            return true;
        case Qt.Key_Down:
            root.moveDays(7);
            return true;
        case Qt.Key_PageUp:
            root.moveMonths(-1);
            return true;
        case Qt.Key_PageDown:
            root.moveMonths(1);
            return true;
        case Qt.Key_Home:
        case Qt.Key_T:
            root.pick(root.today);
            return true;
        }
        return false;
    }

    // A bar item asking for its tab -- the media chip, cpu/ram. Answered by
    // the dashboard on that bar's monitor, open or not: asked before it
    // opens, it opens on the tab.
    Connections {
        target: ShellState

        function onDashboardTabAsked(tab: string, screen: string): void {
            if (screen !== root.screenName)
                return;
            const at = root.tabs.findIndex(t => t.key === tab);
            if (at >= 0)
                root.select(at);
        }

        // The calendar -- a right-click on the bar clock, super + shift + D:
        // Home, with the month out.
        function onCalendarAsked(screen: string): void {
            if (screen !== root.screenName)
                return;
            root.select(0);
            root.monthOpen = true;
            root.takeKeys();
        }
    }

    function select(index: int): void {
        const next = Math.max(0, Math.min(root.tabs.length - 1, index));
        if (next === root.tabIndex)
            return;
        // A side drawer's content slides the way the pill does -- the next
        // tab in from the right, the previous from the left. A top drawer's
        // rises either way.
        content.direction = root.side && next < root.tabIndex ? -1 : 1;
        root.tabIndex = next;
    }

    FocusScope {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                // A form open puts the form away first.
                if (root.editor !== null)
                    root.closeEditor();
                else
                    ShellState.close("dashboard");
            } else if (root.editor !== null && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab || event.key === Qt.Key_C || (event.key >= Qt.Key_1 && event.key <= Qt.Key_9))) {
                // Nothing leaves the form by accident: not the tabs, not
                // folding the month away under it.
            } else if (root.monthKey(event.key)) {
                // Moved the day or the month.
            } else if (root.tab === "home" && event.key === Qt.Key_C) {
                root.toggleMonth();
            } else if (event.key === Qt.Key_Tab) {
                root.select((root.tabIndex + 1) % root.tabs.length);
            } else if (event.key === Qt.Key_Backtab) {
                root.select((root.tabIndex + root.tabs.length - 1) % root.tabs.length);
            } else if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + root.tabs.length) {
                root.select(event.key - Qt.Key_1);
            } else {
                return;
            }
            event.accepted = true;
        }

        AttachedDrawer {
            id: drawer

            anchors.fill: parent
            key: "dashboard"
            screenName: root.screenName
            bar: root.bar
            open: root.shown
            radius: Appearance.dashboard.radius
            contentWidth: root.pageWidth
            contentHeight: root.pageHeight

            // The page: the strip, then the tab.
            Item {
                id: page

                anchors.fill: parent

                // ---- tab strip --------------------------------------------
                Item {
                    id: strip

                    width: parent.width
                    height: Appearance.dashboard.stripHeight

                    Segmented {
                        // Re-asserted, not only bound: a click on a tab
                        // writes the strip's own index, which undoes a
                        // plain binding, and every tab change after that
                        // -- the Tab key, the media chip, cpu/ram -- moved
                        // the page and left the pill where it was.
                        readonly property int wanted: root.tabIndex

                        anchors.centerIn: parent
                        sliding: true
                        model: root.tabs
                        currentIndex: wanted
                        onWantedChanged: currentIndex = wanted
                        segmentWidth: root.side ? Appearance.dashboard.tabWidthSide : Appearance.dashboard.tabWidthTop
                        segmentHeight: Appearance.dashboard.tabHeight
                        inset: Appearance.dashboard.tabInset
                        railRadius: Appearance.dashboard.tabRailRadius
                        fontSize: root.side ? Appearance.dashboard.tabLabelSide : Appearance.dashboard.tabLabelTop
                        iconSize: root.side ? Appearance.dashboard.tabIconSide : Appearance.dashboard.tabIconTop
                        slideDuration: Appearance.dashboard.pill
                        slideCurve: Appearance.dashboard.curve

                        onSelected: index => root.select(index)
                    }
                }

                // ---- the tab ----------------------------------------------
                //
                // A tab's content rises in (top) or slides in (side) and fades
                // up whenever it is shown, and the one it replaces fades out
                // the opposite way rather than vanishing.
                Crossfade {
                    id: content

                    y: strip.height
                    width: parent.width
                    height: root.contentHeight
                    vertical: !root.side
                    distance: root.side ? Appearance.dashboard.slide : Appearance.dashboard.rise

                    component: root.tab === "home" ? homeTab : root.tab === "media" ? mediaTab : root.tab === "system" ? systemTab : focusTab
                }
            }
        }
    }

    Component {
        id: homeTab

        HomeTab {
            side: root.side
            monthOpen: root.monthOpen
            day: root.day
            today: root.today
            openHeight: root.homeOpenHeight
            editor: root.editor
            onMonthToggled: root.toggleMonth()
            onDayPicked: d => root.pick(d)
            onNewRequested: root.newEvent()
            onEditRequested: e => root.editEvent(e)
            onEditorClosed: root.closeEditor()
            onDayStepped: by => root.moveDays(by)
        }
    }

    Component {
        id: mediaTab

        MediaTab {
            side: root.side
            live: root.shown
        }
    }

    Component {
        id: systemTab

        SystemTab {
            side: root.side
            live: root.shown
        }
    }

    Component {
        id: focusTab

        FocusTab {
            side: root.side
        }
    }
}
