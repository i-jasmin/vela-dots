pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.services
import qs.components

// Off the privacy capsule on the bar: which applications have the microphone,
// the camera and the screen, one row each for whatever is in use.
//
// The microphone row is the one with a control, because it is the one you can
// do something about from here: mute the input, which every recording stream
// on it goes quiet with. A camera or a screen share is stopped in the
// application that started it.
PopoutContent {
    id: root

    readonly property var uses: [
        {
            key: "mic",
            icon: Audio.micMuted ? "mic_off" : "mic",
            title: Audio.micMuted ? qsTr("Microphone, muted") : qsTr("Microphone"),
            apps: Privacy.mic
        },
        {
            key: "camera",
            icon: "videocam",
            title: qsTr("Camera"),
            apps: Privacy.camera
        },
        {
            key: "screen",
            icon: "screen_share",
            title: qsTr("Screen"),
            apps: Privacy.screen
        }
    ].filter(u => u.apps.length > 0)

    icon: "privacy_tip"
    heading: qsTr("In use")

    Repeater {
        model: root.uses

        Row {
            id: use

            required property var modelData

            icon: use.modelData.icon
            title: use.modelData.title
            subtitle: use.modelData.apps.join(", ")
            interactive: use.modelData.key === "mic"
            iconColour: Colours.tertiary
            trailing: use.modelData.key === "mic" ? mute : null
            onClicked: Audio.toggleMicMute()

            Layout.fillWidth: true
        }
    }

    Empty {
        visible: root.uses.length === 0
        text: qsTr("Nothing is using them now")
    }

    Component {
        id: mute

        Pill {
            text: Audio.micMuted ? qsTr("Unmute") : qsTr("Mute")
            tone: "subtle"
            onClicked: Audio.toggleMicMute()
        }
    }
}
