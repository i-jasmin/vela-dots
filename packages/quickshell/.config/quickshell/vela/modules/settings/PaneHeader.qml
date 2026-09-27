import QtQuick
import QtQuick.Layouts
import qs.tokens

// The top line of a settings pane: the page's name, and the one or two actions
// that belong to that page. The actions are children, so the call site reads
// the way the screen does:
//
//     PaneHeader {
//         title: qsTr("Bar")
//         Pill { text: qsTr("Reset") }
//         Pill { text: qsTr("Apply"); tone: "filled" }
//     }
//
// The title is a sibling of the action row rather than the first thing in it,
// which is what keeps a call-site action from landing to the left of it.
Item {
    id: root

    property string title

    default property alias actions: row.data

    implicitHeight: Math.max(label.implicitHeight, Appearance.settings.actionHeight)

    Layout.fillWidth: true

    Text {
        id: label

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        font.family: Appearance.font.ui
        font.pixelSize: Appearance.size.title
        color: Colours.on.surface
    }

    RowLayout {
        id: row

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.space.sm
    }
}
