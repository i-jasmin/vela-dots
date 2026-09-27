pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.tokens
import qs.config
import qs.services
import qs.components

// The wallpaper switcher, on `super + W`.
//
// A coverflow over ~/Pictures/Wallpapers, the palette the centred image would
// generate, a miniature of the bar wearing it, and the rest of the folder
// along the bottom. Typing filters by filename, the arrows move the selection,
// Tab picks light, dark or auto (the palette and the bar preview show the
// one picked), and APPLY IS EXPLICIT: moving through the coverflow costs a
// matugen dry run and nothing else, so nothing changes under the user until
// they say so -- then the wallpaper and the mode apply together.
// Revert is `super + shift + W`, which reaches `Wallpaper.revert()` through the
// IPC handler at the bottom of this file.
//
// The service does the work and has two things in it that must not be undone:
// matugen is always invoked as `matugen --config <resolved>`, never bare,
// because ~/.config/matugen may belong to a different rice; and the config it
// is pointed at is rewritten against `Quickshell.shellDir` first, so a copy of
// this tree -- the test harness, for instance -- cannot write its colours into
// the running desktop's. Neither is visible from here, and both are why this
// screen is safe to open from a throwaway config.
//
// THE WINDOW IS FULL SCREEN AND THE PANEL IS INSET INTO IT: a layer-shell
// surface clips at its own edges, so the drawer shadow needs transparent gutter
// to fall into, and a 1120px window cannot hear a click beside itself. Nothing
// is drawn in the margin.
PanelWindow {
    id: root

    readonly property bool shown: ShellState.wallpaper

    property string filter: ""
    property int index: 0
    // Light, dark or auto: what Apply sets along with the wallpaper, and what
    // the palette is previewed in until then.
    readonly property var modes: ["light", "dark", "auto"]
    property string mode: "auto"

    onModeChanged: if (root.shown)
        Wallpaper.previewMode = root.mode

    // The folder, narrowed by what has been typed. Filtering by name rather
    // than fuzzily: these are filenames, and a wallpaper folder is browsed, not
    // searched.
    readonly property var entries: {
        const all = Wallpaper.wallpapers;
        const q = root.filter.trim().toLowerCase();
        if (!q)
            return all;
        return all.filter(w => w.name.toLowerCase().includes(q));
    }

    readonly property var selection: root.entries.length > 0 ? root.entries[Math.min(root.index, root.entries.length - 1)] : null
    readonly property string path: root.selection ? root.selection.path : ""

    readonly property string countText: {
        const dir = Config.launcher.wallpaperDir;
        if (Wallpaper.scanning && Wallpaper.count === 0)
            return qsTr("%1 · scanning").arg(dir);
        if (root.entries.length === 0)
            return Wallpaper.count === 0 ? qsTr("%1 · empty").arg(dir) : qsTr("%1 · no match in %2").arg(dir).arg(Wallpaper.count);
        return qsTr("%1 · %2 of %3").arg(dir).arg(Math.min(root.index, root.entries.length - 1) + 1).arg(root.entries.length);
    }

    // The launcher's expression: the panel is centred on the space the bar
    // leaves, not on the screen.
    readonly property int insetLeft: Config.bar.position === "left" ? Config.bar.footprint : 0
    readonly property int insetRight: Config.bar.position === "right" ? Config.bar.footprint : 0
    readonly property int insetTop: Config.bar.position === "top" ? Config.bar.footprint : 0
    readonly property int insetBottom: Config.bar.position === "bottom" ? Config.bar.footprint : 0

    function move(step: int): void {
        const n = root.entries.length;
        if (n === 0)
            return;
        // Wraps, like the coverflow itself: the ends of an alphabetical folder
        // are not a wall.
        root.index = ((root.index + step) % n + n) % n;
    }

    function selectPath(target: string): void {
        const i = root.entries.findIndex(w => w.path === target);
        root.index = i < 0 ? 0 : i;
    }

    function applyEverywhere(): void {
        // The mode first, so the retint the wallpaper starts is in it.
        if (root.mode !== Config.appearance.mode) {
            Config.appearance.mode = root.mode;
            Config.save();
        }
        if (root.path)
            Wallpaper.apply(root.path, "");
        // The Apply pill takes focus when clicked; give it back to the filter
        // so typing and the arrow keys keep working.
        input.forceActiveFocus();
    }

    function applyHere(): void {
        if (root.path && Hypr.focusedMonitorName)
            Wallpaper.apply(root.path, Hypr.focusedMonitorName);
        input.forceActiveFocus();
    }

    // Every key the switcher answers, wherever focus is inside it. The filter
    // field calls this first so its own caret handling never sees the arrows;
    // the scope around the panel calls it for anything else that took focus.
    function handleKey(event: var): void {
        switch (event.key) {
        case Qt.Key_Escape:
            ShellState.close("wallpaper");
            break;
        case Qt.Key_Left:
        case Qt.Key_Up:
            root.move(-1);
            break;
        case Qt.Key_Right:
        case Qt.Key_Down:
            root.move(1);
            break;
        case Qt.Key_Home:
            root.index = 0;
            break;
        case Qt.Key_End:
            root.index = Math.max(0, root.entries.length - 1);
            break;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            {
                const step = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1;
                const i = root.modes.indexOf(root.mode);
                root.mode = root.modes[((i < 0 ? 0 : i) + step + root.modes.length) % root.modes.length];
            }
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            // Shift sets this monitor only, which is the second button rather
            // than a second keybind.
            if (event.modifiers & Qt.ShiftModifier)
                root.applyHere();
            else
                root.applyEverywhere();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    onEntriesChanged: {
        if (root.index >= root.entries.length)
            root.index = Math.max(0, root.entries.length - 1);
    }

    onShownChanged: {
        if (!root.shown) {
            Wallpaper.previewMode = "";
            return;
        }
        root.mode = Config.appearance.mode;
        Wallpaper.previewMode = root.mode;
        // A fresh open starts unfiltered, on the wallpaper in use -- which is
        // also the only honest place to start, since the centre card is what
        // Apply would set.
        root.filter = "";
        root.selectPath(Wallpaper.current);
        input.forceActiveFocus();
        preview.restart();
    }

    // A dry run per keystroke of the arrow keys would be four matugen
    // invocations a second; one per pause is what the panel actually needs.
    onPathChanged: if (root.shown)
        preview.restart()

    Timer {
        id: preview

        interval: Appearance.anim.normal
        onTriggered: {
            // The service drops a request made while one is in flight, so this
            // waits for the last one rather than losing the newest selection.
            if (Wallpaper.previewing)
                return preview.restart();
            if (root.shown && root.path)
                Wallpaper.preview(root.path);
        }
    }

    // Follows the focused monitor; `Hypr` is empty for the first second or two
    // of a session, so this falls through to the first screen rather than null.
    screen: {
        const screens = Quickshell.screens;
        if (screens.length === 0)
            return null;
        return screens.find(s => s.name === Hypr.focusedMonitorName) ?? screens[0];
    }

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
    WlrLayershell.namespace: "vela-wallpaper"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // `super + shift + W`, which is a Hyprland bind rather than a key this
    // window can see -- the switcher does not have to be open to revert.
    //
    //     qs -c vela ipc call wallpaper revert
    IpcHandler {
        target: "wallpaper"

        function revert(): void {
            Wallpaper.revert();
        }

        function apply(path: string): void {
            Wallpaper.apply(path, "");
        }
    }

    // A FocusScope, not a plain Item: when a clicked control inside takes
    // focus and then goes away, focus falls back to the scope and the keys
    // below still arrive.
    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => root.handleKey(event)

        MouseArea {
            anchors.fill: parent

            onClicked: mouse => {
                const p = mapToItem(panel, mouse.x, mouse.y);
                if (p.x < 0 || p.y < 0 || p.x > panel.width || p.y > panel.height)
                    ShellState.close("wallpaper");
            }
        }

        Panel {
            id: panel

            level: "drawer"
            padding: Appearance.space.drawerPadding

            // Capped rather than fixed: the shell has to open on whatever
            // monitor it is given, and a panel wider than its screen would
            // run off it.
            width: Math.min(Appearance.wallpaper.width, parent.width - root.insetLeft - root.insetRight - Appearance.space.overlayMargin * 2)
            implicitHeight: column.implicitHeight + panel.padding * 2

            x: Math.round(root.insetLeft + (parent.width - root.insetLeft - root.insetRight - width) / 2)

            // The design's offset down the frame, clamped so a short screen
            // gets the panel pushed up rather than run off the bottom edge --
            // no surface ever touches a screen edge.
            readonly property int restY: {
                const free = parent.height - root.insetTop - root.insetBottom;
                const wanted = root.insetTop + free * Appearance.wallpaper.topFraction;
                const lowest = root.insetTop + free - panel.implicitHeight - Appearance.space.overlayMargin;
                const highest = root.insetTop + Appearance.space.overlayMargin;
                return Math.round(Math.max(highest, Math.min(wanted, lowest)));
            }
            y: panel.restY + entrance.offset
            opacity: entrance.opacity

            Reveal {
                id: entrance

                shown: root.shown
            }

            ColumnLayout {
                id: column

                anchors.fill: parent
                spacing: Appearance.wallpaper.blockGap

                // ---- header ------------------------------------------------
                RowLayout {
                    spacing: Appearance.wallpaper.headerGap

                    Layout.fillWidth: true

                    Icon {
                        text: "wallpaper"
                        size: Appearance.size.iconLg
                        // The field the shell is waiting on -- the same reason
                        // the launcher's search glyph carries the accent.
                        color: Colours.primary

                        Layout.alignment: Qt.AlignVCenter
                    }

                    TextInput {
                        id: input

                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.heading
                        color: Colours.on.surface
                        selectionColor: Colours.primaryContainer
                        selectedTextColor: Colours.on.primaryContainer
                        selectByMouse: true
                        // Drawn below rather than by Qt: the built-in caret
                        // blinks, and nothing in this shell pulses.
                        cursorDelegate: Item {}

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        onTextChanged: {
                            if (root.filter === input.text)
                                return;
                            root.filter = input.text;
                            // A narrowed list starts at its own first entry,
                            // not at whatever ordinal the cursor was on.
                            root.index = 0;
                        }

                        Keys.onPressed: event => root.handleKey(event)

                        Connections {
                            target: root

                            function onFilterChanged(): void {
                                if (input.text !== root.filter)
                                    input.text = root.filter;
                            }
                        }

                        Text {
                            // Clear of the caret, which sits at x 0 while the
                            // field is empty.
                            x: Appearance.wallpaper.caretWidth + Appearance.space.xs
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text.length === 0
                            text: qsTr("Type to filter")
                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.size.heading
                            color: Colours.outline
                        }

                        Rectangle {
                            x: input.cursorRectangle.x
                            y: input.cursorRectangle.y + Math.round((input.cursorRectangle.height - height) / 2)
                            implicitWidth: Appearance.wallpaper.caretWidth
                            implicitHeight: Appearance.wallpaper.caretHeight
                            color: Colours.primary
                            visible: input.activeFocus
                        }
                    }

                    Text {
                        text: root.countText
                        // A path and two ordinals.
                        font.family: Appearance.font.mono
                        font.pixelSize: Appearance.size.label
                        color: Colours.outline
                        elide: Text.ElideRight

                        Layout.alignment: Qt.AlignVCenter
                    }

                    Keycap {
                        key: Config.keybinds.wallpaper

                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                // ---- coverflow ---------------------------------------------
                Coverflow {
                    entries: root.entries
                    index: root.index
                    onActivated: i => root.index = i

                    Layout.fillWidth: true
                }

                // ---- palette and preview -----------------------------------
                RowLayout {
                    spacing: Appearance.wallpaper.panelGap

                    Layout.fillWidth: true

                    PalettePanel {
                        path: root.path
                        monitor: Hypr.focusedMonitorName
                        mode: root.mode
                        onModePicked: m => {
                            root.mode = m;
                            input.forceActiveFocus();
                        }
                        onApplied: root.applyEverywhere()
                        onAppliedToMonitor: root.applyHere()

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    Card {
                        radius: Appearance.radius.cardXl

                        Layout.fillWidth: false
                        Layout.preferredWidth: Appearance.wallpaper.previewWidth
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Appearance.wallpaper.previewGap

                            SectionLabel {
                                text: qsTr("Preview on the bar")

                                Layout.fillWidth: true
                            }

                            BarPreview {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                            }

                            RowLayout {
                                spacing: Appearance.space.sm

                                Layout.fillWidth: true

                                Icon {
                                    text: "history"
                                    size: Appearance.size.iconSm
                                    color: Colours.outline
                                }

                                Text {
                                    text: qsTr("Revert with")
                                    font.family: Appearance.font.ui
                                    font.pixelSize: Appearance.size.caption
                                    color: Colours.outline
                                }

                                Text {
                                    // A keybind is a literal.
                                    text: Config.keybinds.wallpaperRevert
                                    font.family: Appearance.font.mono
                                    font.pixelSize: Appearance.size.caption
                                    color: Colours.outline
                                    elide: Text.ElideRight

                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }

                // ---- filmstrip ---------------------------------------------
                Filmstrip {
                    entries: Wallpaper.wallpapers
                    onActivated: i => {
                        // The strip is the whole folder; the coverflow may be
                        // filtered, so select by path rather than by ordinal.
                        root.filter = "";
                        root.selectPath(Wallpaper.wallpapers[i].path);
                    }

                    Layout.fillWidth: true
                }
            }
        }
    }
}
