import QtQuick
import QtQuick.Layouts
import qs.tokens

// A line of text a setting is: a city, a folder, a search URL.
//
//     SettingField {
//         wanted: Config.weather.location
//         placeholder: qsTr("A city, e.g. Hamburg")
//         onCommitted: text => { Config.weather.location = text; Persist.commit(); }
//     }
//
// Nothing is written while typing. Return, or clicking away, commits the text
// if it changed; esc puts back what the config holds. `wanted` is re-asserted
// whenever the config moves underneath -- by hand in shell.json, or from the
// other controls on the page -- unless the field is being edited, so a file
// save never snatches text out from under the cursor. The same pattern the
// sliders and rails on the Appearance and Bar pages follow.
Rectangle {
    id: root

    property string wanted
    property string placeholder
    // A path or a URL is a literal, so monospace.
    property bool mono: false
    // A password: dots, never the text.
    property bool secret: false
    // Where Tab and shift + Tab go: the next and previous fields of a form.
    // Without them Tab follows the window's focus chain, which starts at the
    // settings nav -- so filling in a form, Tab jumped to the menu.
    property Item next: null
    property Item previous: null
    readonly property alias text: input.text
    readonly property bool editing: input.activeFocus

    signal committed(string text)
    // Return pressed, as distinct from the field losing focus: a form sends
    // on this, not on `committed`, or tabbing out of its last field sent it.
    signal submitted(string text)

    implicitWidth: Appearance.settings.fieldWidth
    implicitHeight: Appearance.settings.fieldHeight
    radius: Appearance.settings.fieldRadius
    color: Colours.hover
    border.width: 1
    border.color: input.activeFocus ? Colours.primary : Colours.panelBorder

    Behavior on border.color {
        enabled: !Colours.crossing

        ColorAnimation {
            duration: Appearance.anim.fast
        }
    }

    onWantedChanged: if (!input.activeFocus)
        input.text = root.wanted
    Component.onCompleted: input.text = root.wanted

    // Puts the cursor in the field with its text selected, ready to type
    // over. `forceActiveFocus()` on the field itself would focus the frame.
    // The selection is made once focus has landed; made at once, the focus
    // arriving can clear it.
    function edit(): void {
        input.forceActiveFocus();
        Qt.callLater(() => input.selectAll());
    }

    // Empties it, for a form that has been sent.
    function clear(): void {
        input.text = "";
    }

    function commit(): void {
        const t = input.text.trim();
        if (t !== root.wanted)
            root.committed(t);
    }

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: Appearance.settings.fieldPad
        anchors.rightMargin: Appearance.settings.fieldPad
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        font.family: root.mono ? Appearance.font.mono : Appearance.font.ui
        font.pixelSize: root.mono ? Appearance.settings.valueSize : Appearance.size.label
        color: Colours.on.surface
        selectionColor: Colours.primaryContainer
        selectedTextColor: Colours.on.primaryContainer
        selectByMouse: true
        // Kept through the window losing the keyboard for a moment, and
        // dropped when another field is chosen.
        persistentSelection: true
        onFocusChanged: if (!input.focus)
            input.deselect()
        echoMode: root.secret ? TextInput.Password : TextInput.Normal
        // Drawn below: the built-in caret blinks, and nothing in this shell
        // moves while nothing is happening (docs/motion.md).
        cursorDelegate: Item {}

        onAccepted: {
            root.commit();
            input.focus = false;
            root.submitted(input.text.trim());
        }
        onActiveFocusChanged: if (!input.activeFocus)
            root.commit()

        Keys.onTabPressed: event => {
            if (root.next && root.next.visible) {
                root.next.edit();
                event.accepted = true;
            } else {
                event.accepted = false;
            }
        }
        Keys.onBacktabPressed: event => {
            if (root.previous && root.previous.visible) {
                root.previous.edit();
                event.accepted = true;
            } else {
                event.accepted = false;
            }
        }
        Keys.onEscapePressed: event => {
            input.text = root.wanted;
            input.focus = false;
            event.accepted = true;
        }

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: input.text.length === 0 && !input.activeFocus
            text: root.placeholder
            font: input.font
            color: Colours.outline
            elide: Text.ElideRight
        }

        Rectangle {
            x: input.cursorRectangle.x
            y: input.cursorRectangle.y
            width: Appearance.launcher.caretWidth
            height: input.cursorRectangle.height
            color: Colours.primary
            visible: input.activeFocus
        }
    }
}
