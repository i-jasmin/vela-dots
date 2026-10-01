import QtQuick
import qs.tokens

// A value between 0 and 1: master volume and the per-app streams in the Output
// popout, corner radius and panel opacity on the Appearance page, the
// brightness OSD.
//
// `value` is normalised, always. A slider that knew about decibels or pixels
// would need a different one per unit; the call site does that mapping and
// keeps the widget one file.
//
//     Slider {
//         value: Audio.volume
//         onMoved: v => Audio.setVolume(v)
//     }
//
// The handle is the only thing that varies: 4x14 beside the master volume,
// 16x16 round in settings, and absent on a per-app or OSD slider, where the
// fill alone carries the value and drops to `secondary` -- the design reserves
// `primary` for the control the user is actually holding.
//
// DISABLED, IT IS ONE PICTURE. A row that cannot be used is dimmed with
// opacity, and Qt fades each item on its own: the fill and the track under
// the handle showed through it, a circle half green and half grey. So while
// the slider is disabled it is drawn into a layer first and the layer is
// faded, as one thing. Only then -- enabled, it draws as it always has, the
// fill running into the handle.
Item {
    id: root

    property real value: 0
    property bool interactive: true
    property real stepSize: 0.05
    // The wheel moves it only once it has focus, and until then goes past it
    // to what it sits in: for a slider on a page that scrolls.
    property bool wheelNeedsFocus: false

    // The wheel's turn towards the next step. A mouse wheel's notch is 120; a
    // touchpad sends a swipe as many small turns, and a high-resolution wheel
    // a notch as several. Stepping on every one of them took a light swipe
    // from one end to the other.
    property real wheelTurn: 0

    property real trackHeight: Appearance.widget.sliderTrack
    // 0 draws no handle.
    property real handleWidth: Appearance.widget.sliderHandleWidth
    property real handleHeight: Appearance.widget.sliderHandleHeight

    property color fill: Colours.primary
    property color trackColour: Colours.track

    // Emitted only for a change the user made, so a binding to a service
    // cannot feed itself.
    signal moved(real value)

    implicitWidth: Appearance.widget.sliderWidth
    implicitHeight: Math.max(root.trackHeight, root.handleHeight)

    layer.enabled: !root.enabled || !root.interactive

    activeFocusOnTab: root.interactive

    Keys.onLeftPressed: root.nudge(-root.stepSize)
    Keys.onRightPressed: root.nudge(root.stepSize)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            root.commit(0);
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.commit(1);
            event.accepted = true;
        }
    }

    function nudge(by: real): void {
        root.commit(root.value + by);
    }

    function commit(v: real): void {
        const next = Math.max(0, Math.min(1, v));
        if (next !== root.value) {
            root.value = next;
            root.moved(next);
        }
    }

    Rectangle {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: root.trackHeight
        radius: height / 2
        color: root.trackColour

        Rectangle {
            width: root.value <= 0 ? 0 : Math.max(parent.radius * 2, Math.min(1, root.value) * parent.width)
            height: parent.height
            radius: parent.radius
            color: root.fill
        }
    }

    Rectangle {
        id: handle

        visible: root.handleWidth > 0
        width: root.handleWidth
        height: root.handleHeight
        radius: width / 2
        color: root.fill
        anchors.verticalCenter: parent.verticalCenter
        x: Math.min(1, Math.max(0, root.value)) * root.width - width / 2

        // The focused control may carry colour; a ring rather than a fill, so
        // the handle does not change size under the cursor.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + Appearance.space.sm
            height: parent.height + Appearance.space.sm
            radius: width / 2
            color: "transparent"
            border.width: Appearance.widget.hairline
            border.color: Colours.primary
            visible: root.activeFocus
        }
    }

    MouseArea {
        anchors.fill: parent
        // A 6px track is a small target; let the whole row take the press.
        anchors.topMargin: -Appearance.space.sm
        anchors.bottomMargin: -Appearance.space.sm
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        onPressed: event => {
            root.forceActiveFocus();
            root.commit(event.x / root.width);
        }
        onPositionChanged: event => {
            if (pressed)
                root.commit(event.x / root.width);
        }
    }

    WheelHandler {
        enabled: root.interactive && (!root.wheelNeedsFocus || root.activeFocus)
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const turn = event.angleDelta.y / 120;
            // Turning back starts afresh rather than first undoing the part
            // of a step left over from the other way.
            root.wheelTurn = Math.sign(turn) === Math.sign(root.wheelTurn) ? root.wheelTurn + turn : turn;
            const steps = Math.trunc(root.wheelTurn);
            if (steps !== 0) {
                root.wheelTurn -= steps;
                root.nudge(steps * root.stepSize);
            }
        }
    }
}
