import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.tokens

// The phone in reach, and the way into its popout: KDE Connect's phone glyph
// and the phone's charge. On the bar only while a paired phone is connected
// -- a phone left at home is not news -- and folded away with the status run
// it sits at the head of (BarExpander).
//
// Called PhoneItem so it does not shadow the `Phone` service.
Item {
    id: root

    required property BarState bar

    readonly property int leadMargin: root.bar.vertical ? 0 : Appearance.bar.trayGapH - Appearance.bar.gapTrailH
    readonly property bool present: Phone.connected && !root.bar.collapsed

    implicitWidth: flow.implicitWidth
    implicitHeight: flow.implicitHeight

    BarFlow {
        id: flow

        anchors.centerIn: parent
        vertical: root.bar.vertical
        gap: root.bar.vertical ? Appearance.bar.statGap : Appearance.space.xs

        Icon {
            Layout.alignment: root.bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            text: Phone.iconFor(Phone.phone)
            size: root.bar.vertical ? Appearance.size.iconRow : Appearance.size.iconLabel
            color: BarPopouts.isOpen("phone", root.bar.screenName) ? Colours.primary : Colours.on.surfaceVariant
        }

        Text {
            visible: Phone.battery >= 0
            Layout.alignment: root.bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            text: root.bar.vertical ? `${Phone.battery}` : `${Phone.battery}%`
            font.family: Appearance.font.mono
            font.pixelSize: root.bar.vertical ? Appearance.bar.statSize : Appearance.size.label
            color: Colours.on.surfaceVariant
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.bar.popout("phone", root, undefined)
    }

    Connections {
        target: BarPopouts

        function onRequested(name: string): void {
            if (name === "phone" && root.bar.forKeys && Phone.connected)
                root.bar.popout(name, root, undefined);
        }
    }
}
