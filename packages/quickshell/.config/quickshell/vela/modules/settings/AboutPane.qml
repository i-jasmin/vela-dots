import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.tokens
import qs.components

// What this shell actually is, on the machine it runs on. Every line is
// measured or read rather than declared, because the one thing an About page
// must not do is state a version it is not.
ColumnLayout {
    id: root

    readonly property var facts: [
        {
            label: qsTr("Configuration"),
            value: Config.path
        },
        {
            label: qsTr("Shell"),
            value: Quickshell.shellDir
        },
        {
            label: qsTr("Palette"),
            value: `${Config.appearance.scheme} · ${Colours.light ? qsTr("light") : qsTr("dark")}`
        },
        {
            label: qsTr("Monospace"),
            value: Appearance.font.mono
        },
        {
            label: qsTr("Wallpapers"),
            value: Wallpaper.directory
        }
    ]

    spacing: Appearance.settings.paneGap

    PaneHeader {
        title: qsTr("About")
    }

    Section {
        title: qsTr("vela")

        Repeater {
            model: root.facts

            SettingRow {
                id: fact

                required property var modelData

                title: fact.modelData.label
                labelWidth: Appearance.settings.labelWidthNarrow

                Text {
                    text: fact.modelData.value
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.size.label
                    color: Colours.on.surfaceVariant
                    elide: Text.ElideMiddle

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
