import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.components

// What every popout has in common: a heading, a column, and the shape it wants
// the panel around it to take.
//
// The five contents are all Items with an implicit height and a fixed width, so
// `Popout.qml` can size its window from whichever one is loaded without knowing
// which. They differ in more than their contents -- the workspace window list
// is 246px wide with an 18px radius and 1px between its rows, where the four
// control popouts are 292px at 20 with 12 -- so the shape is declared here and
// read back by the shell.
//
//     PopoutContent {
//         icon: "wifi"
//         heading: qsTr("Network")
//
//         Row { ... }
//         Divider {}
//     }
//
// `Divider` and `Empty` sit beside this file rather than in `components/`
// because they are two lines each and no other module has asked for one yet.
// The section label the popouts head "PER APP" and "WORKSPACE 2 - 3 WINDOWS"
// with is not one of them: that is `components/SectionLabel.qml`, shared.
Item {
    id: root

    // Material Symbols ligature and the word beside it. An empty heading draws
    // no header at all, which is what the workspace window list wants.
    property string icon
    property string heading

    // The shape of the panel this content wants around it.
    property int popoutWidth: Appearance.popout.width
    property int contentPadding: Appearance.popout.padding
    property int contentRadius: Appearance.radius.popout
    property int contentSpacing: Appearance.space.md

    default property alias content: column.data

    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        anchors.fill: parent
        spacing: root.contentSpacing

        RowLayout {
            spacing: Appearance.popout.headerGap
            visible: root.heading !== ""

            Layout.fillWidth: true

            Icon {
                text: root.icon
                size: Appearance.size.iconMd
                // A heading's glyph is the one accent a popout carries that is
                // not a selection: it names which control this is.
                color: Colours.primary
            }

            Text {
                text: root.heading
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.body
                color: Colours.on.surface
                elide: Text.ElideRight

                Layout.fillWidth: true
            }
        }
    }
}
