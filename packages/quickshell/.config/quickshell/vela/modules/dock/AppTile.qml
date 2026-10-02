pragma ComponentBehavior: Bound

import QtQuick
import qs.tokens
import qs.components

// One item in the dock -- an application or a stack. The design gives both the
// same tile, and the only differences are what the click does and whether there
// is a dot under it, so this is one component rather than two.
//
// MAGNIFICATION IS FOUR DISCRETE STEPS, not a curve. The design draws
// 52 / 56 / 60 / 68 with a glyph and a corner for each, so the size is chosen
// by how far the item is from the one under the cursor and then animated to; a
// continuous falloff would be a different design and would never land on those
// numbers. Every item reserves the height of the largest step, so the dock does
// not change shape as the cursor crosses it.
Item {
    id: root

    // One entry of the dock's model.
    required property var item
    // Distance, in items, from the one under the cursor. -1 when nothing is.
    required property int distance
    required property bool magnify

    // Bound by the dock rather than carried in the model, so a window opening
    // or a folder gaining a file does not rebuild every delegate in the row --
    // which would drop the hover the magnification is reading.
    property bool running: false
    property int badge: 0
    // A stack whose panel is open is the enabled control on this screen, and
    // the only thing in the dock allowed to carry colour besides a running dot.
    property bool accent: false

    readonly property bool hovered: hover.hovered

    signal activated
    signal secondary

    // The same table the dock lays the row out from, so the tile it draws and
    // the space it was given are never a pixel apart.
    readonly property int side: Appearance.dock.sideAt(root.magnify ? root.distance : -1)
    readonly property real glyph: Appearance.dock.glyphAt(root.magnify ? root.distance : -1)

    implicitWidth: root.side
    // The tallest step plus the dot, always: bottom-aligned content in a fixed
    // box beats asking a positioner to align things it is also measuring.
    implicitHeight: Appearance.dock.tileHover + Appearance.dock.dotGap + Appearance.dock.runningDot

    // Gated with the rest of the magnifier: this width is what pushes every
    // neighbour sideways, so animating it under reduced motion puts the
    // translation back that the `Behavior on x` gates removed.
    Behavior on implicitWidth {
        enabled: !Appearance.reduceMotion

        NumberAnimation {
            duration: Appearance.anim.fast
            easing.type: Appearance.anim.enterEasing
        }
    }

    Rectangle {
        id: tile

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - Appearance.dock.runningDot - Appearance.dock.dotGap - height
        // The item's own width, which is already animating: one Behavior for
        // the whole magnification rather than three that could drift apart.
        width: root.width
        height: root.width
        radius: Appearance.dock.tileRadius(width)
        color: root.accent ? Colours.primaryContainer : Colours.hover

        Behavior on color {
            enabled: !Colours.crossing

            ColorAnimation {
                duration: Appearance.anim.fast
                easing.type: Appearance.anim.enterEasing
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Colours.hover
            opacity: root.hovered && !root.accent ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Appearance.anim.enterEasing
                }
            }
        }

        // The app's own icon, when an icon theme is chosen; a stack is always
        // its glyph. Decoded once at the largest step, so the magnification
        // scales a picture rather than redrawing an SVG every frame.
        AppIcon {
            anchors.centerIn: parent
            source: root.item.image ?? ""
            glyph: root.item.icon
            size: root.glyph
            imageSize: tile.width * Appearance.size.appIconFill
            decodeSize: Appearance.dock.tileHover * Appearance.size.appIconFill
            color: root.accent ? Colours.on.primaryContainer : Colours.on.surfaceVariant

            Behavior on size {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Appearance.anim.enterEasing
                }
            }
        }

        // The stack's count badge. Primary rather than error: it is a number of
        // things waiting, not a problem.
        Rectangle {
            visible: root.badge > 0
            x: parent.width - width + Appearance.dock.badgeOffset
            y: -Appearance.dock.badgeOffset
            implicitWidth: Math.max(Appearance.dock.badge, badge.implicitWidth + Appearance.dock.badgePadding * 2)
            implicitHeight: Appearance.dock.badge
            radius: height / 2
            color: Colours.primary

            Text {
                id: badge

                anchors.centerIn: parent
                // A count is a number, so it is mono.
                text: root.badge > 99 ? qsTr("99+") : `${root.badge}`
                font.family: Appearance.font.mono
                font.pixelSize: Appearance.dock.badgeSize
                font.weight: Font.Medium
                color: Colours.on.primary
            }
        }
    }

    // Running, in the one place a dock has room to say it.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - height
        implicitWidth: Appearance.dock.runningDot
        implicitHeight: Appearance.dock.runningDot
        radius: height / 2
        color: Colours.primary
        opacity: root.running ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Appearance.anim.enterEasing
            }
        }
    }

    // A HoverHandler rather than the MouseArea's own hover: the dock reads it
    // to magnify the neighbours, and a handler reports the cursor without
    // taking it away from anything else.
    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: event => {
            if (event.button === Qt.MiddleButton)
                root.secondary();
            else
                root.activated();
        }
    }
}
