import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.components

// The lock screen's password entry: a lock glyph, a run of dots with a caret
// after them, and a primary submit. The field carries the only `primary` border
// on the screen because it is the focused control, which is one of the three
// things the design spends colour on.
//
// THE FIELD IS NEVER DISABLED. Not while PAM is thinking, not after an error,
// not after any number of wrong answers -- a lock screen that stops accepting
// keystrokes is a lost session, so `Auth` guards the attempt and this stays
// typeable throughout.
Panel {
    id: root

    property Auth auth: null

    readonly property bool busy: root.auth?.busy ?? false
    readonly property int filled: Math.min(input.text.length, Appearance.lock.maxDots)

    function focusField(): void {
        input.forceActiveFocus();
    }

    function clear(): void {
        input.text = "";
    }

    function submit(): void {
        if (root.busy || input.text.length === 0)
            return;
        root.auth?.submit(input.text);
    }

    level: "popout"
    padding: 0
    radius: Appearance.lock.fieldRadius
    borderColour: Colours.alpha(Colours.primary, 0.22)
    // The design's 60% fill, held as a reduction of the user's panel opacity
    // so the settings screen's slider still moves it.
    colour: Colours.alpha(Colours.panel, Math.max(0, Appearance.panelOpacity - Appearance.lock.fieldFade))

    implicitWidth: row.implicitWidth + Appearance.lock.fieldPadLead + Appearance.lock.fieldPadTrail
    implicitHeight: Appearance.lock.fieldHeight

    // A click anywhere on the field puts the caret back, including on the dots.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: input.forceActiveFocus()
    }

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.leftMargin: Appearance.lock.fieldPadLead
        anchors.rightMargin: Appearance.lock.fieldPadTrail
        spacing: Appearance.lock.fieldGap

        Icon {
            text: "lock"
            size: Appearance.lock.fieldIcon
            color: Colours.primary

            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            id: dots

            Layout.preferredWidth: Appearance.lock.dotsWidth
            Layout.fillHeight: true

            // NoEcho draws nothing at all, which is exactly what is wanted: the
            // dots below are the display, and the field underneath them is a
            // real TextInput, so paste, backspace, home/end and a compose key
            // all behave the way they do everywhere else.
            TextInput {
                id: input

                anchors.fill: parent
                echoMode: TextInput.NoEcho
                activeFocusOnPress: true
                focus: true
                // The dots ARE the cursor here. `cursorVisible: false` is not
                // enough -- TextInput re-shows its own cursor on focus, and it
                // paints in the default text colour, which is black.
                cursorDelegate: Item {}

                onAccepted: root.submit()

                Keys.onEscapePressed: event => {
                    // Esc clears the field. It does NOT dismiss: there is
                    // nothing behind a lock screen to dismiss it to.
                    input.text = "";
                    root.auth?.clearMessage();
                    event.accepted = true;
                }

                Keys.onPressed: root.auth?.clearMessage()
            }

            Repeater {
                model: root.filled

                Rectangle {
                    required property int index

                    x: index * (Appearance.lock.dot + Appearance.lock.dotGap)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Appearance.lock.dot
                    height: width
                    radius: width / 2
                    color: Colours.on.surfaceVariant
                }
            }

            Rectangle {
                x: root.filled * (Appearance.lock.dot + Appearance.lock.dotGap)
                anchors.verticalCenter: parent.verticalCenter
                width: Appearance.lock.caretWidth
                height: Appearance.lock.caretHeight
                color: Colours.primary
                // Solid, not blinking: nothing moves while nothing is
                // happening (docs/motion.md), and a blinking caret would be
                // the only thing on this screen that did.
                visible: input.activeFocus
            }
        }

        Pill {
            tone: "filled"
            icon: "arrow_forward"
            iconSize: Appearance.lock.submitIcon
            pillHeight: Appearance.lock.submit
            implicitWidth: Appearance.lock.submit
            enabled: input.text.length > 0 && !root.busy
            // Tab must not walk the focus off the field: the keyboard path on
            // this screen is type-and-press-return, and nothing else.
            activeFocusOnTab: false
            onClicked: root.submit()

            Layout.alignment: Qt.AlignVCenter
        }
    }

    // A rejected attempt empties the field rather than leaving the old answer
    // in it to be corrected -- which is what every other lock screen does, and
    // what stops a second Return re-sending a password PAM has already refused.
    Connections {
        target: root.auth

        function onStateChanged(): void {
            if (root.auth.failed)
                input.text = "";
        }
    }
}
