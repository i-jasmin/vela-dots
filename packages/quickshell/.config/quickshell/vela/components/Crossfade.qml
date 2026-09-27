import QtQuick
import qs.tokens

// Swaps one piece of content for another without a cut: what was there leaves
// quickly while its replacement arrives. The dashboard's tabs, settings panes,
// Home's months.
//
//     Crossfade {
//         anchors.fill: parent
//         component: pane === "look" ? lookPane : otherPane
//         direction: forward ? 1 : -1
//     }
//
// Each change of `component` is one swap. The outgoing item keeps the size it
// had, so it does not reflow on its way out, stops taking input, and fades
// over `anim.depart` while travelling away; the incoming one waits
// `anim.handover` so the two never overlap much, then fades up over
// `anim.arrive` and settles over `anim.travel`. The old item is destroyed
// once it has gone, so a page holding a process (the media tab's audio tap)
// lets go of it.
//
// `direction` says which way the change runs: 1 brings the new content in from
// below (or from the right when `vertical` is off) and sends the old out the
// other way; -1 reverses both; 0 has neither move, only fade. Under
// reduceMotion `distance` is zero, so a swap is a short crossfade.
//
// A swap from nothing, the first page included, just loads: there is nothing to
// cross from, and the surface opening has its own entrance. `enter()` plays
// the arrival alone on what is showing, from `direction` -- for a surface
// that wants its content to arrive as it opens.
Item {
    id: root

    property Component component
    property int direction: 1
    property bool vertical: true
    // Where a leaving page sits once it has frozen at its old size, if the
    // box has since changed size: its top-left by default. A surface whose
    // content is centred on something -- a popout on its bar item -- keeps
    // the old page centred on the same thing while it goes.
    property int alignment: Qt.AlignLeft | Qt.AlignTop
    property real distance: root.vertical ? Appearance.anim.riseBy : Appearance.anim.shiftBy

    // The page on show, once it has loaded.
    readonly property Item item: root.current?.item ?? null

    property Loader current: first

    implicitWidth: root.item?.implicitWidth ?? 0
    implicitHeight: root.item?.implicitHeight ?? 0

    // A change of `key` is a swap too, to a fresh instance of the same
    // component: Home's next month is the same grid showing
    // something else. The page should take what it shows once, when it is
    // made, or the one leaving would change with it.
    property var key

    onComponentChanged: root.swap(false)
    onKeyChanged: root.swap(true)
    Component.onCompleted: root.swap(false)

    function swap(force: bool): void {
        if (!force && root.current.sourceComponent === root.component)
            return;
        if (!root.current.sourceComponent) {
            root.current.sourceComponent = root.component;
            return;
        }

        const outgoing = root.current;
        const incoming = outgoing === first ? second : first;

        // A swap before the last one finished: whatever was still leaving is
        // simply dropped.
        leaving.stop();
        arriving.stop();
        incoming.sourceComponent = null;

        // Freeze the leaving page where it is.
        outgoing.width = outgoing.width;
        outgoing.height = outgoing.height;
        outgoing.enabled = false;
        outgoing.z = 0;
        outgoing.vertical = root.vertical;
        leaving.target = outgoing;
        leaving.toOffset = -root.direction * root.distance;

        incoming.width = Qt.binding(() => root.width);
        incoming.height = Qt.binding(() => root.height);
        incoming.enabled = true;
        incoming.z = 1;
        incoming.sourceComponent = root.component;
        root.current = incoming;

        leaving.start();
        root.arrive(root.direction, Appearance.anim.handover);
    }

    function enter(): void {
        root.arrive(root.direction, 0);
    }

    function arrive(from: int, wait: int): void {
        arriving.stop();
        const page = root.current;
        page.opacity = 0;
        page.offset = from * root.distance;
        page.vertical = root.vertical;
        arriving.target = page;
        arriving.wait = wait;
        arriving.start();
    }

    component Page: Loader {
        id: page

        property real offset: 0
        // Taken from `vertical` when the page starts to arrive or leave, so a
        // surface can change axis between one move and the next -- a popout
        // rises as it opens and crosses along the bar after -- without
        // turning a move already under way.
        property bool vertical: root.vertical

        width: root.width
        height: root.height
        x: root.alignment & Qt.AlignHCenter ? (root.width - page.width) / 2 : root.alignment & Qt.AlignRight ? root.width - page.width : 0
        y: root.alignment & Qt.AlignVCenter ? (root.height - page.height) / 2 : root.alignment & Qt.AlignBottom ? root.height - page.height : 0
        transform: Translate {
            x: page.vertical ? 0 : page.offset
            y: page.vertical ? page.offset : 0
        }
    }

    Page {
        id: first
    }

    Page {
        id: second
    }

    ParallelAnimation {
        id: arriving

        property Loader target
        // After a swap the page stays clear until what it replaces is mostly
        // gone, so two pages of text never sit on top of each other. It is
        // already moving, and still settling once it shows.
        property int wait: 0

        SequentialAnimation {
            PauseAnimation {
                duration: arriving.wait
            }

            NumberAnimation {
                target: arriving.target
                property: "opacity"
                to: 1
                duration: Appearance.anim.arrive
            }
        }

        NumberAnimation {
            target: arriving.target
            property: "offset"
            to: 0
            duration: Appearance.anim.travel
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.rise
        }
    }

    ParallelAnimation {
        id: leaving

        property Loader target
        property real toOffset: 0

        onFinished: {
            leaving.target.sourceComponent = null;
            leaving.target.opacity = 1;
            leaving.target.offset = 0;
        }

        // Fades from the start, where the movement below only gathers pace
        // as the page disappears.
        NumberAnimation {
            target: leaving.target
            property: "opacity"
            to: 0
            duration: Appearance.anim.depart
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: leaving.target
            property: "offset"
            to: leaving.toOffset
            duration: Appearance.anim.depart
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.leave
        }
    }
}
