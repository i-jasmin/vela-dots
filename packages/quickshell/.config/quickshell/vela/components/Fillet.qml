import QtQuick
import QtQuick.Shapes
import qs.tokens

// A concave corner: a square filled everywhere except a quarter disc centred
// on one of its corners. Where a surface meets another at a right angle, it
// curves the join instead of leaving a notch -- the dashboard's drawer grows
// out of the bar on two of these.
//
//     Fillet {
//         size: 28
//         // the corner the disc is centred on: 0/1 for left/right, top/bottom
//         centreX: 0
//         centreY: 1
//         color: Colours.surfaceBarAttached
//     }
//
// The filled part is the corner opposite the centre, bounded by the two edges
// that meet there and the arc between them.
Item {
    id: root

    property real size: Appearance.dashboard.fillet
    property int centreX: 0
    property int centreY: 1
    property color color: Colours.surfaceBarAttached

    implicitWidth: root.size
    implicitHeight: root.size
    width: root.size
    height: root.size
    visible: root.size > 0

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false

        ShapePath {
            fillColor: root.color
            strokeWidth: -1

            // Round the filled region: down the edge away from the centre's
            // column, across to the far corner, then back along the arc.
            startX: root.centreX * root.size
            startY: (1 - root.centreY) * root.size

            PathLine {
                x: (1 - root.centreX) * root.size
                y: (1 - root.centreY) * root.size
            }

            PathLine {
                x: (1 - root.centreX) * root.size
                y: root.centreY * root.size
            }

            PathArc {
                x: root.centreX * root.size
                y: (1 - root.centreY) * root.size
                radiusX: root.size
                radiusY: root.size
                // Seen from the centre, the arc turns one way when the centre
                // sits on the diagonal through the origin and the other way
                // when it sits on the other diagonal.
                direction: root.centreX === root.centreY ? PathArc.Clockwise : PathArc.Counterclockwise
            }
        }
    }
}
