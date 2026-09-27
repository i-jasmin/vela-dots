pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.tokens
import qs.config
import qs.services
import qs.components

// The keybinds cheatsheet, on super + < (super + / on a US layout).
//
// A 1160px drawer over a blurred 70% dim: a header with a filter field and the
// main modifier, three columns of group cards, one row per bind, and a footer
// that says where the list came from.
//
// NOT A STATIC LIST, which is the rule the screen exists to state. Every row is
// read from `hyprctl binds` when this opens (see `services/Binds.qml`), so it
// can never disagree with binds.lua; the only rows written here are keys that
// Hyprland does not own -- the ones inside a surface.
PanelWindow {
    id: root

    readonly property bool shown: ShellState.keybinds

    property string query: ""

    // The groups with only the rows that match the filter, by key or action.
    readonly property var matched: {
        const q = root.query.trim().toLowerCase();
        if (!q)
            return Binds.groups;
        const out = [];
        for (const g of Binds.groups) {
            const rows = g.rows.filter(r => r.action.toLowerCase().includes(q) || r.keys.join(" + ").toLowerCase().includes(q) || g.name.toLowerCase().includes(q));
            if (rows.length > 0)
                out.push({
                    name: g.name,
                    icon: g.icon,
                    rows: rows
                });
        }
        return out;
    }

    // Groups flow down the first column, then the second, then the third, in
    // order -- the split point chosen so the tallest column is as short as it
    // can be. A card costs its header and padding as well as its rows.
    readonly property var columns: {
        const k = Appearance.keybinds;
        const cost = g => g.rows.length * (k.rowHeight + k.rowGap) + k.cardPadding * 2 + Appearance.size.iconLabel + k.cardGap + k.columnGap;
        const groups = root.matched;
        const n = groups.length;
        const sum = (a, b) => groups.slice(a, b).reduce((t, g) => t + cost(g), 0);
        // Ties on the tallest column go to the most even split, or a short
        // first column can win over a balanced one; then to the split that
        // sits furthest left, so a filtered list leaves the last column empty,
        // not the first.
        let best = [groups, [], []];
        let bestKey = [Infinity, Infinity, Infinity];
        for (let i = 0; i <= n; i++) {
            for (let j = i; j <= n; j++) {
                const h = [sum(0, i), sum(i, j), sum(j, n)];
                const key = [Math.max(...h), h.reduce((t, x) => t + x * x, 0), -(i + j)];
                const better = key[0] !== bestKey[0] ? key[0] < bestKey[0] : key[1] !== bestKey[1] ? key[1] < bestKey[1] : key[2] < bestKey[2];
                if (better) {
                    bestKey = key;
                    best = [groups.slice(0, i), groups.slice(i, j), groups.slice(j, n)];
                }
            }
        }
        return best;
    }

    // A row's keys with a null between each pair, where the `+` goes. By hand:
    // the list arrives through the model as a sequence, which has no flatMap.
    function tokens(keys: var): var {
        const out = [];
        for (let i = 0; i < keys.length; i++) {
            if (i > 0)
                out.push(null);
            out.push(keys[i]);
        }
        return out;
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
    WlrLayershell.namespace: "vela-keybinds"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (!root.shown)
            return;
        root.query = "";
        filter.text = "";
        Binds.refresh();
        filter.forceActiveFocus();
    }

    FocusScope {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: event => {
            ShellState.close("keybinds");
            event.accepted = true;
        }

        // The power menu's kind of stop, a shade lighter: what is behind is
        // there to be recognised, not read.
        Rectangle {
            anchors.fill: parent
            color: Colours.alpha(Colours.scrim, Appearance.keybinds.dim)
            opacity: panel.opacity
        }

        MouseArea {
            anchors.fill: parent

            onClicked: event => {
                const p = mapToItem(panel, event.x, event.y);
                if (p.x < 0 || p.y < 0 || p.x > panel.width || p.y > panel.height)
                    ShellState.close("keybinds");
            }
        }

        Panel {
            id: panel

            level: "drawer"
            padding: Appearance.space.drawerPadding

            readonly property int available: parent.width - root.insetLeft - root.insetRight - Appearance.space.overlayMargin * 2

            width: Math.min(Appearance.keybinds.width, panel.available)
            implicitHeight: column.implicitHeight + panel.padding * 2

            // Centred on the space the bar leaves -- the design's
            // `calc(50% + 34px)`.
            x: Math.round(root.insetLeft + (parent.width - root.insetLeft - root.insetRight - width) / 2)

            // The design's top, unless the list is too long to fit below it --
            // a config with more binds than the design's -- in which case the
            // panel rises to the overlay margin before anything scrolls.
            readonly property int designY: Math.round(root.insetTop + (parent.height - root.insetTop - root.insetBottom) * Appearance.keybinds.top)
            readonly property int highestY: root.insetTop + Appearance.space.overlayMargin
            readonly property int naturalHeight: column.implicitHeight - grid.height + columnsRow.implicitHeight + panel.padding * 2
            readonly property int restY: Math.max(panel.highestY, Math.min(panel.designY, parent.height - root.insetBottom - Appearance.space.overlayMargin - panel.naturalHeight))
            // Whatever is left below the top: past that the grid scrolls
            // rather than the panel running off the bottom.
            readonly property int maxHeight: parent.height - root.insetBottom - panel.restY - Appearance.space.overlayMargin

            y: panel.restY + entrance.offset
            opacity: entrance.opacity

            Reveal {
                id: entrance

                shown: root.shown
            }

            ColumnLayout {
                id: column

                width: panel.width - panel.padding * 2
                spacing: Appearance.space.lg

                // ---- header ------------------------------------------------
                RowLayout {
                    id: headerRow

                    spacing: Appearance.keybinds.headerGap

                    Layout.fillWidth: true

                    Icon {
                        text: "keyboard"
                        size: Appearance.size.iconLg
                        color: Colours.primary
                    }

                    Text {
                        text: qsTr("Keybinds")
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.heading
                        color: Colours.on.surface
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth: Appearance.keybinds.filterWidth
                        implicitHeight: Appearance.keybinds.filterHeight
                        radius: height / 2
                        color: Colours.hover

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Appearance.keybinds.filterPad
                            anchors.rightMargin: Appearance.keybinds.filterPad
                            spacing: Appearance.keybinds.filterGap

                            Icon {
                                text: "search"
                                size: Appearance.size.iconLabel
                                color: Colours.outline
                            }

                            TextInput {
                                id: filter

                                clip: true
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.keybinds.textSize
                                color: Colours.on.surface
                                selectionColor: Colours.primaryContainer
                                selectedTextColor: Colours.on.primaryContainer

                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter

                                onTextChanged: root.query = filter.text

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !filter.text
                                    text: qsTr("Filter by key or action")
                                    font: filter.font
                                    color: Colours.outline
                                }
                            }
                        }
                    }

                    RowLayout {
                        spacing: Appearance.keybinds.modGap

                        Text {
                            text: qsTr("mod is")
                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.size.label
                            color: Colours.outline
                        }

                        Keycap {
                            large: true
                            key: Binds.mod
                        }
                    }
                }

                // ---- the groups ------------------------------------------------
                Flickable {
                    id: grid

                    clip: true
                    contentHeight: columnsRow.implicitHeight
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(columnsRow.implicitHeight, Math.max(0, panel.maxHeight - panel.padding * 2 - headerRow.height - footer.height - column.spacing * 2))

                    RowLayout {
                        id: columnsRow

                        width: grid.width
                        spacing: Appearance.keybinds.columnGap

                        Repeater {
                            model: root.columns

                            ColumnLayout {
                                id: col

                                required property var modelData
                                required property int index

                                spacing: Appearance.keybinds.columnGap

                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.alignment: Qt.AlignTop

                                Repeater {
                                    model: col.modelData

                                    Card {
                                        id: card

                                        required property var modelData
                                        required property int index

                                        opacity: arrival.opacity
                                        transform: Translate {
                                            y: arrival.offset
                                        }

                                        // Across the columns row by row, so
                                        // the sheet fills in from the top.
                                        Stagger {
                                            id: arrival

                                            index: card.index * root.columns.length + col.index
                                            active: entrance.entering
                                        }

                                        // The card's key column: its widest chord,
                                        // so its actions line up, within keysWidth
                                        // and keysMax.
                                        readonly property real keysWidth: {
                                            const k = Appearance.keybinds;
                                            let w = k.keysWidth;
                                            for (const row of rows.children)
                                                if (row.chordWidth !== undefined && row.chordWidth <= k.keysMax)
                                                    w = Math.max(w, row.chordWidth);
                                            return w;
                                        }

                                        radius: Appearance.radius.cardLg
                                        padding: Appearance.keybinds.cardPadding
                                        implicitHeight: body.implicitHeight + card.padding * 2

                                        Layout.fillWidth: true

                                        ColumnLayout {
                                            id: body

                                            width: parent.width
                                            spacing: Appearance.keybinds.cardGap

                                            RowLayout {
                                                spacing: Appearance.keybinds.cardHeaderGap

                                                Icon {
                                                    text: card.modelData.icon
                                                    size: Appearance.size.iconLabel
                                                    color: Colours.primary
                                                }

                                                SectionLabel {
                                                    text: card.modelData.name
                                                    Layout.fillWidth: true
                                                }
                                            }

                                            ColumnLayout {
                                                id: rows

                                                spacing: Appearance.keybinds.rowGap

                                                Layout.fillWidth: true

                                                Repeater {
                                                    model: card.modelData.rows

                                                    RowLayout {
                                                        id: bindRow

                                                        required property var modelData
                                                        readonly property real chordWidth: chord.implicitWidth

                                                        spacing: Appearance.keybinds.rowSpacing

                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: Appearance.keybinds.rowHeight

                                                        // One flat run of keys and the `+` between
                                                        // them. Nested Rows collapsed to zero width
                                                        // here and drew every key on top of the last.
                                                        // A chord wider than the card's column (super
                                                        // + ctrl + shift + 1–5) pushes only its own
                                                        // action along, never over it.
                                                        RowLayout {
                                                            id: chord

                                                            spacing: Appearance.keybinds.keyGap

                                                            Layout.preferredWidth: Math.max(card.keysWidth, chord.implicitWidth)
                                                            Layout.minimumWidth: Layout.preferredWidth
                                                            Layout.maximumWidth: Layout.preferredWidth
                                                            Layout.fillWidth: false
                                                            Layout.alignment: Qt.AlignVCenter

                                                            Repeater {
                                                                model: root.tokens(bindRow.modelData.keys)

                                                                Item {
                                                                    id: token

                                                                    required property var modelData
                                                                    readonly property bool plus: token.modelData === null

                                                                    implicitWidth: token.plus ? plusSign.implicitWidth : cap.implicitWidth
                                                                    implicitHeight: cap.implicitHeight

                                                                    Layout.alignment: Qt.AlignVCenter

                                                                    Text {
                                                                        id: plusSign

                                                                        visible: token.plus
                                                                        anchors.centerIn: parent
                                                                        text: "+"
                                                                        font.family: Appearance.font.ui
                                                                        font.pixelSize: Appearance.keybinds.plusSize
                                                                        color: Colours.outlineVariant
                                                                    }

                                                                    Keycap {
                                                                        id: cap

                                                                        visible: !token.plus
                                                                        large: true
                                                                        key: token.modelData ?? ""
                                                                    }
                                                                }
                                                            }

                                                            Item {
                                                                Layout.fillWidth: true
                                                            }
                                                        }

                                                        Text {
                                                            text: bindRow.modelData.action
                                                            font.family: Appearance.font.ui
                                                            font.pixelSize: Appearance.keybinds.textSize
                                                            color: bindRow.modelData.secondary ? Colours.outline : Colours.on.surfaceVariant
                                                            elide: Text.ElideRight

                                                            Layout.fillWidth: true
                                                            Layout.alignment: Qt.AlignVCenter
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: Binds.loaded && root.matched.length === 0
                    text: Binds.groups.length === 0 ? (Binds.error || qsTr("Hyprland reported no binds")) : qsTr("Nothing bound matches “%1”").arg(root.query)
                    font.family: Appearance.font.ui
                    font.pixelSize: Appearance.keybinds.textSize
                    color: Colours.outline

                    Layout.fillWidth: true
                    Layout.leftMargin: Appearance.keybinds.footerPad
                }

                // ---- footer ------------------------------------------------
                RowLayout {
                    id: footer

                    spacing: Appearance.keybinds.footerGap

                    Layout.fillWidth: true
                    Layout.leftMargin: Appearance.keybinds.footerPad
                    Layout.rightMargin: Appearance.keybinds.footerPad

                    Text {
                        text: qsTr("%1 binds · read live from hyprctl binds").arg(Binds.count)
                        font.family: Appearance.font.mono
                        font.pixelSize: Appearance.size.caption
                        color: Colours.outline
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: Appearance.keybinds.linkGap

                        Icon {
                            text: "edit"
                            size: Appearance.size.iconSm
                            color: Colours.outline
                        }

                        Text {
                            text: qsTr("Edit in settings")
                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.size.label
                            color: Colours.primary

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -Appearance.space.xs
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ShellState.openSettings("keybinds")
                            }
                        }
                    }

                    RowLayout {
                        spacing: Appearance.keybinds.modGap

                        Text {
                            text: qsTr("dismiss")
                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.size.label
                            color: Colours.outline
                        }

                        Keycap {
                            large: true
                            key: "esc"
                        }
                    }
                }
            }
        }
    }
}
