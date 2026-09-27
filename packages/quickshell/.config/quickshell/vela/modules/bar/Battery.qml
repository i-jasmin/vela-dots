import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.tokens

// Charge, and the way into the Power popout -- the one of the bar's four
// control popouts that does not hang off the status run next door.
//
// Glyph over percentage on a vertical bar, glyph beside it on a horizontal one.
// Both neutral: the design reserves `error` for urgent notifications,
// destructive actions and a required reboot, and does not tint a low battery.
// That is deliberate -- a dying battery says so in the popout, not in the bar.
Item {
    id: root

    required property BarState bar

    // A horizontal bar keeps the battery inside the status run's 11px rhythm,
    // then closes the run before the power button.
    readonly property int leadMargin: root.bar.vertical ? 0 : Appearance.bar.trayGapH - Appearance.bar.gapTrailH
    readonly property int trailMargin: root.bar.vertical ? 0 : Appearance.bar.chipPadLead

    // Folded away with the rest of the status run (BarExpander).
    readonly property bool present: Power.available && !root.bar.collapsed

    implicitWidth: flow.implicitWidth
    implicitHeight: flow.implicitHeight

    BarFlow {
        id: flow

        anchors.centerIn: parent
        vertical: root.bar.vertical
        gap: root.bar.vertical ? Appearance.bar.statGap : Appearance.space.xs

        Icon {
            Layout.alignment: root.bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            text: Power.icon
            size: root.bar.vertical ? Appearance.size.iconRow : Appearance.size.iconLabel
        }

        Text {
            Layout.alignment: root.bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            // The column has no room for the sign; the row does.
            text: root.bar.vertical ? `${Power.percent}` : `${Power.percent}%`
            font.family: Appearance.font.mono
            font.pixelSize: root.bar.vertical ? Appearance.bar.statSize : Appearance.size.label
            color: Colours.on.surfaceVariant
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.bar.popout("power", root, undefined)
    }

    Connections {
        target: BarPopouts

        function onRequested(name: string): void {
            if (name === "power" && root.bar.forKeys && Power.available)
                root.bar.popout(name, root, undefined);
        }
    }
}
