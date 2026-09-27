import QtQuick
import qs.tokens

// The grid of dots at the head of the bar. Opens the launcher.
//
// One of the three things on the bar the design paints `primary`, and the only
// one that is not a state: it is the shell's own mark, drawn once, at the end
// the bar starts from.
BarButton {
    id: root

    required property BarState bar

    size: root.bar.vertical ? Appearance.bar.launcherTile : Appearance.bar.launcherTileH
    iconSize: root.bar.vertical ? Appearance.size.iconLg : Appearance.bar.glyphH
    icon: "apps"
    iconColour: root.bar.accent(Colours.primary)
    showing: root.bar.holds("launcher")

    onClicked: root.bar.toggle("launcher")
}
