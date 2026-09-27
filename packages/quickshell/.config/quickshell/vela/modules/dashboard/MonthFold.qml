pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.services
import qs.components

// Home's month: the card that folds out under the day, from the arrow on the
// day card, the date under the clock, a right-click on the bar clock or
// super + shift + D. It took over from the calendar window, which was a second
// place to read the same day.
//
// Picking a day is Home's business, not this card's: it says which day was
// picked (`picked`), and Home's day -- the timeline or the agenda -- follows,
// with this card's selection. The month shown is the picked day's, so the
// arrows pick the same day a month on.
//
// Top layout: the month on the left, the picked day's events beside it, and
// the calendars they come from underneath. Side layout: the month alone, with
// the calendars under it -- the agenda below the card already lists the day.
//
// The height is fixed per layout (`Appearance.dashboard.foldTop` and
// `foldSide`), and a month always draws six weeks: the drawer grows by a
// number known before anything is laid out, and never changes size between
// months.
Rectangle {
    id: root

    required property bool side
    required property date day
    required property date today
    // The event being written, or null (EventForm). When there is one it
    // takes the place of the day's list -- of the month, off a vertical bar.
    property var editor: null

    signal picked(date day)
    signal newRequested
    signal editRequested(var event)
    signal editorClosed
    signal dayStepped(int by)

    readonly property bool isToday: root.day.getTime() === root.today.getTime()
    readonly property date viewMonth: new Date(root.day.getFullYear(), root.day.getMonth(), 1)

    // The last month the grid showed, to tell which way a change of month
    // runs. Set by hand, never bound: a binding would already hold the new
    // month by the time the handler below compared the two.
    property date shownMonth
    Component.onCompleted: {
        root.shownMonth = root.viewMonth;
        root.ensureRange();
    }

    onViewMonthChanged: {
        root.ensureRange();
        if (root.viewMonth.getTime() === root.shownMonth.getTime())
            return;
        // Later months come in from the right, earlier ones from the left.
        // The direction first: the grid swaps the moment the key changes.
        root.monthDirection = root.viewMonth > root.shownMonth ? 1 : -1;
        root.shownMonth = root.viewMonth;
        root.monthKey = root.viewMonth.getTime();
    }

    property int monthDirection: 1
    property real monthKey: 0

    // The service's range follows today; a month further out has to ask for
    // more, or its days would have no dots and no events.
    function ensureRange(): void {
        if (!Calendar.available)
            return;
        const from = new Date(root.viewMonth.getFullYear(), root.viewMonth.getMonth(), -7);
        const to = new Date(root.viewMonth.getFullYear(), root.viewMonth.getMonth() + 1, 14);
        if (from.getTime() >= Calendar.rangeStart.getTime() && to.getTime() <= Calendar.rangeEnd.getTime())
            return;
        const lo = new Date(Math.min(from.getTime(), root.today.getTime() - 35 * 86400000));
        const hi = new Date(Math.max(to.getTime(), root.today.getTime() + 35 * 86400000));
        Calendar.load(lo, hi);
    }

    // The same day of the month, or the last one where the month is shorter:
    // setMonth alone rolls the 31st of October over into December.
    function monthOn(months: int): date {
        const d = new Date(root.day.getTime());
        const day = d.getDate();
        d.setDate(1);
        d.setMonth(d.getMonth() + months);
        const last = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
        d.setDate(Math.min(day, last));
        return d;
    }

    // ISO days carrying at least one event, for the grid's dots.
    readonly property var markedDays: {
        const out = [];
        if (!Calendar.available)
            return out;
        const events = Calendar.events;
        for (let i = 0; i < events.length; i++) {
            // An event may straddle midnight, so walk its span rather than
            // marking only the day it starts on.
            const d = new Date(events[i].start.getTime());
            d.setHours(0, 0, 0, 0);
            const end = events[i].end.getTime();
            while (d.getTime() < end) {
                const key = Qt.formatDateTime(d, "yyyy-MM-dd");
                if (out.indexOf(key) < 0)
                    out.push(key);
                d.setDate(d.getDate() + 1);
                // An unbounded event would otherwise walk forever.
                if (out.length > 400)
                    return out;
            }
        }
        return out;
    }

    // What is waiting, when anything is: written here, not yet on the
    // server.
    readonly property string waiting: Calendar.pending > 0 ? qsTr("%n waiting", "", Calendar.pending) : ""

    readonly property string syncLine: {
        if (!Calendar.available)
            return Calendar.reason || qsTr("No calendar yet");
        if (Calendar.syncing)
            return qsTr("Syncing…");
        // A server out of reach -- one at home, a laptop out -- is not a
        // failure, and does not read as one.
        if (Calendar.unreachable.length > 0)
            return root.waiting ? qsTr("%1 · can't reach %2").arg(root.waiting).arg(Calendar.unreachable[0]) : qsTr("Can't reach %1").arg(Calendar.unreachable[0]);
        if (Calendar.syncError)
            return qsTr("Sync failed: %1").arg(Calendar.syncError);
        if (Calendar.lastSync > 0)
            return [Calendar.syncedAgo(Calendar.lastSync), root.waiting].filter(t => t).join(" · ");
        return Calendar.syncLabel;
    }

    // ---- the picked day (top layout) -----------------------------------------

    readonly property var events: Calendar.available ? Calendar.eventsOn(root.day) : []
    // The first thing after the picked day, for a day with nothing on it.
    readonly property var after: {
        if (!Calendar.available || root.events.length > 0)
            return null;
        const end = new Date(root.day.getTime());
        end.setDate(end.getDate() + 1);
        return Calendar.events.find(e => e.start.getTime() >= end.getTime()) ?? null;
    }

    function hhmm(d: date): string {
        return Qt.formatDateTime(d, "hh:mm");
    }

    function duration(e: var): string {
        const m = Math.round((e.end.getTime() - e.start.getTime()) / 60000);
        return m >= 60 ? qsTr("%1 h").arg(+(m / 60).toFixed(1)) : qsTr("%1 min").arg(m);
    }

    function linkOf(e: var): string {
        const url = e.url || e.location || "";
        // Only a URL is joinable. khal's `location` is as often a room.
        return /^https?:\/\//.test(url) ? url : "";
    }

    radius: Appearance.dashboard.cardRadius
    color: Colours.surfaceContainer
    implicitHeight: root.side ? Appearance.dashboard.foldSide : Appearance.dashboard.foldTop

    component Chevron: Icon {
        id: chevron

        signal clicked

        size: Appearance.dashboard.foldChevron
        color: chevronMouse.containsMouse ? Colours.on.surface : Colours.outline

        MouseArea {
            id: chevronMouse

            anchors.fill: parent
            anchors.margins: -Appearance.dashboard.hitSlop
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chevron.clicked()
        }
    }

    // The month's name, the way back to today, and the arrows.
    component Header: RowLayout {
        spacing: Appearance.dashboard.foldHeaderGap

        Text {
            text: Qt.formatDateTime(root.viewMonth, "MMMM yyyy")
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.dashboard.foldMonth
            color: Colours.on.surface
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Pill {
            visible: !root.isToday
            text: qsTr("Today")
            tone: "subtle"
            pillHeight: Appearance.dashboard.foldPill
            onClicked: root.picked(root.today)
        }

        Chevron {
            text: "chevron_left"
            onClicked: root.picked(root.monthOn(-1))
        }

        Chevron {
            text: "chevron_right"
            onClicked: root.picked(root.monthOn(1))
        }
    }

    // A change of month slides the grid across rather than redrawing it.
    component Grid: Crossfade {
        vertical: false
        component: monthPage
        clip: true
        direction: root.monthDirection
        key: root.monthKey
    }

    component SyncLine: RowLayout {
        spacing: Appearance.dashboard.foldSyncGap

        Icon {
            text: !Calendar.available ? "event_busy" : Calendar.unreachable.length > 0 ? "cloud_off" : Calendar.syncError ? "sync_problem" : "sync"
            size: Appearance.dashboard.foldSyncIcon
            color: Colours.outline
        }

        Text {
            text: root.syncLine
            font.family: Appearance.font.mono
            font.pixelSize: Appearance.dashboard.foldCaption
            color: Colours.outline
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    // The calendars being shown and the colour their events carry: a legend,
    // so neutral pills with a dot, never the accent. As many as fit and a
    // count of the rest; the count, and the pencil after it, open Settings,
    // Calendars, where they are added, coloured and switched off. With none
    // at all, the one thing to do instead.
    //
    // (A RowLayout, not a Row: `Row` here is the settings row in
    // components/.)
    component Sources: RowLayout {
        id: legend

        readonly property var shown: Calendar.sources.filter(s => s.enabled)
        readonly property int room: root.side ? Appearance.dashboard.foldChipsSide : Appearance.dashboard.foldChipsTop

        spacing: Appearance.dashboard.foldChipGap
        clip: true

        Repeater {
            model: legend.shown.slice(0, legend.room)

            Pill {
                id: chip

                required property var modelData

                readonly property color dot: Calendar.colourOf(chip.modelData.role)

                text: chip.modelData.name
                tone: "subtle"
                interactive: false
                pillHeight: Appearance.dashboard.foldPill
                spacing: Appearance.calendar.chipGap
                color: chip.modelData.role === "outline" ? Colours.hover : Colours.alpha(chip.dot, 0.1)
                foreground: chip.modelData.role === "outline" ? Colours.outline : Colours.on.surfaceVariant

                leading: Rectangle {
                    implicitWidth: Appearance.calendar.chipDot
                    implicitHeight: Appearance.calendar.chipDot
                    radius: height / 2
                    color: chip.dot
                }
            }
        }

        Pill {
            visible: legend.shown.length > legend.room
            text: qsTr("+%1").arg(legend.shown.length - legend.room)
            tone: "subtle"
            pillHeight: Appearance.dashboard.foldPill
            onClicked: ShellState.openSettings("calendars")
        }

        Pill {
            visible: Calendar.sources.length === 0
            text: qsTr("Add a calendar")
            icon: "add"
            tone: "subtle"
            pillHeight: Appearance.dashboard.foldPill
            onClicked: ShellState.openSettings("calendars")
        }

        Item {
            Layout.fillWidth: true
        }

        Chevron {
            visible: Calendar.sources.length > 0
            text: "edit_calendar"
            onClicked: ShellState.openSettings("calendars")
        }
    }

    Component {
        id: monthPage

        MonthGrid {
            today: root.today
            selected: root.day
            markedDays: root.markedDays
            showWeekdays: true
            fixedWeeks: 6
            cellHeight: root.side ? Appearance.dashboard.foldCellSide : Appearance.dashboard.foldCell
            cellRadius: Appearance.dashboard.foldCellRadius
            daySize: Appearance.dashboard.foldDay
            weekdaySize: Appearance.dashboard.foldWeekday
            onDayActivated: d => root.picked(d)

            // Taken once, not bound: a grid on its way out keeps the month it
            // was showing while the next one comes in.
            Component.onCompleted: month = root.viewMonth
        }
    }

    Loader {
        anchors.fill: parent
        anchors.topMargin: Appearance.dashboard.foldPadV
        anchors.bottomMargin: Appearance.dashboard.foldPadV
        anchors.leftMargin: root.side ? Appearance.dashboard.foldPadHSide : Appearance.dashboard.foldPadH
        anchors.rightMargin: root.side ? Appearance.dashboard.foldPadHSide : Appearance.dashboard.foldPadH
        sourceComponent: root.side ? sideBody : topBody
    }

    // ---- top: the month, then the day beside it ------------------------------
    Component {
        id: topBody

        RowLayout {
            spacing: Appearance.dashboard.foldGap

            ColumnLayout {
                spacing: Appearance.dashboard.foldStack
                Layout.preferredWidth: Appearance.dashboard.foldMonthWidth
                Layout.fillWidth: false
                Layout.fillHeight: true

                Header {
                    Layout.fillWidth: true
                }

                Grid {
                    Layout.fillWidth: true
                }

                Item {
                    Layout.fillHeight: true
                }

                SyncLine {
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                implicitWidth: Appearance.widget.hairline
                color: Colours.alpha(Colours.on.surface, Appearance.dashboard.ruleAlpha)
                Layout.fillHeight: true
            }

            // The day's events, or the event being written.
            Crossfade {
                vertical: true
                component: root.editor ? formPage : dayPage
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    // ---- side: the month, with the calendars under it ------------------------
    Component {
        id: sideBody

        Crossfade {
            vertical: true
            component: root.editor ? formPage : sideMonth
        }
    }

    Component {
        id: sideMonth

        ColumnLayout {
            spacing: Appearance.dashboard.foldStack

            Header {
                Layout.fillWidth: true
            }

            Grid {
                Layout.fillWidth: true
            }

            Item {
                Layout.fillHeight: true
            }

            SyncLine {
                Layout.fillWidth: true
            }

            Sources {
                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.dashboard.foldPill
            }
        }
    }

    Component {
        id: dayPage

        ColumnLayout {
            spacing: Appearance.dashboard.foldStack
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.dashboard.foldPill

                SectionLabel {
                    text: root.isToday ? qsTr("Today") : Qt.formatDateTime(root.day, "dddd d MMMM")
                    font.pixelSize: Appearance.dashboard.sectionLabel
                    Layout.fillWidth: true
                }

                Text {
                    visible: Calendar.available && root.events.length > 0
                    text: root.events.length === 1 ? qsTr("1 event") : qsTr("%1 events").arg(root.events.length)
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.dashboard.eventLabel
                    color: Colours.outline
                }

                // A new event on this day, in a calendar that takes one.
                Chevron {
                    visible: Calendar.writable.length > 0
                    text: "add"
                    Layout.leftMargin: Appearance.dashboard.stackGap
                    onClicked: root.newRequested()
                }
            }

            // The day's events, as many as fit, and a count of the rest.
            Item {
                id: list

                readonly property int step: Appearance.dashboard.foldRow + Appearance.dashboard.foldRowGap
                readonly property int capacity: Math.max(1, Math.floor((list.height + Appearance.dashboard.foldRowGap) / list.step))
                readonly property int shown: root.events.length > list.capacity ? list.capacity - 1 : root.events.length

                clip: true
                Layout.fillWidth: true
                Layout.fillHeight: true

                Column {
                    width: parent.width
                    spacing: Appearance.dashboard.foldRowGap

                    Repeater {
                        model: root.events.slice(0, list.shown)

                        // An event that can be changed here opens in the
                        // form when clicked; one that cannot says why with
                        // a glyph -- a lock for a read-only calendar, arrows
                        // for a repeating series -- once there is anything
                        // writable to compare it with.
                        Item {
                            id: entry

                            required property var modelData

                            readonly property bool past: entry.modelData.end.getTime() <= Time.now.getTime()
                            readonly property string link: root.linkOf(entry.modelData)
                            readonly property bool writable: Calendar.isWritable(entry.modelData)

                            width: parent.width
                            height: Appearance.dashboard.foldRow

                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: -Appearance.dashboard.formRowBleed
                                anchors.rightMargin: -Appearance.dashboard.formRowBleed
                                radius: Appearance.dashboard.agendaRowRadius
                                color: Colours.hover
                                visible: entry.writable && rowMouse.containsMouse
                            }

                            MouseArea {
                                id: rowMouse

                                anchors.fill: parent
                                enabled: entry.writable
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.editRequested(entry.modelData)
                            }

                            RowLayout {
                                anchors.fill: parent
                                spacing: Appearance.dashboard.agendaCols

                                Rectangle {
                                    implicitWidth: Appearance.calendar.spineWidth
                                    radius: Appearance.calendar.spineRadius
                                    color: entry.past ? Colours.outlineVariant : Calendar.colourOf(entry.modelData.role)
                                    Layout.fillHeight: true
                                    Layout.topMargin: Appearance.dashboard.foldSpineInset
                                    Layout.bottomMargin: Appearance.dashboard.foldSpineInset
                                }

                                Text {
                                    text: entry.modelData.allDay ? qsTr("all day") : root.hhmm(entry.modelData.start)
                                    font.family: Appearance.font.mono
                                    font.pixelSize: Appearance.dashboard.eventLabel
                                    color: Colours.outline
                                    Layout.preferredWidth: Appearance.dashboard.agendaTime
                                }

                                Text {
                                    text: entry.modelData.title
                                    font.family: Appearance.font.ui
                                    font.pixelSize: Appearance.dashboard.agendaTitle
                                    color: entry.past ? Colours.outline : Colours.on.surface
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: !entry.link && !entry.modelData.allDay
                                    text: root.duration(entry.modelData)
                                    font.family: Appearance.font.mono
                                    font.pixelSize: Appearance.dashboard.eventLabel
                                    color: Colours.outline
                                }

                                Icon {
                                    visible: !entry.writable && Calendar.writable.length > 0
                                    text: entry.modelData.recurring && Calendar.writableFor(entry.modelData.source) ? "repeat" : "lock"
                                    size: Appearance.dashboard.formLock
                                    color: Colours.outlineVariant
                                }

                                Pill {
                                    visible: entry.link !== ""
                                    text: qsTr("Join")
                                    icon: "videocam"
                                    tone: entry.past ? "subtle" : "filled"
                                    pillHeight: Appearance.dashboard.foldPill
                                    onClicked: Files.openUrl(entry.link)
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.events.length > list.shown
                        text: qsTr("+%n more", "", root.events.length - list.shown)
                        font.family: Appearance.font.mono
                        font.pixelSize: Appearance.dashboard.foldCaption
                        color: Colours.outline
                    }
                }

                // Nothing on the day, or no calendar at all: says which, and
                // for an empty day, what comes next.
                ColumnLayout {
                    visible: root.events.length === 0
                    width: parent.width
                    spacing: Appearance.dashboard.subGap

                    Text {
                        text: Calendar.available ? (root.isToday ? qsTr("Nothing on today.") : qsTr("Nothing on this day.")) : qsTr("No calendar yet. Add Google, Outlook, iCloud or any other in Settings, Calendars.")
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.dashboard.smallText
                        color: Colours.on.surfaceVariant
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: root.after !== null
                        text: root.after ? qsTr("Next: %1 · %2").arg(root.after.title).arg(Qt.formatDateTime(root.after.start, "ddd d MMM")) : ""
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.dashboard.smallText
                        color: Colours.outline
                        elide: Text.ElideRight
                        Layout.fillWidth: true

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const d = new Date(root.after.start.getTime());
                                d.setHours(0, 0, 0, 0);
                                root.picked(d);
                            }
                        }
                    }
                }
            }

            Sources {
                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.dashboard.foldPill
            }
        }
    }

    Component {
        id: formPage

        EventForm {
            editor: root.editor
            day: root.day
            onClosed: root.editorClosed()
            onDayMoved: by => root.dayStepped(by)
        }
    }
}
