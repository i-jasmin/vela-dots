pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config
import qs.services
import qs.tokens
import qs.components

// A surface hanging off the bar. The dashboard's drawer, taken out of the
// dashboard so the popouts, the launcher and the power menu hang the same way:
// flush against the bar's inner face, joined to it by two concave fillets, in
// the same opaque `surfaceBarAttached` the bar switches to while anything is
// attached, so the two read as one shape.
//
//     AttachedDrawer {
//         anchors.fill: parent          // the monitor's shell window
//         key: "launcher"
//         screenName: root.screenName
//         open: root.shown
//         contentWidth: 598
//         contentHeight: column.implicitHeight + 16
//
//         ColumnLayout {
//             id: column
//             anchors.fill: parent
//             ...
//         }
//     }
//
// ONE DRAWER, EVERY EDGE. Which way it grows, which corners round and where the
// fillets sit all follow `Config.bar.position`, live. "Length" is the drawer's
// size away from the bar, "breadth" its size along it.
//
// MOTION. Opening grows the length from nothing on `Morph`; a change of
// content size morphs length and breadth; a change of `along` slides the
// drawer along the bar -- a popout moving to another bar item. Opening while
// another drawer is out on the same bar starts from that drawer's outline
// instead (see `takeOver`), so the dashboard over a popout, or a popout over
// the power menu, is one drawer changing shape rather than one going back
// into the bar and another coming out. Breadth and
// place only animate once the drawer has finished opening: one that opens
// somewhere new starts there rather than sliding over from where it last
// closed, and nothing that settles while it opens -- the window's own size
// arriving a frame late, the content loading -- is drawn as a slide. The
// content is laid out at its full size from the start and uncovered from the
// bar outward, clipped to the drawer's rounded outline while it moves, and
// fades with the drawer over `attached.fade`.
//
// PLACE. `along` is where on the bar the drawer goes, in window coordinates
// along the bar's axis: its middle (`align: "centre"`) or its top or left edge
// (`align: "start"`, which grows away from that edge and keeps content there
// still while the drawer changes size). -1 centres it on the screen. It is
// kept off the bar's rounded ends, fillet included, so the join always lands
// on the flat of the bar.
//
// ONE WINDOW WITH THE BAR. Every drawer is drawn in its monitor's shell window
// (modules/shell/Shell.qml), above the bar, so the two are one picture painted
// in one frame. The window owns everything a window does -- layer, keyboard,
// input region -- and so does click-away: a click beside the drawer lands on
// the window's own dismissal area, underneath the bar, so the bar's buttons
// are still in front of it. Everything else here is the drawer's.
Item {
    id: root

    // ---- set by the surface --------------------------------------------------

    // Names this drawer to ShellState, which tells the bar on `screenName` to
    // go solid and stay out while the drawer has any extent there. Every
    // monitor has its own of each drawer, so they are told apart by screen
    // too: one retracting on one monitor while its twin opens on the other
    // must not clear the other's claim.
    required property string key
    property string screenName: ""
    readonly property string slot: `${root.key}@${root.screenName}`
    // The BarState of the bar this hangs from, for its colour.
    property var bar: null

    property bool open: false
    // The content's full size, in screen axes, padding included.
    property real contentWidth: 0
    property real contentHeight: 0

    property real along: -1
    property string align: "centre"

    // The two far corners, and the fillets where the drawer meets the bar.
    property int radius: Appearance.radius.drawer
    property int fillet: root.radius

    default property alias content: page.data

    // ---- read by the surface -------------------------------------------------

    readonly property string edge: Config.bar.position
    readonly property bool side: Config.bar.vertical
    // Screen distance from the edge the bar is on to its inner face.
    readonly property int inset: Config.bar.footprint
    readonly property bool out: root.length > 0.5
    // From the moment the drawer is asked for until it has fully gone: what
    // the surface is visible for, what it keeps its content loaded for, and
    // what the window takes input across the whole screen for. Set by hand
    // rather than bound to `out`. The surface appearing lays its content
    // out, the content's size is the drawer's length, and a binding from the
    // length back to the surface made a loop -- one that only showed when the
    // morph is instant, under reduceMotion.
    property bool live: false
    // The window's own size along the bar.
    readonly property real extent: root.side ? root.height : root.width

    // ---- geometry ------------------------------------------------------------

    readonly property real barStart: Config.bar.floating ? Config.bar.margin : 0
    readonly property int barRadius: root.side ? Appearance.radius.barV : Appearance.radius.barH

    // The bar's own panel, in window coordinates: what a surface that dims
    // the screen leaves lit.
    readonly property rect barRect: {
        const t = root.inset - root.barStart;
        const along = root.extent - root.barStart * 2;
        if (root.edge === "top")
            return Qt.rect(root.barStart, root.barStart, along, t);
        if (root.edge === "bottom")
            return Qt.rect(root.barStart, root.height - root.inset, along, t);
        if (root.edge === "left")
            return Qt.rect(root.barStart, root.barStart, t, along);
        return Qt.rect(root.width - root.inset, root.barStart, t, along);
    }
    readonly property real targetBreadth: root.side ? root.contentHeight : root.contentWidth

    // Where the drawer's near edge along the bar is heading.
    readonly property real targetStart: {
        const lo = root.barStart + root.barRadius + root.fillet;
        const hi = root.extent - root.barStart - root.barRadius - root.fillet - root.targetBreadth;
        const centred = (root.extent - root.targetBreadth) / 2;
        if (root.along < 0 || hi < lo)
            return Math.round(centred);
        const wanted = root.align === "start" ? root.along : root.along - root.targetBreadth / 2;
        return Math.round(Math.max(lo, Math.min(hi, wanted)));
    }

    // A layer surface is shown before the compositor has told it its size,
    // and the window reads 0 by 0 until it has: every place worked out
    // before then is against a screen of nothing -- the far left, or the top
    // -- and the drawer glided in from there to where it belonged. So it
    // waits for a size before it starts to open.
    readonly property bool sized: root.width > 0 && root.height > 0
    readonly property real targetLength: root.side ? root.contentWidth : root.contentHeight

    // Out from the bar, or on the way: asked for, with somewhere to be, and
    // not handed over to another drawer.
    readonly property bool reaching: root.open && root.sized && !root.handedOff

    property real length: root.reaching ? root.targetLength : 0
    property real breadth: root.targetBreadth
    property real start: root.targetStart
    property real filletSize: root.reaching ? root.fillet : 0

    // True from the moment the drawer has finished opening until it is asked
    // to close. Place and breadth animate only then; before, they jump.
    property bool settled: false
    // Growing or shrinking: what the rounded clip below is for.
    readonly property bool moving: Math.abs(root.length - (root.reaching ? root.targetLength : 0)) > 0.5

    onLengthChanged: if (root.reaching && Math.abs(root.length - root.targetLength) < 0.5)
        root.settled = true

    // For one instant, while an outline is adopted or given up: nothing
    // animates, so it is where it is at once.
    property bool jumping: false

    Behavior on length {
        enabled: !root.jumping

        Morph {}
    }

    Behavior on breadth {
        enabled: root.settled && !root.jumping

        Morph {}
    }

    Behavior on start {
        enabled: root.settled && !root.jumping

        Morph {}
    }

    Behavior on filletSize {
        enabled: !root.jumping

        Morph {}
    }

    // ---- taking over -------------------------------------------------------
    //
    // A drawer opening where another is still out -- the dashboard over a
    // popout, a popout over the dashboard or the power menu -- used to wait
    // for that one to fold back into the bar and then grow out of it itself:
    // everything went down and came up again, where moving between popouts,
    // one drawer, slides and reshapes. Now the one opening takes the other's
    // outline as it stands, jumps there, and morphs from there to its own
    // size and place, while the other is gone in that same frame. Both are
    // drawn in one window, so no frame has two drawers or none.
    //
    // Either may be first to hear of it: opening the dashboard opens it
    // before the popout is told to close, and opening a popout closes the
    // dashboard first. So the one given up is marked `handedOff`, which
    // holds it in the bar until it is next asked for, however its own `open`
    // arrives.
    property bool handedOff: false

    function takeOver(from: var): void {
        root.jumping = true;
        root.length = from.length;
        root.breadth = from.breadth;
        root.start = from.start;
        root.filletSize = from.filletSize;
        root.jumping = false;
        // Out already, so place and breadth move rather than jump from here.
        root.settled = true;
        root.length = Qt.binding(() => root.reaching ? root.targetLength : 0);
        root.breadth = Qt.binding(() => root.targetBreadth);
        root.start = Qt.binding(() => root.targetStart);
        root.filletSize = Qt.binding(() => root.reaching ? root.fillet : 0);
        from.vanish();
    }

    // Written, not left to the bindings: a drawer already folding back in
    // has 0 as its target already, so marking it handed off changes nothing
    // and its retraction ran on beside the drawer taking over. A write with
    // the Behaviors off stops that where it is.
    function vanish(): void {
        root.jumping = true;
        root.handedOff = true;
        root.length = 0;
        root.filletSize = 0;
        root.jumping = false;
        root.length = Qt.binding(() => root.reaching ? root.targetLength : 0);
        root.filletSize = Qt.binding(() => root.reaching ? root.fillet : 0);
    }

    Component.onCompleted: ShellState.registerDrawer(root.slot, root)

    readonly property real bodyWidth: root.side ? root.length : root.breadth
    readonly property real bodyHeight: root.side ? root.breadth : root.length
    readonly property real bodyX: root.side ? (root.edge === "left" ? root.inset : root.width - root.inset - root.bodyWidth) : root.start
    readonly property real bodyY: root.side ? root.start : (root.edge === "top" ? root.inset : root.height - root.inset - root.bodyHeight)

    // ---- the bar's side of it ------------------------------------------------

    onOpenChanged: {
        root.live = root.open || root.out;
        if (root.open) {
            root.handedOff = false;
            const from = ShellState.drawerOutOn(root.screenName, root);
            if (from && root.sized)
                root.takeOver(from);
        } else {
            root.settled = false;
        }
    }
    onOutChanged: if (!root.out)
        root.live = root.open

    // From the moment the drawer is asked for, not from its first frame out:
    // the bar has to start going solid in the same instant this one does --
    // see `fill` below.
    readonly property string attachedTo: root.open || root.out ? root.screenName : ""

    // ---- the join --------------------------------------------------------------
    //
    // The bar and the drawer meet along the bar's face, and they have to read
    // as one shape at every frame of the opening, not only once it has
    // settled. Three things kept them apart:
    //
    // - two windows. They used to be, and two windows are two frames that do
    //   not always land together: whichever came first showed the join half
    //   made, as a line, for a frame. Now both are drawn in the same window,
    //   so every frame has both of them in the same state.
    // - colour. The bar is translucent until something hangs off it, and it
    //   eases to solid over `anim.fast`; a drawer that was solid from its first
    //   frame met a bar still on its way there, and the edge between them read
    //   as a line. So the drawer does not keep a colour of its own: it takes
    //   the bar's (`bar.fill`, mixed by `bar.solid`), and the two are the same
    //   colour in every frame, fade included.
    // - the seam. A fractional scale leaves a half-covered pixel row on each
    //   side of the join, and two half-covered rows do not add up to a whole
    //   one. `bridge` paints a sliver of the drawer over the bar's face across
    //   the join, so the bar's edge is underneath.
    readonly property real solid: root.bar?.solid ?? 1
    readonly property color fill: root.bar?.fill ?? Colours.surfaceBarAttached

    onAttachedToChanged: ShellState.setAttached(root.slot, root.attachedTo)
    Component.onDestruction: {
        ShellState.setAttached(root.slot, "");
        ShellState.unregisterDrawer(root.slot, root);
    }

    // ---- drawing -------------------------------------------------------------

    // Cast away from the bar and clipped at the bar's inner face, so it
    // darkens what is under the drawer and never the bar it hangs from.
    Item {
        x: root.edge === "left" ? root.inset : 0
        y: root.edge === "top" ? root.inset : 0
        width: root.side ? root.width - root.inset : root.width
        height: root.side ? root.height : root.height - root.inset
        clip: true
        visible: root.out
        // Arriving with the fill: under a body that is still translucent, a
        // full-strength shadow would read through it.
        opacity: root.solid

        RectangularShadow {
            x: root.bodyX - parent.x
            y: root.bodyY - parent.y
            width: root.bodyWidth
            height: root.bodyHeight
            radius: root.radius
            blur: Appearance.attached.shadowBlur
            spread: Appearance.attached.shadowSpread
            offset: Qt.vector2d(root.edge === "left" ? Appearance.attached.shadowOffset : root.edge === "right" ? -Appearance.attached.shadowOffset : 0, root.edge === "top" ? Appearance.attached.shadowOffset : root.edge === "bottom" ? -Appearance.attached.shadowOffset : 0)
            color: Colours.alpha(Colours.shadow, Appearance.attached.shadowAlpha)
        }
    }

    // Over the bar's face, across the join and both fillets. The drawer is
    // drawn after the bar, so this covers the bar rather than the other way
    // round. Only once both are solid: laid over a bar that is still
    // translucent, a translucent bridge doubles up and is itself the darker
    // line it is there to hide. Before then the bar's border is already gone:
    // it snaps away in the frame the drawer starts in.
    Rectangle {
        readonly property int reach: Appearance.attached.bridge

        visible: root.out && root.solid >= 1
        color: root.fill
        x: root.side ? (root.edge === "left" ? root.inset - reach : root.width - root.inset) : root.bodyX - root.filletSize
        y: root.side ? root.bodyY - root.filletSize : (root.edge === "top" ? root.inset - reach : root.height - root.inset)
        width: root.side ? reach : root.bodyWidth + root.filletSize * 2
        height: root.side ? root.bodyHeight + root.filletSize * 2 : reach
    }

    // Either side of the drawer, where it leaves the bar. Each is centred on
    // the corner away from both the bar and the drawer, so its filled part
    // runs along the bar's face and down the drawer's side.
    Fillet {
        size: root.filletSize
        color: root.fill
        centreX: root.edge === "left" ? 1 : 0
        centreY: root.edge === "top" ? 1 : 0
        x: root.side ? (root.edge === "left" ? root.inset : root.width - root.inset - size) : root.bodyX - size
        y: root.side ? root.bodyY - size : (root.edge === "top" ? root.inset : root.height - root.inset - size)
    }

    Fillet {
        size: root.filletSize
        color: root.fill
        centreX: root.edge === "left" ? 1 : root.edge === "right" ? 0 : 1
        centreY: root.edge === "top" ? 1 : root.edge === "bottom" ? 0 : 1
        x: root.side ? (root.edge === "left" ? root.inset : root.width - root.inset - size) : root.bodyX + root.bodyWidth
        y: root.side ? root.bodyY + root.bodyHeight : (root.edge === "top" ? root.inset : root.height - root.inset - size)
    }

    Rectangle {
        id: body

        x: root.bodyX
        y: root.bodyY
        width: root.bodyWidth
        height: root.bodyHeight
        visible: root.out
        clip: true
        color: root.fill

        // Round the two corners away from the bar; the two against it stay
        // square, because that is where it joins.
        readonly property int r: Math.min(root.radius, width / 2, height / 2)
        topLeftRadius: root.edge === "bottom" || root.edge === "right" ? body.r : 0
        topRightRadius: root.edge === "bottom" || root.edge === "left" ? body.r : 0
        bottomLeftRadius: root.edge === "top" || root.edge === "right" ? body.r : 0
        bottomRightRadius: root.edge === "top" || root.edge === "left" ? body.r : 0

        // `clip` cuts to the bounding box, not to the rounded corners, so
        // while the far edge moves through the content, whatever it crosses
        // near a corner -- a card, a row's fill -- showed there cut square
        // until the drawer stopped. Only while it moves: at rest the content
        // sits inside its padding, clear of the corners, and needs no layer.
        layer.enabled: root.moving
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: outline
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        // Clicks on the drawer are the drawer's, not the window's dismissal
        // area's underneath.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        // Drawn at full size and uncovered as the body grows, from the bar
        // outward. Across the bar it stays centred in the body, so a change
        // of breadth opens from the middle -- or, aligned to its start, stays
        // put while the far edge moves.
        Item {
            id: page

            width: root.contentWidth
            height: root.contentHeight
            x: root.edge === "left" ? 0 : root.edge === "right" ? body.width - width : root.align === "start" ? 0 : (body.width - width) / 2
            y: root.edge === "top" ? 0 : root.edge === "bottom" ? body.height - height : root.align === "start" ? 0 : (body.height - height) / 2

            opacity: root.open ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.attached.fade
                }
            }
        }
    }

    // The body's outline, drawn only as the mask above.
    Item {
        id: outline

        width: body.width
        height: body.height
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            color: "black"
            topLeftRadius: body.topLeftRadius
            topRightRadius: body.topRightRadius
            bottomLeftRadius: body.bottomLeftRadius
            bottomRightRadius: body.bottomRightRadius
        }
    }
}
