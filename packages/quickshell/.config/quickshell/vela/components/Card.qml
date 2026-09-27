import QtQuick
import qs.tokens

// The surface *inside* a panel: one of the dashboard's ten cards, a section in
// the settings pane, the preview block in the wallpaper switcher. Neutral, flat
// and shadowless -- the panel below it already carries the elevation, and a
// second shadow here is what makes a shell look busy.
//
//     Card {
//         implicitHeight: column.implicitHeight + padding * 2
//         ColumnLayout { id: column; anchors.fill: parent }
//     }
//
// Sizes itself no more than Panel does, and for the same reason.
//
// Radius by size, from the design's table: `card` (15) for a card in a window,
// `cardLg` (18) for a large one, `cardXl` (20) for the dashboard's, which sit
// inside a 26px drawer and are drawn a step rounder to match it.
Rectangle {
    id: root

    default property alias content: body.data
    readonly property alias contentItem: body

    property int padding: Appearance.space.panelPadding

    color: Colours.surfaceContainer
    radius: Appearance.radius.card

    Item {
        id: body

        anchors.fill: parent
        anchors.margins: root.padding
    }
}
