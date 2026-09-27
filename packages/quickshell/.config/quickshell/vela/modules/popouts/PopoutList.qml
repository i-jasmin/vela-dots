pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.tokens
import qs.components

// A popout's list that shows its first few and opens out to all of them: the
// networks a scan finds, the Bluetooth devices nearby.
//
//     PopoutList {
//         model: Net.networks
//         moreText: n => qsTr("%1 more networks").arg(n)
//         delegate: Component {
//             Row {
//                 required property var modelData
//                 ...
//             }
//         }
//     }
//
// The first `shown` rows, and under them "8 more" with the same chevron the
// notification centre opens an app's history with; clicked, the rest follow
// and it turns into "Show fewer". Opened out, the list scrolls past
// `popout.listMax`, so a busy street's worth of access points still leaves
// the popout on the screen. It starts closed each time the popout opens,
// since the popout's content is made anew.
//
// The rows are kept by the thing they stand for (ScriptModel), not rebuilt on
// every scan: a network answers again every few seconds while the popout is
// up, and a row rebuilt under the pointer loses a half-typed password and
// the place the list was scrolled to.
ColumnLayout {
    id: root

    property var model: []
    property Component delegate
    property int shown: Appearance.popout.listShown
    // What the button says while closed, given how many are hidden.
    property var moreText: n => qsTr("%1 more").arg(n)
    property int rowSpacing: Appearance.space.md

    property bool open: false

    readonly property int hidden: Math.max(0, (root.model?.length ?? 0) - root.shown)
    // A plain array in both states. `model` is usually a QML `list<T>`
    // (Net.networks, Bt.known), which ScriptModel refuses -- "Unable to assign
    // QQmlListReference to QList<QJSValue>" -- so handed over as it was, the
    // opened-out list drew nothing. The folded one only worked because
    // `slice()` happens to return an array.
    readonly property var rows: {
        const all = Array.from(root.model ?? []);
        return root.open ? all : all.slice(0, root.shown);
    }

    spacing: Appearance.space.xs
    visible: root.rows.length > 0

    Layout.fillWidth: true

    onOpenChanged: if (!root.open)
        scroll.contentY = 0

    Flickable {
        id: scroll

        contentWidth: width
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: scroll.contentHeight > scroll.height
        clip: scroll.interactive

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(column.implicitHeight, Appearance.popout.listMax)

        ColumnLayout {
            id: column

            width: scroll.width
            spacing: root.rowSpacing

            Repeater {
                model: ScriptModel {
                    values: root.rows
                }
                delegate: root.delegate
            }
        }
    }

    Pill {
        visible: root.hidden > 0
        text: root.open ? qsTr("Show fewer") : root.moreText(root.hidden)
        icon: root.open ? "expand_less" : "expand_more"
        tone: "plain"
        pillHeight: Appearance.settings.segmentHeight
        fontSize: Appearance.size.caption
        onClicked: root.open = !root.open
    }
}
