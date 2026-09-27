pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.services
import qs.components

// The bar's third control popout: the devices the machine has a relationship
// with, connected first, each with its type glyph and whatever battery it
// reports.
//
// Discovery costs airtime and battery, so nothing turns it on speculatively.
// The `Binding` below holds it on for as long as the popout is on screen and
// restores the previous value when the shell's loader destroys this content --
// the same shape as the Wi-Fi scan next door.
//
// THE BATTERY LINE IS UNPROVEN. It was built on a machine with nothing paired,
// so in practice every row here was an empty state. `Bt.detail()` composes
// "Connected · 84%" from `batteryAvailable` and a fractional 0-1 level that the
// service already rounds -- the same trap as UPower's percentage -- and a
// device that does not report one falls back to "Connected" on its own. It is
// built to the design and has never been seen with data in it; that is stated
// here rather than hidden.
//
// Both lists show their first few and open out to the rest (PopoutList): a
// scan in a busy office finds a room's worth of headphones and watches.
PopoutContent {
    id: root

    readonly property string emptyText: {
        if (!Bt.available)
            return qsTr("No Bluetooth adapter");
        if (!Bt.enabled)
            return qsTr("Bluetooth is off");
        return qsTr("No paired devices");
    }

    icon: Bt.icon
    heading: qsTr("Bluetooth")

    Binding {
        target: Bt
        property: "discoverable"
        value: true
    }

    PopoutList {
        model: Bt.enabled ? Bt.known : []
        moreText: n => n === 1 ? qsTr("1 more device") : qsTr("%1 more devices").arg(n)

        delegate: Row {
            id: device

            required property var modelData

            // BlueZ answers with a freedesktop icon name; the service maps the
            // two vocabularies so no row has to know about either.
            icon: Bt.deviceIcon(device.modelData)
            title: Bt.deviceName(device.modelData)
            subtitle: Bt.detail(device.modelData)
            selected: device.modelData.connected
            titleColour: device.selected ? Colours.on.surface : Colours.on.surfaceVariant
            onClicked: Bt.toggleConnection(device.modelData)

            Layout.fillWidth: true
        }
    }

    Empty {
        text: root.emptyText
        visible: !Bt.enabled || Bt.known.length === 0
    }

    // Pairing. The scan is already running while this popout is open (the
    // Binding above); these are the named devices it has found.
    Text {
        text: qsTr("Nearby")
        visible: Bt.enabled && Bt.nearby.length > 0
        font.family: Appearance.font.ui
        font.pixelSize: Appearance.size.micro
        font.capitalization: Font.AllUppercase
        color: Colours.outline
        leftPadding: Appearance.space.md

        Layout.fillWidth: true
    }

    PopoutList {
        model: Bt.enabled ? Bt.nearby : []
        moreText: n => qsTr("%1 more nearby").arg(n)

        delegate: Row {
            id: candidate

            required property var modelData

            icon: Bt.deviceIcon(candidate.modelData)
            title: Bt.deviceName(candidate.modelData)
            subtitle: candidate.modelData.pairing ? qsTr("Pairing…") : qsTr("Pair")
            titleColour: Colours.on.surfaceVariant
            onClicked: Bt.pair(candidate.modelData)

            Layout.fillWidth: true

            Connections {
                target: candidate.modelData

                function onPairedChanged(): void {
                    if (candidate.modelData.paired)
                        Bt.connect(candidate.modelData);
                }
            }
        }
    }

    Divider {
        visible: Bt.available
    }

    // The switch that was missing: with Bluetooth off, this popout could only
    // say so, and the one way back on was airplane mode twice -- which takes
    // Wi-Fi down with it.
    RowLayout {
        visible: Bt.available
        spacing: Appearance.space.md

        Layout.fillWidth: true

        Icon {
            text: Bt.enabled ? "bluetooth" : "bluetooth_disabled"
            size: Appearance.size.iconRow
            color: Bt.enabled ? Colours.primary : Colours.outline
        }

        Text {
            text: qsTr("Bluetooth")
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.body
            color: Colours.on.surfaceVariant
            elide: Text.ElideRight

            Layout.fillWidth: true
        }

        Toggle {
            id: power

            checked: Bt.enabled
            trackWidth: Appearance.popout.toggleWidth
            trackHeight: Appearance.popout.toggleHeight
            onToggled: on => Bt.setEnabled(on)

            Binding {
                target: power
                property: "checked"
                value: Bt.enabled
            }
        }
    }
}
