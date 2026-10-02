pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.tokens
import qs.components

// One window in the overview: a mirror of the real surface, at the position
// and size it really has, scaled by its workspace card's model of the monitor.
//
// ONE LAYER OVER THE WHOLE GRID, not a child of its card. A window that moves
// to another workspace is then the same item going somewhere else -- it glides
// from where it was dropped to where Hyprland put it -- rather than one card
// destroying it and another building it from nothing. The card is looked up
// by workspace, and only lends its geometry.
//
// WHERE A WINDOW IS comes from `lastIpcObject`, which only a full toplevel
// query refreshes: the overview asks for one after everything it does and on
// every event that moves a window. Before it did, a window dragged alone onto
// an empty workspace stayed drawn at the half of the screen it had come from,
// and the next one dropped there was drawn over it.
//
// ONE FRAME, NOT A LIVE MIRROR. `live: true` keeps a screencopy session running
// per window, and the overview can be showing a dozen of them at once on a
// surface that exists only while a key is held. So a thumbnail runs live only
// until it has a frame, and again for a moment after its window changes size,
// so the picture is not the old shape stretched over the new one.
Item {
    id: root

    // The Overview: cards, drops and dismissal.
    required property var host
    required property var client

    readonly property var geo: root.client?.lastIpcObject ?? null
    readonly property string address: root.client?.address ?? ""
    readonly property int wsId: root.client?.workspace?.id ?? 0
    readonly property bool floating: root.geo?.floating ?? false

    // The card this window's workspace is drawn in, or null when the grid
    // does not show it. `cardCount` is read for its notification: the cards
    // come and go with the overview.
    readonly property var card: {
        root.host.cardCount;
        return root.host.cardFor(root.wsId);
    }

    // Where the window is, in the grid's coordinates.
    readonly property real homeX: root.card ? root.card.x + root.card.originX + ((root.geo?.at?.[0] ?? 0) - root.card.monX) * root.card.fit : 0
    readonly property real homeY: root.card ? root.card.y + root.card.originY + ((root.geo?.at?.[1] ?? 0) - root.card.monY) * root.card.fit : 0
    readonly property real homeWidth: Math.max(1, (root.geo?.size?.[0] ?? 0) * (root.card?.fit ?? 0))
    readonly property real homeHeight: Math.max(1, (root.geo?.size?.[1] ?? 0) * (root.card?.fit ?? 0))

    // In the hand, and after it: a dropped window stays where it was let go
    // until Hyprland has said where it went (`holding`), then moves there.
    // Snapping it back to its old place first, and then on to the new one,
    // was a jump and a second jump.
    property bool dragging: false
    property bool holding: false
    property real heldX: 0
    property real heldY: 0

    // Off until the first frame has been laid out, so a thumbnail does not
    // fly in from the grid's corner when the overview opens.
    property bool placed: false

    x: root.dragging || root.holding ? root.heldX : root.homeX
    y: root.dragging || root.holding ? root.heldY : root.homeY
    width: root.homeWidth
    height: root.homeHeight

    // Off while the button is down, so a window in the hand follows the
    // pointer exactly. Not `dragging`: letting go changes `dragging` and the
    // position it chooses at once, in no fixed order, and when the position
    // went first the window jumped back to where it had been picked up from
    // with nothing animating it -- then flew from there to where it was put.
    // `pressed` has already cleared by the time the release is handled.
    Behavior on x {
        enabled: root.placed && !mouse.pressed

        Morph {}
    }

    Behavior on y {
        enabled: root.placed && !mouse.pressed

        Morph {}
    }

    Behavior on width {
        enabled: root.placed

        Morph {}
    }

    Behavior on height {
        enabled: root.placed

        Morph {}
    }

    Component.onCompleted: Qt.callLater(() => root.placed = true)

    // A new answer from Hyprland: whatever was being held is now known.
    onGeoChanged: {
        root.holding = false;
        const size = `${root.geo?.size?.[0]}x${root.geo?.size?.[1]}`;
        if (size !== root.lastSize) {
            if (root.lastSize !== "")
                recapture.restart();
            root.lastSize = size;
        }
    }

    property string lastSize: ""

    Timer {
        id: recapture

        interval: Appearance.overview.recapture
    }

    Timer {
        id: hold

        interval: Appearance.overview.dropHold
        running: root.holding
        onTriggered: root.holding = false
    }

    // A window Hyprland has not described yet has no geometry to draw at, and
    // a group's hidden tab is not on screen at all.
    visible: root.card !== null && root.geo !== null && !root.geo.hidden && root.card.fit > 0

    // Stacked the way the compositor stacks them: fullscreen over floating
    // over tiled, the most recently focused on top within each, and whatever
    // is in the hand over everything.
    z: (root.dragging || root.holding ? 10 : 0) + (root.geo?.fullscreen ? 2 : root.floating ? 1 : 0) + 1 / (2 + (root.geo?.focusHistoryID ?? 98))

    // With its card as the cards come in, one after another.
    opacity: (root.card?.arrival ?? 1) * (root.dragging ? Appearance.overview.dragOpacity : 1)
    transform: Translate {
        y: root.card?.enterOffset ?? 0
    }

    ClippingRectangle {
        id: frame

        anchors.fill: parent
        radius: Appearance.overview.thumbRadius
        // What shows through until the capture arrives, and behind a window
        // that is itself translucent.
        color: Colours.alpha(Colours.surface, Appearance.overview.thumbAlpha)
        border.width: 1
        border.color: root.dragging ? Colours.primary : Colours.panelBorder

        ScreencopyView {
            id: view

            anchors.fill: parent
            captureSource: root.client?.wayland ?? null
            paintCursor: false

            // Live until the first frame lands, then frozen. `captureFrame()`
            // alone does not work from cold -- measured: the screencopy context
            // is built lazily by the live session, so a capture asked for
            // before one has ever run answers "no recording context is ready"
            // and the thumbnail stays empty. Letting `live` bring the context
            // up and dropping it the moment there is something to show costs
            // one or two frames per window instead of one per window per frame.
            live: !view.hasContent || recapture.running
        }

        // The honest empty state: a window too small to read, or one the
        // compositor would not hand over, is drawn as what it is rather than as
        // an empty box.
        AppIcon {
            anchors.centerIn: parent
            source: AppIcons.forClient(root.client)
            glyph: Hypr.iconOf(root.client)
            size: Appearance.size.iconRow
            imageSize: Appearance.size.iconRow + Appearance.size.appIconGrow
            color: Colours.outline
            visible: !view.hasContent || Math.min(root.width, root.height) < Appearance.overview.thumbMinSide
        }
    }

    // Hovering a window is hovering its workspace: the cards lie underneath
    // this layer and do not see the pointer while it is over a window.
    HoverHandler {
        onHoveredChanged: {
            if (hovered && !root.host.dragging)
                root.host.selected = root.wsId;
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        // Where on the thumbnail it was taken, so it stays under the pointer
        // at the same spot while it travels.
        property real grabX: 0
        property real grabY: 0
        property real pressX: 0
        property real pressY: 0

        function layerPoint(event: var): point {
            return mouse.mapToItem(root.parent, event.x, event.y);
        }

        onPressed: event => {
            const p = mouse.layerPoint(event);
            mouse.pressX = p.x;
            mouse.pressY = p.y;
            mouse.grabX = p.x - root.x;
            mouse.grabY = p.y - root.y;
        }

        onPositionChanged: event => {
            if (!mouse.pressed)
                return;
            const p = mouse.layerPoint(event);
            if (!root.dragging && Math.abs(p.x - mouse.pressX) + Math.abs(p.y - mouse.pressY) < Appearance.overview.dragThreshold)
                return;
            // Placed first, so the moment it is taken it is already where the
            // pointer has it.
            root.heldX = p.x - mouse.grabX;
            root.heldY = p.y - mouse.grabY;
            if (!root.dragging) {
                root.holding = false;
                root.dragging = true;
                root.host.dragging = true;
            }
            const scene = mouse.mapToItem(null, event.x, event.y);
            root.host.dragOver(scene.x, scene.y);
        }

        onReleased: event => {
            if (!root.dragging) {
                Hypr.focusWindow(root.address);
                ShellState.close("overview");
                return;
            }
            const scene = mouse.mapToItem(null, event.x, event.y);
            // Held only if the drop asked Hyprland for something; a drop on
            // nothing goes straight back. Held first, so between the two the
            // window is never anywhere but where it was let go.
            root.holding = root.host.drop(root, scene.x, scene.y);
            root.dragging = false;
        }

        onCanceled: {
            root.dragging = false;
            root.holding = false;
            root.host.drop(null, -1, -1);
        }
    }
}
