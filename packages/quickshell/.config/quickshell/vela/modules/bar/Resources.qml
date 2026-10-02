pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.tokens

// CPU and memory, as the design draws them: a glyph over a number down a
// vertical bar, a word beside a number along a horizontal one. Both are
// monospace, because both are quantities.
//
// While package updates wait, a third pair follows them: a download arrow
// and how many, in the accent (`services/Updates.qml`). The System tab, a
// click away, says what they are and has the button that runs them.
//
// Clicking opens the dashboard on its System tab, NOT a popout; a second click
// puts it away. System stats are information you
// go and look at; a popout is a control for the thing you clicked. The design
// makes that the rule its whole layout exists to enforce, and a "resources
// popout" is the first thing that would break it.
Item {
    id: root

    required property BarState bar

    // Folded away with the rest of the status run (BarExpander).
    readonly property bool present: !root.bar.collapsed

    // "--" rather than "0": SysInfo needs two samples before it knows anything,
    // and a confident zero during the first few seconds is a lie.
    readonly property var stats: {
        const ready = SysInfo.available;
        const cpu = ready ? `${Math.round(SysInfo.cpuPerc)}` : "--";
        const gib = SysInfo.memTotal > 0 ? (SysInfo.memUsed / (1024 * 1024 * 1024)).toFixed(1) : "";
        return [
            {
                "glyph": "memory",
                "label": "cpu",
                "stacked": cpu,
                "inline": ready ? `${cpu}%` : cpu
            },
            {
                "glyph": "database",
                "label": "ram",
                "stacked": gib || "--",
                "inline": gib ? `${gib}G` : "--"
            }
        ];
    }

    readonly property int updates: Updates.shown ? Updates.count : 0

    implicitWidth: root.bar.vertical ? stack.implicitWidth : chip.implicitWidth
    implicitHeight: root.bar.vertical ? stack.implicitHeight : chip.implicitHeight

    BarFlow {
        id: stack

        visible: root.bar.vertical
        anchors.centerIn: parent
        vertical: true
        gap: Appearance.space.sm

        Repeater {
            model: root.stats

            BarFlow {
                id: entry

                required property var modelData

                Layout.alignment: Qt.AlignHCenter
                vertical: true
                gap: Appearance.bar.statGap

                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    text: entry.modelData.glyph
                    size: Appearance.size.iconSm
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: entry.modelData.stacked
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.bar.statSize
                    color: Colours.outline
                }
            }
        }

        BarFlow {
            visible: root.updates > 0
            Layout.alignment: Qt.AlignHCenter
            vertical: true
            gap: Appearance.bar.statGap

            Icon {
                Layout.alignment: Qt.AlignHCenter
                text: "download"
                size: Appearance.size.iconSm
                color: Colours.primary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.updates
                font.family: Appearance.font.mono
                font.pixelSize: Appearance.bar.statSize
                color: Colours.primary
            }
        }
    }

    BarChip {
        id: chip

        visible: !root.bar.vertical
        anchors.verticalCenter: parent.verticalCenter
        padLead: Appearance.bar.chipPadTrail
        padTrail: Appearance.bar.chipPadTrail
        gap: Appearance.bar.statGapH
        interactive: true

        onClicked: root.bar.dashboardOn("system")

        Repeater {
            model: root.stats

            BarFlow {
                id: pair

                required property var modelData

                Layout.alignment: Qt.AlignVCenter
                gap: Appearance.space.xs

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: pair.modelData.label
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.size.caption
                    color: Colours.outline
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: pair.modelData.inline
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.size.caption
                    color: Colours.on.surfaceVariant
                }
            }
        }

        BarFlow {
            visible: root.updates > 0
            Layout.alignment: Qt.AlignVCenter
            gap: Appearance.space.xs

            Icon {
                Layout.alignment: Qt.AlignVCenter
                text: "download"
                size: Appearance.size.iconSm
                color: Colours.primary
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.updates
                font.family: Appearance.font.mono
                font.pixelSize: Appearance.size.caption
                color: Colours.primary
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.bar.vertical
        cursorShape: Qt.PointingHandCursor
        onClicked: root.bar.dashboardOn("system")
    }
}
