import QtQuick
import qs.tokens

// The 1px rule between runs of bar items. A 20px line across a vertical
// bar, a 16px line down a horizontal one -- the same rule, turned with
// everything else.
Rectangle {
    id: root

    required property BarState bar

    implicitWidth: root.bar.vertical ? Appearance.space.xl : 1
    implicitHeight: root.bar.vertical ? 1 : Appearance.space.lg

    // The design's `rgba(222,227,229,.1)`, which is the text ramp's top colour
    // at a tenth -- a shade above `panelBorder` on purpose, because this rule
    // sits inside the panel rather than around it.
    color: Colours.alpha(Colours.on.surface, 0.1)
}
