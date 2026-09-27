pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.tokens
import qs.components

// The panel a stack opens above the dock -- the design's Downloads.
//
// A folder, newest first, in a three-column grid or a list, with the folder
// itself one click away. The grid/list choice is a config key, not a property:
// shell.json holds it per stack, so which way you last looked at Downloads
// survives a restart and the settings screen could set it without this file
// knowing.
Panel {
    id: root

    // The entry of `Config.dock.stacks` this panel belongs to, and its index,
    // which is what writing the view choice back needs.
    required property var stack
    required property int index
    required property var stacks

    readonly property string path: root.stack.path ?? ""
    readonly property string label: root.stacks.label(root.path)
    // How many of the newest to show. The design draws six, which is two rows
    // of three; a stack may name its own.
    readonly property int recent: root.stack.recent ?? Appearance.dock.stackColumns * 2
    readonly property bool grid: (root.stack.view ?? "grid") !== "list"

    readonly property var files: root.stacks.files(root.path).slice(0, root.recent)
    readonly property int total: root.stacks.count(root.path)

    function setView(view: string): void {
        // `list<var>` holds references, so the entries are copied rather than
        // edited in place: mutating one and assigning the same array back would
        // not notify, and nothing would redraw.
        const next = Config.dock.stacks.map(s => Object.assign({}, s));
        if (!next[root.index])
            return;
        next[root.index].view = view;
        Config.dock.stacks = next;
        Config.save();
    }

    level: "panel"
    padding: Appearance.dock.stackPadding
    implicitWidth: Appearance.dock.stackWidth
    implicitHeight: column.implicitHeight + root.padding * 2

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Appearance.dock.stackGap

        // ---- heading -------------------------------------------------------
        RowLayout {
            spacing: Appearance.dock.stackHeaderGap

            Layout.fillWidth: true

            Icon {
                text: root.stack.icon ?? "folder"
                size: Appearance.dock.stackHeaderIcon
                color: Colours.primary

                Layout.preferredHeight: Appearance.dock.stackHeaderIcon
            }

            Text {
                text: root.label
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.body
                color: Colours.on.surface
                elide: Text.ElideRight

                Layout.fillWidth: true
            }

            // A count is a number, so it is mono.
            Text {
                text: root.files.length > 0 ? qsTr("%1 recent").arg(root.files.length) : ""
                font.family: Appearance.font.mono
                font.pixelSize: Appearance.size.micro
                color: Colours.outline
            }
        }

        // ---- the grid ------------------------------------------------------
        GridLayout {
            visible: root.grid && root.files.length > 0
            columns: Appearance.dock.stackColumns
            columnSpacing: Appearance.dock.stackCellGap
            rowSpacing: Appearance.dock.stackCellGap

            Layout.fillWidth: true

            Repeater {
                model: root.grid ? root.files : []

                Rectangle {
                    id: cell

                    required property var modelData

                    radius: Appearance.radius.chip
                    color: Colours.hover

                    implicitHeight: cellBody.implicitHeight + Appearance.dock.stackCellPadding * 2

                    // Equal thirds. `preferredWidth: 1` with `fillWidth` is the
                    // layout's way of saying "share the row" -- a cell must not
                    // ask for its content's width or a long file name would
                    // push the other two out of the panel.
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1

                    // Hover is a second coat of the same neutral, which is how
                    // every other hoverable surface in the shell does it.
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Colours.hover
                        opacity: hover.hovered ? 1 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                                easing.type: Appearance.anim.enterEasing
                            }
                        }
                    }

                    ColumnLayout {
                        id: cellBody

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Appearance.dock.stackCellPadding
                        spacing: Appearance.dock.stackCellInnerGap

                        // Given its own height: a Text box is the font's line
                        // spacing tall, which on a 20px glyph is six pixels
                        // more than the glyph -- twice over, in a two-row grid,
                        // on a panel measured against the design.
                        Icon {
                            text: root.stacks.iconFor(cell.modelData)
                            size: Appearance.dock.stackCellIcon
                            color: Colours.on.surfaceVariant

                            Layout.preferredHeight: Appearance.dock.stackCellIcon
                        }

                        ColumnLayout {
                            spacing: 0

                            Layout.fillWidth: true

                            Text {
                                text: cell.modelData.name
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.dock.stackNameSize
                                color: Colours.on.surface
                                elide: Text.ElideRight

                                Layout.fillWidth: true
                            }

                            // A timestamp is a literal.
                            Text {
                                text: root.stacks.ago(cell.modelData.time)
                                font.family: Appearance.font.mono
                                font.pixelSize: Appearance.dock.stackTimeSize
                                color: Colours.outline
                            }
                        }
                    }

                    HoverHandler {
                        id: hover
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stacks.openFile(cell.modelData)
                    }
                }
            }
        }

        // ---- or the list ---------------------------------------------------
        //
        // The same files through `components/Row`, which is what every other
        // list in the shell is made of.
        ColumnLayout {
            visible: !root.grid && root.files.length > 0
            spacing: 0

            Layout.fillWidth: true

            Repeater {
                model: root.grid ? [] : root.files

                Row {
                    required property var modelData

                    icon: root.stacks.iconFor(modelData)
                    title: modelData.name
                    trailingText: root.stacks.ago(modelData.time)
                    rowHeight: Appearance.dock.stackRowHeight
                    hPadding: Appearance.space.sm
                    iconSize: Appearance.size.iconLabel

                    Layout.fillWidth: true

                    onClicked: root.stacks.openFile(modelData)
                }
            }
        }

        // ---- or nothing ----------------------------------------------------
        //
        // An empty stack says so. A folder that has not been read yet says
        // nothing at all, rather than claiming to be empty.
        Text {
            visible: root.files.length === 0 && root.stacks.known(root.path)
            text: qsTr("Nothing in %1").arg(root.label)
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.label
            color: Colours.outline
            horizontalAlignment: Text.AlignHCenter

            Layout.fillWidth: true
            Layout.topMargin: Appearance.space.sm
            Layout.bottomMargin: Appearance.space.sm
        }

        // ---- footer --------------------------------------------------------
        RowLayout {
            spacing: Appearance.dock.stackCellGap

            Layout.fillWidth: true

            // The trash's own verb, in the error tint every destructive
            // action wears. It asks once -- nothing comes back from an
            // emptied trash -- and forgets the question if not answered.
            Pill {
                id: emptyTrash

                property bool asking: false

                visible: root.path === "trash" && root.files.length > 0
                text: emptyTrash.asking ? qsTr("Sure?") : qsTr("Empty")
                icon: "delete_forever"
                tone: "danger"
                pillHeight: Appearance.dock.stackFooterHeight
                fontSize: Appearance.size.label

                onClicked: {
                    if (!emptyTrash.asking) {
                        emptyTrash.asking = true;
                        forget.restart();
                        return;
                    }
                    emptyTrash.asking = false;
                    forget.stop();
                    root.stacks.emptyTrash();
                }

                Timer {
                    id: forget

                    interval: Appearance.dock.confirmWindow
                    onTriggered: emptyTrash.asking = false
                }
            }

            Pill {
                text: qsTr("Open folder")
                tone: "subtle"
                pillHeight: Appearance.dock.stackFooterHeight
                fontSize: Appearance.size.label

                Layout.fillWidth: true

                onClicked: root.stacks.openFolder(root.path)
            }

            Segmented {
                // Re-asserted, not only bound: a click writes the rail's own
                // index, which undoes a plain binding, and another stack's
                // view then showed under this one's choice.
                readonly property int wanted: root.grid ? 0 : 1

                model: [qsTr("Grid"), qsTr("List")]
                currentIndex: wanted
                onWantedChanged: currentIndex = wanted
                segmentHeight: Appearance.dock.stackToggleHeight
                segmentRadius: Appearance.radius.chip
                railRadius: Appearance.dock.stackToggleRail
                fontSize: Appearance.size.caption
                hPadding: Appearance.dock.stackCellPadding

                onSelected: i => root.setView(i === 0 ? "grid" : "list")
            }
        }
    }
}
