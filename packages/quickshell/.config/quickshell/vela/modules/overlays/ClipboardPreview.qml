import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.services
import qs.components

// The right half of clipboard history: what the selected entry actually is,
// where it came from, and what can be done with it.
//
// PROVENANCE IS THE HONEST PART. cliphist stores an id and a preview line and
// nothing else -- no application, no time -- so `Clipboard` keeps a sidecar and
// stamps entries as it watches them arrive. Anything already in the history the
// first time vela ran has no stamp, and this pane says so rather than printing
// a plausible time.
Item {
    id: root

    property var entry: null
    property bool literal: false

    readonly property string kind: root.entry?.kind ?? ""

    signal pasted
    signal pinned
    signal opened

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.space.panelPadding
        spacing: Appearance.overlays.clipboard.previewGap

        SectionLabel {
            text: qsTr("Preview")

            Layout.fillWidth: true
        }

        Rectangle {
            radius: Appearance.radius.tile
            color: Colours.surfaceContainer
            border.width: 1
            border.color: Colours.panelBorder
            clip: true

            Layout.fillWidth: true
            Layout.fillHeight: true

            Image {
                anchors.fill: parent
                visible: root.kind === "image"
                source: root.kind === "image" ? root.entry.previewPath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }

            // A colour's preview is the colour, at the size of the pane. The
            // hex is already the row's title and the pane's job here is the one
            // thing a 12px string cannot do.
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                visible: root.kind === "colour"
                color: root.kind === "colour" ? root.entry.colour : "transparent"
            }

            Text {
                anchors.fill: parent
                anchors.margins: Appearance.space.panelPadding
                visible: root.entry !== null && root.kind !== "image" && root.kind !== "colour"
                text: root.entry?.text ?? ""
                font.family: root.literal ? Appearance.font.mono : Appearance.font.ui
                font.pixelSize: Appearance.size.body
                color: Colours.on.surface
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                verticalAlignment: Text.AlignTop
            }

            Text {
                anchors.centerIn: parent
                visible: root.entry === null
                text: qsTr("Nothing selected")
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.label
                color: Colours.outline
            }
        }

        ColumnLayout {
            spacing: Appearance.overlays.clipboard.metaGap
            visible: root.entry !== null

            Layout.fillWidth: true

            RowLayout {
                spacing: Appearance.space.sm

                Layout.fillWidth: true

                Text {
                    text: qsTr("Copied from")
                    font.family: Appearance.font.ui
                    font.pixelSize: Appearance.size.label
                    color: Colours.outline
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    // An application name is prose; "Not recorded" is the
                    // admission that the entry predates the sidecar.
                    text: root.entry?.app ? root.entry.app : qsTr("Not recorded")
                    font.family: Appearance.font.ui
                    font.pixelSize: Appearance.size.label
                    color: root.entry?.app ? Colours.on.surface : Colours.outline
                    elide: Text.ElideRight

                    Layout.maximumWidth: root.width / 2
                }
            }

            RowLayout {
                spacing: Appearance.space.sm

                Layout.fillWidth: true

                Text {
                    text: qsTr("Saved")
                    font.family: Appearance.font.ui
                    font.pixelSize: Appearance.size.label
                    color: Colours.outline
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: root.entry?.stamped ? Qt.formatDateTime(root.entry.time, "HH:mm:ss") : qsTr("Not recorded")
                    // A time is a literal; the apology is not.
                    font.family: root.entry?.stamped ? Appearance.font.mono : Appearance.font.ui
                    font.pixelSize: Appearance.size.label
                    color: root.entry?.stamped ? Colours.on.surface : Colours.outline
                }
            }
        }

        RowLayout {
            spacing: Appearance.overlays.clipboard.actionGap
            visible: root.entry !== null

            Layout.fillWidth: true

            // The screen's one affirmative verb, and therefore the only filled
            // control on it.
            Pill {
                text: qsTr("Paste")
                icon: "content_copy"
                tone: "filled"
                pillHeight: Appearance.overlays.clipboard.actionHeight
                fontSize: Appearance.size.body
                iconSize: Appearance.size.iconLabel

                Layout.fillWidth: true

                onClicked: root.pasted()
            }

            Pill {
                icon: "push_pin"
                checked: root.entry?.pinned ?? false
                pillHeight: Appearance.overlays.clipboard.actionHeight
                iconSize: Appearance.size.iconRow

                Layout.preferredWidth: Appearance.overlays.clipboard.actionIcon

                onClicked: root.pinned()
            }

            // A link in the browser, an image in the image viewer
            // (Clipboard.open). Only for those: text and colours have nothing
            // to open in, and Paste takes the room instead.
            Pill {
                icon: "open_in_new"
                visible: Clipboard.opens(root.entry)
                pillHeight: Appearance.overlays.clipboard.actionHeight
                iconSize: Appearance.size.iconRow

                Layout.preferredWidth: Appearance.overlays.clipboard.actionIcon

                onClicked: root.opened()
            }
        }
    }
}
