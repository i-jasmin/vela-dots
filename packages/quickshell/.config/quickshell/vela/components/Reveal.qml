import QtQuick
import qs.tokens

// A floating surface's open and close, in the expressive register: it fades up
// over `anim.arrive` while rising into place over `anim.travel`, and on the way
// out fades over `anim.depart` as it sinks back. The clipboard, the
// cheatsheet, the sessions panel, the calendar, settings, the wallpaper
// switcher -- everything that floats rather than hanging off the bar.
//
//     Panel {
//         id: panel
//
//         y: panel.restY + reveal.offset
//         opacity: reveal.opacity
//         scale: reveal.scale
//
//         Reveal {
//             id: reveal
//
//             shown: root.shown
//         }
//     }
//
// Not a visual item: the surface binds what it wants of `opacity`, `offset`
// and `scale`. `scaleFrom` below 1 has it come forward as well as up -- the
// overview and the window picker, which fill more of the screen than they
// rise over.
//
// `entering` is true while the open is under way. A list inside passes it to
// its rows' `Stagger`, so they arrive one after another as the surface opens
// and rows a view creates later, as it scrolls, simply appear.
//
// Under reduceMotion the distance is zero and the scale stays at 1; what is
// left is a short fade each way.
QtObject {
    id: root

    property bool shown: false
    property real distance: Appearance.anim.riseBy
    property real scaleFrom: 1

    // Bind these on the surface. Plain values, not bindings: the animations
    // below own them, and a binding on `shown` would jump them to the end
    // before the open had begun.
    property real opacity: 0
    property real offset: 0
    property real scale: 1

    readonly property bool entering: root.enter.running

    // Created already open: in place, with no entrance to run.
    Component.onCompleted: {
        root.opacity = root.shown ? 1 : 0;
        root.offset = root.shown ? 0 : root.distance;
        root.scale = root.shown || Appearance.reduceMotion ? 1 : root.scaleFrom;
    }

    onShownChanged: {
        root.enter.stop();
        root.exit.stop();
        if (root.shown) {
            // From wherever a close that was still under way left it.
            if (root.opacity === 0) {
                root.offset = root.distance;
                root.scale = Appearance.reduceMotion ? 1 : root.scaleFrom;
            }
            root.enter.start();
        } else {
            root.exit.start();
        }
    }

    readonly property Animation enter: ParallelAnimation {
        NumberAnimation {
            target: root
            property: "opacity"
            to: 1
            duration: Appearance.anim.arrive
        }

        NumberAnimation {
            target: root
            property: "offset"
            to: 0
            duration: Appearance.anim.travel
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.rise
        }

        NumberAnimation {
            target: root
            property: "scale"
            to: 1
            duration: Appearance.anim.travel
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.rise
        }
    }

    readonly property Animation exit: ParallelAnimation {
        NumberAnimation {
            target: root
            property: "opacity"
            to: 0
            duration: Appearance.anim.depart
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "offset"
            to: root.distance
            duration: Appearance.anim.depart
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.leave
        }

        NumberAnimation {
            target: root
            property: "scale"
            to: Appearance.reduceMotion ? 1 : root.scaleFrom
            duration: Appearance.anim.depart
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.leave
        }
    }
}
