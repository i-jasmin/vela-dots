pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.tokens

// Claude Code and Codex, while a session is doing something: a spinner while
// it works, a raised hand in a container while it waits on you (a permission
// to give), a tick for a moment once it is done -- and nothing at all the
// rest of the time. Only with the tool connected in Settings, AI tools, since
// the tools' hooks are what say so (`services/AiUsage.qml`).
//
// It does not fold with the status run: it has nothing to show unless a
// session is doing something, and switched on from Settings it stands before
// the fold arrow (`BarContent.unfolded`).
//
// A click goes to the terminal of the session that most wants you; a
// right-click opens the System tab, where the plan's numbers are.
Item {
    id: root

    required property BarState bar

    readonly property var items: AiUsage.pill
    readonly property bool present: root.items.length > 0
    // One tool says what it is doing in words; two say only who.
    readonly property bool wordy: root.items.length === 1

    implicitWidth: root.bar.vertical ? column.implicitWidth : chip.implicitWidth
    implicitHeight: root.bar.vertical ? column.implicitHeight : chip.implicitHeight

    function glyph(state: string): string {
        return state === "need" ? "front_hand" : state === "done" ? "check_circle" : "progress_activity";
    }

    function words(item: var): string {
        const state = item.session.state;
        if (!root.wordy)
            return item.name;
        return state === "need" ? qsTr("%1 needs you").arg(item.name) : state === "done" ? qsTr("%1 done").arg(item.name) : item.name;
    }

    function go(): void {
        AiUsage.focus(root.items[0]?.session ?? null);
    }

    component Glyph: Icon {
        id: glyph

        property string state

        text: root.glyph(glyph.state)
        fill: glyph.state === "need" ? 1 : 0
        size: Appearance.size.iconSm
        color: glyph.state === "need" ? Colours.on.primaryContainer : Colours.primary

        // The spinner turns while it works.
        RotationAnimation on rotation {
            running: glyph.state === "working" && !Appearance.reduceMotion
            from: 0
            to: 360
            duration: 1400
            loops: Animation.Infinite
            onStopped: glyph.rotation = 0
        }
    }

    BarChip {
        id: chip

        visible: !root.bar.vertical
        anchors.verticalCenter: parent.verticalCenter
        padLead: Appearance.bar.chipPadLead
        // A "needs you" capsule at the end sits close to the chip's edge.
        padTrail: root.items[root.items.length - 1]?.session.state === "need" ? 3 : Appearance.bar.chipPadTrail
        interactive: true

        onClicked: root.go()
        onSecondaryClicked: root.bar.dashboardOn("system")

        Repeater {
            model: root.items

            RowLayout {
                id: item

                required property var modelData
                required property int index

                readonly property bool need: item.modelData.session.state === "need"

                spacing: Appearance.bar.chipGap
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    visible: item.index > 0
                    implicitWidth: 1
                    implicitHeight: 12
                    color: Colours.outlineVariant
                }

                Rectangle {
                    implicitWidth: inner.implicitWidth + (item.need ? 14 : 0)
                    implicitHeight: Appearance.bar.iconButtonH - 6
                    radius: height / 2
                    color: item.need ? Colours.primaryContainer : "transparent"

                    RowLayout {
                        id: inner

                        anchors.centerIn: parent
                        spacing: 5

                        Glyph {
                            state: item.modelData.session.state
                        }

                        Text {
                            text: root.words(item.modelData)
                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.size.label
                            color: item.need ? Colours.on.primaryContainer : Colours.on.surfaceVariant
                        }
                    }
                }
            }
        }
    }

    // A vertical bar: the glyphs alone, one over the other.
    ColumnLayout {
        id: column

        visible: root.bar.vertical
        anchors.centerIn: parent
        spacing: Appearance.space.xs

        Repeater {
            model: root.items

            Rectangle {
                id: tile

                required property var modelData

                readonly property bool need: tile.modelData.session.state === "need"

                implicitWidth: Appearance.bar.iconButton
                implicitHeight: Appearance.bar.iconButton
                radius: Appearance.bar.tileRadius(Appearance.bar.iconButton)
                color: tile.need ? Colours.primaryContainer : "transparent"

                Glyph {
                    anchors.centerIn: parent
                    state: tile.modelData.session.state
                }
            }
        }
    }

    MouseArea {
        visible: root.bar.vertical
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton ? root.bar.dashboardOn("system") : root.go()
    }
}
