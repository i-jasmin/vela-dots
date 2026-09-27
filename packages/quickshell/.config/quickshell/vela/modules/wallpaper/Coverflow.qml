pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.tokens

// The switcher's coverflow: 120 / 200 / 360 / 200 / 120, the centre one
// bordered and ringed, with its filename and resolution over a gradient scrim.
//
// Five fixed slots rather than a scrolling strip, and the selection changes by
// the slots taking new images. There is deliberately no travel animation: the
// only honest one is a slide, which needs a strip twice this long to slide
// *into*, and every size in this row is discrete -- animating a card from 200px
// to 360px would be animating size, which nothing in the shell does. The
// border and the ring are the affordance, exactly as they are in the workspace
// overview, the window picker and sessions.
Item {
    id: root

    // [{ path, name, thumbnail, resolution }]
    property var entries: []
    property int index: 0

    signal activated(int index)

    // Wrapping only once there are more images than slots: with four in the
    // folder it would show the same picture twice, which reads as a bug.
    function slotFor(offset: int): var {
        const n = root.entries.length;
        if (n === 0)
            return null;
        if (n > 5) {
            const i = ((root.index + offset) % n + n) % n;
            return {
                i: i,
                entry: root.entries[i]
            };
        }
        const i = root.index + offset;
        if (i < 0 || i >= n)
            return null;
        return {
            i: i,
            entry: root.entries[i]
        };
    }

    // The design's ring is a box-shadow, so it spills into the gaps above and
    // below without taking layout room -- which is why this is the card height
    // exactly, and why nothing here clips: a clip at 226 would cut the ring off.
    implicitHeight: Appearance.wallpaper.centreHeight

    Item {
        anchors.centerIn: parent
        implicitWidth: Appearance.wallpaper.centreWidth + (Appearance.wallpaper.nearWidth + Appearance.wallpaper.cardGap) * 2 + (Appearance.wallpaper.farWidth + Appearance.wallpaper.cardGap) * 2
        implicitHeight: Appearance.wallpaper.centreHeight
        width: implicitWidth
        height: implicitHeight

        Repeater {
            model: [-2, -1, 0, 1, 2]

            Cover {
                required property int modelData

                offset: modelData
            }
        }
    }

    component Cover: Item {
        id: cover

        required property int offset
        readonly property var slot: root.slotFor(cover.offset)
        readonly property int distance: Math.abs(cover.offset)
        readonly property bool centre: cover.distance === 0

        readonly property int cardWidth: cover.centre ? Appearance.wallpaper.centreWidth : cover.distance === 1 ? Appearance.wallpaper.nearWidth : Appearance.wallpaper.farWidth
        readonly property int cardHeight: cover.centre ? Appearance.wallpaper.centreHeight : cover.distance === 1 ? Appearance.wallpaper.nearHeight : Appearance.wallpaper.farHeight
        readonly property int cardRadius: cover.centre ? Appearance.radius.cardLg : cover.distance === 1 ? Appearance.wallpaper.nearRadius : Appearance.radius.chip

        // Laid out from the centre outwards, so the middle card is on the
        // panel's centre line whatever the flanks are doing.
        readonly property int step: cover.offset === 0 ? 0 : cover.offset < 0 ? -(Appearance.wallpaper.centreWidth + Appearance.wallpaper.nearWidth) / 2 - Appearance.wallpaper.cardGap : (Appearance.wallpaper.centreWidth + Appearance.wallpaper.nearWidth) / 2 + Appearance.wallpaper.cardGap
        readonly property int outer: cover.distance < 2 ? 0 : cover.offset < 0 ? -(Appearance.wallpaper.nearWidth + Appearance.wallpaper.farWidth) / 2 - Appearance.wallpaper.cardGap : (Appearance.wallpaper.nearWidth + Appearance.wallpaper.farWidth) / 2 + Appearance.wallpaper.cardGap

        x: Math.round(parent.width / 2 + cover.step + cover.outer - cover.cardWidth / 2)
        y: Math.round((parent.height - cover.cardHeight) / 2)
        width: cover.cardWidth
        height: cover.cardHeight
        // A flank that would run past the panel's edge is dropped rather than
        // cropped: half a photograph under a rounded corner reads as a bug.
        readonly property bool fits: Math.abs(cover.step + cover.outer) + cover.cardWidth / 2 <= root.width / 2
        visible: cover.slot !== null && cover.fits
        opacity: cover.centre ? 1 : cover.distance === 1 ? Appearance.wallpaper.nearOpacity : Appearance.wallpaper.farOpacity

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Appearance.anim.enterEasing
            }
        }

        // The ring: flat, not blurred, so it reads as a second border rather
        // than as a glow.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -Appearance.wallpaper.halo
            radius: cover.cardRadius + Appearance.wallpaper.halo
            visible: cover.centre
            color: Colours.alpha(Colours.primary, Appearance.wallpaper.haloAlpha)
        }

        RectangularShadow {
            anchors.fill: image
            radius: image.radius
            blur: Appearance.wallpaper.centreShadowBlur
            offset: Qt.vector2d(0, Appearance.wallpaper.centreShadowY)
            color: Colours.alpha(Colours.shadow, Appearance.shadow.alpha)
            visible: cover.centre
            cached: true
        }

        ClippingRectangle {
            id: image

            anchors.fill: parent
            radius: cover.cardRadius
            color: Colours.surfaceContainerHigh
            // The selected wallpaper is the one control on this screen that is
            // allowed colour.
            border.width: cover.centre ? Appearance.wallpaper.centreBorder : 0
            border.color: Colours.primary

            Image {
                anchors.fill: parent
                anchors.margins: image.border.width
                source: cover.slot ? `file://${cover.slot.entry.thumbnail}` : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: cover.cardWidth * 2
                asynchronous: true
                cache: true
            }

            // The caption, over a scrim so a filename survives a pale
            // photograph. Centre card only -- the flanks are context.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: Appearance.wallpaper.scrimHeight
                visible: cover.centre && cover.slot !== null

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }

                    GradientStop {
                        position: 1
                        color: Colours.alpha(Colours.shadow, Appearance.wallpaper.scrimAlpha)
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Appearance.wallpaper.scrimPadH
                    anchors.bottomMargin: Appearance.wallpaper.scrimPadBottom
                    text: cover.slot ? cover.slot.entry.name : ""
                    // A filename is a literal.
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.size.body
                    color: Colours.on.surface
                }

                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: Appearance.wallpaper.scrimPadH
                    anchors.bottomMargin: Appearance.wallpaper.scrimPadBottom
                    text: cover.slot ? cover.slot.entry.resolution : ""
                    visible: text !== ""
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.size.micro
                    color: Colours.on.surfaceVariant
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: cover.slot !== null && !cover.centre
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activated(cover.slot.i)
        }
    }
}
