import QtQuick
import qs.tokens
import qs.components

// One 38px square in the Bar page's pinned-and-stacks list: a pinned
// application, a folder stack, or the dashed square that adds another.
//
// The accent is the design's, and it means what every accent in this design
// means -- this is the control that has the focus. The design draws it on the
// Downloads stack because that is the tile it is holding; nothing here picks a
// favourite out of a list of equals.
//
// The tile knows how to be dragged but not where it lands: it reports the x it
// was let go at and the strip above it decides which slot that is. Neighbours
// deliberately do not shuffle under the cursor -- rewriting the model mid-drag
// destroys the delegate being dragged.
Rectangle {
    id: root

    property string icon
    // A pinned app's own icon, when an icon theme is chosen (`AppIcons`).
    property string source
    // The dashed outline of the "add" square, which has no fill.
    property bool outlined: false
    property bool draggable: false

    property bool dragging: false
    property real dragX: 0

    signal activated
    signal move(int by)
    signal reorder(int by)
    signal removed
    signal dropped(real x)

    readonly property bool accented: root.activeFocus

    implicitWidth: Appearance.settings.tile
    implicitHeight: Appearance.settings.tile
    radius: Appearance.settings.tileRadius
    color: root.outlined ? "transparent" : root.accented ? Colours.alpha(Colours.primaryContainer, 0.6) : Colours.hover

    activeFocusOnTab: true

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.activated();
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            root.removed();
        } else if (event.key === Qt.Key_Left) {
            if (event.modifiers & Qt.ControlModifier)
                root.reorder(-1);
            else
                root.move(-1);
        } else if (event.key === Qt.Key_Right) {
            if (event.modifiers & Qt.ControlModifier)
                root.reorder(1);
            else
                root.move(1);
        } else {
            return;
        }
        event.accepted = true;
    }

    Behavior on color {
        enabled: !Colours.crossing

        ColorAnimation {
            duration: Appearance.anim.fast
            easing.type: Appearance.anim.enterEasing
        }
    }

    // Qt draws no dashed border, and the "add" square is the one place the
    // design asks for one. A canvas is cheaper than pulling in Shapes for a
    // single 38px rectangle, and it repaints only when the palette moves.
    Canvas {
        id: dashes

        readonly property color stroke: root.accented ? Colours.primary : Colours.outlineVariant

        anchors.fill: parent
        visible: root.outlined
        onStrokeChanged: dashes.requestPaint()
        onPaint: {
            const ctx = dashes.getContext("2d");
            ctx.reset();
            const r = root.radius;
            const w = dashes.width - 0.5;
            const h = dashes.height - 0.5;
            ctx.strokeStyle = dashes.stroke;
            ctx.lineWidth = 1;
            ctx.setLineDash([3, 3]);
            ctx.beginPath();
            ctx.moveTo(0.5 + r, 0.5);
            ctx.arcTo(w, 0.5, w, h, r);
            ctx.arcTo(w, h, 0.5, h, r);
            ctx.arcTo(0.5, h, 0.5, 0.5, r);
            ctx.arcTo(0.5, 0.5, w, 0.5, r);
            ctx.closePath();
            ctx.stroke();
        }
    }

    AppIcon {
        anchors.centerIn: parent
        source: root.source
        glyph: root.icon
        size: root.outlined ? Appearance.settings.tileIconSmall : Appearance.settings.tileIcon
        imageSize: Appearance.settings.tile * Appearance.size.appIconFill
        color: root.accented ? Colours.on.primaryContainer : Colours.on.surfaceVariant
    }

    MouseArea {
        id: mouse

        property real grab: 0
        property real origin: 0
        property bool moved: false

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        onPressed: event => {
            root.forceActiveFocus();
            mouse.origin = mouse.mapToItem(root.parent, event.x, 0).x;
            mouse.grab = mouse.origin - root.x;
            mouse.moved = false;
        }

        onPositionChanged: event => {
            if (!root.draggable || !mouse.pressed)
                return;
            const here = mouse.mapToItem(root.parent, event.x, 0).x;
            if (!root.dragging && Math.abs(here - mouse.origin) < Qt.styleHints.startDragDistance)
                return;
            root.dragging = true;
            mouse.moved = true;
            root.dragX = here - mouse.grab;
        }

        onReleased: {
            if (!root.dragging)
                return;
            root.dragging = false;
            root.dropped(root.dragX);
        }

        onClicked: if (!mouse.moved)
            root.activated()
    }
}
