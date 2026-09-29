import QtQuick
import QtQuick.Layouts
import qs.services
import qs.tokens
import qs.components

// A bind's keys on the Keybinds page, as a button that records new ones.
//
// Clicked, it asks BindEditor to listen -- which puts Hyprland where its binds
// cannot act on what is pressed -- takes the keyboard, and hands it every key
// until a whole combination comes. While it waits it says what it wants, and
// the modifiers held so far. Red when the keys are on another bind too.
Rectangle {
    id: root

    required property var row

    readonly property bool listening: BindEditor.capturing !== "" && BindEditor.capturing === root.row.id
    readonly property bool clashing: BindEditor.clashesFor(root.row.id).length > 0
    readonly property bool fixed: root.row.fixed !== ""
    readonly property var caps: BindEditor.capsOf(root.row)

    implicitWidth: Appearance.settings.bindKeysWidth
    implicitHeight: Appearance.settings.bindKeysHeight
    radius: Appearance.settings.bindKeysRadius
    color: root.listening ? Colours.alpha(Colours.primary, 0.10) : mouse.containsMouse && !root.fixed ? Colours.hover : "transparent"
    border.width: 1
    border.color: root.listening ? Colours.primary : root.clashing ? Colours.error : Colours.panelBorder
    activeFocusOnTab: !root.fixed

    // Clicking anywhere else -- the filter, another field -- ends the
    // recording rather than leaving Hyprland's binds off behind it; so does
    // the button going away, filtered out or with its page.
    onActiveFocusChanged: {
        if (!root.activeFocus && root.listening)
            BindEditor.cancelCapture();
    }
    Component.onDestruction: {
        if (root.listening)
            BindEditor.cancelCapture();
    }

    function listen(): void {
        if (root.fixed)
            return;
        root.forceActiveFocus();
        BindEditor.startCapture(root.row.id);
    }

    Keys.onPressed: event => {
        if (root.listening) {
            if (BindEditor.keyPressed(event))
                event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
            root.listen();
            event.accepted = true;
        }
    }

    // A modifier let go shows what is still held.
    Keys.onReleased: event => {
        if (!root.listening)
            return;
        const held = [];
        if (event.modifiers & Qt.MetaModifier)
            held.push("SUPER");
        if (event.modifiers & Qt.ControlModifier)
            held.push("CTRL");
        if (event.modifiers & Qt.AltModifier)
            held.push("ALT");
        if (event.modifiers & Qt.ShiftModifier)
            held.push("SHIFT");
        BindEditor.held = held.join(" + ");
        event.accepted = true;
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.fixed ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: root.listening ? BindEditor.cancelCapture() : root.listen()
    }

    // The keys, or "Off".
    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: Appearance.settings.bindKeysPad
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.settings.bindKeyGap
        visible: !root.listening

        Repeater {
            model: root.caps

            Keycap {
                required property string modelData

                key: modelData
            }
        }

        Text {
            visible: root.caps.length === 0
            text: root.row.custom ? qsTr("Click to set keys") : qsTr("Off")
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.label
            color: Colours.outline
        }
    }

    Icon {
        anchors.right: parent.right
        anchors.rightMargin: Appearance.settings.bindKeysPad
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.listening
        text: root.fixed ? "lock" : root.clashing ? "error" : "edit"
        size: Appearance.size.iconXs
        color: root.clashing ? Colours.error : Colours.outline
        opacity: root.fixed || root.clashing || mouse.containsMouse || root.activeFocus ? 1 : 0
    }

    // Listening: what it wants, or what is held so far.
    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Appearance.settings.bindKeysPad + 2
        anchors.rightMargin: Appearance.settings.bindKeysPad
        anchors.verticalCenter: parent.verticalCenter
        visible: root.listening
        text: BindEditor.held !== "" ? `${BindEditor.held.toLowerCase().split(" + ").join(" + ")} + …` : root.row.family ? qsTr("Hold the modifiers, press %1").arg(Binds.keyLabel(root.row.family[0])) : qsTr("Press the keys · esc cancels")
        font.family: BindEditor.held !== "" ? Appearance.font.mono : Appearance.font.ui
        font.pixelSize: Appearance.size.label
        color: Colours.primary
        elide: Text.ElideRight
    }
}
