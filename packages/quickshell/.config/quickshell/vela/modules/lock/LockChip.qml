import QtQuick
import qs.tokens
import qs.components

// The translucent capsule the lock screen uses for both corner pieces -- the
// network chip at the top right and the media controls at the bottom left. One
// component, two instances: they differ only in height and in what is in them.
//
// Shadowless on purpose. The design gives these a border and nothing else:
// they sit on the wallpaper's own light, not over another surface, so a shadow
// under them would be the second elevation on a screen that has one.
Panel {
    id: root

    level: "popout"
    padding: 0
    radius: Appearance.radius.popout
    shadowY: 0
    shadowBlur: 0
    // The design's 50% fill, as a reduction of the user's panel opacity rather
    // than a fixed alpha, so the settings screen's slider still moves it.
    colour: Colours.alpha(Colours.panel, Math.max(0, Appearance.panelOpacity - Appearance.lock.chipFade))
    implicitHeight: Appearance.lock.chipHeight
}
