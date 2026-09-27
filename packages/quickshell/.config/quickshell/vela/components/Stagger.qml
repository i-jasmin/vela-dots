import QtQuick
import qs.tokens

// One list item's share of a staggered entrance: it waits its turn, then fades
// up and rises into place.
//
//     RowLayout {
//         id: row
//
//         required property int index
//
//         opacity: arrival.opacity
//         transform: Translate {
//             y: arrival.offset
//         }
//
//         Stagger {
//             id: arrival
//
//             index: row.index
//             active: panel.shown
//         }
//     }
//
// Not a visual item, so it goes inside any delegate -- a Layout's child
// included -- without taking a place in the layout; the delegate binds its
// `opacity` and `offset`. It plays when it is created with `active` already
// true, and again every time `active` turns true, so a panel that is shown,
// hidden and shown again arrives each time.
//
// Item n waits n * `anim.stagger`, up to `anim.staggerMax` items; the rest
// arrive with the last. A view that creates delegates as it scrolls should
// pass an `active` that is true only for the moment after it opens, or rows
// scrolled into view will arrive as well.
QtObject {
    id: root

    property int index: 0
    property bool active: true
    // Where the item starts, along whichever axis the delegate applies it to.
    // Positive is below (or after), so the default rises.
    property real distance: Appearance.anim.riseBy

    // Bind these on the delegate.
    property real opacity: 1
    property real offset: 0

    readonly property int delay: Math.max(0, Math.min(root.index, Appearance.anim.staggerMax)) * Appearance.anim.stagger

    function play(): void {
        root.sequence.stop();
        root.opacity = 0;
        root.offset = root.distance;
        root.sequence.start();
    }

    onActiveChanged: if (root.active)
        root.play()
    Component.onCompleted: if (root.active)
        root.play()

    readonly property Animation sequence: SequentialAnimation {
        PauseAnimation {
            duration: root.delay
        }

        ParallelAnimation {
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
        }
    }
}
