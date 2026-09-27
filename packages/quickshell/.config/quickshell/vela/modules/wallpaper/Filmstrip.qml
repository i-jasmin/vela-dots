pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Widgets
import qs.tokens
import qs.components

// The wallpaper switcher's bottom strip: the folder, at a glance, with
// everything past the eighth counted rather than drawn.
//
// Clicking one centres it in the coverflow -- it selects, it does not apply.
// Applying is the one explicit act on this screen and it lives on the button
// that says so.
RowLayout {
    id: root

    // [{ path, name, thumbnail }]
    property var entries: []

    signal activated(int index)

    readonly property int shown: Math.min(root.entries.length, Appearance.wallpaper.stripShown)
    readonly property int rest: root.entries.length - root.shown

    spacing: Appearance.wallpaper.stripGap

    Repeater {
        model: root.entries.slice(0, root.shown)

        ClippingRectangle {
            id: tile

            required property var modelData
            required property int index

            implicitHeight: Appearance.wallpaper.stripHeight
            radius: Appearance.wallpaper.stripRadius
            color: Colours.surfaceContainerHigh
            opacity: mouse.containsMouse ? 1 : Appearance.wallpaper.stripOpacity

            Layout.fillWidth: true
            Layout.preferredWidth: 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Appearance.anim.enterEasing
                }
            }

            Image {
                anchors.fill: parent
                source: `file://${tile.modelData.thumbnail}`
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 240
                asynchronous: true
                cache: true
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activated(tile.index)
            }
        }
    }

    // The tail of the folder, counted. A dashed outline rather than a filled
    // tile, because there is no picture behind it to show.
    Item {
        id: more

        implicitWidth: Appearance.wallpaper.stripMoreWidth
        implicitHeight: Appearance.wallpaper.stripHeight
        visible: root.rest > 0

        Layout.fillWidth: false

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Colours.alpha(Colours.on.surface, 0.14)
                strokeWidth: 1
                fillColor: "transparent"
                strokeStyle: ShapePath.DashLine
                dashPattern: [Appearance.wallpaper.dashOn, Appearance.wallpaper.dashOff]

                PathRectangle {
                    x: 0.5
                    y: 0.5
                    width: more.width - 1
                    height: more.height - 1
                    radius: Appearance.wallpaper.stripRadius
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Appearance.wallpaper.stripMoreGap

            Icon {
                text: "more_horiz"
                size: Appearance.size.iconLabel
                color: Colours.outline

                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: `+${root.rest}`
                // A count is a numeral.
                font.family: Appearance.font.mono
                font.pixelSize: Appearance.wallpaper.stripMoreSize
                color: Colours.outline

                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
