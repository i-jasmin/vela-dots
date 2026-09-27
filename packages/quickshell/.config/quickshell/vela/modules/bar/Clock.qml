import QtQuick
import QtQuick.Layouts
import qs.services
import qs.tokens

// The clock, in the two shapes the design gives it.
//
// A vertical bar stacks it -- hour over minute over date, on a 1.1 line so the
// two halves read as one number rather than as two rows. The minute is a step
// down the neutral ramp from the hour, which is what lets you read the time at
// a glance without the colon a column has no room for.
//
// A horizontal bar sets date and time side by side, and that is the only
// place on the bar where prose and a number sit in the same run: the date is
// Rubik, the time is JetBrains Mono, because one is a name and the other is a
// quantity.
//
// The design lays the horizontal bar out with `space-between`, which does not
// centre the clock -- it parks it wherever the left and right groups happen to
// leave it, so the time would shift sideways every time the focused window's
// title changed length. It is centred on the screen here instead, which is what
// the design's own prose asks for ("Centre: date and time side by side").
Item {
    id: root

    required property BarState bar

    // The design sets the stacked clock on a 1.1 line so the hour and the minute
    // read as one number. `Text.ProportionalHeight` is NOT that: it multiplies
    // the FONT's natural line height -- about 1.32em -- so 1.1 there came out
    // at 22px against the design's 16.5 and pushed the two digits five pixels
    // apart. CSS `line-height` is a multiple of the font SIZE, and the QML
    // spelling of that is a fixed line box.
    readonly property int lineBox: Math.round(Appearance.bar.clockSize * 1.1)

    // The dashboard's "Countdown in the bar": while a focus session runs the
    // clock shows its time left, in the same two slots, and says so.
    readonly property bool counting: Focus.countdownInBar && Focus.running
    readonly property var countdown: Focus.clock.split(":")

    implicitWidth: flow.implicitWidth
    implicitHeight: flow.implicitHeight

    // The trigger's pressed look while the drawer is open. Drawn around the
    // clock rather than as part of it, so opening the dashboard moves nothing
    // on the bar.
    Rectangle {
        anchors.centerIn: flow
        width: flow.implicitWidth + (root.bar.vertical ? Appearance.dashboard.clockPillPadV : Appearance.dashboard.clockPillPad) * 2
        height: root.bar.vertical ? flow.implicitHeight + Appearance.dashboard.clockPillPadV * 2 : Appearance.dashboard.clockPillHeight
        radius: Appearance.dashboard.clockPillRadius
        color: root.bar.dashboardOpen ? root.bar.accent(Colours.primaryContainer) : Colours.alpha(Colours.primaryContainer, 0)

        Behavior on color {
            enabled: !Colours.crossing

            ColorAnimation {
                duration: Appearance.dashboard.colourFade
            }
        }
    }

    BarFlow {
        id: flow

        anchors.centerIn: parent
        vertical: root.bar.vertical
        gap: root.bar.vertical ? 0 : Appearance.bar.gapCentreH

        // Stacked: hour, minute. Inline: date, time. Same order either way --
        // coarse before fine -- so the two are the same component rotated and
        // not two clocks.
        Text {
            Layout.alignment: root.bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            text: root.bar.vertical ? (root.counting ? root.countdown[0] : Time.hour) : (root.counting ? qsTr("Focus") : Time.dateShort)
            font.family: root.bar.vertical ? Appearance.font.mono : Appearance.font.ui
            font.pixelSize: root.bar.vertical ? Appearance.bar.clockSize : Appearance.bar.titleSize
            font.weight: root.bar.vertical ? Font.Medium : Font.Normal
            color: root.bar.vertical ? Colours.on.surface : root.bar.dashboardOpen || root.counting ? root.bar.accent(Colours.on.primaryContainer) : Colours.outline
            // The line box has to be forced onto the layout cell, not just onto
            // the Text: `Text.FixedHeight` changes where the glyph paints but
            // leaves `implicitHeight` at the font's own line height, which is
            // what the flow would otherwise measure.
            Layout.preferredHeight: root.bar.vertical ? root.lineBox : -1
            verticalAlignment: Text.AlignVCenter
            lineHeight: root.bar.vertical ? root.lineBox : 1
            lineHeightMode: root.bar.vertical ? Text.FixedHeight : Text.ProportionalHeight
        }

        Text {
            Layout.alignment: root.bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            text: root.bar.vertical ? (root.counting ? root.countdown[1] : Time.minute) : (root.counting ? Focus.clock : Time.time)
            font.family: Appearance.font.mono
            font.pixelSize: root.bar.vertical ? Appearance.bar.clockSize : Appearance.bar.timeSize
            font.weight: Font.Medium
            font.letterSpacing: root.bar.vertical ? 0 : Appearance.bar.timeSize * Appearance.bar.timeTracking
            color: root.bar.vertical ? Colours.outline : Colours.on.surface
            // The line box has to be forced onto the layout cell, not just onto
            // the Text: `Text.FixedHeight` changes where the glyph paints but
            // leaves `implicitHeight` at the font's own line height, which is
            // what the flow would otherwise measure.
            Layout.preferredHeight: root.bar.vertical ? root.lineBox : -1
            verticalAlignment: Text.AlignVCenter
            lineHeight: root.bar.vertical ? root.lineBox : 1
            lineHeightMode: root.bar.vertical ? Text.FixedHeight : Text.ProportionalHeight
        }

        // The date only fits under a stacked clock; the horizontal bar already
        // has it in the first slot.
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Appearance.space.xs
            visible: root.bar.vertical
            text: root.counting ? qsTr("focus") : Time.dateCompact
            font.family: Appearance.font.mono
            font.pixelSize: Appearance.bar.dateSize
            color: Colours.outline
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        // The dashboard, not a popout: the calendar is information you go and
        // look at. The design states the rule; this is the click that would
        // break it if it opened anything else. A right-click opens it with
        // Home's month folded out -- the calendar, as super + shift + D.
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.bar.calendar();
            else
                root.bar.toggle("dashboard");
        }
    }
}
