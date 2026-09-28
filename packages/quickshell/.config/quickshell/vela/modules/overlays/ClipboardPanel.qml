import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.tokens
import qs.config
import qs.services
import qs.components

// Clipboard history, on `super + V`. A 940x600 split panel: the list on the
// left, one entry's preview on the right.
//
// NAMED `ClipboardPanel` AND NOT `Clipboard`. A QML file in a module directory
// is a type in that module's namespace, and `shell.qml` imports `qs.services`
// alongside `qs.modules.overlays` -- a local `Clipboard.qml` would shadow the
// `Clipboard` singleton for every file that imported the overlays after the
// services, silently, and the service is what this file is built on.
//
// THE LIST IS TYPE-AWARE, which is the whole point of the screen: an image is a
// 34px thumbnail with its format and dimensions, a colour is a swatch and its
// hex, a link is a link glyph. Everything else is a leading ligature and one
// line. All of it comes from `Clipboard`; nothing here parses an entry.
//
// The window is full screen and the panel is inset into it, for the launcher's
// two reasons: a layer-shell surface clips at its own edges so the shadow needs
// gutter, and a 940px window cannot hear a click beside itself.
PanelWindow {
    id: root

    readonly property bool shown: ShellState.clipboard

    // Sections, in the design's order, with the empty ones dropped so the list
    // does not grow a heading over nothing. "Earlier" is not in the design: it
    // is where entries that predate vela's sidecar go, because cliphist stores
    // no timestamps and inventing one would be worse than admitting the gap.
    readonly property var groups: {
        const all = [
            {
                "label": qsTr("Pinned"),
                "items": Clipboard.pinnedEntries
            },
            {
                "label": qsTr("Today"),
                "items": Clipboard.today
            },
            {
                "label": qsTr("Yesterday"),
                "items": Clipboard.yesterday
            },
            {
                "label": qsTr("Earlier"),
                "items": Clipboard.earlier
            }
        ];
        return all.filter(g => g.items.length > 0);
    }

    // The same entries again, in drawing order, so up and down can cross a
    // heading without knowing that headings exist.
    readonly property var flat: root.groups.reduce((acc, g) => acc.concat(g.items), [])

    property int selected: 0
    readonly property var current: root.flat.length > 0 ? root.flat[Math.min(root.selected, root.flat.length - 1)] : null

    // BY ID, NEVER BY IDENTITY. A `Repeater` over a JS array hands its delegate
    // a `modelData` that has been round-tripped through QVariant, so the object
    // the row holds is a copy of the one in `flat` and `===` between them is
    // always false -- the selection simply never draws. Measured.
    function isCurrent(entry: var): bool {
        return !!entry && !!root.current && root.current.id === entry.id;
    }

    function indexOf(entry: var): int {
        return root.flat.findIndex(e => e.id === entry.id);
    }

    // A clipboard entry is a literal far more often than it is prose: a path, a
    // command, a hex, a key. Rubik is for the sentence somebody copied out of a
    // document; everything else keeps the grid.
    function isLiteral(entry: var): bool {
        if (!entry)
            return false;
        if (entry.kind === "colour")
            return true;
        if (entry.kind === "link")
            return false;
        const t = entry.text;
        return !t.includes(" ") || /[/~$|><]/.test(t) || /\s-{1,2}\w/.test(t);
    }

    function move(by: int): void {
        const n = root.flat.length;
        if (n === 0)
            return;
        root.selected = Math.max(0, Math.min(n - 1, root.selected + by));
    }

    // Closes first, so the window the entry is going into has the keyboard
    // back by the time the service types the paste shortcut.
    function paste(entry: var): void {
        if (!entry)
            return;
        ShellState.close("clipboard");
        Clipboard.paste(entry);
    }

    // Out of the way, so the browser or the image viewer is what is in front.
    function open(entry: var): void {
        if (!Clipboard.opens(entry))
            return;
        ShellState.close("clipboard");
        Clipboard.open(entry);
    }

    // Clear all asks once: the first press arms it -- "Clear 24 items?" in
    // red -- and a second within `clearConfirm` clears. Left alone, it goes
    // back. Pinned entries are never cleared (Clipboard.wipe).
    property bool clearArmed: false

    function clearAll(): void {
        if (Clipboard.clearable === 0)
            return;
        if (!root.clearArmed) {
            root.clearArmed = true;
            disarm.restart();
            return;
        }
        root.clearArmed = false;
        disarm.stop();
        Clipboard.wipe();
        root.selected = 0;
    }

    Timer {
        id: disarm

        interval: Appearance.overlays.clipboard.clearConfirm
        onTriggered: root.clearArmed = false
    }

    screen: {
        const screens = Quickshell.screens;
        if (screens.length === 0)
            return null;
        return screens.find(s => s.name === Hypr.focusedMonitorName) ?? screens[0];
    }

    readonly property int insetLeft: Config.bar.position === "left" ? Config.bar.footprint : 0
    readonly property int insetRight: Config.bar.position === "right" ? Config.bar.footprint : 0
    readonly property int insetTop: Config.bar.position === "top" ? Config.bar.footprint : 0
    readonly property int insetBottom: Config.bar.position === "bottom" ? Config.bar.footprint : 0

    visible: root.shown || panel.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vela-clipboard"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (!root.shown)
            return;
        // A fresh open starts from an empty query at the newest entry.
        Clipboard.search = "";
        root.selected = 0;
        Clipboard.refresh();
        input.forceActiveFocus();
    }

    // The filter changing invalidates the cursor: the entry that was under it
    // is very unlikely to still be at that index.
    Connections {
        target: Clipboard

        function onSearchChanged(): void {
            root.selected = 0;
        }
    }

    Item {
        anchors.fill: parent
        focus: true

        // Every overlay in the design dims what is behind it -- .60 on
        // clipboard history and what changed, .62 on capture and sessions, .66
        // on the window picker -- and asks the compositor for an 8-9px blur of
        // it. One token covers all five: the spread is three parts in 255 over
        // any wallpaper. The blur is the `vela-*` layer rule, because QML
        // cannot blur what is behind its own window.
        Rectangle {
            anchors.fill: parent
            color: Colours.scrim
            opacity: panel.opacity
        }

        MouseArea {
            anchors.fill: parent

            onClicked: event => {
                const p = mapToItem(panel, event.x, event.y);
                if (p.x < 0 || p.y < 0 || p.x > panel.width || p.y > panel.height)
                    ShellState.close("clipboard");
            }
        }

        Panel {
            id: panel

            level: "drawer"
            padding: Appearance.overlays.clipboard.padding

            // 940x600 as designed, and never past the edges of a smaller output.
            width: Math.min(Appearance.overlays.clipboard.width, parent.width - root.insetLeft - root.insetRight - Appearance.space.overlayMargin * 2)
            height: Math.min(Appearance.overlays.clipboard.height, parent.height - root.insetTop - root.insetBottom - Appearance.space.overlayMargin * 2)

            x: Math.round(root.insetLeft + (parent.width - root.insetLeft - root.insetRight - width) / 2)

            readonly property int restY: Math.round(root.insetTop + (parent.height - root.insetTop - root.insetBottom) * Appearance.overlays.topClipboard)
            y: panel.restY + entrance.offset
            opacity: entrance.opacity

            Reveal {
                id: entrance

                shown: root.shown
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // ---- the list ---------------------------------------------
                ColumnLayout {
                    spacing: 0

                    // `Layout.fillWidth` defaults to TRUE for a layout nested in
                    // a layout, and only to false for a plain item -- so without
                    // this the list eats the whole panel and pushes the preview
                    // out through its right edge. Measured, not theoretical.
                    Layout.fillWidth: false
                    Layout.preferredWidth: Appearance.overlays.clipboard.listWidth
                    Layout.fillHeight: true

                    RowLayout {
                        spacing: Appearance.overlays.clipboard.searchGap

                        Layout.fillWidth: true
                        Layout.preferredHeight: Appearance.overlays.clipboard.searchHeight
                        Layout.leftMargin: Appearance.overlays.clipboard.searchPadding
                        Layout.rightMargin: Appearance.overlays.clipboard.searchPadding

                        // The field the shell is waiting on -- one of the three
                        // things allowed to carry colour on this screen.
                        Icon {
                            text: "content_paste"
                            size: Appearance.overlays.iconBanner
                            color: Colours.primary

                            Layout.alignment: Qt.AlignVCenter
                        }

                        TextInput {
                            id: input

                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.size.subheading
                            color: Colours.on.surface
                            selectionColor: Colours.primaryContainer
                            selectedTextColor: Colours.on.primaryContainer
                            selectByMouse: true
                            // Drawn below, unblinking: nothing in this shell
                            // pulses.
                            cursorDelegate: Item {}

                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter

                            onTextChanged: Clipboard.search = input.text

                            Keys.onPressed: event => {
                                switch (event.key) {
                                case Qt.Key_Escape:
                                    ShellState.close("clipboard");
                                    break;
                                case Qt.Key_Down:
                                    root.move(1);
                                    break;
                                case Qt.Key_Up:
                                    root.move(-1);
                                    break;
                                case Qt.Key_Return:
                                case Qt.Key_Enter:
                                    root.paste(root.current);
                                    break;
                                case Qt.Key_Delete:
                                    // ctrl + shift + del: Clear all, which
                                    // asks the same way the button does.
                                    if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier))
                                        root.clearAll();
                                    else
                                        Clipboard.remove(root.current);
                                    break;
                                case Qt.Key_P:
                                    if (!(event.modifiers & Qt.ControlModifier))
                                        return;
                                    Clipboard.togglePin(root.current);
                                    break;
                                default:
                                    return;
                                }
                                event.accepted = true;
                            }

                            Connections {
                                target: Clipboard

                                function onSearchChanged(): void {
                                    if (input.text !== Clipboard.search)
                                        input.text = Clipboard.search;
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: input.text.length === 0
                                text: qsTr("Search clipboard")
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.size.subheading
                                color: Colours.outline
                            }
                        }

                        // A count is a number, so it is monospace.
                        Text {
                            text: qsTr("%1 kept").arg(Clipboard.count)
                            font.family: Appearance.font.mono
                            font.pixelSize: Appearance.size.micro
                            color: Colours.outline

                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    Rectangle {
                        implicitHeight: 1
                        color: Colours.panelBorder

                        Layout.fillWidth: true
                        Layout.leftMargin: Appearance.overlays.clipboard.dividerInset
                        Layout.rightMargin: Appearance.overlays.clipboard.dividerInset
                    }

                    Flickable {
                        id: list

                        // Dropped out of the layout entirely when there is
                        // nothing in it, so the empty state can have the space
                        // instead of sitting under a full-height empty list.
                        visible: root.flat.length > 0
                        clip: true
                        contentWidth: width
                        contentHeight: rows.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        flickDeceleration: 6000

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: Appearance.overlays.clipboard.listPadV
                        Layout.bottomMargin: Appearance.overlays.clipboard.listPadV
                        Layout.leftMargin: Appearance.overlays.clipboard.listPadH
                        Layout.rightMargin: Appearance.overlays.clipboard.listPadH

                        // Keyboard navigation has to drag the view with it, or
                        // the fifteenth entry is selected somewhere off screen.
                        function reveal(top: real, h: real): void {
                            if (top < list.contentY)
                                list.contentY = top;
                            else if (top + h > list.contentY + list.height)
                                list.contentY = top + h - list.height;
                        }

                        ColumnLayout {
                            id: rows

                            width: list.width
                            spacing: Appearance.overlays.clipboard.listGap

                            Repeater {
                                model: root.groups

                                ColumnLayout {
                                    id: group

                                    required property var modelData
                                    required property int index

                                    spacing: Appearance.overlays.clipboard.listGap

                                    Layout.fillWidth: true

                                    SectionLabel {
                                        text: group.modelData.label

                                        Layout.fillWidth: true
                                        Layout.leftMargin: Appearance.overlays.clipboard.sectionPadding
                                        Layout.rightMargin: Appearance.overlays.clipboard.sectionPadding
                                        Layout.topMargin: group.index === 0 ? Appearance.overlays.clipboard.sectionTopFirst : Appearance.overlays.clipboard.sectionTop
                                        Layout.bottomMargin: Appearance.overlays.clipboard.sectionBottom
                                    }

                                    Repeater {
                                        model: group.modelData.items

                                        ClipboardRow {
                                            id: clipRow

                                            required property var modelData

                                            entry: modelData
                                            selected: root.isCurrent(modelData)
                                            literal: root.isLiteral(modelData)
                                            opacity: arrival.opacity
                                            transform: Translate {
                                                y: arrival.offset
                                            }

                                            Layout.fillWidth: true

                                            // In order down the whole list as
                                            // the panel opens; rows a search
                                            // brings in later just appear.
                                            Stagger {
                                                id: arrival

                                                index: root.indexOf(clipRow.modelData)
                                                active: entrance.entering
                                            }

                                            // Clicking selects rather than
                                            // pastes: the point of a split
                                            // panel is that the preview is
                                            // reachable without committing.
                                            onClicked: root.selected = root.indexOf(modelData)

                                            onSelectedChanged: {
                                                if (selected)
                                                    list.reveal(mapToItem(rows, 0, 0).y, height);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // The honest empty states. cliphist missing is a different
                    // thing from cliphist having nothing, and a user who typed a
                    // query that matched nothing needs to be told that and not
                    // shown a blank panel.
                    Text {
                        visible: root.flat.length === 0
                        text: !Clipboard.available ? qsTr("cliphist is not running — no history to show") : Clipboard.count === 0 ? qsTr("Nothing copied yet") : qsTr("No entry matches “%1”").arg(Clipboard.search)
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.label
                        color: Colours.outline
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.bottomMargin: Appearance.space.lg
                    }

                    Rectangle {
                        implicitHeight: 1
                        color: Colours.panelBorder

                        Layout.fillWidth: true
                        Layout.leftMargin: Appearance.overlays.clipboard.dividerInset
                        Layout.rightMargin: Appearance.overlays.clipboard.dividerInset
                    }

                    RowLayout {
                        spacing: Appearance.overlays.clipboard.footerGap

                        Layout.fillWidth: true
                        Layout.preferredHeight: Appearance.overlays.clipboard.footerHeight
                        Layout.leftMargin: Appearance.overlays.clipboard.footerPadding
                        Layout.rightMargin: Appearance.overlays.clipboard.footerPadding

                        Repeater {
                            model: [
                                {
                                    "key": "↵",
                                    "verb": qsTr("paste")
                                },
                                {
                                    "key": "ctrl+p",
                                    "verb": qsTr("pin")
                                },
                                {
                                    "key": "del",
                                    "verb": qsTr("forget")
                                }
                            ]

                            Text {
                                required property var modelData

                                // Both halves are literal, so the whole strip is
                                // monospace; only the key is lifted out of the
                                // neutral.
                                text: `<font color="${Colours.on.surfaceVariant}">${modelData.key}</font> ${modelData.verb}`
                                textFormat: Text.RichText
                                font.family: Appearance.font.mono
                                font.pixelSize: Appearance.size.micro
                                color: Colours.outline
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Pill {
                            visible: Clipboard.clearable > 0
                            text: !root.clearArmed ? qsTr("Clear all") : Clipboard.clearable === 1 ? qsTr("Clear 1 item?") : qsTr("Clear %1 items?").arg(Clipboard.clearable)
                            icon: "delete_sweep"
                            tone: root.clearArmed ? "danger" : "plain"
                            pillHeight: Appearance.overlays.clipboard.clearHeight
                            fontSize: Appearance.size.label
                            iconSize: Appearance.size.iconXs

                            Layout.alignment: Qt.AlignVCenter

                            onClicked: root.clearAll()
                        }
                    }
                }

                Rectangle {
                    implicitWidth: 1
                    color: Colours.panelBorder

                    Layout.fillHeight: true
                }

                // ---- the preview ------------------------------------------
                ClipboardPreview {
                    entry: root.current
                    literal: root.isLiteral(root.current)

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    onPasted: root.paste(root.current)
                    onPinned: Clipboard.togglePin(root.current)
                    onOpened: root.open(root.current)
                }
            }
        }
    }
}
