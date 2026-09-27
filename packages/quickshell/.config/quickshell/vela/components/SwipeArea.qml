import QtQuick
import qs.tokens

// Swipe it away, the way a phone's notifications go: pulled sideways with the
// pointer (press and drag, or a finger on a touch screen), or swept with two
// fingers on a touchpad. Let go past `threshold`, or flick it, and it flies
// out that way; short of that it springs back.
//
//     Item {
//         id: row
//
//         SwipeArea {
//             id: swipe
//
//             anchors.fill: parent
//             threshold: width * Notifs.swipeThreshold
//             onTapped: mouse => ...
//             onThrown: direction => Notifs.dismiss(row.entry)
//         }
//
//         Rectangle {
//             x: swipe.offset
//             opacity: swipe.fade
//             ...
//         }
//     }
//
// Declared before what it moves, so the buttons on the card get a click
// first, and anchored to the thing that stays put rather than to the card:
// a gesture whose frame slides with the finger cannot measure itself.
//
// Up and down is left alone -- a pull or a sweep that starts more vertical
// than sideways is the list's to scroll, which is what makes this safe inside
// a Flickable. A mouse wheel, tilted or not, never swipes.
//
// A swipe is direct manipulation, so the card follows the finger even under
// reduced motion; only the flight out after letting go is dropped there, and
// the card is put away where it stands (the fade is left to its owner).
MouseArea {
    id: root

    // How far it has been moved, for the card to draw itself at.
    property real offset: 0
    // Dims with the distance, for the card's opacity.
    readonly property real fade: Math.max(0, 1 - Math.abs(root.offset) / (root.width * 0.8))
    // Letting go past this throws it. The notifications pass their
    // `notifications.swipeThreshold` share of the width.
    property real threshold: root.width * 0.3
    property bool swipeEnabled: true

    // Held, or being swept: what a countdown freezes on.
    readonly property bool swiping: root.pulling || root.sweeping
    property bool pulling: false
    property bool sweeping: false

    // Thrown out, and to be put away now: -1 left, 1 right.
    signal thrown(int direction)
    // A press and release that never became a swipe, with its button.
    signal tapped(var mouse)

    function throwAway(direction: int): void {
        settle.stop();
        if (Appearance.reduceMotion) {
            root.offset = 0;
            root.thrown(direction);
            return;
        }
        flyOut.direction = direction;
        flyOut.to = direction * (root.width + Appearance.space.overlayMargin);
        flyOut.restart();
    }

    // ---- how fast it was going ---------------------------------------------
    //
    // The last tenth of a second of movement, so a short quick flick throws
    // it as surely as a long slow pull. Where it started counts as the first
    // of them: a flick can be over in a single movement.
    property var samples: []

    function track(): void {
        const now = Date.now();
        root.samples = root.samples.filter(s => now - s.t < Appearance.notifications.flingWindow).concat([
            {
                t: now,
                x: root.offset
            }
        ]);
    }

    // Measured up to the moment it is let go: a pull that stopped before the
    // release was not a flick.
    function speed(): real {
        const now = Date.now();
        const s = root.samples.filter(p => now - p.t < Appearance.notifications.flingWindow);
        if (s.length < 2)
            return 0;
        const dt = Math.max(1, now - s[0].t);
        return (s[s.length - 1].x - s[0].x) / dt;
    }

    function letGo(): void {
        const v = root.speed();
        root.samples = [];
        const flung = Math.abs(v) > Appearance.notifications.flingSpeed && Math.sign(v) === Math.sign(root.offset);
        if (root.offset !== 0 && (Math.abs(root.offset) > root.threshold || flung))
            root.throwAway(root.offset > 0 ? 1 : -1);
        else
            settle.restart();
    }

    NumberAnimation {
        id: settle

        target: root
        property: "offset"
        to: 0
        duration: Appearance.anim.fast
        easing.type: Appearance.anim.enterEasing
    }

    NumberAnimation {
        id: flyOut

        property int direction: 1

        target: root
        property: "offset"
        duration: Appearance.anim.normal
        easing.type: Appearance.anim.exitEasing
        onFinished: root.thrown(flyOut.direction)
    }

    // ---- pulled with the pointer ---------------------------------------------
    property real pressX: 0
    property real pressY: 0
    // Decided once it moves past the slop: 1 sideways (a swipe), 2 up or
    // down (the list's), 0 not yet.
    property int pullAxis: 0

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    // Kept from the moment it is a sideways pull, so a list it sits in does
    // not take the gesture over halfway.
    preventStealing: root.pulling

    onPressed: mouse => {
        root.pressX = mouse.x;
        root.pressY = mouse.y;
        root.pullAxis = 0;
        root.pulling = false;
        root.samples = [
            {
                t: Date.now(),
                x: root.offset
            }
        ];
    }

    onPositionChanged: mouse => {
        if (!(mouse.buttons & Qt.LeftButton) || !root.swipeEnabled)
            return;
        const dx = mouse.x - root.pressX, dy = mouse.y - root.pressY;
        // A few pixels of slop, so a click with an unsteady hand is still
        // a click.
        if (root.pullAxis === 0) {
            if (Math.abs(dx) < Appearance.notifications.swipeSlop && Math.abs(dy) < Appearance.notifications.swipeSlop)
                return;
            root.pullAxis = Math.abs(dx) > Math.abs(dy) ? 1 : 2;
            if (root.pullAxis === 1) {
                settle.stop();
                flyOut.stop();
                root.pulling = true;
            }
        }
        if (root.pullAxis !== 1)
            return;
        root.offset = dx;
        root.track();
    }

    onReleased: mouse => {
        if (root.pulling) {
            root.pulling = false;
            root.letGo();
        } else if (root.pullAxis === 0)
            root.tapped(mouse);
        root.pullAxis = 0;
    }

    onCanceled: {
        if (root.pulling) {
            root.pulling = false;
            root.letGo();
        }
        root.pullAxis = 0;
    }

    // ---- swept on a touchpad -------------------------------------------------
    //
    // Two fingers sideways arrive as a horizontal scroll, in pixels. Which way
    // the fingers went depends on natural scrolling, which the event reports
    // as `inverted`; the card goes the way the fingers did either way.
    property int sweepAxis: 0
    property real sweptX: 0
    property real sweptY: 0

    function endSweep(): void {
        sweepEnd.stop();
        const mine = root.sweepAxis === 1;
        root.sweepAxis = 0;
        root.sweptX = 0;
        root.sweptY = 0;
        if (mine) {
            root.sweeping = false;
            root.letGo();
        }
    }

    // The fingers lifting is reported (`ScrollEnd`); this is for when it is
    // not.
    Timer {
        id: sweepEnd

        interval: Appearance.notifications.sweepIdle
        onTriggered: root.endSweep()
    }

    onWheel: wheel => {
        if (wheel.phase === Qt.ScrollEnd) {
            wheel.accepted = root.sweepAxis === 1;
            root.endSweep();
            return;
        }
        // A mouse wheel reports steps, not pixels.
        if (!root.swipeEnabled || root.pulling || (wheel.pixelDelta.x === 0 && wheel.pixelDelta.y === 0)) {
            wheel.accepted = false;
            return;
        }
        if (wheel.phase === Qt.ScrollBegin && root.sweepAxis !== 0)
            root.endSweep();
        const dx = wheel.inverted ? wheel.pixelDelta.x : -wheel.pixelDelta.x;
        sweepEnd.restart();
        if (root.sweepAxis === 0) {
            root.sweptX += dx;
            root.sweptY += wheel.pixelDelta.y;
            if (Math.abs(root.sweptX) < Appearance.notifications.swipeSlop && Math.abs(root.sweptY) < Appearance.notifications.swipeSlop) {
                wheel.accepted = false;
                return;
            }
            root.sweepAxis = Math.abs(root.sweptX) > Math.abs(root.sweptY) ? 1 : 2;
            if (root.sweepAxis === 1) {
                settle.stop();
                flyOut.stop();
                root.sweeping = true;
                root.samples = [
                    {
                        t: Date.now(),
                        x: root.offset
                    }
                ];
                root.offset = root.sweptX;
                root.track();
                wheel.accepted = true;
                return;
            }
        }
        if (root.sweepAxis !== 1) {
            wheel.accepted = false;
            return;
        }
        root.offset += dx;
        root.track();
        wheel.accepted = true;
    }
}
