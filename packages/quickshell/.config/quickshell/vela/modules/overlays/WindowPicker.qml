import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.tokens
import qs.config
import qs.services
import qs.components

// The window picker, on `alt + tab`. A 1080px panel with a three-column grid
// of live window thumbnails, filtered by whatever is typed.
//
// It replaces alt-tab rather than decorating it, so it behaves like alt-tab:
// the grid is in focus-history order, the selection starts on the window you
// were on *before* this one, and letting go of alt commits. Everything else is
// a bonus -- arrows, a filter, `ctrl+w` to close a window without focusing it,
// and `shift+return` to pull a window here instead of travelling to it.
PanelWindow {
    id: root

    readonly property bool shown: ShellState.windowPicker

    // Typed straight into the panel rather than into a TextInput: the design
    // draws a bare string and a caret, not a field, and a picker that needs a
    // click before it will accept a keystroke is not a picker.
    property string query: ""
    // Which windows the grid offers. "This monitor" only means something with
    // a second monitor: on one, it is every window, and choosing it changed
    // nothing at all. So it is offered only then, and "This workspace" --
    // which narrows the list on any setup -- always is.
    property string scope: "all"
    readonly property var scopes: Quickshell.screens.length > 1 ? ["all", "monitor", "workspace"] : ["all", "workspace"]
    readonly property var scopeLabels: ({
            "all": qsTr("All"),
            "monitor": qsTr("This monitor"),
            "workspace": qsTr("This workspace")
        })
    // The monitor choice goes when the second monitor does; "all" then.
    readonly property int scopeIndex: Math.max(0, root.scopes.indexOf(root.scope))
    readonly property string shownScope: root.scopes[root.scopeIndex]
    property int selected: 0
    // Alt-tab commits on release, but only if alt was ever down -- the picker
    // can also be opened from the bar or over IPC, and a stray modifier release
    // must not then fire it.
    property bool altHeld: false

    readonly property list<var> scoped: {
        const here = Hypr.focusedMonitorName;
        const ws = Hypr.focusedWorkspaceId;
        if (root.shownScope === "monitor")
            return Hypr.clients.filter(c => (c.monitor?.name ?? "") === here);
        if (root.shownScope === "workspace")
            return Hypr.clients.filter(c => (c.workspace?.id ?? 0) === ws);
        // Copied: a toplevel list assigned to a `list<var>` as it is becomes
        // one entry, the list itself.
        return [...Hypr.clients];
    }

    // Focus history ascending: index 0 is the window on screen now, index 1 is
    // the one before it, and a window never focused sorts last rather than
    // first. Kept live from focus events (`Hypr.focusRank`), so it is right
    // the moment the picker opens: a quick alt + tab commits before any query
    // could answer.
    readonly property list<var> ordered: [...root.scoped].sort((a, b) => Hypr.focusRank(a) - Hypr.focusRank(b))

    readonly property list<var> matched: {
        const q = root.query.trim().toLowerCase();
        if (!q)
            return root.ordered;
        return root.ordered.filter(c => (c.title ?? "").toLowerCase().includes(q) || Hypr.classOf(c).toLowerCase().includes(q));
    }

    // The design draws six windows. A real session holds many more and a grid
    // that runs off the bottom of the screen is not a picker, so the rest are
    // counted in the footer instead.
    readonly property list<var> cards: root.matched.slice(0, Appearance.overlays.picker.maximum)

    // `selected` clamped to what the filter left, so a list that shrank under
    // it still highlights the card return would open.
    readonly property int shownIndex: Math.min(root.selected, root.cards.length - 1)
    readonly property var current: root.cards.length > 0 ? root.cards[root.shownIndex] : null

    readonly property string countText: {
        const windows = root.scoped.length;
        const spaces = new Set(root.scoped.map(c => c.workspace?.id ?? 0)).size;
        const w = windows === 1 ? qsTr("1 window") : qsTr("%1 windows").arg(windows);
        const s = spaces === 1 ? qsTr("1 workspace") : qsTr("%1 workspaces").arg(spaces);
        return `${w} · ${s}`;
    }

    readonly property string filterText: {
        if (root.query.trim())
            return qsTr("filtering “%1” · %2 of %3").arg(root.query).arg(root.cards.length).arg(root.ordered.length);
        if (root.cards.length < root.matched.length)
            return qsTr("%1 of %2").arg(root.cards.length).arg(root.matched.length);
        return "";
    }

    function move(by: int): void {
        const n = root.cards.length;
        if (n === 0)
            return;
        root.selected = Math.max(0, Math.min(n - 1, root.selected + by));
    }

    function cycle(by: int): void {
        const n = root.cards.length;
        if (n === 0)
            return;
        root.selected = (root.selected + by + n) % n;
    }

    function activate(pull: bool): void {
        // The surface keeps the keyboard while it fades out, so a second alt
        // release (or a return pressed in that moment) would commit again.
        if (!root.shown)
            return;
        const client = root.current;
        ShellState.close("windowPicker");
        if (!client)
            return;
        if (pull)
            Hypr.pullWindowHere(client.address);
        else
            Hypr.focusWindow(client.address);
    }

    function closeCurrent(): void {
        const client = root.current;
        if (!client)
            return;
        Hypr.closeWindow(client.address);
        // The list shrinks under the cursor; keeping the index in range here
        // rather than waiting for the next clamp stops the selection jumping to
        // the end of the grid for a frame.
        root.selected = Math.max(0, Math.min(root.selected, root.cards.length - 2));
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
    WlrLayershell.namespace: "vela-window-picker"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (!root.shown) {
            root.altHeld = false;
            return;
        }
        // Opened by alt + tab: alt is down now, even though this surface never
        // saw it go down.
        root.altHeld = ShellState.altTabbing;
        const backwards = ShellState.altTabbing && ShellState.altTabStart < 0;
        // Titles and workspaces, which Quickshell only refreshes on a full
        // toplevel query. The order does not wait for it.
        Hypr.refresh();
        root.query = "";
        root.scope = "all";
        // Alt-tab's whole contract: one press lands on the window you came
        // from, not on the one you are already looking at.
        root.selected = backwards ? Math.max(0, root.cards.length - 1) : (root.cards.length > 1 ? 1 : 0);
        keys.forceActiveFocus();
    }

    Connections {
        target: ShellState

        function onAltTabStep(step: int): void {
            root.cycle(step);
        }

        // Alt let go, as Hyprland saw it -- in time even when that was before
        // this surface had the keyboard, which a quick alt + tab always is.
        function onAltTabReleased(): void {
            if (root.altHeld)
                root.activate(false);
        }
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Alt) {
                root.altHeld = true;
                event.accepted = true;
                return;
            }
            switch (event.key) {
            case Qt.Key_Escape:
                ShellState.close("windowPicker");
                break;
            case Qt.Key_Left:
                root.move(-1);
                break;
            case Qt.Key_Right:
                root.move(1);
                break;
            case Qt.Key_Up:
                root.move(-Appearance.overlays.columns);
                break;
            case Qt.Key_Down:
                root.move(Appearance.overlays.columns);
                break;
            case Qt.Key_Tab:
                root.cycle(1);
                break;
            case Qt.Key_Backtab:
                root.cycle(-1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.activate(!!(event.modifiers & Qt.ShiftModifier));
                break;
            case Qt.Key_W:
                if (!(event.modifiers & Qt.ControlModifier)) {
                    root.query += event.text;
                    break;
                }
                root.closeCurrent();
                break;
            case Qt.Key_Backspace:
                root.query = root.query.slice(0, -1);
                break;
            default:
                // Anything printable filters. `event.text` is empty for a bare
                // modifier or a function key, which is exactly the test wanted.
                if (event.text.length !== 1 || event.text.charCodeAt(0) < 0x20)
                    return;
                root.query += event.text;
                break;
            }
            event.accepted = true;
        }

        Keys.onReleased: event => {
            if (event.key !== Qt.Key_Alt || !root.altHeld)
                return;
            event.accepted = true;
            root.activate(false);
        }

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
                    ShellState.close("windowPicker");
            }
        }

        Panel {
            id: panel

            level: "drawer"
            padding: Appearance.space.drawerPadding

            // 1080 as designed, but never wider than the room the bar leaves
            // it: a panel that runs off both edges of a small output is not a
            // floating panel, and the invariant is that nothing touches an edge.
            width: Math.min(Appearance.overlays.picker.width, parent.width - root.insetLeft - root.insetRight - Appearance.space.overlayMargin * 2)
            implicitHeight: column.implicitHeight + panel.padding * 2

            x: Math.round(root.insetLeft + (parent.width - root.insetLeft - root.insetRight - width) / 2)

            readonly property int restY: Math.round(root.insetTop + (parent.height - root.insetTop - root.insetBottom) * Appearance.overlays.topPicker)
            y: panel.restY
            // The design gives the picker no translation at all -- it is a
            // replacement for a key combination, not a drawer -- so it comes
            // forward instead of rising, from just under full size. A quick
            // alt + tab commits on release whatever the picker is showing, so
            // none of this is ever waited on.
            opacity: entrance.opacity
            scale: entrance.scale

            Reveal {
                id: entrance

                shown: root.shown
                distance: 0
                scaleFrom: Appearance.overlays.picker.enterScale
            }

            ColumnLayout {
                id: column

                anchors.fill: parent
                spacing: Appearance.overlays.blockGap

                // ---- header ------------------------------------------------
                RowLayout {
                    spacing: Appearance.overlays.headerGap

                    Layout.fillWidth: true

                    Icon {
                        text: "select_window"
                        size: Appearance.size.iconLg
                        color: Colours.primary

                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: root.query
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.heading
                        color: Colours.on.surface
                        elide: Text.ElideRight

                        Layout.alignment: Qt.AlignVCenter
                        Layout.maximumWidth: root.width / 3
                    }

                    // Unblinking, like the launcher's: nothing in this shell
                    // pulses.
                    Rectangle {
                        implicitWidth: Appearance.overlays.picker.caretWidth
                        implicitHeight: Appearance.overlays.picker.caretHeight
                        color: Colours.primary

                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: -Appearance.overlays.headerGap + Appearance.space.xs
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.countText
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.label
                        color: Colours.outline

                        Layout.alignment: Qt.AlignVCenter
                    }

                    Segmented {
                        // Re-asserted, not only bound: a click writes the
                        // rail's own index, which undoes a plain binding, and
                        // the picker then reopened on All with the rail still
                        // showing the last choice.
                        readonly property int wanted: root.scopeIndex

                        model: root.scopes.map(s => root.scopeLabels[s])
                        currentIndex: wanted
                        onWantedChanged: currentIndex = wanted
                        segmentHeight: Appearance.overlays.picker.segmentHeight
                        segmentRadius: Appearance.overlays.picker.segmentRadius
                        railRadius: Appearance.overlays.picker.railRadius
                        hPadding: Appearance.overlays.picker.segmentPadding
                        fontSize: Appearance.size.caption

                        Layout.alignment: Qt.AlignVCenter

                        onSelected: i => {
                            root.scope = root.scopes[i];
                            root.selected = root.cards.length > 1 ? 1 : 0;
                            // The click left the keyboard on the rail, where
                            // typing, return and escape went nowhere.
                            keys.forceActiveFocus();
                        }
                    }
                }

                // ---- the grid ----------------------------------------------
                //
                // A card is always one column of three wide, however many
                // there are. Stretched to fill the row instead, a lone window
                // became a strip the width of the panel and only 168px tall,
                // and two became two half-panel strips. A row of fewer than
                // three is centred; from four on the grid is full and the last
                // row starts at the left, as a grid's does.
                GridLayout {
                    id: grid

                    readonly property real cardWidth: Math.floor((column.width - Appearance.overlays.cardGap * (Appearance.overlays.columns - 1)) / Appearance.overlays.columns)

                    columns: Math.max(1, Math.min(Appearance.overlays.columns, root.cards.length))
                    columnSpacing: Appearance.overlays.cardGap
                    rowSpacing: Appearance.overlays.cardGap
                    visible: root.cards.length > 0

                    Layout.alignment: Qt.AlignHCenter

                    Repeater {
                        model: root.cards

                        WindowCard {
                            required property var modelData
                            required property int index

                            client: modelData
                            query: root.query
                            selected: index === root.shownIndex
                            // Captures run only while the picker is on screen.
                            capturing: root.shown

                            Layout.preferredWidth: grid.cardWidth
                            Layout.preferredHeight: implicitHeight

                            onClicked: root.selected = index
                            onActivated: root.activate(false)
                        }
                    }
                }

                Text {
                    visible: root.cards.length === 0
                    text: root.query.trim() ? qsTr("No window matches “%1”").arg(root.query) : root.shownScope === "workspace" ? qsTr("No windows on this workspace") : root.shownScope === "monitor" ? qsTr("No windows on this monitor") : qsTr("No other windows are open")
                    font.family: Appearance.font.ui
                    font.pixelSize: Appearance.size.label
                    color: Colours.outline
                    horizontalAlignment: Text.AlignHCenter

                    Layout.fillWidth: true
                    Layout.topMargin: Appearance.space.xl
                    Layout.bottomMargin: Appearance.space.xl
                }

                // ---- footer -------------------------------------------------
                RowLayout {
                    spacing: Appearance.overlays.picker.hintGap

                    Layout.fillWidth: true
                    Layout.leftMargin: Appearance.space.xs / 2
                    Layout.rightMargin: Appearance.space.xs / 2

                    Repeater {
                        model: [
                            {
                                "key": "↑↓←→",
                                "verb": qsTr("move")
                            },
                            {
                                "key": "↵",
                                "verb": qsTr("focus")
                            },
                            {
                                "key": "shift+↵",
                                "verb": qsTr("pull to this workspace")
                            },
                            {
                                "key": "ctrl+w",
                                "verb": qsTr("close")
                            }
                        ]

                        Text {
                            required property var modelData

                            text: `<font color="${Colours.on.surfaceVariant}">${modelData.key}</font> ${modelData.verb}`
                            textFormat: Text.StyledText
                            font.family: Appearance.font.mono
                            font.pixelSize: Appearance.size.caption
                            color: Colours.outline
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.filterText
                        font.family: Appearance.font.mono
                        font.pixelSize: Appearance.size.caption
                        color: Colours.outline
                    }
                }
            }
        }
    }
}
