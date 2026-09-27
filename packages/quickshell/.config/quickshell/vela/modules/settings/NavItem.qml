import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.components

// One line of the settings nav -- `components/Row.qml` wearing the settings
// window's geometry. The differences from a list row are all the design's: a
// full-height pill rather than the list's 12px corner, no trailing tick (the
// pill already says which page you are on), and an unselected label one step
// quieter than a list of equal candidates would use.
Row {
    id: root

    // Arrow keys walk the nav, which is the primary path into every pane.
    signal move(int by)

    rowHeight: Appearance.settings.navItemHeight
    hPadding: Appearance.settings.navItemPad
    iconSize: Appearance.size.iconMd
    radius: root.rowHeight / 2
    trailingIcon: ""
    titleColour: root.selected ? Colours.on.surface : Colours.on.surfaceVariant

    Layout.fillWidth: true

    Keys.onUpPressed: root.move(-1)
    Keys.onDownPressed: root.move(1)
}
