import QtQuick
import qs.tokens

// A box that grows and shrinks to fit what is in it instead of jumping: a
// popout swapping pages, a list gaining results, a notification whose body
// opens.
//
//     MorphBox {
//         ColumnLayout {
//             width: 320
//             ...
//         }
//     }
//
// Its size follows the first child's implicit size, through `Morph`. The child
// is laid out at the new size straight away and uncovered -- or cut back -- as
// the box catches up, so nothing inside reflows mid-motion. The box clips only
// while it is moving, which leaves focus rings and shadows alone at rest.
//
// When a layout sizes the box across (Layout.fillWidth), turn `morphWidth`
// off: the child then gets the box's real width to fill, and only the height
// moves. Likewise `morphHeight` for a box sized down by its parent.
//
// A box that was empty takes its first size at once. The surface it sits in
// has its own entrance, and growing out of nothing would run a second one.
Item {
    id: root

    property bool morphWidth: true
    property bool morphHeight: true

    default property alias content: holder.data
    readonly property Item item: holder.children.length > 0 ? holder.children[0] : null

    // The size the box is heading for. `implicitWidth` and `implicitHeight`
    // are where it is on the way.
    readonly property real targetWidth: root.item?.implicitWidth ?? 0
    readonly property real targetHeight: root.item?.implicitHeight ?? 0
    readonly property bool morphing: widthMorph.running || heightMorph.running

    implicitWidth: root.targetWidth
    implicitHeight: root.targetHeight
    clip: root.morphing

    Behavior on implicitWidth {
        enabled: root.morphWidth && root.implicitWidth > 0

        Morph {
            id: widthMorph
        }
    }

    Behavior on implicitHeight {
        enabled: root.morphHeight && root.implicitHeight > 0

        Morph {
            id: heightMorph
        }
    }

    Item {
        id: holder

        width: root.morphWidth ? root.targetWidth : root.width
        height: root.morphHeight ? root.targetHeight : root.height
    }
}
