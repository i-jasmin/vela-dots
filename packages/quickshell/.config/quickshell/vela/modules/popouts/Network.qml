pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import qs.tokens
import qs.services
import qs.components

// The bar's second control popout: the networks the machine can see, and the
// one switch that turns every radio off.
//
// NetworkManager only reports the access point it is already connected to
// unless something has asked it to scan, so a picker that did not ask would
// show exactly one row -- correct, and useless. The scan is turned on for as
// long as this popout is on screen and released with it, which is what the
// `Binding` below does: it restores the previous value when it is destroyed,
// and the shell's loader destroys this content once the popout has faded.
//
// A real scan answers with far more than the three networks the design draws, so
// the strongest few are shown and the rest open out on request, scrolling
// rather than running off the bottom of the screen (PopoutList).
PopoutContent {
    id: root

    readonly property string emptyText: {
        if (!Net.wifiAvailable)
            return qsTr("No Wi-Fi adapter");
        if (Net.wifiBlocked)
            return qsTr("Wi-Fi blocked in hardware");
        if (!Net.wifiEnabled)
            return qsTr("Wi-Fi is off");
        return qsTr("Scanning…");
    }

    // The network the password field is open under, if any.
    property var askingFor: null
    property string askError: ""

    icon: Net.icon
    heading: qsTr("Network")

    Binding {
        target: Net
        property: "scanning"
        value: true
    }

    PopoutList {
        model: Net.networks
        moreText: n => n === 1 ? qsTr("1 more network") : qsTr("%1 more networks").arg(n)

        delegate: ColumnLayout {
            id: entry

            required property var modelData
            readonly property bool asking: root.askingFor === entry.modelData

            spacing: Appearance.space.xs

            Layout.fillWidth: true

            function join(): void {
                if (!psk.text)
                    return;
                Net.connectWithPsk(entry.modelData, psk.text);
                psk.text = "";
                root.askingFor = null;
            }

            Row {
                id: network

                icon: Net.signalIcon(entry.modelData)
                title: entry.modelData.name
                // "Connected · WPA3 · 866 Mb/s", "Open", "Saved".
                subtitle: Net.detail(entry.modelData)
                selected: entry.modelData.connected
                titleColour: network.selected ? Colours.on.surface : Colours.on.surfaceVariant
                // Clicking the network you are on is the only click here with
                // nothing to do, so that is the one that disconnects. A new
                // secured network asks for its password first.
                onClicked: {
                    if (network.selected) {
                        Net.disconnect(entry.modelData);
                    } else if (Net.needsPassword(entry.modelData)) {
                        root.askError = "";
                        root.askingFor = entry.asking ? null : entry.modelData;
                    } else {
                        Net.connect(entry.modelData);
                    }
                }

                Layout.fillWidth: true
            }

            // A saved password that no longer works, or a network whose
            // security was not recognised up front, fails with NoSecrets --
            // the field opens then instead.
            Connections {
                target: entry.modelData
                ignoreUnknownSignals: true

                function onConnectionFailed(reason: int): void {
                    if (reason !== ConnectionFailReason.NoSecrets)
                        return;
                    root.askError = qsTr("Wrong or missing password");
                    root.askingFor = entry.modelData;
                }
            }

            Rectangle {
                visible: entry.asking
                radius: Appearance.radius.small
                color: Colours.surfaceContainerHigh
                border.width: 1
                border.color: psk.activeFocus ? Colours.primary : Colours.outlineVariant
                implicitHeight: Appearance.popout.rowHeight

                Layout.fillWidth: true

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.space.md
                    anchors.rightMargin: Appearance.space.xs
                    spacing: Appearance.space.sm

                    Icon {
                        text: "key"
                        size: Appearance.size.iconRow
                        color: Colours.outline
                    }

                    TextInput {
                        id: psk

                        echoMode: TextInput.Password
                        clip: true
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.body
                        color: Colours.on.surface
                        selectionColor: Colours.primaryContainer

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        onVisibleChanged: {
                            if (visible)
                                psk.forceActiveFocus();
                            else
                                psk.text = "";
                        }

                        Keys.onReturnPressed: entry.join()
                        Keys.onEnterPressed: entry.join()
                        // Esc closes the field first, and the popout only on
                        // the next press.
                        Keys.onEscapePressed: event => {
                            root.askingFor = null;
                            event.accepted = true;
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !psk.text
                            text: root.askError || qsTr("Password")
                            font: psk.font
                            color: root.askError ? Colours.error : Colours.outline
                        }
                    }

                    Pill {
                        text: qsTr("Join")
                        tone: "filled"
                        interactive: psk.text !== ""
                        onClicked: entry.join()
                    }
                }
            }
        }
    }

    Empty {
        text: root.emptyText
        visible: Net.networks.length === 0
    }

    Divider {}

    RowLayout {
        spacing: Appearance.space.md

        Layout.fillWidth: true

        Icon {
            text: "airplanemode_active"
            size: Appearance.size.iconRow
            color: Net.airplane ? Colours.primary : Colours.outline
        }

        Text {
            text: qsTr("Airplane mode")
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.body
            color: Colours.on.surfaceVariant
            elide: Text.ElideRight

            Layout.fillWidth: true
        }

        Toggle {
            id: airplane

            checked: Net.airplane
            trackWidth: Appearance.popout.toggleWidth
            trackHeight: Appearance.popout.toggleHeight
            // Both radios, through the two backends that own them. Neither
            // NetworkManager nor BlueZ takes kindly to being second-guessed
            // through rfkill, so the service goes via them.
            onToggled: on => Net.setAirplane(on)

            // Flipped from anywhere else -- a keybind, nm-applet, the other
            // monitor -- the switch still follows. A plain binding would have
            // been destroyed by the first click on it.
            Binding {
                target: airplane
                property: "checked"
                value: Net.airplane
            }
        }
    }
}
