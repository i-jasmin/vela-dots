import QtQuick
import QtQuick.Layouts
import qs.tokens

// A settings page that may be taller than the window. Its sections are laid out
// in one column, as the Appearance and Bar pages lay theirs, and the column
// scrolls once it outgrows the 706px window -- which General, with seven
// sections, does.
//
//     PaneScroll {
//         PaneHeader { title: qsTr("General") }
//         Section { ... }
//     }
//
// The thumb on the right only appears while there is somewhere to scroll to,
// and the wheel moves the page a row at a time.
Item {
    id: root

    default property alias content: column.data
    property int spacing: Appearance.settings.paneGap

    Flickable {
        id: view

        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column

            // Clear of the thumb, so nothing at the right edge of a card sits
            // under it.
            width: view.width - Appearance.settings.scrollbar * 2
            spacing: root.spacing
        }
    }

    Rectangle {
        visible: view.contentHeight > view.height
        x: root.width - width
        y: view.visibleArea.yPosition * view.height
        width: Appearance.settings.scrollbar
        height: view.visibleArea.heightRatio * view.height
        radius: width / 2
        color: Colours.track
    }
}
