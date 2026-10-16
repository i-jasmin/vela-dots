pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.services
import qs.components
import qs.modules.bar

// The phone's popout, off its item on the bar: the phone in reach, the four
// things worth doing with it from here, what it sent last, and whether what
// is copied here goes to it.
//
// Everything is KDE Connect's (`Phone`); an action the phone has turned off in
// its own app -- KDE Connect lets each plugin be switched off there -- is
// shown dimmed rather than missing, so the row of four keeps its shape.
//
// Called PhonePopout rather than Phone so it does not shadow the service of
// that name (see Popout.qml on `Power`).
PopoutContent {
    id: root

    readonly property var phone: Phone.phone

    // "Connected · same Wi-Fi", "Connected · Bluetooth · 5G".
    readonly property string detail: {
        if (!Phone.connected)
            return qsTr("Not in reach");
        const parts = [qsTr("Connected")];
        const via = root.phone?.via ?? [];
        if (via.includes("lan"))
            parts.push(qsTr("same Wi-Fi"));
        else if (via.includes("bluetooth"))
            parts.push(qsTr("Bluetooth"));
        if (root.phone?.network)
            parts.push(root.phone.network.type);
        return parts.join(" · ");
    }

    function sizeText(bytes: real): string {
        if (bytes < 1024)
            return qsTr("%1 B").arg(bytes);
        if (bytes < 1024 * 1024)
            return qsTr("%1 KB").arg(Math.round(bytes / 1024));
        return qsTr("%1 MB").arg((bytes / 1024 / 1024).toFixed(1));
    }

    // Today's arrivals by the clock, yesterday's as "yesterday", older ones by
    // the date.
    function whenText(seconds: real): string {
        const then = new Date(seconds * 1000);
        const now = new Date();
        const days = Math.round((new Date(now.getFullYear(), now.getMonth(), now.getDate()) - new Date(then.getFullYear(), then.getMonth(), then.getDate())) / 86400000);
        if (days === 0)
            return Qt.formatTime(then, "HH:mm");
        if (days === 1)
            return qsTr("yesterday");
        return Qt.formatDate(then, "d MMM");
    }

    readonly property var actions: [
        {
            icon: "ring_volume",
            label: qsTr("Ring"),
            plugin: "findmyphone",
            run: () => Phone.ring()
        },
        {
            icon: "upload_file",
            label: qsTr("Send files"),
            plugin: "share",
            run: () => {
                BarPopouts.close();
                Phone.pickFiles();
            }
        },
        {
            icon: "content_paste_go",
            label: qsTr("Clipboard"),
            plugin: "clipboard",
            run: () => Phone.sendClipboard()
        },
        {
            icon: "folder_open",
            label: qsTr("Its files"),
            plugin: "sftp",
            run: () => {
                BarPopouts.close();
                Phone.browse();
            }
        }
    ]

    icon: Phone.iconFor(root.phone)
    heading: qsTr("Phone")
    popoutWidth: Appearance.popout.phoneWidth

    Row {
        icon: Phone.iconFor(root.phone)
        title: root.phone?.name ?? qsTr("No phone")
        subtitle: root.detail
        selected: Phone.connected
        interactive: false
        trailing: Phone.battery >= 0 ? charge : null

        Layout.fillWidth: true

        Component {
            id: charge

            RowLayout {
                spacing: Appearance.space.xs

                Icon {
                    text: Phone.batteryIcon(Phone.battery, Phone.charging)
                    size: Appearance.size.iconLabel
                    color: Colours.on.primaryContainer
                }

                Text {
                    text: `${Phone.battery}%`
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.size.label
                    color: Colours.on.primaryContainer
                }
            }
        }
    }

    GridLayout {
        columns: root.actions.length
        columnSpacing: Appearance.popout.phoneTileGap
        rowSpacing: 0

        Layout.fillWidth: true

        Repeater {
            model: root.actions

            Rectangle {
                id: tile

                required property var modelData

                readonly property bool usable: Phone.connected && Phone.has(tile.modelData.plugin)

                radius: Appearance.radius.tile
                color: Colours.surfaceContainerHigh
                opacity: tile.usable ? 1 : 0.45
                activeFocusOnTab: tile.usable

                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.popout.phoneTile

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        tile.modelData.run();
                        event.accepted = true;
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Colours.hover
                    visible: mouse.containsMouse
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 2
                    border.color: Colours.primary
                    visible: tile.activeFocus
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Appearance.space.xs

                    Icon {
                        text: tile.modelData.icon
                        size: Appearance.size.iconMd
                        color: Colours.on.surface
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: tile.modelData.label
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.micro
                        color: Colours.on.surfaceVariant
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    enabled: tile.usable
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tile.modelData.run()
                }
            }
        }
    }

    // What the phone sent most recently; the folder they went to.
    RowLayout {
        visible: Phone.received.length > 0

        Layout.fillWidth: true
        Layout.topMargin: Appearance.space.xs

        SectionLabel {
            text: qsTr("Received")
            leftPadding: Appearance.space.md
            Layout.fillWidth: true
        }

        Text {
            text: qsTr("Open folder")
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.micro
            color: Colours.primary
            rightPadding: Appearance.space.md

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    BarPopouts.close();
                    Phone.open(root.phone?.folder ?? "");
                }
            }
        }
    }

    Repeater {
        model: Phone.received.slice(0, Appearance.popout.phoneShown)

        Row {
            id: file

            required property var modelData

            readonly property bool picture: /\.(jpe?g|png|webp|gif|heic|avif)$/i.test(file.modelData.name)

            title: file.modelData.name
            subtitle: `${root.sizeText(file.modelData.size)} · ${root.whenText(file.modelData.time)}`
            titleColour: Colours.on.surfaceVariant
            leading: file.picture ? thumb : glyph
            onClicked: {
                BarPopouts.close();
                Phone.open(file.modelData.path);
            }

            Layout.fillWidth: true

            Component {
                id: thumb

                Rectangle {
                    implicitWidth: Appearance.popout.phoneThumb
                    implicitHeight: Appearance.popout.phoneThumb
                    radius: Appearance.radius.small
                    color: Colours.surfaceContainerHigh
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: `file://${file.modelData.path}`
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: Appearance.popout.phoneThumb * 2
                        sourceSize.height: Appearance.popout.phoneThumb * 2
                    }
                }
            }

            Component {
                id: glyph

                Rectangle {
                    implicitWidth: Appearance.popout.phoneThumb
                    implicitHeight: Appearance.popout.phoneThumb
                    radius: Appearance.radius.small
                    color: Colours.surfaceContainerHigh

                    Icon {
                        anchors.centerIn: parent
                        text: /\.pdf$/i.test(file.modelData.name) ? "picture_as_pdf" : "draft"
                        size: Appearance.size.iconLabel
                        color: Colours.on.surfaceVariant
                    }
                }
            }
        }
    }

    Divider {}

    RowLayout {
        spacing: Appearance.space.md
        visible: root.phone !== null

        Layout.fillWidth: true
        Layout.leftMargin: Appearance.space.md

        Icon {
            text: "sync_alt"
            size: Appearance.size.iconRow
            color: Colours.outline
        }

        Text {
            text: qsTr("Send copies to the phone")
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.body
            color: Colours.on.surfaceVariant
            elide: Text.ElideRight

            Layout.fillWidth: true
        }

        Toggle {
            id: share

            checked: root.phone?.autoShare ?? false
            interactive: Phone.connected
            trackWidth: Appearance.popout.toggleWidth
            trackHeight: Appearance.popout.toggleHeight
            onToggled: on => Phone.setAutoShare(root.phone.id, on)

            Binding {
                target: share
                property: "checked"
                value: root.phone?.autoShare ?? false
            }
        }
    }
}
