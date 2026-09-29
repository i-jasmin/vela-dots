import QtQuick
import QtQuick.Layouts
import qs.services
import qs.tokens
import qs.components

// One of your own binds on the Keybinds page: a name for the cheatsheet, the
// command it runs, its keys, and a way to delete it.
//
// Held by index, not by value: the page's list is a count, so typing a name
// and moving on to the command does not rebuild the row under the cursor.
Item {
    id: root

    required property int index

    readonly property var row: BindEditor.rows.find(r => r.id === `custom:${root.index}`) ?? null
    readonly property var clashes: root.row ? BindEditor.clashesFor(root.row.id) : []
    readonly property bool listening: root.row !== null && BindEditor.capturing === root.row.id

    readonly property string note: {
        if (!root.row)
            return "";
        if (root.clashes.length > 0)
            return qsTr("Also %1 — change one of them").arg(root.clashes.map(c => c.others.join(", ")).join(", "));
        if (root.listening && BindEditor.refusal !== "")
            return BindEditor.refusal;
        return BindEditor.incomplete(root.row);
    }

    // Puts the cursor in the name, for a bind just added.
    function editName(): void {
        name.edit();
    }

    implicitHeight: column.implicitHeight

    Layout.fillWidth: true

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Appearance.settings.labelGap

        RowLayout {
            spacing: Appearance.settings.bindRowGap

            Layout.fillWidth: true

            SettingField {
                id: name

                wanted: root.row?.name ?? ""
                placeholder: qsTr("Name, e.g. VS Code")
                next: command
                implicitWidth: Appearance.settings.bindNameWidth

                onCommitted: text => BindEditor.setCustom(root.index, "name", text)
            }

            SettingField {
                id: command

                wanted: root.row?.command ?? ""
                placeholder: qsTr("Command, e.g. code")
                mono: true
                previous: name

                Layout.fillWidth: true

                onCommitted: text => BindEditor.setCustom(root.index, "command", text)
            }

            BindKeys {
                visible: root.row !== null
                row: root.row ?? {
                    id: "",
                    keys: "",
                    fixed: "",
                    custom: true
                }

                Layout.alignment: Qt.AlignVCenter
            }

            Pill {
                icon: "delete"
                tone: "plain"
                pillHeight: Appearance.settings.bindActionSize
                iconSize: Appearance.settings.bindActionIcon

                Layout.preferredWidth: Appearance.settings.bindActionSize
                Layout.alignment: Qt.AlignVCenter

                onClicked: {
                    BindEditor.cancelCapture();
                    BindEditor.removeCustom(root.index);
                }
            }
        }

        Text {
            visible: root.note !== ""
            text: root.note
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.label
            color: root.clashes.length > 0 || (root.listening && BindEditor.refusal !== "") ? Colours.error : Colours.outline
            wrapMode: Text.WordWrap

            Layout.fillWidth: true
        }
    }
}
