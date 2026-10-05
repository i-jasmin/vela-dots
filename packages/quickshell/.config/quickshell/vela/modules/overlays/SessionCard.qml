import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.services
import qs.components

// One saved layout in the sessions panel: a mini diagram of the windows, the
// name, the count and the applications, and the card's verb.
//
// THE DIAGRAM IS THE SAVED GEOMETRY, not an illustration. Every window in the
// session's busiest workspace is normalised into the tile box, so a two-up
// split looks like a two-up split and a main-and-stack looks like a
// main-and-stack. The window that had focus when the session was saved takes
// the primary outline -- the one piece of colour on an inactive card.
Item {
    id: root

    required property var session
    // NOT `index`: the panel's Repeater declares that on the delegate, and a
    // component that also declares it required is shadowed by the delegate's
    // copy and never initialised. The card has no use for it anyway -- it
    // signals, and the panel knows which card signalled.
    property bool active: false
    property bool canRestore: false
    // This card's layout is being brought back right now.
    property bool restoring: false
    property bool editing: false
    property bool menuOpen: false

    readonly property var windows: root.session?.windows ?? []

    signal updateRequested
    signal restoreRequested
    signal renamed(string name)
    signal forgotten

    // The workspace with the most windows in it is the one worth drawing: a
    // session usually has one real layout and a stray window somewhere else.
    readonly property int busiestWorkspace: {
        const counts = {};
        for (const w of root.windows)
            counts[w.workspace] = (counts[w.workspace] ?? 0) + 1;
        let best = 0;
        let bestCount = -1;
        for (const id in counts)
            if (counts[id] > bestCount) {
                best = parseInt(id);
                bestCount = counts[id];
            }
        return best;
    }

    // Fractions of the diagram box, so the tiles scale with it rather than
    // carrying pixel geometry from whatever monitor saved them.
    readonly property var tiles: {
        const here = root.windows.filter(w => w.workspace === root.busiestWorkspace && w.w > 0 && w.h > 0);
        if (here.length === 0)
            return [];
        const minX = Math.min(...here.map(w => w.x));
        const minY = Math.min(...here.map(w => w.y));
        const spanX = Math.max(1, Math.max(...here.map(w => w.x + w.w)) - minX);
        const spanY = Math.max(1, Math.max(...here.map(w => w.y + w.h)) - minY);
        return here.map(w => ({
                    "fx": (w.x - minX) / spanX,
                    "fy": (w.y - minY) / spanY,
                    "fw": w.w / spanX,
                    "fh": w.h / spanY,
                    "focused": !!w.focused
                }));
    }

    // "3 windows · 2 workspaces · Obsidian, foot, Firefox". The workspace count
    // is dropped when there is only one.
    readonly property string meta: {
        const n = root.windows.length;
        const spaces = new Set(root.windows.map(w => w.workspace)).size;
        const counts = {};
        for (const w of root.windows)
            counts[w.appClass] = (counts[w.appClass] ?? 0) + 1;
        const apps = Object.keys(counts).map(k => counts[k] > 1 ? `${Hypr.appName(k)} ×${counts[k]}` : Hypr.appName(k)).join(", ");
        const parts = [n === 1 ? qsTr("1 window") : qsTr("%1 windows").arg(n)];
        if (spaces > 1)
            parts.push(qsTr("%1 workspaces").arg(spaces));
        if (apps)
            parts.push(apps);
        return parts.join(" · ");
    }

    implicitHeight: card.implicitHeight

    Rectangle {
        anchors.fill: parent
        anchors.margins: -Appearance.overlays.halo
        radius: Appearance.radius.cardXl + Appearance.overlays.halo
        color: "transparent"
        border.width: Appearance.overlays.halo
        border.color: Colours.alpha(Colours.primary, Appearance.overlays.haloAlphaSoft)
        visible: root.active
    }

    Card {
        id: card

        anchors.fill: parent
        radius: Appearance.radius.cardXl
        padding: Appearance.overlays.sessions.cardPadding
        implicitHeight: body.implicitHeight + card.padding * 2

        ColumnLayout {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Appearance.overlays.sessions.cardGap

            // ---- the layout diagram ---------------------------------------
            Rectangle {
                id: diagram

                radius: Appearance.overlays.sessions.diagramRadius
                color: Colours.alpha(Colours.surface, 0.7)
                clip: true

                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.overlays.sessions.diagram

                Item {
                    id: field

                    anchors.fill: parent
                    anchors.margins: Appearance.overlays.sessions.diagramPadding

                    Repeater {
                        model: root.tiles

                        Rectangle {
                            required property var modelData

                            readonly property int gap: Appearance.overlays.sessions.diagramGap

                            x: Math.round(modelData.fx * field.width + gap / 2)
                            y: Math.round(modelData.fy * field.height + gap / 2)
                            width: Math.max(1, Math.round(modelData.fw * field.width - gap))
                            height: Math.max(1, Math.round(modelData.fh * field.height - gap))

                            radius: Appearance.overlays.sessions.tileRadius
                            color: Colours.surfaceContainerHigh
                            // The focused window is outlined rather than filled:
                            // a diagram that fills one tile with the accent
                            // reads as a selection, which it is not.
                            border.width: modelData.focused ? 1 : 0
                            border.color: Colours.alpha(Colours.primary, 0.2)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.tiles.length === 0
                        text: qsTr("no geometry recorded")
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.caption
                        color: Colours.outline
                    }
                }
            }

            // ---- name and contents -----------------------------------------
            ColumnLayout {
                spacing: Appearance.overlays.sessions.metaGap

                Layout.fillWidth: true

                RowLayout {
                    spacing: Appearance.space.sm

                    Layout.fillWidth: true

                    Text {
                        visible: !root.editing
                        text: root.session?.name ?? ""
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.overlays.sessions.nameSize
                        color: Colours.on.surface
                        elide: Text.ElideRight

                        Layout.fillWidth: !root.active
                    }

                    TextInput {
                        id: nameField

                        visible: root.editing
                        text: root.session?.name ?? ""
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.overlays.sessions.nameSize
                        color: Colours.on.surface
                        selectionColor: Colours.primaryContainer
                        selectedTextColor: Colours.on.primaryContainer
                        selectByMouse: true

                        Layout.fillWidth: true

                        onAccepted: {
                            root.renamed(nameField.text);
                            root.editing = false;
                        }

                        onVisibleChanged: {
                            if (!nameField.visible)
                                return;
                            nameField.text = root.session?.name ?? "";
                            nameField.forceActiveFocus();
                            nameField.selectAll();
                        }

                        Keys.onEscapePressed: root.editing = false
                    }

                    Rectangle {
                        visible: root.active && !root.editing
                        implicitWidth: Appearance.overlays.sessions.dot
                        implicitHeight: Appearance.overlays.sessions.dot
                        radius: width / 2
                        color: Colours.primary

                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        visible: root.active && !root.editing
                        text: qsTr("active")
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.caption
                        color: Colours.primary

                        Layout.fillWidth: true
                    }
                }

                Text {
                    text: root.meta
                    font.family: Appearance.font.ui
                    font.pixelSize: Appearance.size.caption
                    color: Colours.outline
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }
            }

            // ---- the verb ---------------------------------------------------
            //
            // The two rows share one place and cross-fade in it, rather than
            // one vanishing as the other appears.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.overlays.sessions.actionHeight

                RowLayout {
                    anchors.fill: parent
                    opacity: root.menuOpen ? 0 : 1
                    visible: opacity > 0
                    enabled: !root.menuOpen
                    spacing: Appearance.overlays.sessions.actionGap

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    // The active layout is the one you can write to; every other one
                    // is one you can go back to. Only the second carries colour, and
                    // only when it can actually do something.
                    Pill {
                        text: root.restoring ? qsTr("Restoring…") : root.active ? qsTr("Update") : qsTr("Restore")
                        tone: root.active ? "subtle" : "accent"
                        enabled: !root.restoring && (root.active || root.canRestore)
                        pillHeight: Appearance.overlays.sessions.actionHeight
                        radius: Appearance.overlays.sessions.actionRadius
                        fontSize: Appearance.size.label

                        Layout.fillWidth: true

                        onClicked: root.active ? root.updateRequested() : root.restoreRequested()
                    }

                    Pill {
                        icon: "more_horiz"
                        pillHeight: Appearance.overlays.sessions.actionHeight
                        radius: Appearance.overlays.sessions.actionRadius
                        iconSize: Appearance.size.iconLabel

                        Layout.preferredWidth: Appearance.overlays.sessions.actionMore

                        onClicked: root.menuOpen = true
                    }
                }

                // "More" opens in place rather than in a popup: one card's worth of
                // choices does not need a second surface, and a menu floating over
                // a panel would be the shell's only one.
                RowLayout {
                    anchors.fill: parent
                    opacity: root.menuOpen ? 1 : 0
                    visible: opacity > 0
                    enabled: root.menuOpen
                    spacing: Appearance.overlays.sessions.actionGap

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    Pill {
                        text: qsTr("Rename")
                        pillHeight: Appearance.overlays.sessions.actionHeight
                        radius: Appearance.overlays.sessions.actionRadius
                        fontSize: Appearance.size.label

                        Layout.fillWidth: true

                        onClicked: {
                            root.menuOpen = false;
                            root.editing = true;
                        }
                    }

                    Pill {
                        text: qsTr("Forget")
                        tone: "danger"
                        pillHeight: Appearance.overlays.sessions.actionHeight
                        radius: Appearance.overlays.sessions.actionRadius
                        fontSize: Appearance.size.label

                        Layout.fillWidth: true

                        onClicked: {
                            root.menuOpen = false;
                            root.forgotten();
                        }
                    }

                    Pill {
                        icon: "close"
                        pillHeight: Appearance.overlays.sessions.actionHeight
                        radius: Appearance.overlays.sessions.actionRadius
                        iconSize: Appearance.size.iconLabel

                        Layout.preferredWidth: Appearance.overlays.sessions.actionMore

                        onClicked: root.menuOpen = false
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.active
        radius: Appearance.radius.cardXl
        color: "transparent"
        border.width: Appearance.overlays.selectedBorder
        border.color: Colours.primary
    }
}
