pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
// Qualified, every one: `qs.services` has a `Session` and a `Power` of its own,
// which would otherwise stand in for the power menu here and for the battery
// popout in the popouts module.
import qs.modules.bar as B
import qs.modules.dashboard as D
import qs.modules.launcher as L
import qs.modules.popouts as P
import qs.modules.session as S

// The bar and everything that hangs off it, as one window per monitor.
//
// WHY ONE WINDOW. The dashboard, the popouts, the launcher and the power menu
// grow out of the bar's inner face and are meant to read as one shape with it.
// They used to be windows of their own over the bar's, and two windows are two
// frames the compositor puts on screen when each is ready -- not always the
// same one. For a frame or so of every opening the drawer and the bar were in
// different states, and the join between them showed as a line. Drawn in one
// window, every frame has both of them in it, in step.
//
// So each monitor gets:
//
// - this window, covering the whole output: the bar, then the four drawers
//   over it. It draws nothing but the bar while nothing hangs off it, and its
//   input region is only the bar -- a full-screen surface that took every
//   click would take the desktop with it. While a drawer is out it takes the
//   whole screen, so a click beside the drawer can put it away.
// - an empty 1x1 window whose only job is the bar's exclusive zone. A surface
//   anchored to all four edges cannot reserve one edge, and this one has to
//   cover the screen.
//
// ONE OF EACH DRAWER PER MONITOR. Each window holds its own dashboard,
// popout, launcher and power menu; only the one on the monitor it was opened
// for opens (`ShellState.drawerScreen`, `BarPopouts.screenName`), and the one
// it replaces on the other monitor retracts as it does.
//
// LAYER. On `Top`, where the bar has always been: under a fullscreen window,
// over the others. On `Overlay` while a drawer is out, which is where the
// drawers have always been -- a launcher opened over a fullscreen video has
// to show, and now the bar it hangs from shows with it. Never while the
// session is locked: Hyprland draws Overlay surfaces over the lock screen.
//
// KEYBOARD. Exclusive while a drawer is shown, and nothing otherwise, as each
// drawer's own window had it: the launcher is opened from a keybind and the
// first keystroke after it has to land in the field without a click first.
// Which item in the window gets the keys is the drawer's business; each
// takes them as it opens.
Variants {
    model: Quickshell.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        B.BarState {
            id: state

            screen: scope.modelData
        }

        // The space the bar keeps windows out of. A pinned bar reserves its
        // own depth, margin included, so nothing tiles under it. An
        // autohiding one reserves nothing -- that is what makes it worth
        // hiding.
        PanelWindow {
            screen: scope.modelData
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "vela-bar-zone"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Anchored to the one edge, so the zone applies to that edge.
            anchors {
                left: state.position === "left"
                right: state.position === "right"
                top: state.position === "top"
                bottom: state.position === "bottom"
            }

            exclusiveZone: bar.autohides ? 0 : bar.reserve
            implicitWidth: 1
            implicitHeight: 1
            mask: Region {}
        }

        PanelWindow {
            id: win

            // Anything hanging off the bar at all, retracting included: what
            // the window takes the whole screen's input for, and sits on the
            // Overlay layer for.
            readonly property bool live: dashboard.live || popout.live || launcher.live || session.live
            // Asked for and not yet put away: what it takes the keyboard for.
            readonly property bool shown: dashboard.shown || popout.shown || launcher.shown || session.shown

            screen: scope.modelData
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // The whole output, from its origin: a bar item's place in the
            // window is its place on the screen, which is what
            // `BarPopouts.anchor` is.
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: win.live && !ShellState.locked ? WlrLayer.Overlay : WlrLayer.Top
            // The compositor does the backdrop blur; `hl.layer_rule` in the
            // Hyprland config blurs `^(vela-.*)$` and ignores the alpha of the
            // fully transparent rest of the window.
            WlrLayershell.namespace: "vela-shell"
            WlrLayershell.keyboardFocus: win.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // The whole screen only while a drawer is out. While one is
            // retracting nothing on it answers a click, and a region that
            // still covered the screen swallowed every click for the half
            // second it took.
            mask: Region {
                item: win.shown ? away : bar.hitbox
            }

            // Click-away, for every drawer. It is underneath the bar, so a
            // click on a bar item still reaches the item -- the clock toggles
            // the dashboard shut, another item swaps one popout for another
            // -- and underneath the drawers, whose own bodies keep their
            // clicks. Anywhere else puts away whatever is out here.
            MouseArea {
                id: away

                anchors.fill: parent
                enabled: win.shown
                onClicked: {
                    if (popout.shown)
                        B.BarPopouts.close();
                    if (dashboard.shown || launcher.shown || session.shown)
                        ShellState.closeAttached();
                }
            }

            B.Bar {
                id: bar

                anchors.fill: parent
                bar: state
            }

            // After the bar, so each is drawn over it: the drawer's join
            // covers the bar's face rather than the other way round.
            D.Dashboard {
                id: dashboard

                anchors.fill: parent
                screenName: state.screenName
                bar: state
            }

            P.Popout {
                id: popout

                anchors.fill: parent
                host: state.screenName
                bar: state
            }

            L.Launcher {
                id: launcher

                anchors.fill: parent
                screenName: state.screenName
                bar: state
            }

            S.Session {
                id: session

                anchors.fill: parent
                screenName: state.screenName
                bar: state
            }
        }
    }
}
