pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.tokens
import qs.services
import qs.components

// Claude Code and Codex under the rest of the System tab: one card per tool
// while it is open, side by side off a horizontal bar (a lone one takes the
// whole row), stacked off a vertical one, and none once both are closed. Each
// has the plan, what the session is doing, the model and its effort, and a
// small ring per plan window with how long until it resets -- Claude Code's
// session, week and a model's own week (Fable's) among them. Three windows to
// a half card put their labels under the rings, so they still fit on one row.
// The numbers are the tool's own and as fresh as its last reply
// (`services/AiUsage.qml`).
//
// A card is clicked to go to the terminal its session runs in.
Item {
    id: root

    required property bool side

    readonly property var tools: AiUsage.cards
    readonly property bool pair: !root.side && root.tools.length > 1
    readonly property real cardWidth: root.pair ? (root.width - Appearance.dashboard.gap) / 2 : root.width

    // What a card needs, in rows of rings -- the drawer asks the same thing
    // (`Dashboard.aiHeight`) to know how tall the tab is.
    readonly property bool stacked: Appearance.dashboard.aiStacked(root.tools, root.cardWidth)
    readonly property int pairRows: Math.max(1, ...root.tools.map(t => Appearance.dashboard.aiRows(t, root.cardWidth, root.stacked)))

    implicitHeight: layout.implicitHeight
    visible: root.tools.length > 0

    component Meter: GridLayout {
        id: meter

        required property var modelData

        readonly property bool hot: meter.modelData.used >= AiUsage.nearLimit

        // Beside the ring, or under it.
        columns: root.stacked ? 1 : 2
        rowSpacing: 6
        columnSpacing: Appearance.dashboard.aiMeterGap
        Layout.preferredWidth: root.stacked ? Appearance.dashboard.aiStackWidth : Appearance.dashboard.aiMeter
        Layout.maximumWidth: Layout.preferredWidth
        Layout.alignment: Qt.AlignTop

        Ring {
            Layout.alignment: root.stacked ? Qt.AlignHCenter : Qt.AlignVCenter
            diameter: Appearance.dashboard.aiRing
            thickness: Appearance.dashboard.aiStroke
            value: meter.modelData.used / 100
            fill: meter.hot ? Colours.error : Colours.primary
            capStyle: ShapePath.RoundCap
            valueDuration: Appearance.dashboard.ringValueMs
            valueCurve: Appearance.dashboard.curve

            RowLayout {
                anchors.centerIn: parent
                spacing: Appearance.dashboard.unitGap

                Text {
                    text: Math.round(meter.modelData.used)
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.dashboard.aiValue
                    color: Colours.on.surface
                    Layout.alignment: Qt.AlignBaseline
                }

                Text {
                    text: "%"
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.dashboard.aiUnit
                    color: Colours.outline
                    Layout.alignment: Qt.AlignBaseline
                }
            }
        }

        ColumnLayout {
            spacing: Appearance.dashboard.subGap + 2
            Layout.fillWidth: true

            Text {
                text: meter.modelData.label
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.dashboard.ringLabelTop
                color: Colours.on.surface
                elide: Text.ElideRight
                horizontalAlignment: root.stacked ? Text.AlignHCenter : Text.AlignLeft
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 3
                Layout.fillWidth: !root.stacked
                Layout.alignment: root.stacked ? Qt.AlignHCenter : Qt.AlignLeft

                Icon {
                    visible: !meter.modelData.reset && meter.modelData.resetsAt > 0
                    text: "update"
                    size: Appearance.dashboard.eventLabel + 2
                    color: meter.hot ? Colours.error : Colours.outline
                }

                Text {
                    text: meter.modelData.reset ? qsTr("reset") : AiUsage.resetText(meter.modelData.resetsAt)
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.dashboard.eventLabel
                    color: meter.hot ? Colours.error : Colours.outline
                    elide: Text.ElideRight
                    Layout.fillWidth: !root.stacked
                    Layout.maximumWidth: root.stacked ? Appearance.dashboard.aiStackWidth - 16 : -1
                }
            }
        }
    }

    component Card: Rectangle {
        id: card

        required property var tool
        property int rows: 1

        readonly property var session: card.tool.session
        readonly property string doing: card.session?.state ?? ""
        readonly property string where: AiUsage.shortPath(card.session?.cwd ?? "")
        readonly property string window: AiUsage.windowOf(card.session)

        // Under the name: what the session is doing, and where.
        readonly property string statusText: {
            const place = card.where ? ` · ${card.where}` : "";
            switch (card.doing) {
            case "working":
                return qsTr("Working") + place;
            case "done":
                return qsTr("Done") + place;
            case "need":
                return card.where;
            }
            return qsTr("Open") + place;
        }

        radius: Appearance.dashboard.cardRadius
        color: Colours.surfaceContainer
        implicitHeight: Appearance.dashboard.aiCardHeight(card.rows, root.stacked)

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: Appearance.dashboard.cardPadV
            anchors.bottomMargin: Appearance.dashboard.cardPadV
            anchors.leftMargin: Appearance.dashboard.cardPadH
            anchors.rightMargin: Appearance.dashboard.cardPadH
            spacing: Appearance.dashboard.aiHeaderGap

            RowLayout {
                spacing: Appearance.dashboard.aiMeterGap
                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.dashboard.aiHeader

                Rectangle {
                    implicitWidth: Appearance.dashboard.aiBadge
                    implicitHeight: Appearance.dashboard.aiBadge
                    radius: Appearance.dashboard.aiBadgeRadius
                    color: Colours.surfaceContainerHigh

                    // The tool's logo, or the terminal glyph without one.
                    ToolIcon {
                        anchors.centerIn: parent
                        tool: card.tool.id
                        size: Appearance.size.iconSm + 2
                        colour: Colours.on.surfaceVariant
                    }
                }

                ColumnLayout {
                    spacing: Appearance.dashboard.subGap + 1
                    Layout.fillWidth: true

                    // The name, the plan, and on the right the model and its
                    // effort -- on this line, so what the session is doing
                    // has the whole line under it.
                    RowLayout {
                        spacing: 7
                        Layout.fillWidth: true

                        Text {
                            text: card.tool.name
                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.dashboard.aiName
                            color: Colours.on.surface
                        }

                        // The plan, quietly: Max, Business.
                        Text {
                            visible: card.tool.plan !== ""
                            text: card.tool.plan
                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.dashboard.eventLabel + 0.5
                            color: Colours.outline
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // "Fable 5.1 · high", "gpt-5.5-codex · medium".
                        Rectangle {
                            visible: card.tool.chip !== ""
                            implicitWidth: chipText.implicitWidth + 14
                            implicitHeight: chipText.implicitHeight + 6
                            radius: Appearance.dashboard.aiBadgeRadius - 1
                            color: "transparent"
                            border.width: 1
                            border.color: Colours.outlineVariant
                            Layout.maximumWidth: implicitWidth
                            Layout.fillWidth: true

                            Text {
                                id: chipText

                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, parent.width - 14)
                                elide: Text.ElideRight
                                text: card.tool.chip
                                font.family: Appearance.font.mono
                                font.pixelSize: Appearance.dashboard.eventLabel
                                color: Colours.outline
                            }
                        }
                    }

                    RowLayout {
                        spacing: 6
                        Layout.fillWidth: true

                        // Working: a dot in the accent.
                        Rectangle {
                            visible: card.doing === "working"
                            implicitWidth: 7
                            implicitHeight: 7
                            radius: 3.5
                            color: Colours.primary
                        }

                        Icon {
                            visible: card.doing === "done"
                            text: "check_circle"
                            size: Appearance.dashboard.eventLabel + 3
                            color: Colours.primary
                        }

                        // Needs you: the one thing on the card in a container.
                        Rectangle {
                            visible: card.doing === "need"
                            implicitWidth: needRow.implicitWidth + 14
                            implicitHeight: needRow.implicitHeight + 4
                            radius: height / 2
                            color: Colours.primaryContainer

                            RowLayout {
                                id: needRow

                                anchors.centerIn: parent
                                spacing: 4

                                Icon {
                                    text: "front_hand"
                                    fill: 1
                                    size: Appearance.dashboard.eventLabel + 2
                                    color: Colours.on.primaryContainer
                                }

                                Text {
                                    text: qsTr("Needs you")
                                    font.family: Appearance.font.mono
                                    font.pixelSize: Appearance.dashboard.eventLabel
                                    color: Colours.on.primaryContainer
                                }
                            }
                        }

                        Text {
                            text: card.statusText
                            font.family: Appearance.font.mono
                            font.pixelSize: Appearance.dashboard.eventLabel
                            color: card.doing === "working" || card.doing === "done" ? Colours.primary : Colours.outline
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            GridLayout {
                visible: card.tool.windows.length > 0
                columns: Appearance.dashboard.aiColumns(card.width, root.stacked)
                rowSpacing: Appearance.dashboard.aiRowGap
                columnSpacing: Appearance.dashboard.aiColumnGap
                Layout.fillWidth: true

                Repeater {
                    model: card.tool.windows

                    Meter {}
                }
            }

            // No numbers yet: Claude Code before it is connected, or either
            // tool before its first reply.
            RowLayout {
                visible: card.tool.windows.length === 0
                spacing: Appearance.dashboard.ringGap
                Layout.fillWidth: true
                Layout.preferredHeight: root.stacked ? Appearance.dashboard.aiStackHeight : Appearance.dashboard.aiRing

                Text {
                    text: card.tool.needsConnect ? qsTr("Connect it to see how much of your plan is used.") : qsTr("The numbers come with its next reply.")
                    font.family: Appearance.font.ui
                    font.pixelSize: Appearance.dashboard.toggleNote
                    color: Colours.outline
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Pill {
                    visible: card.tool.needsConnect
                    text: qsTr("Connect")
                    icon: "link"
                    tone: "subtle"
                    onClicked: ShellState.openSettings("ai")
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            enabled: card.window !== ""
            cursorShape: Qt.PointingHandCursor
            onClicked: AiUsage.focus(card.session)
        }
    }

    GridLayout {
        id: layout

        width: root.width
        columns: root.pair ? 2 : 1
        rowSpacing: Appearance.dashboard.gap
        columnSpacing: Appearance.dashboard.gap

        Repeater {
            model: root.tools

            Card {
                required property var modelData

                tool: modelData
                rows: root.pair ? root.pairRows : Appearance.dashboard.aiRows(modelData, root.cardWidth, root.stacked)
                Layout.fillWidth: true
                Layout.preferredWidth: 1
            }
        }
    }
}
