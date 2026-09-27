import QtQuick
import qs.services
import qs.tokens

// The bar's `expand_circle_down`: the arrow that folds the status run away. It
// leads the trailing run, and everything after it up to the clock goes --
// media, resources, the tray glyphs and any tray icons, the battery -- leaving
// the arrow, the clock and the power button.
//
// Two things stay while folded, because hiding them would hide news: the
// bell, while anything is unread, and the privacy dots, which only exist
// while a microphone, camera or screen share is live. Each module decides
// through its own `present`, reading `bar.collapsed`.
//
// The glyph points the way a click moves things. The run grows out of the
// clock's end of the bar, so while folded it points away from the clock --
// left, or up on a vertical bar: open -- and while open back towards it --
// right, or down: close. (The glyph is a down arrow; a clockwise quarter turn
// points it left.)
BarButton {
    id: root

    required property BarState bar

    icon: "expand_circle_down"
    tile: false
    size: root.bar.vertical ? Appearance.size.iconRow : Appearance.size.iconLabel
    iconSize: root.size
    iconColour: root.bar.collapsed ? Colours.on.surfaceVariant : Colours.on.surface

    rotation: root.bar.vertical ? (root.bar.collapsed ? 180 : 0) : (root.bar.collapsed ? 90 : -90)

    Behavior on rotation {
        enabled: !Appearance.reduceMotion

        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Appearance.anim.enterEasing
        }
    }

    onClicked: {
        // A popout hangs off an item that is about to go.
        if (!root.bar.collapsed)
            BarPopouts.close();
        ShellState.setBarCollapsed(!root.bar.collapsed);
    }
}
