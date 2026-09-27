import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.tokens
import qs.config

// Who is being asked for a password. The design draws a monogram; ~/.face is
// shown instead where there is one, which is the same rule the dashboard's
// profile card follows.
//
// This duplicates that card's avatar. It should be one `components/Avatar.qml`
// used by both, and is not yet.
RowLayout {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string user: Quickshell.env("USER") || Quickshell.env("LOGNAME")
    readonly property string facePath: {
        const p = Config.dashboard.profilePicture ?? "";
        return p.startsWith("~") ? root.home + p.slice(1) : p;
    }
    // A FileView, not the Image's own status: pointing an Image at a missing
    // ~/.face makes Qt log "Cannot open" on every render. This answers the same
    // question silently, and the Image is only given a source once the file is
    // known to open.
    readonly property bool hasFace: faceProbe.found

    FileView {
        id: faceProbe

        property bool found: false

        path: root.facePath
        printErrors: false
        onLoaded: faceProbe.found = true
        onLoadFailed: faceProbe.found = false
    }

    spacing: Appearance.lock.identityGap

    ClippingRectangle {
        id: avatar

        implicitWidth: Appearance.lock.avatar
        implicitHeight: Appearance.lock.avatar
        radius: width / 2
        color: Colours.primaryContainer
        border.width: 1
        border.color: Colours.alpha(Colours.on.primaryContainer, 0.24)

        Layout.alignment: Qt.AlignVCenter

        // The design's gradient, read out of the two tones it is built from
        // rather than as two hexes: a lit edge falling to the container.
        Rectangle {
            anchors.fill: parent
            visible: !root.hasFace
            gradient: Gradient {
                orientation: Gradient.Vertical

                GradientStop {
                    position: 0
                    color: Colours.primaryContainer
                }

                GradientStop {
                    position: 1
                    color: Colours.surfaceContainerHigh
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !root.hasFace
            text: root.user.slice(0, 1).toLowerCase()
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.subheading
            font.weight: Font.Light
            color: Colours.on.primaryContainer
        }

        Image {
            id: face

            anchors.fill: parent
            source: root.hasFace ? `file://${root.facePath}` : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: avatar.width * 2
            sourceSize.height: avatar.height * 2
            asynchronous: true
            cache: true
            visible: root.hasFace
        }
    }

    Text {
        text: root.user
        font.family: Appearance.font.ui
        font.pixelSize: Appearance.size.subheading
        color: Colours.on.surface

        Layout.alignment: Qt.AlignVCenter
    }
}
