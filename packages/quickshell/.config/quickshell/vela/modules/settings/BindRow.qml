import QtQuick
import QtQuick.Layouts
import qs.services
import qs.tokens
import qs.components

// One of vela's binds on the Keybinds page: what it does, its keys (a button
// that records new ones), and, once changed, the way back to the default.
//
// The line under the name carries whatever needs saying, most urgent first:
// the other binds on the same keys (red), why the last key pressed could not
// be used, why a bind is fixed, and what the default was.
Item {
    id: root

    required property var row

    readonly property var clashes: BindEditor.clashesFor(root.row.id)
    readonly property bool listening: BindEditor.capturing === root.row.id

    readonly property string note: {
        if (root.clashes.length > 0)
            return qsTr("Also %1 — change one of them").arg(root.clashes.map(c => c.others.join(", ")).filter((t, i, all) => all.indexOf(t) === i).join(", "));
        if (root.listening && BindEditor.refusal !== "")
            return BindEditor.refusal;
        if (root.row.fixed)
            return qsTr("Fixed: %1").arg(root.row.fixed);
        if (root.row.changed)
            return qsTr("Default: %1").arg(root.defaultLabel);
        return "";
    }

    readonly property string defaultLabel: {
        const caps = BindEditor.capsOf({
            keys: root.row.defaultKeys,
            family: root.row.family
        });
        return caps.join(" + ");
    }

    implicitHeight: Math.max(labels.implicitHeight, Appearance.settings.bindKeysHeight)

    Layout.fillWidth: true

    RowLayout {
        anchors.fill: parent
        spacing: Appearance.settings.bindRowGap

        ColumnLayout {
            id: labels

            spacing: Appearance.settings.labelGap

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: root.row.action
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.settings.rowTitleSize
                color: root.row.secondary ? Colours.on.surfaceVariant : Colours.on.surface
                elide: Text.ElideRight

                Layout.fillWidth: true
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

        BindKeys {
            row: root.row

            Layout.alignment: Qt.AlignVCenter
        }

        // Back to the default: for a changed bind, including one turned off.
        Pill {
            icon: "undo"
            tone: "plain"
            opacity: root.row.changed ? 1 : 0
            enabled: root.row.changed
            pillHeight: Appearance.settings.bindActionSize
            iconSize: Appearance.settings.bindActionIcon

            Layout.preferredWidth: Appearance.settings.bindActionSize
            Layout.alignment: Qt.AlignVCenter

            onClicked: BindEditor.restore(root.row.id)
        }

        // Off. A bind that is off comes back with the one above.
        Pill {
            icon: "block"
            tone: "plain"
            opacity: !root.row.off && !root.row.fixed ? 1 : 0
            enabled: !root.row.off && !root.row.fixed
            pillHeight: Appearance.settings.bindActionSize
            iconSize: Appearance.settings.bindActionIcon

            Layout.preferredWidth: Appearance.settings.bindActionSize
            Layout.alignment: Qt.AlignVCenter

            onClicked: BindEditor.turnOff(root.row.id)
        }
    }
}
