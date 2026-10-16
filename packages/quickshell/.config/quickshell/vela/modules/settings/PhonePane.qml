pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.tokens
import qs.components

// Phone -- KDE Connect: setting it up, pairing a phone, and what vela does
// with what the phone sends.
//
// Pairing is KDE Connect's own and stays in its files; the page asks it
// through `vela phone` (services/Phone.qml) and draws what it reports. A
// request either way shows the key both screens draw, to be compared before
// it is accepted: it is what makes sure the phone answering is yours.
PaneScroll {
    id: root

    // Every device not paired that is worth a line: asking to pair, being
    // asked, or simply on this network. Asking first.
    readonly property var unpaired: Phone.devices.filter(d => !d.paired && (d.reachable || d.incoming || d.outgoing)).sort((a, b) => (b.incoming ? 1 : 0) - (a.incoming ? 1 : 0))

    // The phone Unpair was pressed for once; pressed again, it goes.
    property string confirming: ""

    // "Paired · connected over Wi-Fi · 72%, charging"
    function detailOf(d: var): string {
        const parts = [qsTr("Paired")];
        if (!d.reachable)
            parts.push(qsTr("not in reach"));
        else if (d.via.includes("lan"))
            parts.push(qsTr("connected over Wi-Fi"));
        else if (d.via.includes("bluetooth"))
            parts.push(qsTr("connected over Bluetooth"));
        else
            parts.push(qsTr("connected"));
        const charge = d.battery?.charge ?? -1;
        if (d.reachable && charge >= 0)
            parts.push(d.battery.charging ? qsTr("%1%, charging").arg(charge) : qsTr("%1%").arg(charge));
        return parts.join(" · ");
    }

    function home(path: string): string {
        const h = Quickshell.env("HOME");
        return h && path.startsWith(h) ? `~${path.slice(h.length)}` : path;
    }

    // Looked at again whenever the window opens: Set up may have finished
    // in between, or the package gone.
    Component.onCompleted: Phone.check()

    Connections {
        target: ShellState

        function onSettingsChanged(): void {
            if (ShellState.settings)
                Phone.check();
            root.confirming = "";
        }
    }

    Timer {
        interval: Appearance.settings.confirmWindow
        running: root.confirming !== ""
        onTriggered: root.confirming = ""
    }

    PaneHeader {
        title: qsTr("Phone")
    }

    // What KDE Connect is doing, and what this PC is called to a phone.
    RowLayout {
        spacing: Appearance.space.sm

        Layout.fillWidth: true
        Layout.topMargin: -Appearance.space.sm

        Rectangle {
            implicitWidth: Appearance.bar.dot
            implicitHeight: Appearance.bar.dot
            radius: width / 2
            color: Phone.running ? Colours.primary : Phone.problem ? Colours.error : Colours.outline

            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: Phone.running ? qsTr("KDE Connect is running · this PC is “%1” on the network").arg(Phone.name) : !Phone.installed ? qsTr("KDE Connect is not set up") : Phone.problem || qsTr("KDE Connect is installed, and starting")
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.label
            color: Phone.problem && !Phone.running ? Colours.error : Colours.on.surfaceVariant
            wrapMode: Text.WordWrap

            Layout.fillWidth: true
        }
    }

    // ---- set up ------------------------------------------------------------
    Section {
        visible: !Phone.installed
        title: qsTr("Set up")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("KDE Connect")
            subtitle: qsTr("Installs KDE Connect's background service and sshfs with dnf, in a terminal, and opens its ports in the firewall. Then get KDE Connect on the phone, from Google Play or F-Droid, and open it on the same Wi-Fi.")
            leading: Icon {
                text: "smartphone"
                size: Appearance.settings.tileIcon
                color: Colours.on.surfaceVariant
            }

            Pill {
                text: qsTr("Set up")
                icon: "download"
                tone: "filled"
                pillHeight: Appearance.settings.actionHeight
                fontSize: Appearance.settings.actionSize
                onClicked: Phone.setup()

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // ---- your phone ----------------------------------------------------------
    Section {
        visible: Phone.running
        title: Phone.paired.length > 1 ? qsTr("Your phones") : qsTr("Your phone")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            visible: Phone.paired.length === 0
            title: qsTr("No phone paired yet")
            subtitle: qsTr("Open KDE Connect on the phone, on the same Wi-Fi, and pick “%1”. Its request shows up below, with a key to check.").arg(Phone.name)
            leading: Icon {
                text: "smartphone"
                size: Appearance.settings.tileIcon
                color: Colours.outline
            }
        }

        Repeater {
            model: Phone.paired

            SettingRow {
                id: device

                required property var modelData

                title: device.modelData.name
                subtitle: root.detailOf(device.modelData)
                labelGap: Appearance.settings.labelGap
                leading: Rectangle {
                    implicitWidth: Appearance.settings.phoneTile
                    implicitHeight: Appearance.settings.phoneTile
                    radius: Appearance.bar.tileRadius(Appearance.settings.phoneTile)
                    color: device.modelData.reachable ? Colours.primaryContainer : Colours.hover

                    Icon {
                        anchors.centerIn: parent
                        text: Phone.iconFor(device.modelData)
                        size: Appearance.settings.tileIcon
                        color: device.modelData.reachable ? Colours.on.primaryContainer : Colours.outline
                    }
                }

                Pill {
                    readonly property bool asking: root.confirming === device.modelData.id

                    text: asking ? qsTr("Unpair?") : qsTr("Unpair")
                    tone: asking ? "danger" : "subtle"
                    pillHeight: Appearance.settings.segmentHeight
                    fontSize: Appearance.settings.actionSize
                    onClicked: {
                        if (asking) {
                            root.confirming = "";
                            Phone.unpair(device.modelData.id);
                        } else {
                            root.confirming = device.modelData.id;
                        }
                    }

                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    // ---- nearby ------------------------------------------------------------
    Section {
        visible: Phone.running && root.unpaired.length > 0
        title: qsTr("Nearby")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        Repeater {
            model: root.unpaired

            ColumnLayout {
                id: other

                required property var modelData

                readonly property bool asking: other.modelData.incoming || other.modelData.outgoing

                spacing: Appearance.settings.cardGapTight

                Layout.fillWidth: true

                SettingRow {
                    title: other.modelData.name
                    subtitle: other.modelData.incoming ? qsTr("Wants to pair. Check that both screens show this key.") : other.modelData.outgoing ? qsTr("Waiting: accept there if both screens show this key.") : qsTr("On this network, not paired")
                    labelGap: Appearance.settings.labelGap
                    leading: Icon {
                        text: Phone.iconFor(other.modelData)
                        size: Appearance.settings.tileIcon
                        color: Colours.on.surfaceVariant
                    }

                    Pill {
                        visible: other.asking
                        text: other.modelData.incoming ? qsTr("Refuse") : qsTr("Cancel")
                        tone: "subtle"
                        pillHeight: Appearance.settings.segmentHeight
                        fontSize: Appearance.settings.actionSize
                        onClicked: Phone.refuse(other.modelData.id)

                        Layout.alignment: Qt.AlignVCenter
                    }

                    Pill {
                        visible: !other.modelData.outgoing
                        text: qsTr("Pair")
                        tone: other.modelData.incoming ? "filled" : "subtle"
                        pillHeight: Appearance.settings.segmentHeight
                        fontSize: Appearance.settings.actionSize
                        onClicked: Phone.pair(other.modelData.id)

                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                // The key both screens draw for this pairing.
                Rectangle {
                    visible: other.asking && other.modelData.key !== ""
                    implicitHeight: Appearance.settings.phoneKeyHeight
                    radius: Appearance.radius.card
                    color: Colours.hover

                    Layout.fillWidth: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Appearance.space.md
                        anchors.rightMargin: Appearance.space.md
                        spacing: Appearance.space.md

                        Icon {
                            text: "key"
                            size: Appearance.settings.tileIconSmall
                            color: Colours.primary
                        }

                        Text {
                            text: other.modelData.key
                            font.family: Appearance.font.mono
                            font.pixelSize: Appearance.settings.phoneKeySize
                            font.letterSpacing: Appearance.settings.phoneKeySize * 0.15
                            color: Colours.on.surface

                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    // ---- on this pc ----------------------------------------------------------
    Section {
        visible: Phone.installed
        title: qsTr("On this PC")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("The phone's notifications")
            subtitle: qsTr("Shown here as cards, with Reply where the app on the phone takes one")
            leading: Icon {
                text: "notifications"
                size: Appearance.settings.tileIconSmall
                color: Colours.on.surfaceVariant
            }

            Toggle {
                readonly property bool wanted: Config.phone.notifications

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.phone.notifications = on;
                    Persist.commit();
                }
                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("One-time codes")
            subtitle: qsTr("A Copy code button on a text that carries one, kept out of clipboard history")
            leading: Icon {
                text: "pin"
                size: Appearance.settings.tileIconSmall
                color: Colours.on.surfaceVariant
            }

            Toggle {
                readonly property bool wanted: Config.phone.codes

                checked: wanted
                interactive: Config.phone.notifications
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.phone.codes = on;
                    Persist.commit();
                }
                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("Send copies to the phone")
            subtitle: qsTr("What you copy here can be pasted on the phone. The phone sends its own when you tap Send clipboard there.")
            leading: Icon {
                text: "sync_alt"
                size: Appearance.settings.tileIconSmall
                color: Colours.on.surfaceVariant
            }

            Toggle {
                readonly property bool wanted: Phone.phone?.autoShare ?? false

                checked: wanted
                interactive: Phone.connected
                onWantedChanged: checked = wanted
                onToggled: on => Phone.setAutoShare(Phone.phone.id, on)
                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("On the bar")
            subtitle: qsTr("While the phone is in reach: its charge, and the way to its popout. Move it in Modules.")
            leading: Icon {
                text: "view_quilt"
                size: Appearance.settings.tileIconSmall
                color: Colours.on.surfaceVariant
            }

            Toggle {
                readonly property bool wanted: Phone.onBar

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => Phone.showOnBar(on)
                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            visible: (Phone.phone?.folder ?? "") !== ""
            title: qsTr("Files from the phone")
            detail: root.home(Phone.phone?.folder ?? "")
            subtitle: qsTr("Where KDE Connect saves what the phone sends")
            labelGap: Appearance.settings.labelGap
            leading: Icon {
                text: "download"
                size: Appearance.settings.tileIconSmall
                color: Colours.on.surfaceVariant
            }

            Pill {
                text: qsTr("Open")
                tone: "subtle"
                pillHeight: Appearance.settings.segmentHeight
                fontSize: Appearance.settings.actionSize
                onClicked: Phone.open(Phone.phone.folder)

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
