import QtQuick
import qs.tokens

// The horizontal bar's neutral capsule: the media chip and the cpu/ram chip,
// which are the same 26px rounded fill with different contents.
//
// It has no vertical twin. A column has the room to stack a glyph over a
// number and does not need a container to hold them together, so a vertical bar
// simply does not build one of these -- see Media.qml and Resources.qml, each
// of which draws the chip on one axis and the stack on the other.
Rectangle {
    id: root

    property int padLead: Appearance.bar.chipPadLead
    property int padTrail: Appearance.bar.chipPadTrail
    property int gap: Appearance.bar.chipGap
    property bool interactive: false

    default property alias content: flow.data

    signal clicked
    signal secondaryClicked

    implicitHeight: Appearance.bar.iconButtonH
    implicitWidth: flow.implicitWidth + root.padLead + root.padTrail
    radius: Appearance.bar.tileRadius(root.implicitHeight)
    color: Colours.hover

    BarFlow {
        id: flow

        anchors.left: parent.left
        anchors.leftMargin: root.padLead
        anchors.verticalCenter: parent.verticalCenter
        gap: root.gap
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Colours.hover
        visible: opacity > 0
        opacity: root.interactive && mouse.containsMouse ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Appearance.anim.enterEasing
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton ? root.secondaryClicked() : root.clicked()
    }
}
