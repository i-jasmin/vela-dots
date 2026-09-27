import QtQuick
import QtQuick.Shapes
import qs.tokens

// A progress arc: the dashboard's focus timer and its CPU / memory / GPU rings.
// The design draws these as SVG circles and conic gradients; a stroked arc is
// the QML equivalent and, unlike a gradient, leaves the middle genuinely
// transparent, so the card behind shows through instead of being repainted by a
// disc that has to know its own background.
//
//     Ring {
//         value: Sys.cpu / 100
//         diameter: 56
//         thickness: 6
//
//         Text { text: "12" }     // children are centred in the hole
//     }
//
// The arc starts at twelve o'clock and runs clockwise. `fill` is `primary` for
// the meter that matters and `muted` for one that is merely present -- the
// dashboard draws disk usage in the quiet colour for exactly that reason.
Item {
    id: root

    property real value: 0
    property real diameter: Appearance.widget.ringDiameter
    property real thickness: Appearance.widget.ringThickness
    property color fill: Colours.primary
    property color trackColour: Colours.track
    // The value arc's ends: flat by default, round where a design asks
    // (the dashboard's system rings and focus timer).
    property int capStyle: ShapePath.FlatCap
    // How the arc travels to a new value: the shell's normal motion unless a
    // design names its own duration and cubic-bezier.
    property int valueDuration: Appearance.anim.normal
    property var valueCurve: []

    default property alias content: centre.data

    readonly property real clamped: Math.max(0, Math.min(1, root.value))

    implicitWidth: root.diameter
    implicitHeight: root.diameter

    // The value itself, not decoration: a meter that jumps between samples
    // reads as broken. Halved with the rest when motion is reduced.
    Behavior on value {
        NumberAnimation {
            duration: root.valueDuration
            easing.type: root.valueCurve.length > 0 ? Easing.BezierSpline : Appearance.anim.enterEasing
            easing.bezierCurve: root.valueCurve
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false

        ShapePath {
            strokeColor: root.trackColour
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.diameter - root.thickness) / 2
                radiusY: (root.diameter - root.thickness) / 2
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root.fill
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: root.capStyle

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.diameter - root.thickness) / 2
                radiusY: (root.diameter - root.thickness) / 2
                startAngle: -90
                sweepAngle: 360 * root.clamped
            }
        }
    }

    Item {
        id: centre

        anchors.centerIn: parent
        width: root.diameter - root.thickness * 2
        height: width
    }
}
