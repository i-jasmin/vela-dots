pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.services
import qs.components

// The bar's first control popout: everything you would change about sound, and
// nothing you would only look at.
//
// Three sections, in the order the design puts them. The devices you can send
// audio to, with the current one in `primaryContainer` and a check -- the one
// selected row on the screen, and therefore the one thing here allowed colour.
// Then the master level. Then a slider per application that is actually
// playing, which is the part that makes this a mixer rather than a volume key.
//
// There is no meter, no spectrum and no album art: those are the dashboard's,
// and the rule the design states is that they appear there and nowhere else.
PopoutContent {
    id: root

    // The device you are listening on, first. `Net.networks` and `Bt.known`
    // are sorted this way by their own services and the design draws all three
    // lists the same; `Audio.sinks` comes out of PipeWire in node order, so
    // the sort happens here until it moves into the service.
    readonly property var devices: {
        const all = [...Audio.sinks];
        all.sort((a, b) => {
            const da = Audio.isDefaultSink(a);
            const db = Audio.isDefaultSink(b);
            if (da !== db)
                return da ? -1 : 1;
            return Audio.deviceName(a).localeCompare(Audio.deviceName(b));
        });
        return all;
    }

    icon: Audio.icon
    heading: qsTr("Output")

    Repeater {
        model: root.devices

        Row {
            id: device

            required property var modelData

            icon: Audio.deviceIcon(device.modelData)
            title: Audio.deviceName(device.modelData)
            // "AAC · 84% battery" -- only a Bluetooth sink has anything to say
            // here, and a built-in card draws one line instead of two.
            subtitle: Audio.deviceDetail(device.modelData)
            selected: Audio.isDefaultSink(device.modelData)
            // A device list dims the rows that are not current; the launcher,
            // where every row is an equal candidate, does not.
            titleColour: device.selected ? Colours.on.surface : Colours.on.surfaceVariant
            onClicked: Audio.setSink(device.modelData)

            Layout.fillWidth: true
        }
    }

    Empty {
        text: qsTr("No output devices")
        visible: root.devices.length === 0
    }

    Divider {}

    RowLayout {
        spacing: Appearance.space.md

        Layout.fillWidth: true

        Icon {
            id: masterIcon

            text: Audio.icon
            size: Appearance.size.iconRow
            color: Audio.muted ? Colours.outline : Colours.on.surfaceVariant

            // Not in the design, and invisible until used: the glyph beside a
            // volume slider is the one place a mute has an obvious home, and
            // the slider itself cannot carry it without becoming a second
            // control.
            MouseArea {
                anchors.fill: parent
                anchors.margins: -Appearance.space.xs
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.toggleMute()
            }
        }

        Slider {
            id: master

            value: Audio.volume
            // Muting does not move the slider -- the level is still the level --
            // so the fill states it the way the glyph does.
            fill: Audio.muted ? Colours.outline : Colours.primary
            onMoved: v => Audio.setVolume(v)

            Layout.fillWidth: true

            // A plain `value:` binding would be destroyed the first time the
            // user dragged the handle, and the slider would stop following the
            // volume keys from then on. A Binding element re-asserts.
            Binding {
                target: master
                property: "value"
                value: Audio.volume
            }
        }

        Text {
            text: Audio.percent
            font.family: Appearance.font.mono
            font.pixelSize: Appearance.size.caption
            color: Colours.outline
            horizontalAlignment: Text.AlignRight

            Layout.preferredWidth: Appearance.popout.valueWidth
        }
    }

    SectionLabel {
        text: qsTr("Per app")

        Layout.fillWidth: true
    }

    Repeater {
        model: Audio.streams

        RowLayout {
            id: stream

            required property var modelData

            spacing: Appearance.space.md

            Layout.fillWidth: true

            Icon {
                text: Audio.streamIcon(stream.modelData)
                size: Appearance.size.iconSm
                color: Colours.outline
            }

            Slider {
                id: level

                value: Audio.streamVolume(stream.modelData)
                trackHeight: Appearance.popout.streamTrack
                // No handle and no accent: `primary` belongs to the control the
                // user is actually holding, and a per-app row is a level, not a
                // selection.
                handleWidth: 0
                fill: Colours.secondary
                onMoved: v => Audio.setStreamVolume(stream.modelData, v)

                Layout.fillWidth: true

                Binding {
                    target: level
                    property: "value"
                    value: Audio.streamVolume(stream.modelData)
                }
            }

            Text {
                // An application's name is prose, so it stays in the UI face
                // while the numeral above it does not.
                text: Audio.streamName(stream.modelData)
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.micro
                color: Colours.outline
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight

                Layout.preferredWidth: Appearance.popout.streamLabelWidth
            }
        }
    }

    Empty {
        text: qsTr("Nothing playing")
        visible: Audio.streams.length === 0
    }
}
