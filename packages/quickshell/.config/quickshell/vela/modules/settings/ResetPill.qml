import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.components

// A page's Reset, asked first. Pressed, it turns into its question with a
// Cancel beside it and the reset itself, in the danger tone, so a page of
// settings is never put back on one stray click:
//
//     ResetPill {
//         id: reset
//         question: qsTr("Put the bar back to how it shipped?")
//         onConfirmed: root.reset()
//     }
//     Pill { text: qsTr("Apply"); visible: !reset.asking }
//
// Nothing times it out: a question that took itself back while it was being
// read would be worse than one left open. Leaving the page puts it away with
// the page.
RowLayout {
    id: root

    property string question
    property string confirmLabel: qsTr("Reset")
    property bool asking: false

    signal confirmed

    spacing: Appearance.space.sm

    Pill {
        visible: !root.asking
        text: qsTr("Reset")
        tone: "subtle"
        pillHeight: Appearance.settings.actionHeight
        fontSize: Appearance.settings.actionSize
        onClicked: root.asking = true
    }

    Text {
        visible: root.asking
        text: root.question
        font.family: Appearance.font.ui
        font.pixelSize: Appearance.settings.actionSize
        color: Colours.on.surfaceVariant
    }

    Pill {
        visible: root.asking
        text: qsTr("Cancel")
        tone: "plain"
        pillHeight: Appearance.settings.actionHeight
        fontSize: Appearance.settings.actionSize
        onClicked: root.asking = false
    }

    Pill {
        visible: root.asking
        text: root.confirmLabel
        tone: "danger"
        pillHeight: Appearance.settings.actionHeight
        fontSize: Appearance.settings.actionSize
        onClicked: {
            root.asking = false;
            root.confirmed();
        }
    }
}
