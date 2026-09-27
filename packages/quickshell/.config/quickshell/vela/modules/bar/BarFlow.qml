import QtQuick
import QtQuick.Layouts

// The one place in the shell that knows which way the bar runs.
//
// Both bars are the same parts in the same order with the flow turned ninety
// degrees, so there is no BarVertical and no BarHorizontal: every group
// in the bar -- the rail itself, the workspace pills, the cpu/ram stacks, the
// tray, the stacked clock -- is one of these with `vertical` set. Rotating the
// bar rotates all of them at once because they all read the same property.
//
//     BarFlow {
//         vertical: bar.vertical
//         gap: Appearance.bar.gapV
//
//         BarButton { ... }
//         Item { Layout.fillHeight: flow.vertical; Layout.fillWidth: !flow.vertical }
//     }
//
// A GridLayout rather than a hand-rolled positioner, because it already has
// what a Row and a Column have between them and nothing either has alone: one
// type whose direction is a property, and the Layout attached properties, which
// is how a spacer takes the slack in whichever axis is running. `rows` and
// `columns` are the wrap points -- GridLayout reads only the one that matches
// the flow -- so pinning the cross axis to 1 makes a single line either way.
//
// Note: nothing inside a BarFlow may size itself from the BarFlow. A
// child binding `implicitHeight: flow.height` collapses the flow's implicit
// width to zero, permanently and without a warning. Cross-axis sizing comes
// from `Layout.alignment` and `Layout.fillWidth`, never from reading back.
GridLayout {
    id: root

    property bool vertical: false
    property int gap: 0

    flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    // 64 is "no wrap": the bar carries a dozen items and the grid is allocated
    // from the wrap count, so an unbounded value would be a real cost.
    rows: root.vertical ? 64 : 1
    columns: root.vertical ? 1 : 64

    rowSpacing: root.vertical ? root.gap : 0
    columnSpacing: root.vertical ? 0 : root.gap
}
