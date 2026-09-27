pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.tokens

// Six weeks from the Monday on or before the first -- the only grid that fits
// every month without reflowing, and the one the old calendar window and the
// dashboard both draw.
//
//     MonthGrid {
//         month: view.viewMonth
//         today: view.today
//         selected: view.selected
//         markedDays: view.busyDays
//         onDayActivated: d => view.selected = d
//     }
//
// Drawn by Home's month on the dashboard (modules/dashboard/MonthFold.qml),
// which sizes it down from the defaults here -- 30px cells, from when the
// calendar was a window of its own.
//
// NO SERVICE IMPORT. A component never asks a singleton anything, so the days
// that have something on them arrive as `markedDays`, a list of ISO strings,
// and the caller is the only thing that knows there is a calendar backend at
// all. Defaults come from `Appearance.calendar` because that is where this
// grid was measured; a caller wanting a tighter one overrides them.
GridLayout {
    id: root

    // Any day inside the month to draw.
    property date month: new Date()
    property date today: new Date()
    property date selected: root.today
    property bool showWeekdays: true
    // ["2026-09-21", ...] -- days carrying at least one event.
    property var markedDays: []

    property int cellHeight: Appearance.calendar.cellHeight
    property int cellRadius: Appearance.calendar.cellRadius
    property real daySize: Appearance.size.label
    property real weekdaySize: Appearance.calendar.weekdaySize
    property bool interactive: true

    signal dayActivated(date day)

    // 0 draws as many weeks as the month needs -- five for September 2026, six
    // for a month that starts late.
    // A caller that would rather not change height between months pins it to 6.
    property int fixedWeeks: 0

    readonly property var weekdays: [qsTr("M"), qsTr("T"), qsTr("W"), qsTr("T"), qsTr("F"), qsTr("S"), qsTr("S")]

    function iso(d: date): string {
        return Qt.formatDateTime(d, "yyyy-MM-dd");
    }

    readonly property int weeks: {
        if (root.fixedWeeks > 0)
            return root.fixedWeeks;
        const first = new Date(root.month.getFullYear(), root.month.getMonth(), 1);
        const lead = (first.getDay() + 6) % 7;
        // Day 0 of the next month is the last day of this one.
        const days = new Date(root.month.getFullYear(), root.month.getMonth() + 1, 0).getDate();
        return Math.ceil((lead + days) / 7);
    }

    readonly property var cells: {
        const first = new Date(root.month.getFullYear(), root.month.getMonth(), 1);
        // getDay() is Sunday-first; the design's grid starts on Monday.
        const lead = (first.getDay() + 6) % 7;
        const todayKey = root.iso(root.today);
        const selectedKey = root.iso(root.selected);
        const marks = root.markedDays ?? [];

        const out = [];
        const count = root.weeks * 7;
        for (let i = 0; i < count; i++) {
            // Day numbers below 1 and past the month's end roll over on their
            // own, which is what makes the leading and trailing weeks correct
            // across a year boundary without a special case.
            const d = new Date(first.getFullYear(), first.getMonth(), 1 - lead + i);
            const key = root.iso(d);
            const dow = (d.getDay() + 6) % 7;
            out.push({
                day: d.getDate(),
                key: key,
                date: d,
                inMonth: d.getMonth() === first.getMonth(),
                weekend: dow >= 5,
                today: key === todayKey,
                selected: key === selectedKey,
                marked: marks.indexOf(key) >= 0
            });
        }
        return out;
    }

    columns: 7
    columnSpacing: Appearance.calendar.gridGap
    rowSpacing: Appearance.calendar.gridGap

    Repeater {
        model: root.showWeekdays ? root.weekdays : []

        Text {
            required property string modelData

            text: modelData
            font.family: Appearance.font.ui
            font.pixelSize: root.weekdaySize
            color: Colours.outline
            horizontalAlignment: Text.AlignHCenter

            Layout.fillWidth: true
            // A GridLayout hands out the slack by the ratio
            // of the preferred widths, so seven equal ones are what makes seven
            // equal columns. Never read the grid's own width back.
            Layout.preferredWidth: 1
        }
    }

    Repeater {
        model: root.cells

        Rectangle {
            id: cell

            required property var modelData

            implicitHeight: root.cellHeight
            radius: root.cellRadius
            // Today is the one cell allowed colour -- it is the selection in a
            // list of equals. The keyboard cursor is a border, not a second
            // fill, so the two never compete.
            color: cell.modelData.today ? Colours.primary : "transparent"
            border.width: cell.modelData.selected && !cell.modelData.today ? 1 : 0
            border.color: Colours.primary

            Layout.fillWidth: true
            Layout.preferredWidth: 1

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Colours.hover
                opacity: root.interactive && mouse.containsMouse && !cell.modelData.today ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Appearance.anim.enterEasing
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: cell.modelData.day
                font.family: Appearance.font.mono
                font.pixelSize: root.daySize
                // The design's 500 on today: a regular-weight number is a
                // hairline on the filled circle, and glare takes it entirely.
                font.weight: cell.modelData.today ? Font.Medium : Font.Normal
                color: {
                    if (cell.modelData.today)
                        return Colours.on.primary;
                    // Disabled, not quiet: a day outside the month cannot be
                    // acted on, which is the only thing `outlineVariant` is
                    // allowed to say.
                    if (!cell.modelData.inMonth)
                        return Colours.outlineVariant;
                    return cell.modelData.weekend ? Colours.outline : Colours.on.surfaceVariant;
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.calendar.markDotGap
                implicitWidth: Appearance.calendar.markDot
                implicitHeight: Appearance.calendar.markDot
                radius: height / 2
                visible: cell.modelData.marked && !cell.modelData.today
                color: Colours.primary
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                enabled: root.interactive
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dayActivated(cell.modelData.date)
            }
        }
    }
}
