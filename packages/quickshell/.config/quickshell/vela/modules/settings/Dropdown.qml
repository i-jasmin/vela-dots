pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.tokens
import qs.components

// A setting with more choices than a segmented rail holds -- the app icon
// themes on the Appearance page, of which a machine can have any number. A
// button showing the current choice, and the list it opens under it.
//
//     Dropdown {
//         model: [{ key: "", title: "vela", subtitle: "…" }, …]
//         current: Config.appearance.iconTheme
//         preview: aComponent      // optional; given `choice` and `compact`
//         onPicked: key => …
//     }
//
// A choice may carry `mono: true` for a subtitle that is a path. `preview` is
// drawn on the button (compact) and at the end of every row, and is handed the
// choice it stands for.
//
// THE LIST IS LIFTED OUT OF THE PAGE while it is open. A page is clipped
// twice, by the crossfade between pages and by its own scroll, so a list drawn
// where the button is would be cut off at the edge of the card it opens over.
// It is drawn on the settings panel itself instead (`objectName:
// "settingsPanel"` in Settings.qml), over everything, under the button -- or
// above it, when there is no room below. Pressing anywhere off the list puts
// it away, as does esc; the wheel is held while it is open, so the page cannot
// scroll the button out from under it.
Item {
    id: root

    property var model: []
    property string current
    property Component preview: null

    signal picked(string key)

    property bool open: false

    readonly property var choice: root.model.find(c => c.key === root.current) ?? null

    // The settings panel the list is drawn on; the dropdown itself outside
    // one, where there is nothing to lift it over.
    readonly property Item host: {
        let p = root.parent;
        while (p && p.objectName !== "settingsPanel")
            p = p.parent;
        return p ?? root;
    }

    implicitWidth: button.implicitWidth
    implicitHeight: Appearance.settings.dropdownHeight

    function show(): void {
        const at = root.mapToItem(layer, 0, 0);
        const margin = Appearance.space.md;
        const gap = Appearance.settings.dropdownOffset;
        // Right edge to the button's right edge, as the list reads from a
        // control at the end of a row.
        menu.x = Math.max(margin, Math.min(at.x + root.width - menu.width, layer.width - menu.width - margin));
        const below = at.y + root.height + gap;
        menu.y = below + menu.height <= layer.height - margin ? below : Math.max(margin, at.y - gap - menu.height);
        const i = root.model.findIndex(c => c.key === root.current);
        list.currentIndex = Math.max(0, i);
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
        root.open = true;
        list.forceActiveFocus();
    }

    function close(): void {
        if (!root.open)
            return;
        root.open = false;
        button.forceActiveFocus();
    }

    function pick(key: string): void {
        root.close();
        if (key !== root.current)
            root.picked(key);
    }

    // Put away with the window, however it closed.
    Connections {
        target: ShellState

        function onSettingsChanged(): void {
            if (!ShellState.settings)
                root.open = false;
        }
    }

    Rectangle {
        id: button

        anchors.fill: parent
        implicitWidth: buttonRow.implicitWidth + Appearance.settings.dropdownPadStart + Appearance.settings.dropdownPadEnd
        radius: Appearance.radius.card
        color: Colours.hover
        border.width: root.open || button.activeFocus ? 1 : 0
        border.color: Colours.primary

        activeFocusOnTab: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
                root.show();
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Colours.hover
            opacity: buttonMouse.containsMouse && !root.open ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Appearance.anim.enterEasing
                }
            }
        }

        RowLayout {
            id: buttonRow

            anchors.fill: parent
            anchors.leftMargin: Appearance.settings.dropdownPadStart
            anchors.rightMargin: Appearance.settings.dropdownPadEnd
            spacing: Appearance.settings.dropdownGap

            Loader {
                active: root.preview !== null && root.choice !== null
                visible: active
                sourceComponent: root.preview
                onLoaded: {
                    item.compact = true;
                    item.choice = Qt.binding(() => root.choice);
                }

                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: root.choice?.title ?? root.current
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.label
                color: Colours.on.surface
                elide: Text.ElideRight

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            Icon {
                text: root.open ? "expand_less" : "expand_more"
                size: Appearance.settings.dropdownChevron
                color: Colours.outline

                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open ? root.close() : root.show()
        }
    }

    // ---- the list ---------------------------------------------------------

    Item {
        id: layer

        parent: root.host
        anchors.fill: parent
        z: 10
        visible: root.open || menu.opacity > 0

        // Off the list: put it away. On the press, as a menu goes the moment
        // you press beside it, and holding the wheel while it is open.
        MouseArea {
            anchors.fill: parent
            enabled: root.open
            acceptedButtons: Qt.AllButtons
            onPressed: root.close()
            onWheel: wheel => wheel.accepted = true
        }

        Panel {
            id: menu

            level: "popout"
            padding: Appearance.space.xs
            // Solid: it opens over the page's own text, and a popout's
            // translucency let that read through the names.
            colour: Colours.surfaceContainerHigh
            width: Appearance.settings.dropdownWidth
            height: list.height + menu.padding * 2
            opacity: root.open ? 1 : 0

            Behavior on opacity {
                id: fading

                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: fading.targetValue > 0 ? Appearance.anim.enterEasing : Appearance.anim.exitEasing
                }
            }

            // Its own presses stay its own, rather than reaching the catcher
            // behind it between two rows.
            MouseArea {
                anchors.fill: parent
                anchors.margins: -menu.padding
                acceptedButtons: Qt.AllButtons
            }

            ListView {
                id: list

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                // Clear of the scroll thumb, when there is one.
                anchors.rightMargin: list.interactive ? Appearance.settings.scrollbar * 2 : 0
                height: Math.min(list.count, Appearance.settings.dropdownRows) * Appearance.settings.dropdownRowHeight
                model: root.model
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: list.count > Appearance.settings.dropdownRows
                // Its own, not `interactive`'s, which it follows by default:
                // a list too short to scroll still walks with the arrows.
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                highlightResizeDuration: 0

                // The row the arrows are on. The current choice carries
                // `primaryContainer` of its own, over this.
                highlight: Rectangle {
                    radius: Appearance.radius.chip
                    color: Colours.hover
                }

                Keys.onReturnPressed: root.pick(root.model[list.currentIndex]?.key ?? root.current)
                Keys.onEnterPressed: root.pick(root.model[list.currentIndex]?.key ?? root.current)
                Keys.onSpacePressed: root.pick(root.model[list.currentIndex]?.key ?? root.current)
                Keys.onEscapePressed: event => {
                    root.close();
                    event.accepted = true;
                }
                // Tab would walk out of the list and leave it open behind.
                Keys.onTabPressed: event => {
                    root.close();
                    event.accepted = true;
                }

                delegate: Row {
                    id: option

                    required property var modelData
                    required property int index

                    width: list.width
                    title: option.modelData.title
                    subtitle: option.modelData.subtitle ?? ""
                    subtitleMono: option.modelData.mono ?? false
                    selected: option.modelData.key === root.current
                    rowHeight: Appearance.settings.dropdownRowHeight
                    trailingIcon: ""
                    leading: check
                    trailing: root.preview !== null ? previewSlot : null
                    activeFocusOnTab: false

                    onHoveredChanged: {
                        if (option.hovered)
                            list.currentIndex = option.index;
                    }
                    onClicked: root.pick(option.modelData.key)

                    Component {
                        id: check

                        Item {
                            implicitWidth: Appearance.settings.dropdownCheck
                            implicitHeight: Appearance.settings.dropdownCheck

                            Icon {
                                anchors.centerIn: parent
                                visible: option.selected
                                text: "check"
                                size: Appearance.size.iconLabel
                                color: Colours.on.primaryContainer
                            }
                        }
                    }

                    Component {
                        id: previewSlot

                        Loader {
                            sourceComponent: root.preview
                            onLoaded: {
                                item.compact = false;
                                item.choice = Qt.binding(() => option.modelData);
                            }
                        }
                    }
                }
            }

            // The list scrolls past six; this says so.
            Rectangle {
                visible: list.interactive
                anchors.right: parent.right
                y: list.visibleArea.yPosition * list.height
                width: Appearance.settings.scrollbar
                height: list.visibleArea.heightRatio * list.height
                radius: width / 2
                color: Colours.track
            }
        }
    }
}
