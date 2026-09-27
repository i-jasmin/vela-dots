pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services
import qs.tokens
// Qualified: `qs.components` has a `Row` of its own, which would take the
// place of the positioner the legend is laid out in.
import qs.components as C

// The workspace overview, toggled by a tap of super.
//
// A grid of 376x232 cards three across, one per workspace, each showing that
// workspace's windows at the positions and sizes they actually have. The card
// under the cursor -- or under the keyboard selection -- takes a 2px primary
// border and a 6px ring; empty workspaces are dashed outlines with a plus.
//
// THE WORKSPACES ARE THE BAR'S (`Hypr.workspaceIds`), and after them one more
// card, "New workspace": clicking it, or dropping a window on it, makes the
// next one, which the bar then shows too. With the five a fresh session starts
// with, that is the design's 3x2; a sixth workspace starts a third row.
//
// THE CARDS ARE FIXED AND THE SCREEN IS NOT. 3x376 + 2x18 is 1164px of grid, and
// the design's frame is 1360 wide; a 1280 display, or a laptop's panel with a
// bar down one side, has less than that. Rather than reflowing to two columns
// -- which would stop being the design -- the whole block scales to fit. The
// proportions are the design's at every size, and on a display that is at least
// the design's it is drawn at exactly the measured pixel sizes.
//
// WHY THE THUMBNAILS ARE STILL FRAMES. `ScreencopyView` will mirror a live
// window, and six workspaces' worth of them is six to a dozen simultaneous
// captures for a surface that is on screen for as long as a key is held. Each
// is a compositor-side copy per frame, so the cost is real and it lands on the
// one interaction that must not stutter. Every thumbnail here therefore runs
// live only until its first frame arrives and then freezes on it -- which is
// what the user is looking at anyway, since nothing they can see is moving
// while the overview is up. See `WindowThumb` for why one `captureFrame()` on its
// own does not work.
//
// DRAGGING A WINDOW. Onto another card, it moves to that workspace (a
// floating one to the spot it was dropped on). Within its own card, a
// floating window moves to where it was let go, and a tiled one dropped on
// another tiled window trades places with it. Anywhere else it goes back.
// Every drop is followed by a fresh look at where Hyprland put things, and
// the thumbnails move there.
PanelWindow {
    id: root

    readonly property bool shown: ShellState.overview

    // The grid, the legend and the gap between them, at the design's sizes.
    readonly property int rows: Math.max(1, Math.ceil(root.cardIds.length / Appearance.overview.columns))
    readonly property int gridWidth: Appearance.overview.columns * Appearance.overview.cardWidth + (Appearance.overview.columns - 1) * Appearance.overview.gap
    readonly property int gridHeight: root.rows * Appearance.overview.cardHeight + (root.rows - 1) * Appearance.overview.gap

    // The bar's footprint, so the block centres on the space left over rather
    // than on the screen -- the design's `calc(50% + 34px)`, generalised to all
    // four bar positions. Same expression as the launcher's.
    readonly property int insetLeft: Config.bar.position === "left" ? Config.bar.footprint : 0
    readonly property int insetRight: Config.bar.position === "right" ? Config.bar.footprint : 0
    readonly property int insetTop: Config.bar.position === "top" ? Config.bar.footprint : 0
    readonly property int insetBottom: Config.bar.position === "bottom" ? Config.bar.footprint : 0

    // The workspaces, as the bar has them.
    readonly property var ids: Hypr.workspaceIds

    // Every card: the workspaces, then the one that makes the next, while
    // there is a number left for it.
    //
    // Through a string, so the cards are only rebuilt when the list really
    // changes: `workspaceIds` is recomputed on every workspace event, as a
    // new array each time, and a new array is a new model to a Repeater.
    readonly property string cardKey: (Hypr.nextWorkspace > 0 ? [...root.ids, Hypr.nextWorkspace] : root.ids).join(",")
    readonly property var cardIds: root.cardKey ? root.cardKey.split(",").map(Number) : []

    // The last card that has anything on it. Everything past the one after it
    // is a workspace nobody is thinking about, and is drawn as such.
    readonly property int lastUsedIndex: {
        Hypr.windowCounts;
        let last = -1;
        for (let i = 0; i < root.ids.length; i++)
            if (Hypr.countOn(root.ids[i]) > 0)
                last = i;
        return last;
    }

    // What the ring is around. Starts on the focused workspace and follows the
    // arrow keys from there, so the keyboard path is the primary one.
    property int selected: Hypr.focusedWorkspaceId

    function activate(id: int): void {
        ShellState.close("overview");
        Hypr.focusWorkspaceAfterRelease(id);
    }

    function move(dx: int, dy: int): void {
        const at = root.cardIds.indexOf(root.selected);
        if (at < 0)
            return;
        const cols = Appearance.overview.columns;
        let col = at % cols + dx;
        let row = Math.floor(at / cols) + dy;
        col = Math.max(0, Math.min(cols - 1, col));
        row = Math.max(0, Math.min(root.rows - 1, row));
        root.selected = root.cardIds[row * cols + col] ?? root.selected;
    }

    // Where a dragged window was let go. Returns the workspace id under that
    // scene point, or -1 for the gaps between cards.
    function workspaceAt(sceneX: real, sceneY: real): int {
        for (let i = 0; i < cards.count; i++) {
            const card = cards.itemAt(i);
            if (!card)
                continue;
            const p = card.mapFromItem(null, sceneX, sceneY);
            if (p.x >= 0 && p.y >= 0 && p.x < card.width && p.y < card.height)
                return card.wsId;
        }
        return -1;
    }

    // ---- the windows --------------------------------------------------
    //
    // Drawn in one layer over the cards (see `WindowThumb`), which find their
    // card here.
    readonly property int cardCount: cards.count

    function cardFor(id: int): var {
        const at = root.ids.indexOf(id);
        return at >= 0 && at < cards.count ? cards.itemAt(at) : null;
    }

    // A window in the hand, and the card it would land on.
    property bool dragging: false
    property int dropTarget: -1

    function dragOver(sceneX: real, sceneY: real): void {
        root.dropTarget = root.workspaceAt(sceneX, sceneY);
    }

    // The tiled window under a point on workspace `id`, other than `except`.
    function tiledAt(id: int, sceneX: real, sceneY: real, except: var): var {
        for (let i = 0; i < thumbs.count; i++) {
            const t = thumbs.itemAt(i);
            if (!t || t === except || !t.visible || t.wsId !== id || t.floating)
                continue;
            const p = t.mapFromItem(null, sceneX, sceneY);
            if (p.x >= 0 && p.y >= 0 && p.x < t.width && p.y < t.height)
                return t;
        }
        return null;
    }

    // Where a floating window's top left would be on `card`'s monitor if it
    // were where its thumbnail is now, kept on that monitor.
    function placeOn(card: var, thumb: var): point {
        const w = thumb.geo?.size?.[0] ?? 0;
        const h = thumb.geo?.size?.[1] ?? 0;
        const x = card.monX + (thumb.heldX - card.x - card.originX) / card.fit;
        const y = card.monY + (thumb.heldY - card.y - card.originY) / card.fit;
        return Qt.point(Math.max(card.monX, Math.min(card.monX + card.monWidth - w, x)), Math.max(card.monY, Math.min(card.monY + card.monHeight - h, y)));
    }

    // What letting go of a window means. True when Hyprland was asked to do
    // something, so the thumbnail waits for the answer where it was dropped;
    // false sends it straight back.
    function drop(thumb: var, sceneX: real, sceneY: real): bool {
        root.dragging = false;
        root.dropTarget = -1;
        if (!thumb)
            return false;
        const target = root.workspaceAt(sceneX, sceneY);
        if (target <= 0)
            return false;
        // The ring goes where the window went. Hover will not move it there:
        // a drop that makes a workspace rebuilds the cards under a pointer
        // that is not moving, so no card hears it arrive.
        root.selected = target;
        const settled = () => Hypr.refreshWindows();
        if (target !== thumb.wsId) {
            const card = root.cardFor(target);
            if (thumb.floating && card && card.fit > 0) {
                const at = root.placeOn(card, thumb);
                Hypr.moveWindowToWorkspace(thumb.address, target, () => Hypr.moveWindowTo(thumb.address, at.x, at.y, settled));
            } else {
                Hypr.moveWindowToWorkspace(thumb.address, target, settled);
            }
            return true;
        }
        if (thumb.floating) {
            const at = root.placeOn(thumb.card, thumb);
            Hypr.moveWindowTo(thumb.address, at.x, at.y, settled);
            return true;
        }
        const other = root.tiledAt(target, sceneX, sceneY, thumb);
        if (!other)
            return false;
        Hypr.swapWindows(thumb.address, other.address, settled);
        return true;
    }

    // Anything else that moves a window while the overview is up -- one
    // opening or closing, one the layout moved to make room -- is asked about
    // too. Together, since one change is often several events.
    Connections {
        target: Hyprland
        enabled: root.shown

        function onRawEvent(event: HyprlandEvent): void {
            if (["openwindow", "closewindow", "movewindowv2", "changefloatingmode", "fullscreen", "activewindowv2", "moveworkspacev2"].includes(event.name))
                settle.restart();
        }
    }

    Timer {
        id: settle

        interval: Appearance.overview.settle
        onTriggered: Hypr.refreshWindows()
    }

    // Follows the focused monitor, falling through to the first screen while
    // `Hypr` is still empty, as it is for the first moments of a session.
    screen: {
        const screens = Quickshell.screens;
        if (screens.length === 0)
            return null;
        return screens.find(s => s.name === Hypr.focusedMonitorName) ?? screens[0];
    }

    visible: root.shown || block.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vela-overview"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (!root.shown)
            return;
        // Window geometry comes from `lastIpcObject`, which only a full toplevel
        // query fills -- so the positions would be whatever they were when the
        // shell started without this. Safe on open, never at startup, for the
        // reason `Hypr.refresh` documents.
        Hypr.refresh();
        root.selected = Hypr.focusedWorkspaceId;
        keys.forceActiveFocus();
    }

    Rectangle {
        anchors.fill: parent
        color: Colours.alpha(Colours.scrim, Appearance.overview.dim)
        opacity: entrance.opacity
    }

    // The overview comes forward from just under full size rather than
    // rising: it fills the screen, and there is nowhere for it to rise from.
    C.Reveal {
        id: entrance

        shown: root.shown
        distance: 0
        scaleFrom: Appearance.overview.enterScale
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                root.activate(event.key - Qt.Key_0);
                event.accepted = true;
                return;
            }
            switch (event.key) {
            case Qt.Key_Escape:
                ShellState.close("overview");
                break;
            case Qt.Key_Left:
                root.move(-1, 0);
                break;
            case Qt.Key_Right:
                root.move(1, 0);
                break;
            case Qt.Key_Up:
                root.move(0, -1);
                break;
            case Qt.Key_Down:
                root.move(0, 1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                root.activate(root.selected);
                break;
            default:
                return;
            }
            event.accepted = true;
        }

        // Click-away. The window has to cover the screen to dim it, so a click
        // that lands on nothing has to mean something.
        MouseArea {
            anchors.fill: parent
            onClicked: ShellState.close("overview")
        }

        // The free area, once the bar's edge is taken out.
        Item {
            id: field

            x: root.insetLeft
            y: root.insetTop
            width: parent.width - root.insetLeft - root.insetRight
            height: parent.height - root.insetTop - root.insetBottom

            Item {
                id: block

                // The design's own measurements. `scale` below is what makes
                // them fit a screen that is smaller than the design's frame.
                implicitWidth: root.gridWidth
                implicitHeight: root.gridHeight + Appearance.overview.legendGap + legend.implicitHeight
                width: implicitWidth
                height: implicitHeight

                x: Math.round((field.width - width) / 2)
                y: Math.round((field.height - height) / 2)

                // A row coming or going while the overview is up -- a window
                // dropped on New workspace -- slides the grid to its new
                // centre rather than jumping there. Not while it opens: the
                // window only reaches its real size a frame or two after it is
                // shown, and the grid would slide in from the wrong place.
                Behavior on y {
                    enabled: root.shown && !entrance.entering

                    C.Morph {}
                }

                // Never above 1: the grid is drawn at the design's pixel sizes
                // wherever there is room for it, and shrunk in proportion where
                // there is not. `space.overlayMargin` on every side, because
                // nothing in this shell touches an edge.
                readonly property real fit: Math.min(1, (field.width - Appearance.space.overlayMargin * 2) / width, (field.height - Appearance.space.overlayMargin * 2) / height)

                // Eased on its own: the first time the overview opens, the
                // window reaches its real size a frame or two after it is
                // shown, and the grid would jump from a smaller fit to the
                // right one.
                property real easedFit: block.fit

                Behavior on easedFit {
                    C.Morph {}
                }

                transformOrigin: Item.Center
                // 0.96 to 1, the design's own figure for this surface, on the
                // expressive curve (`entrance` above).
                scale: block.easedFit * entrance.scale
                opacity: entrance.opacity

                Grid {
                    id: grid

                    columns: Appearance.overview.columns
                    rows: root.rows
                    spacing: Appearance.overview.gap

                    Repeater {
                        id: cards

                        // The grid is only instantiated while the overview is
                        // up: every thumbnail in it holds a screencopy session,
                        // and six workspaces of those are not worth keeping
                        // alive for a surface measured in held keypresses. Up
                        // includes its fade out, or the cards vanished the
                        // moment it was asked to close.
                        model: root.shown || entrance.opacity > 0 ? root.cardIds : []

                        WorkspaceCard {
                            id: wsCard

                            required property int modelData
                            required property int index

                            arrival: cardEnter.opacity
                            enterOffset: cardEnter.offset

                            // The cards come in one after another, in
                            // reading order, as the overview opens. One made
                            // while it is up -- a new workspace -- simply
                            // appears, and so do the rest when the list
                            // changes under them.
                            C.Stagger {
                                id: cardEnter

                                index: wsCard.index
                                active: entrance.entering
                            }

                            wsId: modelData
                            fresh: index >= root.ids.length
                            // While a window is in the hand, the ring shows
                            // where it would land.
                            ringed: root.dragging ? modelData === root.dropTarget : modelData === root.selected
                            current: modelData === Hypr.focusedWorkspaceId
                            // The design fades the second empty card: the next
                            // workspace is one you might make, the ones past it
                            // are not.
                            distant: !wsCard.fresh && root.ids.indexOf(modelData) > root.lastUsedIndex + 1

                            onActivated: root.activate(modelData)
                            onEntered: root.selected = modelData
                        }
                    }
                }

                // Every window, over the cards. Built with the cards and
                // gone with them, for the screencopy sessions they hold.
                Item {
                    width: root.gridWidth
                    height: root.gridHeight

                    Repeater {
                        id: thumbs

                        model: root.shown || entrance.opacity > 0 ? Hyprland.toplevels : null

                        WindowThumb {
                            required property var modelData

                            host: root
                            client: modelData
                        }
                    }
                }

                // ---- legend --------------------------------------------------
                //
                // Keys and their verbs. Literals, so the whole strip is mono --
                // and plain text rather than `Keycap` chips, because the design
                // draws it the way it draws the launcher's footer: the key a
                // shade brighter than the verb, no chip.
                Row {
                    id: legend

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.gridHeight + Appearance.overview.legendGap
                    spacing: Appearance.overview.legendItemGap

                    Repeater {
                        model: [
                            {
                                key: qsTr("super"),
                                verb: qsTr("tap to toggle")
                            },
                            {
                                key: qsTr("1-9"),
                                verb: qsTr("jump")
                            },
                            {
                                key: qsTr("drag"),
                                verb: qsTr("move or swap windows")
                            }
                        ]

                        Text {
                            required property var modelData

                            textFormat: Text.StyledText
                            text: `<font color="${Colours.on.surfaceVariant}">${modelData.key}</font> ${modelData.verb}`
                            font.family: Appearance.font.mono
                            font.pixelSize: Appearance.overview.legendSize
                            color: Colours.outline
                        }
                    }
                }
            }
        }
    }
}
