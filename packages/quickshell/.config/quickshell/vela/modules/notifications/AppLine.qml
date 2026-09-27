import QtQuick
import QtQuick.Layouts
import qs.tokens

// The line every notification surface opens with: who sent it, how many of
// them, and how long ago -- "Urgent · systemd  now", "Signal  4 messages  3m".
//
// It is a component rather than a copied block because the toast and the digest
// row draw exactly these three fields at exactly these two sizes, and the only
// thing that differs between them is the colour of the first: `error` on an
// urgent card, `on.surface` everywhere else.
//
// The three run adjacent rather than spread across the width -- the design sets
// them eight pixels apart and lets the slack fall to the right of the last one,
// which is what the trailing filler is for.
Item {
    id: root

    property string label
    // Prose. A count of what the group is carrying: "4 messages".
    property string note
    // A literal, and therefore monospace: the age of the newest entry.
    property string stamp
    property color labelColour: Colours.on.surface

    implicitWidth: line.implicitWidth
    implicitHeight: line.implicitHeight

    RowLayout {
        id: line

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Appearance.space.sm

        Text {
            id: name

            // Capped at the width the whole string would need, and allowed to
            // shrink below it -- which is what makes a long application name
            // elide instead of pushing the age off the card.
            //
            // The cap comes from TextMetrics rather than from this item's own
            // `implicitWidth`, and it has to: an eliding Text reports the width
            // of what it managed to draw, so constraining it by its own
            // implicit width is a ratchet. It tightens every frame until the
            // label is three characters and an ellipsis. Measured.
            text: root.label
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.body
            color: root.labelColour
            elide: Text.ElideRight

            Layout.fillWidth: true
            Layout.maximumWidth: Math.ceil(metrics.advanceWidth)
            Layout.alignment: Qt.AlignBottom

            TextMetrics {
                id: metrics

                font: name.font
                text: root.label
            }
        }

        Text {
            text: root.note
            visible: root.note !== ""
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.micro
            color: Colours.outline

            Layout.alignment: Qt.AlignBottom
        }

        Text {
            text: root.stamp
            visible: root.stamp !== ""
            font.family: Appearance.font.mono
            font.pixelSize: Appearance.size.micro
            color: Colours.outline

            Layout.alignment: Qt.AlignBottom
        }

        Item {
            Layout.fillWidth: true
        }
    }
}
