pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.services
import qs.components

// A new event, or one being changed, in Home's month (MonthFold): its title,
// all day or from and to, and which calendar. The day is the month's picked
// day -- pick another in the grid, or step with the arrows here, and the
// event moves with it.
//
// Only the calendars an event can be written to are offered: a CalDAV
// account's (Calendar.writable). Saving writes it at once and the month
// shows it at once; the sync after uploads it, or the first sync that gets
// through if the server is out of reach.
//
// Keys: Enter saves, Esc puts it away, Tab moves between the fields.
ColumnLayout {
    id: root

    // { uid ("" for new), title, path, allDay, start: "hh:mm", end: "hh:mm",
    //   span (days it runs past its first), location }
    required property var editor
    required property date day

    signal closed
    signal dayMoved(int by)

    // What it was opened with, kept: the dashboard's `editor` goes back to
    // null the moment the form is put away, while the form is still fading
    // out on screen.
    property var ed: ({
            uid: "",
            title: "",
            path: "",
            allDay: false,
            start: "",
            end: "",
            span: 0,
            location: ""
        })
    onEditorChanged: if (root.editor)
        root.ed = root.editor

    property bool allDay: root.ed.allDay
    property string path: root.ed.path
    property bool confirming: false

    readonly property bool editing: root.ed.uid !== ""

    // A time as people type one: "9", "930", "9:30" and "9.30" are all half
    // past nine. -1 for anything else.
    function minutes(t: string): int {
        const m = /^(\d{1,2})(?:[:.]?(\d{2}))?$/.exec(t.trim());
        if (!m)
            return -1;
        const h = parseInt(m[1]), min = m[2] ? parseInt(m[2]) : 0;
        return h < 24 && min < 60 ? h * 60 + min : -1;
    }

    function pad(t: string): string {
        const m = root.minutes(t);
        return `${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;
    }

    readonly property bool timesValid: {
        if (root.allDay)
            return true;
        const a = root.minutes(startField.text), b = root.minutes(endField.text);
        return a >= 0 && b >= 0 && (b > a || root.ed.span > 0);
    }
    readonly property bool canSave: !Calendar.saving && root.timesValid && root.path !== ""

    function iso(d: date): string {
        return Qt.formatDateTime(d, "yyyy-MM-dd");
    }

    function save(): void {
        if (!root.canSave)
            return;
        const last = new Date(root.day.getTime());
        last.setDate(last.getDate() + root.ed.span);
        Calendar.saveEvent({
            uid: root.ed.uid,
            path: root.path,
            title: titleField.text.trim() || qsTr("New event"),
            start: root.allDay ? root.iso(root.day) : `${root.iso(root.day)}T${root.pad(startField.text)}`,
            end: root.allDay ? root.iso(last) : `${root.iso(last)}T${root.pad(endField.text)}`,
            location: root.ed.location ?? ""
        });
    }

    spacing: Appearance.dashboard.formGap

    Component.onCompleted: {
        if (root.editor)
            root.ed = root.editor;
        Calendar.eventError = "";
        Qt.callLater(() => titleField.edit());
    }

    Connections {
        target: Calendar

        function onEventSaved(): void {
            root.closed();
        }
    }

    // A line of text the form asks for.
    component Field: Rectangle {
        id: field

        property alias text: input.text
        property string placeholder
        property bool mono: false
        // Whether what is typed makes sense, for a field that can tell.
        property var check: null
        property Item next: null
        readonly property bool bad: field.check !== null && input.text !== "" && !field.check(input.text)

        // Focus with everything selected, ready to be typed over. The
        // selection is made once focus has landed: made at once, the focus
        // arriving clears it, and the new time went in after the old one.
        function edit(): void {
            input.forceActiveFocus();
            Qt.callLater(() => input.selectAll());
        }

        implicitHeight: Appearance.dashboard.formField
        radius: Appearance.dashboard.formRadius
        color: Colours.hover
        border.width: 1
        border.color: field.bad ? Colours.error : input.activeFocus ? Colours.primary : "transparent"

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: Appearance.dashboard.formPad
            anchors.rightMargin: Appearance.dashboard.formPad
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            font.family: field.mono ? Appearance.font.mono : Appearance.font.ui
            font.pixelSize: Appearance.dashboard.formText
            color: Colours.on.surface
            selectionColor: Colours.primaryContainer
            selectedTextColor: Colours.on.primaryContainer
            selectByMouse: true
            // Drawn below: the built-in caret blinks, and nothing here moves
            // while nothing is happening (docs/motion.md).
            cursorDelegate: Item {}

            // The selection outlives the window losing the keyboard for a
            // moment (a compositor passing focus around), and goes only when
            // another field is chosen: dropped on the blip, the new time
            // went in after the old one.
            persistentSelection: true
            onFocusChanged: if (!input.focus)
                input.deselect()
            Keys.onReturnPressed: root.save()
            Keys.onEnterPressed: root.save()
            Keys.onEscapePressed: event => {
                root.closed();
                event.accepted = true;
            }
            Keys.onTabPressed: event => {
                if (field.next)
                    field.next.edit();
                event.accepted = true;
            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: input.text.length === 0
                text: field.placeholder
                font: input.font
                color: Colours.outline
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

    component Glyph: Icon {
        id: glyph

        signal clicked

        size: Appearance.dashboard.foldChevron
        color: glyphMouse.containsMouse ? Colours.on.surface : Colours.outline

        MouseArea {
            id: glyphMouse

            anchors.fill: parent
            anchors.margins: -Appearance.dashboard.hitSlop
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: glyph.clicked()
        }
    }

    // ---- what, and which day --------------------------------------------
    RowLayout {
        spacing: Appearance.dashboard.foldHeaderGap
        Layout.fillWidth: true
        Layout.preferredHeight: Appearance.dashboard.foldPill

        SectionLabel {
            text: root.editing ? qsTr("Edit event") : qsTr("New event")
            font.pixelSize: Appearance.dashboard.sectionLabel
            Layout.fillWidth: true
        }

        Glyph {
            text: "chevron_left"
            onClicked: root.dayMoved(-1)
        }

        Text {
            text: Qt.formatDateTime(root.day, "ddd d MMM")
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.dashboard.smallText
            color: Colours.on.surface
        }

        Glyph {
            text: "chevron_right"
            onClicked: root.dayMoved(1)
        }
    }

    Field {
        id: titleField

        text: root.ed.title
        placeholder: qsTr("Title")
        next: root.allDay ? titleField : startField
        Layout.fillWidth: true
    }

    // ---- when -------------------------------------------------------------
    RowLayout {
        spacing: Appearance.dashboard.formGap
        Layout.fillWidth: true

        Toggle {
            checked: root.allDay
            onToggled: on => root.allDay = on
        }

        Text {
            text: qsTr("All day")
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.dashboard.smallText
            color: Colours.on.surfaceVariant
        }

        Item {
            Layout.fillWidth: true
        }

        Field {
            id: startField

            visible: !root.allDay
            text: root.ed.start
            mono: true
            placeholder: "09:00"
            next: endField
            check: t => root.minutes(t) >= 0
            Layout.preferredWidth: Appearance.dashboard.formTime
        }

        Text {
            visible: !root.allDay
            text: "–"
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.dashboard.smallText
            color: Colours.outline
        }

        Field {
            id: endField

            visible: !root.allDay
            text: root.ed.end
            mono: true
            placeholder: "10:00"
            next: titleField
            check: t => root.minutes(t) >= 0
            Layout.preferredWidth: Appearance.dashboard.formTime
        }
    }

    // ---- which calendar ------------------------------------------------
    //
    // (A RowLayout, not a Row: `Row` here is the settings row in
    // components/.)
    RowLayout {
        spacing: Appearance.dashboard.foldChipGap
        clip: true
        Layout.fillWidth: true
        Layout.preferredHeight: Appearance.dashboard.foldPill

        Repeater {
            model: Calendar.writable

            Pill {
                id: choice

                required property var modelData

                readonly property color dot: Calendar.colourOf(Calendar.roleFor(choice.modelData.name))

                text: choice.modelData.name
                tone: "subtle"
                checked: root.path === choice.modelData.path
                pillHeight: Appearance.dashboard.foldPill
                spacing: Appearance.calendar.chipGap
                onClicked: root.path = choice.modelData.path

                leading: Rectangle {
                    implicitWidth: Appearance.calendar.chipDot
                    implicitHeight: Appearance.calendar.chipDot
                    radius: height / 2
                    color: choice.dot
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }

    Item {
        Layout.fillHeight: true
    }

    // ---- done -------------------------------------------------------------
    RowLayout {
        spacing: Appearance.dashboard.formGap
        Layout.fillWidth: true

        Text {
            text: Calendar.saving ? qsTr("Saving…") : Calendar.eventError !== "" ? Calendar.eventError : startField.bad || endField.bad ? qsTr("Write times like 9:30") : !root.timesValid ? qsTr("It ends before it starts") : ""
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.dashboard.foldCaption
            color: Calendar.eventError !== "" || !root.timesValid ? Colours.error : Colours.outline
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Pill {
            visible: root.editing
            text: root.confirming ? qsTr("Delete?") : qsTr("Delete")
            tone: root.confirming ? "danger" : "subtle"
            pillHeight: Appearance.dashboard.foldPill
            onClicked: {
                if (Calendar.saving)
                    return;
                if (root.confirming)
                    Calendar.deleteEvent(root.ed.uid);
                else
                    root.confirming = true;
            }
        }

        Pill {
            text: qsTr("Cancel")
            tone: "subtle"
            pillHeight: Appearance.dashboard.foldPill
            onClicked: root.closed()
        }

        // Always a control, never switched off under the pointer (a Pill
        // cannot stop taking focus while it has it); save() says no.
        Pill {
            text: qsTr("Save")
            tone: "filled"
            opacity: root.canSave ? 1 : Appearance.dashboard.disabledOpacity
            pillHeight: Appearance.dashboard.foldPill
            onClicked: root.save()
        }
    }
}
