import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.tokens
import qs.services
import qs.components

// Bottom left of the lock screen: what is playing, and the three controls for
// it. Playing media is one of the three things the design lets carry colour,
// and the transport button is where this screen spends it -- paused, it goes
// neutral like everything else.
LockChip {
    id: root

    readonly property bool hasArt: art.status === Image.Ready

    implicitHeight: Appearance.lock.mediaHeight
    implicitWidth: row.implicitWidth + Appearance.lock.chipPadding * 2

    // A bare glyph with a hit target around it -- the design draws no button
    // under these three, only the icons.
    component Control: Item {
        id: control

        property string icon
        property real size: Appearance.size.iconMd
        property color tint: Colours.on.surfaceVariant
        property bool active: true

        signal triggered

        implicitWidth: glyph.implicitWidth
        implicitHeight: glyph.implicitHeight
        opacity: control.active ? 1 : 0.38

        Icon {
            id: glyph

            anchors.centerIn: parent
            text: control.icon
            size: control.size
            color: control.tint
        }

        MouseArea {
            anchors.centerIn: parent
            width: Math.max(parent.width, Appearance.space.xl)
            height: Math.max(parent.height, Appearance.space.xl)
            enabled: control.active
            cursorShape: Qt.PointingHandCursor
            onClicked: control.triggered()
        }
    }

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.leftMargin: Appearance.lock.chipPadding
        anchors.rightMargin: Appearance.lock.chipPadding
        spacing: Appearance.lock.mediaGap

        ClippingRectangle {
            implicitWidth: Appearance.lock.mediaArt
            implicitHeight: Appearance.lock.mediaArt
            radius: Appearance.radius.chip
            color: Colours.surfaceContainer

            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                visible: !root.hasArt
                gradient: Gradient {
                    orientation: Gradient.Vertical

                    // Quieter than the avatar's, which is the same two tones
                    // at full strength: the design's art placeholder is a
                    // muted teal, not an accent, and a bright tile here would
                    // read as a second thing the screen is colouring.
                    GradientStop {
                        position: 0
                        color: Colours.alpha(Colours.primaryContainer, 0.7)
                    }

                    GradientStop {
                        position: 1
                        color: Colours.alpha(Colours.primaryContainer, 0)
                    }
                }
            }

            Icon {
                anchors.centerIn: parent
                visible: !root.hasArt
                text: "album"
                size: Appearance.size.iconMd
                color: Colours.muted
            }

            Image {
                id: art

                anchors.fill: parent
                source: Players.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: Appearance.lock.mediaArt * 2
                sourceSize.height: Appearance.lock.mediaArt * 2
                asynchronous: true
                cache: true
                visible: root.hasArt
            }
        }

        ColumnLayout {
            spacing: Appearance.space.xs / 2

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Appearance.lock.mediaTextWidth

            Text {
                text: Players.title
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.body
                color: Colours.on.surface
                elide: Text.ElideRight

                Layout.fillWidth: true
            }

            Text {
                text: Players.artist
                visible: text !== ""
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.caption
                color: Colours.outline
                elide: Text.ElideRight

                Layout.fillWidth: true
            }
        }

        RowLayout {
            spacing: Appearance.lock.mediaControlGap

            Layout.alignment: Qt.AlignVCenter

            Control {
                icon: "skip_previous"
                active: Players.canGoPrevious
                onTriggered: Players.previous()
            }

            Control {
                icon: Players.playing ? "pause_circle" : "play_circle"
                size: Appearance.lock.mediaPlayIcon
                tint: Players.playing ? Colours.primary : Colours.on.surfaceVariant
                onTriggered: Players.playPause()
            }

            Control {
                icon: "skip_next"
                active: Players.canGoNext
                onTriggered: Players.next()
            }
        }
    }
}
