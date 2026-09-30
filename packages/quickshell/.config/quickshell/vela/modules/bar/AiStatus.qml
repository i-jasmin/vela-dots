pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.tokens

// Claude Code and Codex, while they are open: each tool's logo with how much
// of its 5-hour window is used. The logo in the accent, gently breathing,
// while it works; in a container while it waits on you (a permission to
// give); with a tick for a moment once it is done; quiet in between -- and
// gone once the tool is closed. That it is open comes from its process; what
// it is doing needs the tool connected in Settings, AI tools, since the
// tools' hooks are what say so (`services/AiUsage.qml`). The number turns red
// at 90%.
//
// It does not fold with the status run: switched on from Settings it stands
// before the fold arrow (`BarContent.unfolded`), so folding the bar never
// hides an open session. A vertical bar stacks the logo over the number, the
// way CPU and memory stand there.
//
// A click opens the dashboard on the System tab, where the plan's numbers
// are, as CPU and memory do; a right-click goes to the terminal of the
// session that most wants you.
Item {
    id: root

    required property BarState bar

    readonly property var items: AiUsage.pill
    readonly property bool present: root.items.length > 0

    implicitWidth: root.bar.vertical ? column.implicitWidth : chip.implicitWidth
    implicitHeight: root.bar.vertical ? column.implicitHeight : chip.implicitHeight

    function go(): void {
        AiUsage.focus(root.items[0]?.session ?? null);
    }

    function used(item: var): var {
        return AiUsage.sessionOf5h(item.id);
    }

    function percent(item: var): string {
        const w = root.used(item);
        return w ? `${Math.round(w.used)}%` : "";
    }

    function hot(item: var): bool {
        const w = root.used(item);
        return !!w && w.used >= AiUsage.nearLimit;
    }

    // The logo, breathing while its session works.
    component Logo: ToolIcon {
        id: logo

        property string state

        size: Appearance.size.iconSm
        colour: logo.state === "need" ? Colours.on.primaryContainer : logo.state === "working" ? Colours.primary : Colours.on.surfaceVariant

        SequentialAnimation on opacity {
            running: logo.state === "working" && !Appearance.reduceMotion
            loops: Animation.Infinite
            onStopped: logo.opacity = 1

            NumberAnimation {
                to: 0.45
                duration: 800
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 1
                duration: 800
                easing.type: Easing.InOutSine
            }
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

        onClicked: root.bar.dashboardOn("system")
        onSecondaryClicked: root.go()

        Repeater {
            model: root.items

            RowLayout {
                id: item

                required property var modelData
                required property int index

                readonly property string state: item.modelData.session.state
                readonly property bool need: item.state === "need"

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

                        Logo {
                            tool: item.modelData.id
                            state: item.state
                        }

                        Icon {
                            visible: item.state === "done"
                            text: "check"
                            size: Appearance.size.iconXs
                            color: Colours.primary
                        }

                        Text {
                            visible: text !== ""
                            text: root.percent(item.modelData)
                            font.family: Appearance.font.mono
                            font.pixelSize: Appearance.size.label - 0.5
                            color: root.hot(item.modelData) ? Colours.error : item.need ? Colours.on.primaryContainer : Colours.on.surfaceVariant
                        }
                    }
                }
            }
        }
    }

    // A vertical bar: the logo over the number, one tool over the other.
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

                readonly property string state: tile.modelData.session.state
                readonly property bool need: tile.state === "need"

                implicitWidth: Appearance.bar.iconButton
                implicitHeight: stack.implicitHeight + 12
                radius: Appearance.bar.tileRadius(Appearance.bar.iconButton)
                color: tile.need ? Colours.primaryContainer : "transparent"

                ColumnLayout {
                    id: stack

                    anchors.centerIn: parent
                    spacing: 2

                    Logo {
                        tool: tile.modelData.id
                        state: tile.state
                        size: Appearance.size.iconSm + 2
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        visible: text !== ""
                        text: tile.state === "done" ? "✓" : root.percent(tile.modelData)
                        font.family: Appearance.font.mono
                        font.pixelSize: Appearance.size.label - 1.5
                        color: root.hot(tile.modelData) ? Colours.error : tile.need ? Colours.on.primaryContainer : Colours.on.surfaceVariant
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }

    MouseArea {
        visible: root.bar.vertical
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton ? root.go() : root.bar.dashboardOn("system")
    }
}
