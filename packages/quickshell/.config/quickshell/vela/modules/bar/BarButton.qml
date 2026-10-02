import QtQuick
import qs.components
import qs.tokens

// Every glyph on the bar you can click. The design draws three kinds and this
// is all three, because the difference between them is two booleans and not
// two files:
//
//   tile + filled   the app icon and the media toggle -- a neutral square that
//                   is always there (`rgba(255,255,255,.05)`)
//   tile            the launcher and the power button -- the same square, drawn
//                   only under the cursor
//   bare            the tray glyphs -- no square at all, 13px apart, so the
//                   hover has to land in the colour instead
//
// Hover stacks a second `Colours.hover` over the first exactly as Pill.qml
// does, so a filled button still answers the cursor.
Item {
    id: root

    property string icon
    // An application's own icon, drawn in the glyph's place when there is one
    // (an icon theme, `AppIcons`) -- the focused window's tile on a vertical bar.
    property string source
    property int size: Appearance.bar.iconButton
    property real iconSize: Appearance.size.iconMd
    // Draw a square behind the glyph. False for the bare tray glyphs.
    property bool tile: true
    // Keep that square drawn when the cursor is elsewhere.
    property bool filled: false
    // The one thing on this button allowed to carry colour.
    property color iconColour: Colours.on.surfaceVariant
    // Held down while this button's popout is the one on screen.
    property bool showing: false
    // A small accent dot at the glyph's corner: something waiting, such as
    // unread notifications on the bell.
    property bool dot: false

    readonly property alias hovered: mouse.containsMouse

    signal clicked
    signal secondaryClicked
    signal scrolled(int delta)

    implicitWidth: root.size
    implicitHeight: root.size

    Rectangle {
        id: base

        anchors.fill: parent
        radius: Appearance.bar.tileRadius(root.size)
        visible: root.tile
        color: root.filled || root.showing ? Colours.hover : "transparent"

        Behavior on color {
            enabled: !Colours.crossing

            ColorAnimation {
                duration: Appearance.anim.fast
                easing.type: Appearance.anim.enterEasing
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: base.radius
        color: Colours.hover
        visible: root.tile && opacity > 0
        opacity: root.tile && mouse.containsMouse ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Appearance.anim.enterEasing
            }
        }
    }

    AppIcon {
        anchors.centerIn: parent
        source: root.source
        glyph: root.icon
        size: root.iconSize
        imageSize: root.size * Appearance.size.appIconFill
        // A bare glyph has no square to brighten, so it brightens itself --
        // one step up the neutral ramp, never into an accent.
        color: !root.tile && mouse.containsMouse ? Colours.on.surface : root.iconColour
    }

    Rectangle {
        x: Math.round(root.width / 2 + root.iconSize / 2 - width * 0.75)
        y: Math.round(root.height / 2 - root.iconSize / 2 - height * 0.25)
        width: Appearance.bar.dot
        height: width
        radius: width / 2
        color: Colours.primary
        // Ringed in the bar's own surface, so it reads as a separate mark
        // rather than as part of the glyph under it.
        border.width: Appearance.widget.hairline
        border.color: Colours.surfaceBarAttached
        scale: root.dot ? 1 : 0
        visible: scale > 0

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Appearance.anim.enterEasing
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton)
                root.secondaryClicked();
            else
                root.clicked();
        }
        // One `scrolled` per wheel notch: a touchpad's stream of small
        // deltas used to move the volume two percent on every one of them.
        property real pendingWheel: 0
        onWheel: event => {
            pendingWheel += event.angleDelta.y;
            if (Math.abs(pendingWheel) < 120)
                return;
            root.scrolled(pendingWheel);
            pendingWheel = 0;
        }
    }
}
