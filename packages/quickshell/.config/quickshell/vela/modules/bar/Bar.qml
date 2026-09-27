pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.tokens

// The bar -- both orientations, one component, rotated by `Config.bar.position`.
//
// There is no BarVertical and no BarHorizontal. `left` and `right` give the
// 58px rail with a 20px radius; `top` and `bottom` give the 40px strip with a
// 16px one. Same parts, same order, same files: the only thing that changes is
// which way `BarFlow` runs and which edge it sits on.
//
// One per monitor, each with its own BarState, so the unfocused monitor can dim
// and a hover on one screen's clock cannot move the other screen's popout.
//
// NOT A WINDOW OF ITS OWN. The bar is drawn in its monitor's shell window
// (modules/shell/Shell.qml), the one the dashboard, the popouts, the launcher
// and the power menu hang from, so a drawer and the bar it grows out of are
// one picture, painted in the same frame. This item covers that window and
// draws only along its edge: the strip of it that is the bar and its 10px
// margin -- 68px wide for a vertical bar -- with the panel inset into it. The
// margin is part of the strip because the panel has to have somewhere to slide
// out to when it autohides, and the strip left behind is where the cursor
// reaches in to bring it back. Nothing is ever drawn in it. (Panel.qml's
// shadow gutter does not apply here: the bar is the one elevation the design
// gives no shadow, because it sits on the wallpaper rather than over another
// surface, so `shadowGutter` is 0.)
//
// The window would eat every click on the screen, so while nothing hangs off
// the bar its input region is `hitbox` -- the panel, or while the bar is
// hidden a two-pixel strip at the very edge -- and the space it reserves is a
// separate, empty window's (`span`, when `autohides` is false).
Item {
    id: root

    required property BarState bar

    readonly property int span: root.bar.margin + root.bar.thickness

    // The live region while nothing hangs off the bar: see `hitbox`.
    readonly property alias hitbox: hitbox

    // --- autohide -------------------------------------------------------------
    //
    // "when-window-overlaps" is answered by asking whether this monitor's
    // active workspace has anything on it, rather than by intersecting
    // rectangles. While the bar is autohiding it reserves no exclusive zone,
    // so windows tile across the whole output and any window on the workspace
    // does reach the bar's edge. The geometry answer would also be a stale
    // one: `lastIpcObject` only refreshes on a full toplevel query, so a window
    // dragged out from under the bar would leave it hidden until something
    // else re-queried.
    readonly property bool occupied: Hypr.countOn(Hypr.activeWorkspaceOn(root.bar.screenName)) > 0
    readonly property string mode: Config.bar.autohide.mode
    readonly property bool pinned: root.mode === "never" || (Config.bar.autohide.keepOnFocusedMonitor && root.bar.focused)
    readonly property bool autohides: !root.pinned && (root.mode === "always" || (root.mode === "when-window-overlaps" && root.occupied))

    property bool revealedByHover: false

    // An open popout holds the bar out, or dismissing it would be a chase
    // across the screen.
    readonly property bool holdingPopout: BarPopouts.current !== "" && BarPopouts.screenName === root.bar.screenName
    readonly property bool shown: !root.autohides || root.revealedByHover || root.holdingPopout || root.bar.attached

    onShownChanged: {
        if (!root.shown && root.holdingPopout)
            BarPopouts.close();
    }

    Timer {
        id: reveal

        interval: Config.bar.autohide.revealDelay
        onTriggered: root.revealedByHover = true
    }

    // Leaving is not taken at its word at once: a pointer that slips off the
    // bar and straight back on, or one that briefly reads as nowhere, does
    // not send it away.
    Timer {
        id: conceal

        interval: Appearance.bar.hideDelay
        onTriggered: root.revealedByHover = false
    }

    // The live region of the window while nothing hangs off the bar: the
    // panel and the margin between it and the screen edge while the bar is
    // out, a two-pixel strip at the edge while it is away. It snaps rather
    // than following the slide, so a cursor left sitting where the bar used
    // to be does not immediately pull it back.
    //
    // The margin has to be in it. A floating bar sits `margin` pixels in from
    // the edge, and a region of just the panel left the pointer that revealed
    // it -- at the edge -- outside: the bar hid, the strip came back under the
    // pointer, and it flickered in and out.
    //
    // A child of this item, which covers the window from its origin, rather
    // than of the strip: the window's input region follows the item's own
    // place, and would not hear the strip move.
    Item {
        id: hitbox

        readonly property int edge: Appearance.bar.revealStrip

        x: strip.x + (root.shown ? (root.bar.vertical ? 0 : panel.restX) : root.bar.position === "right" ? root.span - hitbox.edge : 0)
        y: strip.y + (root.shown ? (root.bar.vertical ? panel.restY : 0) : root.bar.position === "bottom" ? root.span - hitbox.edge : 0)
        width: root.shown ? (root.bar.vertical ? root.span : panel.width) : root.bar.vertical ? hitbox.edge : strip.width
        height: root.shown ? (root.bar.vertical ? panel.height : root.span) : root.bar.vertical ? strip.height : hitbox.edge
    }

    // The bar's strip of the window: `span` deep, along the whole edge.
    Item {
        id: strip

        x: root.bar.position === "right" ? root.width - root.span : 0
        y: root.bar.position === "bottom" ? root.height - root.span : 0
        width: root.bar.vertical ? root.span : root.width
        height: root.bar.vertical ? root.height : root.span

        BarContent {
            id: panel

            bar: root.bar

            readonly property int restX: root.bar.vertical ? (root.bar.position === "left" ? root.bar.margin : 0) : root.bar.margin
            readonly property int restY: root.bar.vertical ? root.bar.margin : (root.bar.position === "top" ? root.bar.margin : 0)

            // Hidden, the panel leaves through the edge it is anchored to --
            // all the way, `span`, which takes it just off the screen. Under
            // reduceMotion it does not travel at all and the fade carries the
            // whole transition.
            readonly property int away: Appearance.reduceMotion ? 0 : root.span

            // Placed in the strip rather than in the window, so the strip
            // taking its place -- the window's size arriving, on the right or
            // the bottom -- moves the bar without the slide below.
            x: panel.restX + (root.shown || !root.bar.vertical ? 0 : root.bar.position === "left" ? -panel.away : panel.away)
            y: panel.restY + (root.shown || root.bar.vertical ? 0 : root.bar.position === "top" ? -panel.away : panel.away)

            width: root.bar.vertical ? root.bar.thickness : strip.width - root.bar.margin * 2
            height: root.bar.vertical ? strip.height - root.bar.margin * 2 : root.bar.thickness

            // The monitor that does not hold focus drops to 62%, and its
            // accents desaturate inside BarState.accent().
            opacity: (root.shown ? 1 : 0) * root.bar.dim
            visible: panel.opacity > 0

            // Each curve is picked from where its value is heading -- back to
            // rest, or away -- which the Behavior knows before it starts.
            // Picked from `shown`, the bar often slid out on the curve for
            // coming back: these bindings and the ones they animate all
            // follow `shown`, in no fixed order.
            Behavior on x {
                id: sliding

                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: sliding.targetValue === panel.restX ? Appearance.anim.enterEasing : Appearance.anim.exitEasing
                }
            }

            Behavior on y {
                id: rising

                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: rising.targetValue === panel.restY ? Appearance.anim.enterEasing : Appearance.anim.exitEasing
                }
            }

            Behavior on opacity {
                id: fading

                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: fading.targetValue > 0 ? Appearance.anim.enterEasing : Appearance.anim.exitEasing
                }
            }
        }
    }

    // Whether the pointer is on the bar: one handler over the whole item --
    // an ancestor of the panel and every button in it, so none of them hides
    // the pointer from it -- asked whether the pointer is inside `hitbox`.
    //
    // It used to be two, one on `hitbox` and one on the panel, in front of
    // it. Hover goes to the item under the pointer and its ancestors, so the
    // pointer passing between them -- or the panel sliding under a pointer
    // that stood still, as it does coming in and going out -- turned one off
    // before the other came on. For that instant the bar was "left", began to
    // hide, slid its clock back under the pointer, and came out again: the
    // bar flickered in and out under a pointer held at the edge.
    HoverHandler {
        id: pointer
    }

    readonly property bool pointerInside: {
        if (!pointer.hovered)
            return false;
        const p = pointer.point.position;
        return p.x >= hitbox.x && p.x < hitbox.x + hitbox.width && p.y >= hitbox.y && p.y < hitbox.y + hitbox.height;
    }

    onPointerInsideChanged: {
        if (root.pointerInside) {
            conceal.stop();
            if (!root.revealedByHover)
                reveal.restart();
        } else {
            reveal.stop();
            conceal.restart();
        }
    }
}
