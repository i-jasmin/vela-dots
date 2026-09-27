pragma ComponentBehavior: Bound

import QtQuick
import qs.tokens
import qs.components

// One of the power menu's five buttons: 150 square, a 26px corner, a glyph over
// a label over its single-key shortcut.
//
// Three tones, and only two of them carry colour. Lock is `primaryContainer`
// because it is the default action -- the enabled control the invariant allows
// -- and Shut down is error-tinted because it is destructive. The middle three
// are neutral, and a reviewer would be right to reject them otherwise.
Card {
    id: root

    // One entry of `SessionActions.items`.
    required property var action
    // Carries the keyboard cursor.
    property bool selected: false

    signal activated

    readonly property bool danger: root.action.tone === "danger"
    readonly property bool accent: root.action.tone === "accent"

    // The design lights Lock's glyph and its key in `onPrimaryContainer` but
    // leaves its label in `onSurface`: the word is the button, the colour is the
    // state, and running all three at the accent would lose that.
    readonly property color glyphColour: root.danger ? Colours.error : root.accent ? Colours.on.primaryContainer : Colours.on.surfaceVariant
    readonly property color labelColour: root.danger ? Colours.error : root.accent ? Colours.on.surface : Colours.on.surfaceVariant
    readonly property color keyColour: root.danger ? Colours.error : root.accent ? Colours.on.primaryContainer : Colours.outline

    implicitWidth: Appearance.session.button
    implicitHeight: Appearance.session.button
    radius: Appearance.radius.drawer
    // A button is not a card with a margin: its content is centred in the whole
    // tile and its hit area is the whole tile.
    padding: 0

    color: root.danger ? Colours.alpha(Colours.error, Appearance.session.dangerFill) : root.accent ? Colours.primaryContainer : Colours.hover

    border.width: 1
    border.color: root.selected ? Colours.primary : root.danger ? Colours.alpha(Colours.error, Appearance.session.dangerBorder) : root.accent ? Colours.alpha(Colours.on.primaryContainer, Appearance.session.accentBorder) : Colours.panelBorder

    Behavior on border.color {
        enabled: !Colours.crossing

        ColorAnimation {
            duration: Appearance.anim.fast
            easing.type: Appearance.anim.enterEasing
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Colours.hover
        opacity: mouse.containsMouse ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Appearance.anim.enterEasing
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Appearance.session.buttonContentGap

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.action.icon
            size: Appearance.session.iconSize
            color: root.glyphColour
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.action.label
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.session.labelSize
            color: root.labelColour
        }

        // A keybind is a literal, so it is mono.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.action.key
            font.family: Appearance.font.mono
            font.pixelSize: Appearance.session.keySize
            color: root.keyColour
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
