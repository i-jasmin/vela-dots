import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.tokens

// The microphone, the camera, the screen: a glyph for each while something is
// using it, in a `tertiary` capsule, and nothing at all otherwise. It is the
// one thing on the bar that takes a colour of its own without being selected,
// because it is the one thing that has to be noticed without being looked for.
//
// Clicking it opens the popout that says who -- `popouts/InUse.qml` -- with a
// way to mute the microphone from there. The mic glyph crosses out while the
// input is muted, so a call that is on but muted says so here too.
Item {
    id: root

    required property BarState bar

    readonly property bool present: Privacy.any
    readonly property real glyphSize: root.bar.vertical ? Appearance.size.iconRow : Appearance.size.iconLabel
    // The capsule's measure across the bar: the width of a vertical bar's
    // buttons, or the height of a horizontal bar's chips.
    readonly property int cross: root.bar.vertical ? Appearance.bar.iconButton : Appearance.bar.iconButtonH

    implicitWidth: capsule.implicitWidth
    implicitHeight: capsule.implicitHeight

    // The popout names what is in use; once nothing is, there is nothing to
    // anchor it to.
    onPresentChanged: if (!root.present && root.bar.showing("privacy"))
        BarPopouts.close()

    Rectangle {
        id: capsule

        anchors.centerIn: parent
        implicitWidth: root.bar.vertical ? root.cross : flow.implicitWidth + Appearance.bar.privacyPad * 2
        implicitHeight: root.bar.vertical ? flow.implicitHeight + Appearance.bar.privacyPad * 2 : root.cross
        radius: Appearance.bar.tileRadius(root.cross)
        color: Colours.alpha(Colours.tertiary, mouse.containsMouse || root.bar.showing("privacy") ? Appearance.bar.privacyTintHover : Appearance.bar.privacyTint)

        Behavior on color {
            enabled: !Colours.crossing

            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        BarFlow {
            id: flow

            anchors.centerIn: parent
            vertical: root.bar.vertical
            gap: Appearance.space.xs

            Icon {
                visible: Privacy.mic.length > 0
                text: Audio.micMuted ? "mic_off" : "mic"
                size: root.glyphSize
                color: Colours.tertiary

                Layout.alignment: Qt.AlignCenter
            }

            Icon {
                visible: Privacy.camera.length > 0
                text: "videocam"
                size: root.glyphSize
                color: Colours.tertiary

                Layout.alignment: Qt.AlignCenter
            }

            Icon {
                visible: Privacy.screen.length > 0
                text: "screen_share"
                size: root.glyphSize
                color: Colours.tertiary

                Layout.alignment: Qt.AlignCenter
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.bar.popout("privacy", root, undefined)
    }

    Connections {
        target: BarPopouts

        function onRequested(name: string): void {
            if (name === "privacy" && root.bar.forKeys && root.present)
                root.bar.popout(name, root, undefined);
        }
    }
}
