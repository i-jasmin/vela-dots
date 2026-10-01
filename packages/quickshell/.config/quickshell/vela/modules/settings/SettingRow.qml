import QtQuick
import QtQuick.Layouts
import qs.tokens

// One line of a settings card: a name, the sentence under it that says what the
// setting does, and whatever control the setting needs at the end of the row.
//
// The controls are the default property, so they are written as children and
// land after the label column:
//
//     SettingRow {
//         title: qsTr("Corner radius")
//         subtitle: qsTr("Panels and cards")
//         labelWidth: Appearance.settings.labelWidth
//
//         SettingSlider {}
//         SettingValue { text: "22 px" }
//     }
//
// `labelWidth` is -1 where the design writes `flex:1` and the label takes the
// slack, and a fixed column on the rows whose slider has to line up with the
// one above it.
Item {
    id: root

    property string title
    // A path, a version, a measured value: monospace, like every literal. Sits
    // between the title and the subtitle -- the Appearance page's wallpaper
    // block is the one row that carries all three.
    property string detail
    property string subtitle

    property int labelWidth: -1
    property int labelGap: 0
    property int gap: Appearance.settings.rowGap

    // Arbitrary content *before* the label -- the 110x68 wallpaper preview on
    // the Appearance page. Same slot shape as `components/Row.qml`, so the two
    // read alike at the call site.
    property Component leading: null

    default property alias content: row.data

    implicitHeight: row.implicitHeight

    Layout.fillWidth: true

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.gap

        Loader {
            active: root.leading !== null
            visible: active
            sourceComponent: root.leading

            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            spacing: root.labelGap

            Layout.fillWidth: root.labelWidth < 0
            Layout.preferredWidth: root.labelWidth
            Layout.maximumWidth: root.labelWidth < 0 ? Number.POSITIVE_INFINITY : root.labelWidth
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: root.title
                visible: root.title !== ""
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.settings.rowTitleSize
                color: Colours.on.surface
                elide: Text.ElideRight

                Layout.fillWidth: true
            }

            Text {
                text: root.detail
                visible: root.detail !== ""
                font.family: Appearance.font.mono
                font.pixelSize: Appearance.size.label
                color: Colours.outline
                elide: Text.ElideMiddle

                Layout.fillWidth: true
            }

            Text {
                text: root.subtitle
                visible: root.subtitle !== ""
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.label
                color: Colours.outline
                wrapMode: Text.WordWrap

                Layout.fillWidth: true
            }
        }
    }
}
