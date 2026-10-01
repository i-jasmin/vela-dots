pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.services
import qs.components

// Home: the time, the weather, and the day. Nothing here is on another tab.
//
// Top layout: the clock and the weather side by side, then the day as a
// horizontal timeline from 08 to 22 with a now-line that moves.
// Side layout: the clock, a weather card, and the day as a vertical agenda
// with a "Now" row at the current time and the next event called out.
//
// The month folds out under the day (MonthFold) from the arrow on the day's
// card or the date under the clock, and the drawer grows to take it. The day
// is today until another is picked there; then the timeline or the agenda
// shows that day instead, and says which.
Item {
    id: root

    required property bool side
    // The dashboard's, so they outlive this page: switching tabs and back
    // keeps the month open on the day it was on.
    required property bool monthOpen
    required property date day
    required property date today
    // The page's height with the month out, from the dashboard.
    required property real openHeight
    // The event being written in the month, or null (Dashboard's `editor`).
    required property var editor
    // From the moment the dashboard is asked for until it has fully gone
    // (Dashboard's `live`).
    required property bool live

    signal monthToggled
    signal dayPicked(date day)
    signal newRequested
    signal editRequested(var event)
    signal editorClosed
    signal dayStepped(int by)

    // The clock only while the dashboard is up. This page stays built behind
    // a closed dashboard, and the seconds and the now line changing in it
    // still had the window draw a frame -- once a second, all session long,
    // with nothing new on screen. Hidden, it rests at midnight.
    readonly property date now: root.live ? Time.now : root.today

    readonly property bool isToday: root.day.getTime() === root.today.getTime()
    readonly property date dayEnd: {
        const d = new Date(root.day.getTime());
        d.setDate(d.getDate() + 1);
        return d;
    }
    readonly property var dayEvents: root.isToday ? Calendar.todayEvents : Calendar.eventsOn(root.day)

    // The day's timed events; all-day ones have no place on a timeline.
    readonly property var timed: root.dayEvents.filter(e => !e.allDay)
    readonly property var allDay: root.dayEvents.filter(e => e.allDay)
    // Only today has a next thing, or a now.
    readonly property var next: root.isToday ? root.timed.find(e => e.start.getTime() > root.now.getTime()) ?? null : null
    readonly property string dayLabel: root.isToday ? qsTr("Today") : Qt.formatDateTime(root.day, "dddd d MMMM")

    // The month stays laid out until it has faded, so what is under it does
    // not jump while the drawer closes over it.
    readonly property bool foldHeld: root.monthOpen || foldIn.opacity > 0

    Reveal {
        id: foldIn

        shown: root.monthOpen
    }

    function hourOf(d: date): real {
        // An event running into the day before or the day after is cut at
        // this day's midnight.
        if (d.getTime() <= root.day.getTime())
            return 0;
        if (d.getTime() >= root.dayEnd.getTime())
            return 24;
        return d.getHours() + d.getMinutes() / 60;
    }

    function hhmm(d: date): string {
        return Qt.formatDateTime(d, "hh:mm");
    }

    function until(e: var): string {
        const m = Math.max(0, Math.round((e.start.getTime() - root.now.getTime()) / 60000));
        return m >= 60 ? qsTr("%1h %2m").arg(Math.floor(m / 60)).arg(m % 60) : qsTr("%1m").arg(m);
    }

    function duration(e: var): string {
        const m = Math.round((e.end.getTime() - e.start.getTime()) / 60000);
        return m >= 60 ? qsTr("%1 h").arg(+(m / 60).toFixed(1)) : qsTr("%1 min").arg(m);
    }

    readonly property string weatherLine: {
        if (!Weather.available)
            return Weather.error || qsTr("Weather unavailable");
        const bits = [Weather.description];
        if (Weather.outlook)
            bits.push(Weather.outlook);
        return bits.filter(b => b).join(" · ");
    }

    readonly property string dayNote: {
        if (!Calendar.available)
            return Calendar.reason;
        if (root.next)
            return qsTr("%1 in %2").arg(root.next.title).arg(root.until(root.next));
        if (root.isToday)
            return qsTr("Nothing else today");
        if (root.dayEvents.length === 0)
            return qsTr("Nothing on");
        return root.dayEvents.length === 1 ? qsTr("1 event") : qsTr("%1 events").arg(root.dayEvents.length);
    }

    // ---- shared pieces -----------------------------------------------------

    component ClockBlock: ColumnLayout {
        id: clockBlock

        property real size: Appearance.dashboard.clockTop
        property real secondsSize: Appearance.dashboard.secondsTop

        spacing: Appearance.dashboard.stackGap

        Text {
            text: Time.salutation
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.dashboard.greeting
            color: Colours.outline
        }

        RowLayout {
            spacing: Appearance.dashboard.clockGap

            Text {
                text: Time.time
                font.family: Appearance.font.mono
                font.pixelSize: clockBlock.size
                font.weight: Font.ExtraLight
                font.letterSpacing: clockBlock.size * Appearance.dashboard.clockTracking
                color: Colours.on.surface
                Layout.alignment: Qt.AlignBaseline
            }

            Text {
                // Not ticking behind a closed dashboard: see `now`.
                text: root.live ? Time.second : ""
                font.family: Appearance.font.mono
                font.pixelSize: clockBlock.secondsSize
                color: Colours.primary
                Layout.preferredWidth: Appearance.dashboard.secondsWidth
                Layout.alignment: Qt.AlignBaseline
            }
        }

        // The date folds the month out, as the arrow on the day card does.
        Text {
            text: Time.date
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.dashboard.dateLine
            color: dateMouse.containsMouse || root.monthOpen ? Colours.primary : Colours.on.surfaceVariant

            MouseArea {
                id: dateMouse

                anchors.fill: parent
                anchors.margins: -Appearance.dashboard.hitSlop
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.monthToggled()
            }
        }
    }

    // The arrow that folds the month out: down while it is away, up while it
    // is out, as the bar's own arrow turns.
    component FoldArrow: Icon {
        text: "expand_circle_down"
        size: Appearance.dashboard.foldArrow
        color: arrowMouse.containsMouse ? Colours.on.surface : root.monthOpen ? Colours.primary : Colours.outline
        rotation: root.monthOpen ? 180 : 0
        // Takes no height in its row: the glyph is taller than the text
        // beside it, and would make the day card taller than it has always
        // been. It is drawn centred on the row all the same.
        Layout.preferredHeight: 0

        Behavior on rotation {
            NumberAnimation {
                duration: Appearance.dashboard.foldTurn
                easing.type: Appearance.anim.enterEasing
            }
        }

        MouseArea {
            id: arrowMouse

            anchors.centerIn: parent
            width: parent.width + Appearance.dashboard.hitSlop * 2
            height: Appearance.dashboard.foldArrow + Appearance.dashboard.hitSlop * 2
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.monthToggled()
        }
    }

    // The month itself, fading up as the drawer grows round it and out before
    // the drawer closes over it.
    component Fold: MonthFold {
        side: root.side
        day: root.day
        today: root.today
        editor: root.editor
        onNewRequested: root.newRequested()
        onEditRequested: e => root.editRequested(e)
        onEditorClosed: root.editorClosed()
        onDayStepped: by => root.dayStepped(by)
        visible: root.foldHeld
        opacity: foldIn.opacity
        transform: Translate {
            y: foldIn.offset
        }
        onPicked: d => root.dayPicked(d)
    }

    component HourStrip: RowLayout {
        spacing: Appearance.dashboard.hourGap

        Repeater {
            model: Weather.nextHours

            ColumnLayout {
                id: hour

                required property var modelData

                spacing: Appearance.dashboard.stackGap

                Text {
                    text: hour.modelData.time
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.dashboard.hourLabel
                    color: Colours.outline
                    Layout.alignment: Qt.AlignHCenter
                }

                Icon {
                    text: hour.modelData.icon
                    size: Appearance.dashboard.hourIcon
                    color: Colours.on.surfaceVariant
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: hour.modelData.temp
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.dashboard.hourValue
                    color: Colours.on.surface
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }

    // ---- top: clock and weather, then the timeline ---------------------------
    Component {
        id: topLayout

        // The clock and the day keep the height they always had, and the
        // month hangs below them, so folding it out moves nothing above it.
        Item {
            ColumnLayout {
                id: upper

                width: parent.width
                height: (Appearance.dashboard.heightsTop.home) - Appearance.dashboard.pageTopGap
                spacing: Appearance.dashboard.gapHome

                RowLayout {
                    spacing: Appearance.dashboard.homeRowGap
                    Layout.fillWidth: true

                    ClockBlock {
                        Layout.alignment: Qt.AlignBottom
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: Appearance.dashboard.weatherGap
                        Layout.alignment: Qt.AlignBottom

                        RowLayout {
                            spacing: Appearance.dashboard.weatherIconGap

                            Icon {
                                text: Weather.available ? Weather.icon : "cloud_off"
                                size: Appearance.dashboard.weatherIconTop
                                color: Colours.secondary
                            }

                            ColumnLayout {
                                spacing: Appearance.dashboard.tempNoteGap

                                Text {
                                    visible: Weather.available
                                    text: Weather.formatTemp(Weather.tempC)
                                    font.family: Appearance.font.ui
                                    font.pixelSize: Appearance.dashboard.tempTop
                                    font.weight: Font.Light
                                    color: Colours.on.surface
                                }

                                Text {
                                    text: root.weatherLine
                                    font.family: Appearance.font.ui
                                    font.pixelSize: Appearance.dashboard.weatherNote
                                    color: Colours.outline
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: Appearance.dashboard.weatherNoteMax
                                }
                            }
                        }

                        Rectangle {
                            visible: Weather.nextHours.length > 0
                            implicitWidth: Appearance.widget.hairline
                            implicitHeight: Appearance.dashboard.weatherRule
                            color: Colours.alpha(Colours.on.surface, Appearance.dashboard.ruleAlpha)
                        }

                        HourStrip {}
                    }
                }

                // The day, 08-22.
                Rectangle {
                    id: dayCard

                    radius: Appearance.dashboard.cardRadius
                    color: Colours.surfaceContainer
                    implicitHeight: timeline.implicitHeight + Appearance.dashboard.timelinePadV + Appearance.dashboard.timelinePadBottom
                    Layout.fillWidth: true

                    ColumnLayout {
                        id: timeline

                        // The window the line covers, in real time, so it can
                        // run past midnight.
                        //
                        // Today it rolls: the last few hours and the next
                        // several, around now -- what happened at six is no
                        // use at eleven at night, and the month is there for
                        // more. It moves on the hour, not by the minute, so it
                        // does not creep while it is looked at; the now-line
                        // moves within it. Late in the evening it reaches
                        // into tomorrow, and tomorrow's events are on it.
                        //
                        // Another day, picked in the month, shows that day:
                        // 08:00 to 22:00, stretched to take in any event
                        // outside it.
                        readonly property real hourMs: 3600000
                        readonly property real wantStart: {
                            if (root.isToday) {
                                const h = new Date(root.now.getTime());
                                h.setMinutes(0, 0, 0);
                                return h.getTime() - Appearance.dashboard.timelineBefore * timeline.hourMs;
                            }
                            let h = Appearance.dashboard.timelineStart;
                            for (const e of root.timed)
                                h = Math.min(h, root.hourOf(e.start));
                            return root.day.getTime() + Math.max(0, Math.floor(h / 2) * 2) * timeline.hourMs;
                        }
                        readonly property real wantEnd: {
                            if (root.isToday)
                                return timeline.wantStart + Appearance.dashboard.timelineSpan * timeline.hourMs;
                            let h = Appearance.dashboard.timelineEnd;
                            for (const e of root.timed)
                                h = Math.max(h, root.hourOf(e.end));
                            return root.day.getTime() + Math.min(24, Math.ceil(h / 2) * 2) * timeline.hourMs;
                        }
                        // Eased, so the hour turning over, or another day
                        // picked, slides the blocks along rather than jumping.
                        property real start: wantStart
                        property real end: wantEnd

                        Behavior on start {
                            Morph {}
                        }

                        Behavior on end {
                            Morph {}
                        }

                        // What is on the line: today, anything timed that
                        // overlaps the window, yesterday's and tomorrow's
                        // included; another day, that day's.
                        readonly property var blocks: root.isToday ? Calendar.events.filter(e => !e.allDay && e.end.getTime() > timeline.wantStart && e.start.getTime() < timeline.wantEnd) : root.timed

                        // Labels every two hours, or three or four once the
                        // window is too wide for two, from its first hour.
                        readonly property int step: {
                            const hours = (timeline.wantEnd - timeline.wantStart) / timeline.hourMs;
                            return hours <= 14 ? 2 : hours <= 18 ? 3 : 4;
                        }
                        readonly property var hours: {
                            const out = [];
                            for (let t = timeline.wantStart; t <= timeline.wantEnd + 1; t += timeline.step * timeline.hourMs)
                                out.push(t);
                            return out;
                        }

                        function fraction(t: real): real {
                            return Math.max(0, Math.min(1, (t - timeline.start) / (timeline.end - timeline.start)));
                        }

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: Appearance.dashboard.timelinePadH
                        anchors.rightMargin: Appearance.dashboard.timelinePadH
                        anchors.topMargin: Appearance.dashboard.timelinePadV
                        spacing: Appearance.dashboard.cardGap

                        RowLayout {
                            spacing: Appearance.dashboard.cardGap
                            Layout.fillWidth: true

                            SectionLabel {
                                text: root.dayLabel
                                font.pixelSize: Appearance.dashboard.sectionLabel
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                visible: root.next !== null
                                implicitWidth: Appearance.dashboard.nextDot
                                implicitHeight: Appearance.dashboard.nextDot
                                radius: width / 2
                                color: Colours.primary
                            }

                            Text {
                                text: root.dayNote
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.dashboard.smallText
                                color: Calendar.available ? Colours.on.surface : Colours.outline
                                elide: Text.ElideRight
                                Layout.maximumWidth: Appearance.dashboard.dayNoteMax
                            }

                            Text {
                                visible: root.next !== null
                                text: root.next ? `${root.hhmm(root.next.start)} – ${root.hhmm(root.next.end)}` : ""
                                font.family: Appearance.font.mono
                                font.pixelSize: Appearance.dashboard.hourValue
                                color: Colours.outline
                            }

                            FoldArrow {
                                Layout.leftMargin: Appearance.dashboard.stackGap
                            }
                        }

                        Item {
                            id: track

                            implicitHeight: Appearance.dashboard.trackHeight
                            Layout.fillWidth: true

                            // Today runs up to now; a day gone by is all behind,
                            // one to come all ahead.
                            readonly property real nowX: timeline.fraction(root.now.getTime()) * track.width
                            readonly property real lineY: (track.height - Appearance.dashboard.trackLine) / 2

                            Rectangle {
                                y: track.lineY
                                width: parent.width
                                height: Appearance.dashboard.trackLine
                                radius: height / 2
                                color: Colours.track
                            }

                            Rectangle {
                                y: track.lineY
                                width: track.nowX
                                height: Appearance.dashboard.trackLine
                                radius: height / 2
                                color: Colours.alpha(Colours.primary, Appearance.dashboard.elapsedAlpha)
                            }

                            Repeater {
                                model: timeline.blocks

                                Rectangle {
                                    id: block

                                    required property var modelData

                                    readonly property real a: timeline.fraction(block.modelData.start.getTime())
                                    readonly property real b: timeline.fraction(block.modelData.end.getTime())
                                    readonly property bool past: block.modelData.end.getTime() <= root.now.getTime()
                                    readonly property bool current: !block.past && block.modelData.start.getTime() <= root.now.getTime()
                                    readonly property bool isNext: root.next !== null && block.modelData.uid === root.next.uid
                                    // Its calendar's colour, as a tint.
                                    readonly property color tone: Calendar.colourOf(block.modelData.role)
                                    readonly property real share: block.b - block.a

                                    x: block.a * track.width
                                    y: (track.height - Appearance.dashboard.eventHeight) / 2
                                    width: Math.max(Appearance.dashboard.eventMin, block.b * track.width - x)
                                    height: Appearance.dashboard.eventHeight
                                    radius: Appearance.dashboard.eventRadius
                                    visible: block.b > 0 && block.a < 1
                                    color: block.current ? Colours.primary : block.past ? Colours.surfaceContainerHigh : block.isNext ? Colours.primaryContainer : Colours.alpha(block.tone, Appearance.dashboard.eventTint)

                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: Appearance.dashboard.eventPad
                                        anchors.rightMargin: Appearance.dashboard.eventPad
                                        visible: block.share >= Appearance.dashboard.eventLabelMin
                                        text: block.modelData.title
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                        font.family: Appearance.font.ui
                                        font.pixelSize: Appearance.dashboard.eventLabel
                                        color: block.current ? Colours.on.primary : block.past ? Colours.outline : block.isNext ? Colours.on.primaryContainer : block.modelData.role === "primary" ? Colours.on.surfaceVariant : block.tone
                                    }
                                }
                            }

                            Rectangle {
                                x: track.nowX - width / 2
                                y: -Appearance.dashboard.nowOverhang
                                width: Appearance.dashboard.nowLine
                                height: track.height + Appearance.dashboard.nowOverhang * 2
                                radius: width / 2
                                color: Colours.primary
                                visible: root.isToday

                                Behavior on x {
                                    NumberAnimation {
                                        duration: Appearance.dashboard.nowMove
                                    }
                                }
                            }
                        }

                        Item {
                            implicitHeight: Appearance.dashboard.hourRow
                            Layout.fillWidth: true

                            Repeater {
                                model: timeline.hours

                                Text {
                                    required property real modelData

                                    readonly property date at: new Date(modelData)
                                    // Midnight inside the window is where the
                                    // day turns over, and is named: "Sun"
                                    // rather than "00".
                                    readonly property bool midnight: at.getHours() === 0 && modelData > timeline.wantStart

                                    x: timeline.fraction(modelData) * parent.width - width / 2
                                    text: midnight ? Qt.formatDateTime(at, "ddd") : Qt.formatDateTime(at, "hh")
                                    font.family: midnight ? Appearance.font.ui : Appearance.font.mono
                                    font.pixelSize: Appearance.dashboard.hourLabel
                                    color: midnight ? Colours.on.surfaceVariant : Colours.outline
                                }
                            }
                        }
                    }
                }
            }

            Fold {
                y: upper.y + dayCard.y + dayCard.height + Appearance.dashboard.gapHome
                width: parent.width
            }
        }
    }

    // ---- side: clock, weather card, agenda -----------------------------------
    Component {
        id: sideLayout

        ColumnLayout {
            spacing: Appearance.dashboard.gapHomeSide

            ClockBlock {
                size: Appearance.dashboard.clockSide
                secondsSize: Appearance.dashboard.secondsSide
            }

            Rectangle {
                radius: Appearance.dashboard.cardRadius
                color: Colours.surfaceContainer
                implicitHeight: weatherCard.implicitHeight + 28
                Layout.fillWidth: true

                ColumnLayout {
                    id: weatherCard

                    anchors.fill: parent
                    anchors.margins: Appearance.dashboard.weatherCardPadV
                    anchors.leftMargin: Appearance.dashboard.weatherCardPadH
                    anchors.rightMargin: Appearance.dashboard.weatherCardPadH
                    spacing: Appearance.dashboard.weatherCardGap

                    RowLayout {
                        spacing: Appearance.dashboard.weatherIconGap

                        Icon {
                            text: Weather.available ? Weather.icon : "cloud_off"
                            size: Appearance.dashboard.weatherIconSide
                            color: Colours.secondary
                        }

                        Text {
                            visible: Weather.available
                            text: Weather.formatTemp(Weather.tempC)
                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.dashboard.tempSide
                            font.weight: Font.Light
                            color: Colours.on.surface
                        }

                        ColumnLayout {
                            spacing: Appearance.dashboard.subGap
                            Layout.fillWidth: true

                            Text {
                                text: Weather.available ? Weather.description : root.weatherLine
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.dashboard.smallText
                                color: Colours.on.surface
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: Weather.available
                                text: {
                                    const bits = [];
                                    if (Weather.outlook)
                                        bits.push(Weather.outlook.charAt(0).toUpperCase() + Weather.outlook.slice(1));
                                    bits.push(qsTr("feels %1").arg(Weather.formatTemp(Weather.feelsLikeC)));
                                    return bits.join(" · ");
                                }
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.dashboard.toggleNote
                                color: Colours.outline
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    RowLayout {
                        visible: Weather.nextHours.length > 0
                        Layout.fillWidth: true

                        Repeater {
                            model: Weather.nextHours

                            ColumnLayout {
                                id: sideHour

                                required property var modelData

                                spacing: Appearance.dashboard.stackGap
                                Layout.fillWidth: true

                                Text {
                                    text: sideHour.modelData.time
                                    font.family: Appearance.font.mono
                                    font.pixelSize: Appearance.dashboard.hourLabel
                                    color: Colours.outline
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Icon {
                                    text: sideHour.modelData.icon
                                    size: Appearance.dashboard.hourIcon
                                    color: Colours.on.surfaceVariant
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: sideHour.modelData.temp
                                    font.family: Appearance.font.mono
                                    font.pixelSize: Appearance.dashboard.hourValue
                                    color: Colours.on.surface
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }

            Fold {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
            }

            // The agenda: the day's events down a spine -- today's with a
            // "Now" row where the current time falls and the next event
            // highlighted with its countdown. As many rows as fit, kept
            // around now.
            Rectangle {
                id: agendaCard

                radius: Appearance.dashboard.cardRadius
                color: Colours.surfaceContainer
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property int rowStep: Appearance.dashboard.agendaRow + Appearance.dashboard.agendaRowGap
                property real listHeight: 0
                readonly property int capacity: Math.max(1, Math.floor((agendaCard.listHeight + Appearance.dashboard.agendaRowGap) / agendaCard.rowStep))

                readonly property var rows: {
                    const out = [];
                    for (const e of root.allDay)
                        out.push({
                            kind: "allday",
                            e: e
                        });
                    // Another day has no now to place.
                    let placed = !root.isToday;
                    for (const e of root.timed) {
                        if (!placed && e.start.getTime() > root.now.getTime()) {
                            out.push({
                                kind: "now"
                            });
                            placed = true;
                        }
                        out.push({
                            kind: "event",
                            e: e
                        });
                    }
                    if (!placed)
                        out.push({
                            kind: "now"
                        });
                    // Keep "Now" in view: drop past rows from the top first.
                    const at = out.findIndex(r => r.kind === "now");
                    const from = at < 0 ? 0 : Math.max(0, Math.min(at - 2, out.length - agendaCard.capacity));
                    return out.slice(from, from + agendaCard.capacity);
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: Appearance.dashboard.agendaPadTop
                    anchors.bottomMargin: Appearance.dashboard.agendaPadBottom
                    anchors.leftMargin: Appearance.dashboard.agendaPadH
                    anchors.rightMargin: Appearance.dashboard.agendaPadH
                    spacing: Appearance.dashboard.agendaGap

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Appearance.dashboard.agendaPad
                        Layout.rightMargin: Appearance.dashboard.agendaPad
                        Layout.bottomMargin: Appearance.dashboard.subGap

                        SectionLabel {
                            text: root.dayLabel
                            font.pixelSize: Appearance.dashboard.sectionLabel
                            Layout.fillWidth: true
                        }

                        Text {
                            text: Calendar.available ? (root.dayEvents.length === 1 ? qsTr("1 event") : qsTr("%1 events").arg(root.dayEvents.length)) : Calendar.reason
                            font.family: Appearance.font.mono
                            font.pixelSize: Appearance.dashboard.eventLabel
                            color: Colours.outline
                            elide: Text.ElideRight
                        }

                        // A new event on this day, in the month's form.
                        Icon {
                            visible: Calendar.writable.length > 0
                            text: "add"
                            size: Appearance.dashboard.foldArrow
                            color: addMouse.containsMouse ? Colours.on.surface : Colours.outline
                            Layout.preferredHeight: 0
                            Layout.leftMargin: Appearance.dashboard.stackGap

                            MouseArea {
                                id: addMouse

                                anchors.centerIn: parent
                                width: parent.width + Appearance.dashboard.hitSlop * 2
                                height: Appearance.dashboard.foldArrow + Appearance.dashboard.hitSlop * 2
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.newRequested()
                            }
                        }

                        FoldArrow {
                            Layout.leftMargin: Appearance.dashboard.stackGap
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onHeightChanged: agendaCard.listHeight = height

                        Rectangle {
                            x: Appearance.dashboard.agendaSpine
                            y: Appearance.dashboard.agendaSpineInset
                            width: Appearance.dashboard.agendaSpineWidth
                            height: Math.max(0, agendaCard.rows.length * agendaCard.rowStep - Appearance.dashboard.agendaSpineInset * 2 - Appearance.dashboard.agendaRowGap)
                            radius: width / 2
                            color: Colours.alpha(Colours.on.surface, Appearance.dashboard.spineAlpha)
                        }

                        Column {
                            width: parent.width
                            spacing: Appearance.dashboard.agendaRowGap

                            Repeater {
                                model: agendaCard.rows

                                Rectangle {
                                    id: row

                                    required property var modelData

                                    readonly property bool isNow: row.modelData.kind === "now"
                                    readonly property var e: row.modelData.e ?? null
                                    readonly property bool past: row.e !== null && row.e.end.getTime() <= root.now.getTime()
                                    readonly property bool isNext: row.e !== null && root.next !== null && row.e.uid === root.next.uid
                                    // Opens in the month's form when clicked.
                                    readonly property bool writable: row.e !== null && Calendar.isWritable(row.e)

                                    width: parent.width
                                    height: Appearance.dashboard.agendaRow
                                    radius: Appearance.dashboard.agendaRowRadius
                                    color: row.isNext ? Colours.primaryContainer : row.writable && rowMouse.containsMouse ? Colours.hover : "transparent"

                                    MouseArea {
                                        id: rowMouse

                                        anchors.fill: parent
                                        enabled: row.writable
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.editRequested(row.e)
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Appearance.dashboard.agendaPad
                                        anchors.rightMargin: Appearance.dashboard.agendaPad
                                        spacing: Appearance.dashboard.agendaCols

                                        Text {
                                            text: row.isNow ? Time.time : row.modelData.kind === "allday" ? qsTr("all day") : root.hhmm(row.e.start)
                                            font.family: Appearance.font.mono
                                            font.pixelSize: Appearance.dashboard.eventLabel
                                            color: row.isNow ? Colours.primary : row.isNext ? Colours.on.primaryContainer : Colours.outline
                                            elide: Text.ElideRight
                                            Layout.preferredWidth: Appearance.dashboard.agendaTime
                                        }

                                        Item {
                                            implicitWidth: Appearance.dashboard.agendaDotCol
                                            implicitHeight: Appearance.dashboard.agendaNowDot

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: row.isNow ? Appearance.dashboard.agendaNowDot : Appearance.dashboard.agendaDot
                                                height: width
                                                radius: width / 2
                                                color: row.isNow ? Colours.primary : row.past ? Colours.outlineVariant : row.isNext ? Colours.on.primaryContainer : Calendar.colourOf(row.e?.role ?? "")
                                            }
                                        }

                                        Text {
                                            text: row.isNow ? qsTr("Now") : row.e.title
                                            font.family: Appearance.font.ui
                                            font.pixelSize: Appearance.dashboard.agendaTitle
                                            color: row.isNow ? Colours.primary : row.past ? Colours.outline : Colours.on.surface
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            visible: !row.isNow && row.modelData.kind !== "allday"
                                            text: row.e ? (row.isNext ? qsTr("in %1").arg(root.until(row.e)) : root.duration(row.e)) : ""
                                            font.family: Appearance.font.mono
                                            font.pixelSize: Appearance.dashboard.eventLabel
                                            color: row.isNext ? Colours.on.primaryContainer : Colours.outline
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Held at the open height until the month has faded: the page shrinks
    // at once when it folds, and a side layout's agenda would otherwise
    // lose its rows under a month still on its way out.
    Loader {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Appearance.dashboard.pageTopGap
        anchors.leftMargin: root.side ? Appearance.dashboard.padSide : Appearance.dashboard.padTop
        anchors.rightMargin: root.side ? Appearance.dashboard.padSide : Appearance.dashboard.padTop
        height: (root.foldHeld ? Math.max(root.openHeight, parent.height) : parent.height) - Appearance.dashboard.pageTopGap
        sourceComponent: root.side ? sideLayout : topLayout
    }
}
