import QtQuick
import qs.tokens
import qs.components

// One row of the launcher's result list: a 30px icon tile, name over subtitle,
// and a ↵ keycap on the selected row.
//
// It is `components/Row.qml` with its two slots filled, not a second list row:
// the selected fill, the hover wash, the title/subtitle ramp and the eliding
// all already live there, and copying them here is exactly the duplication the
// component library exists to prevent. `Row` shadows QtQuick's positioner in
// this file -- which is what is wanted here, and is why nothing below uses one.
Row {
    id: root

    // One entry of `Search.results`.
    required property var result

    // Measured off the design; the values are in `Appearance.launcher`.

    rowHeight: Appearance.launcher.rowHeight
    spacing: Appearance.launcher.tileGap
    title: root.result?.title ?? ""
    subtitle: root.result?.subtitle ?? ""
    titleMono: root.result?.mono ?? false
    // The keyboard is the primary path, so Tab belongs to completion rather
    // than to walking a list the arrow keys already walk.
    activeFocusOnTab: false

    leading: Component {
        Rectangle {
            implicitWidth: Appearance.launcher.tile
            implicitHeight: Appearance.launcher.tile
            radius: Appearance.radius.small
            // A wash of the row's own foreground, so the tile lifts off both a
            // neutral row and a `primaryContainer` one without a second colour.
            // None behind an app's own icon, which has a shape of its own.
            color: app.showsImage ? "transparent" : root.selected ? Colours.alpha(Colours.on.primaryContainer, 0.12) : Colours.hover

            AppIcon {
                id: app

                anchors.centerIn: parent
                visible: !root.result?.glyph
                source: root.result?.image ?? ""
                glyph: root.result?.icon ?? ""
                size: Appearance.size.iconMd
                imageSize: Appearance.launcher.tile
                color: root.selected ? Colours.on.primaryContainer : Colours.outline
            }

            // An emoji is its own icon.
            Text {
                anchors.centerIn: parent
                visible: !!root.result?.glyph
                text: root.result?.glyph ?? ""
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.iconMd
            }
        }
    }

    // Only the selected row says how to launch it; every row carrying a ↵ would
    // be telling the user nothing.
    trailing: root.selected ? enter : null

    Component {
        id: enter

        Keycap {
            key: "↵"
            onAccent: true
        }
    }
}
