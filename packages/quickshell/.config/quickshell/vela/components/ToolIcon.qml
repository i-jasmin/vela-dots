import QtQuick
import QtQuick.Shapes
import qs.services

// An AI tool's logo -- Claude Code's or Codex's -- drawn from path data in
// whatever colour it is given, so it follows the palette like any glyph
// (`AiUsage.icons`, fetched by `vela ai icons`). Without one -- logos off, or
// not fetched yet -- the neutral terminal glyph stands in.
Item {
    id: root

    required property string tool
    property color colour
    property real size: 15

    readonly property var shape: AiUsage.icons[root.tool] ?? null
    readonly property real boxWidth: root.shape ? root.shape.viewBox[2] : 24

    implicitWidth: root.size
    implicitHeight: root.size

    Shape {
        visible: root.shape !== null
        width: root.boxWidth
        height: root.shape ? root.shape.viewBox[3] : 24
        scale: root.size / root.boxWidth
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.colour
            strokeColor: "transparent"
            strokeWidth: 0
            fillRule: root.shape?.evenodd ? ShapePath.OddEvenFill : ShapePath.WindingFill

            PathSvg {
                path: root.shape ? root.shape.paths.join(" ") : ""
            }
        }
    }

    Icon {
        visible: root.shape === null
        anchors.centerIn: parent
        text: "terminal"
        size: root.size
        color: root.colour
    }
}
