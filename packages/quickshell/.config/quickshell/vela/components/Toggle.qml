import QtQuick
import qs.tokens

// A binary setting: airplane mode in the Network popout, generate-from-wallpaper
// and reduce motion on the Appearance page. Two sizes in the design -- 40x22 in
// a popout, 44x26 in the settings window -- and the knob's 3px gutter is the
// same in both, so only the track is a property.
//
//     Toggle {
//         checked: Config.appearance.reduceMotion
//         onToggled: on => Config.appearance.reduceMotion = on
//     }
//
// On is `primary` with an `on.primary` knob: an enabled control is one of the
// three things the design lets carry colour. Off is a neutral track with an
// `outline` knob -- never a red one; off is not an error.
Item {
    id: root

    property bool checked: false
    property bool interactive: true

    property int trackWidth: Appearance.widget.toggleWidth
    property int trackHeight: Appearance.widget.toggleHeight
    // The gutter the knob sits in, constant at both of the design's sizes.
    readonly property int inset: Appearance.widget.toggleInset
    readonly property int knobSize: root.trackHeight - root.inset * 2

    signal toggled(bool checked)

    implicitWidth: root.trackWidth
    implicitHeight: root.trackHeight

    activeFocusOnTab: root.interactive

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.toggle();
            event.accepted = true;
        }
    }

    function toggle(): void {
        root.checked = !root.checked;
        root.toggled(root.checked);
    }

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Colours.primary : Colours.track

        Behavior on color {
            enabled: !Colours.crossing

            ColorAnimation {
                duration: Appearance.anim.fast
                easing.type: Appearance.anim.enterEasing
            }
        }

        Rectangle {
            id: knob

            width: root.knobSize
            height: root.knobSize
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - root.inset : root.inset
            color: root.checked ? Colours.on.primary : Colours.outline

            // The knob's travel is translation, which `reduceMotion` removes
            // outright rather than shortens -- so it snaps, and the colour
            // change alone carries the state.
            Behavior on x {
                NumberAnimation {
                    duration: Appearance.reduceMotion ? 0 : Appearance.anim.fast
                    easing.type: Appearance.anim.enterEasing
                }
            }

            Behavior on color {
                enabled: !Colours.crossing

                ColorAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Appearance.anim.enterEasing
                }
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width + Appearance.space.xs * 2
        height: parent.height + Appearance.space.xs * 2
        radius: height / 2
        color: "transparent"
        border.width: Appearance.widget.hairline
        border.color: Colours.primary
        visible: root.activeFocus
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.toggle();
        }
    }
}
