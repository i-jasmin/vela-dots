import QtQuick
import QtQuick.Layouts
import qs.components
import qs.tokens

// An uppercase section label and the card under it -- the unit the settings
// pages are built from.
//
//     Section {
//         title: qsTr("Colour scheme")
//         SettingRow { ... }
//         Divider {}
//         SettingRow { ... }
//     }
//
// `padding` and `gap` are properties because the two pages disagree: Appearance
// pads its cards 18 and spaces their rows 16 or 18, Bar pads 16 and spaces 14.
// A card that split the difference would be wrong on both.
ColumnLayout {
    id: root

    property string title
    property int padding: Appearance.settings.cardPadding
    property int gap: Appearance.settings.cardGap

    default property alias rows: column.data

    spacing: Appearance.settings.sectionGap

    Layout.fillWidth: true

    SectionLabel {
        text: root.title

        Layout.fillWidth: true
    }

    Card {
        radius: Appearance.radius.cardLg
        padding: root.padding
        implicitHeight: column.implicitHeight + root.padding * 2

        Layout.fillWidth: true

        ColumnLayout {
            id: column

            anchors.fill: parent
            spacing: root.gap
        }
    }
}
