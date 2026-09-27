pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.tokens
import qs.config
import qs.services

// Where a notification actually appears.
//
// `services/Notifs.qml` claims `org.freedesktop.Notifications` for the whole
// session, which means that while vela runs, nothing else is listening. Until
// this module existed the server captured every notification and drew none of
// them, while the sending application was told the delivery had succeeded. That
// is what this file is for, and it is why it is one window per monitor and not
// one that follows focus: a notification the user never looked at is the same
// failure in a quieter form.
//
// THE WINDOW IS NOT THE CARD. A layer-shell surface clips at its own edges, so
// the window is grown past the stack on every free side: `overlayMargin` on the
// side that faces the screen edge -- nothing touches an edge -- and a shadow
// gutter plus swipe room on the other, with nothing drawn in either. What that
// costs is input: a transparent window still swallows clicks, so the input mask
// is limited to the stack itself and everything around it falls through to the
// window underneath.
//
// KEYBOARD. A toast that takes the keyboard is a toast that interrupts typing,
// so the window asks for none of it. The one exception is the digest, which is
// a card with buttons rather than a notice: while it is up the window takes
// focus *on demand*, which means when the user clicks it and not before, and
// then esc puts it away.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        // The design's column: 376 wide, 26 from the top and right edges, with
        // 11 between the cards. The gap belongs to the card above it rather
        // than to the layout, so a card that collapses to nothing takes its gap
        // with it -- which is why the stack itself is spaced zero and why the
        // bottom margin below gives that trailing gap back.

        readonly property string position: Config.notifications.position
        readonly property bool atTop: !win.position.startsWith("bottom")
        readonly property bool atLeft: win.position.endsWith("left")
        readonly property bool centred: !win.atLeft && !win.position.endsWith("right")

        // The same expression `Panel.shadowGutter` evaluates for a popout-level
        // panel -- 78px. It cannot be read off a Panel here, because the window
        // has to be sized before there is a card in it to ask.
        readonly property int gutter: Appearance.shadow.gutter
        // Room beside the stack for a card being thrown out of it. A card
        // swiped towards the screen edge is clipped by it, which is how a
        // thrown thing should leave; one swiped inwards needs somewhere to go.
        readonly property int slideRoom: Math.round(Appearance.notifications.width * 0.55)

        // The digest is the only thing here that is a control rather than a
        // notice, and the only thing that should ever hold a key.
        readonly property bool interactive: Notifs.digestDue && Notifs.heldCount > 0

        // What the service says there is to draw. `popupApps` still counts a
        // group that has been retired but not yet released, which is what keeps
        // the window up while a card animates away.
        readonly property bool wanted: Notifs.popupApps.length > 0 || win.interactive

        screen: win.modelData
        // NOT derived from the stack's height, however tempting: a layout's
        // implicit size is computed during polish, and a window that is not
        // visible is never polished -- so `visible: stack.implicitHeight > 0`
        // is a deadlock that renders nothing, silently. Measured.
        // A toast is the one surface here that appears without being asked for,
        // so it cannot rely on ShellState refusing to open -- it gates itself.
        // Overlay surfaces draw *above* a session lock in Hyprland, and a
        // notification body on a locked screen is a small privacy hole.
        visible: (win.wanted || linger.running) && !ShellState.locked
        color: "transparent"

        // The digest's buttons clear its state the instant they are pressed, so
        // something has to hold the surface open long enough for the card to
        // finish leaving.
        onWantedChanged: if (!win.wanted)
            linger.restart()

        // Reserve nothing, but respect what the bar reserved -- which is what
        // keeps a toast beside a pinned bar instead of underneath it.
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0

        // The full height of the screen, whatever the stack holds, and never
        // resized. The window used to be as tall as its cards, and a card's
        // height is animated as it arrives and leaves -- so the window was
        // resized on every frame of every toast, and Hyprland showed some of
        // those frames with the surface half-updated: toasts flickered as they
        // came and went. Only the cards take input (`mask` below); the rest is
        // transparent and falls through.
        anchors {
            top: true
            bottom: true
            left: win.centred || win.atLeft
            right: win.centred || !win.atLeft
        }

        implicitWidth: Appearance.space.overlayMargin + Appearance.notifications.width + win.gutter + win.slideRoom

        WlrLayershell.layer: WlrLayer.Overlay
        // The compositor does the backdrop blur; QML cannot blur what is behind
        // its own window. `layerrule = blur, ^(vela-.*)$` matches on this name.
        WlrLayershell.namespace: "vela-notifications"
        WlrLayershell.keyboardFocus: win.interactive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        // Everything outside the cards falls through. Without this the shadow
        // gutter and the swipe room -- two thirds of the window -- would be an
        // invisible wall over the user's windows.
        mask: Region {
            item: stack
        }

        Timer {
            id: linger

            // One step longer than the cards' own exit, so the surface is never
            // torn out from under an animation that has not finished.
            interval: Appearance.anim.slow
        }

        Item {
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape && win.interactive) {
                    // Put the card away without losing anything: keep holding
                    // if focus is still on, and otherwise retire the batch
                    // from the digest while it stays in the history.
                    if (Notifs.holding)
                        Notifs.stayInFocus();
                    else
                        Notifs.markAllRead();
                    event.accepted = true;
                }
            }

            ColumnLayout {
                id: stack

                // Each card carries its own gap inside its height, so one that
                // collapses to nothing takes its gap with it rather than
                // leaving a hole behind in the stack.
                spacing: 0
                width: Appearance.notifications.width
                height: implicitHeight

                // Placed, not anchored. An anchor whose binding resolves to
                // `undefined` is not reliably cleared once it has been set, and
                // `Config.notifications.position` is "top-right" for the first
                // frames of every session -- so a bottom-left stack came up
                // anchored left AND right and stretched to 607px. Measured.
                //
                // The vertical figure looks asymmetric and is not: the stack's
                // last card carries a trailing gap inside its own height, so a
                // stack growing upwards from the bottom edge sits that much
                // lower for the card itself to be `overlayMargin` off the edge.
                x: win.centred ? Math.round((win.width - Appearance.notifications.width) / 2) : win.atLeft ? Appearance.space.overlayMargin : win.width - Appearance.notifications.width - Appearance.space.overlayMargin
                y: win.atTop ? Appearance.space.overlayMargin : win.height - height - Appearance.space.overlayMargin + Appearance.notifications.cardGap

                Repeater {
                    // Keyed by application name, so a card already on screen
                    // survives the next notification from the same app:
                    // strings compare by value, and ScriptModel only rebuilds
                    // the delegates whose key has gone. Handing it group
                    // objects instead would rebuild every card on every
                    // arrival and restart animations that were mid-flight.
                    //
                    // Newest first at the top of the screen, newest last at the
                    // bottom of it: either way the one that just arrived is the
                    // one nearest the edge the stack grows from.
                    model: ScriptModel {
                        values: win.atTop ? Notifs.popupApps : [...Notifs.popupApps].reverse()
                    }

                    Toast {
                        required property string modelData

                        app: modelData
                        gap: Appearance.notifications.cardGap
                    }
                }

                Digest {
                    gap: Appearance.notifications.cardGap
                }
            }
        }
    }
}
