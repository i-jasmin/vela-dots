pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.tokens
import qs.services
import qs.components

// System: how busy the machine is, right now and over the last minute.
//
// Three live rings (CPU, memory, GPU), the CPU's last sixty seconds, and the
// busiest processes. While this tab is shown SysInfo samples every second
// (its fast mode); nothing pays for that when it is not.
// Top layout: rings in a row, history beside busiest. Side: rings in a row of
// three, the rest stacked.
Item {
    id: root

    required property bool side
    required property bool live

    // The AI tools' numbers are looked at more often while they are shown,
    // as the machine's are.
    readonly property bool holding: root.live
    onHoldingChanged: {
        root.holding ? SysInfo.holdFast() : SysInfo.releaseFast();
        root.holding ? AiUsage.hold() : AiUsage.release();
    }
    Component.onCompleted: if (root.holding) {
        SysInfo.holdFast();
        AiUsage.hold();
    }
    Component.onDestruction: if (root.holding) {
        SysInfo.releaseFast();
        AiUsage.release();
    }

    function gb(bytes: real): string {
        return (bytes / 1073741824).toFixed(1);
    }

    readonly property var rings: [
        {
            label: qsTr("CPU"),
            value: SysInfo.cpuPerc,
            ready: SysInfo.available,
            colour: Colours.primary,
            sub: [SysInfo.cpuGhz > 0 ? qsTr("%1 GHz").arg(SysInfo.cpuGhz.toFixed(1)) : "", SysInfo.cpuTemp > 0 ? `${Math.round(SysInfo.cpuTemp)} °C` : ""].filter(s => s).join(" · "),
            subSide: SysInfo.cpuTemp > 0 ? `${Math.round(SysInfo.cpuTemp)} °C` : ""
        },
        {
            label: qsTr("Memory"),
            value: SysInfo.memPerc,
            ready: SysInfo.memTotal > 0,
            colour: Colours.secondary,
            sub: qsTr("%1 of %2 GB").arg(root.gb(SysInfo.memUsed)).arg(root.gb(SysInfo.memTotal)),
            subSide: `${root.gb(SysInfo.memUsed)} / ${root.gb(SysInfo.memTotal)} GB`
        },
        {
            label: qsTr("GPU"),
            value: SysInfo.gpuPerc,
            ready: SysInfo.gpuAvailable && SysInfo.available,
            colour: Colours.tertiary,
            sub: SysInfo.gpuAvailable ? SysInfo.gpuName : qsTr("not measured"),
            subSide: SysInfo.gpuAvailable ? SysInfo.gpuName : qsTr("n/a")
        }
    ]

    // Sixty one-second bars, padded at the front: a second not yet measured
    // is drawn as the floor, next to the ones that were.
    readonly property var history: {
        const src = SysInfo.cpuRecent;
        const n = SysInfo.historyLength;
        const out = [];
        for (let i = src.length; i < n; i++)
            out.push(-1);
        return out.concat(src.slice(-n));
    }

    readonly property real procScale: Math.max(Appearance.dashboard.procFull, ...SysInfo.busiest.map(p => p.perc))

    // ---- pieces --------------------------------------------------------------
    component Meter: Ring {
        id: meter

        property var spec
        property real valueSize: Appearance.dashboard.ringValueTop
        property real unitSize: Appearance.dashboard.ringUnitTop

        value: meter.spec.ready ? meter.spec.value / 100 : 0
        fill: meter.spec.colour
        capStyle: ShapePath.RoundCap
        valueDuration: Appearance.dashboard.ringValueMs
        valueCurve: Appearance.dashboard.curve

        RowLayout {
            anchors.centerIn: parent
            spacing: Appearance.dashboard.unitGap

            Text {
                text: meter.spec.ready ? Math.round(meter.spec.value) : "--"
                font.family: Appearance.font.mono
                font.pixelSize: meter.valueSize
                color: Colours.on.surface
                Layout.alignment: Qt.AlignBaseline
            }

            Text {
                visible: meter.spec.ready
                text: "%"
                font.family: Appearance.font.mono
                font.pixelSize: meter.unitSize
                color: Colours.outline
                Layout.alignment: Qt.AlignBaseline
            }
        }
    }

    component Tile: Rectangle {
        radius: Appearance.dashboard.cardRadius
        color: Colours.surfaceContainer
    }

    component History: Tile {
        implicitHeight: historyColumn.implicitHeight + Appearance.dashboard.cardPadV * 2

        ColumnLayout {
            id: historyColumn

            anchors.fill: parent
            anchors.topMargin: Appearance.dashboard.cardPadV
            anchors.bottomMargin: Appearance.dashboard.cardPadV
            anchors.leftMargin: Appearance.dashboard.cardPadH
            anchors.rightMargin: Appearance.dashboard.cardPadH
            spacing: Appearance.dashboard.cardGap

            RowLayout {
                Layout.fillWidth: true

                SectionLabel {
                    text: qsTr("CPU · last 60 s")
                    font.pixelSize: Appearance.dashboard.sectionLabel
                    Layout.fillWidth: true
                }

                Text {
                    text: root.side ? qsTr("load %1 %2").arg(SysInfo.loadAvg1.toFixed(2)).arg(SysInfo.loadAvg5.toFixed(2)) : qsTr("load %1 %2 %3").arg(SysInfo.loadAvg1.toFixed(2)).arg(SysInfo.loadAvg5.toFixed(2)).arg(SysInfo.loadAvg15.toFixed(2))
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.dashboard.eventLabel
                    color: Colours.outline
                }
            }

            Item {
                id: bars

                implicitHeight: Appearance.dashboard.historyHeight
                Layout.fillWidth: true

                readonly property real step: (bars.width + Appearance.dashboard.historyGap) / root.history.length

                Repeater {
                    model: root.history.length

                    Rectangle {
                        required property int index

                        readonly property real v: root.history[index] ?? -1
                        readonly property bool newest: index === root.history.length - 1

                        x: index * bars.step
                        width: bars.step - Appearance.dashboard.historyGap
                        height: Math.max(Appearance.dashboard.historyFloor, Math.min(1, Math.max(0, v) / 100)) * bars.height
                        y: bars.height - height
                        radius: Appearance.dashboard.historyRadius
                        color: Colours.primary
                        opacity: newest ? 1 : Appearance.dashboard.historyOldest + (Appearance.dashboard.historyNewest - Appearance.dashboard.historyOldest) * index / (root.history.length - 1)

                        Behavior on height {
                            enabled: !Appearance.reduceMotion
                            NumberAnimation {
                                duration: Appearance.dashboard.historyMove
                            }
                        }
                    }
                }
            }
        }
    }

    component Busiest: Tile {
        implicitHeight: busiestColumn.implicitHeight + Appearance.dashboard.cardPadV * 2

        ColumnLayout {
            id: busiestColumn

            anchors.fill: parent
            anchors.topMargin: Appearance.dashboard.cardPadV
            anchors.bottomMargin: Appearance.dashboard.cardPadV
            anchors.leftMargin: Appearance.dashboard.cardPadH
            anchors.rightMargin: Appearance.dashboard.cardPadH
            spacing: Appearance.dashboard.cardGap

            SectionLabel {
                text: qsTr("Busiest")
                font.pixelSize: Appearance.dashboard.sectionLabel
                Layout.fillWidth: true
            }

            Text {
                visible: SysInfo.busiest.length === 0
                text: qsTr("Measuring…")
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.dashboard.toggleNote
                color: Colours.outline
            }

            Repeater {
                model: SysInfo.busiest

                RowLayout {
                    id: proc

                    required property var modelData

                    spacing: Appearance.dashboard.cardGap
                    Layout.fillWidth: true

                    Text {
                        text: proc.modelData.name
                        font.family: Appearance.font.mono
                        font.pixelSize: Appearance.dashboard.procName
                        color: Colours.on.surface
                        elide: Text.ElideRight
                        Layout.preferredWidth: root.side ? Appearance.dashboard.procNameSide : Appearance.dashboard.procNameTop
                    }

                    Rectangle {
                        implicitHeight: Appearance.dashboard.procBar
                        radius: height / 2
                        color: Colours.track
                        Layout.fillWidth: true

                        Rectangle {
                            width: parent.width * Math.min(1, proc.modelData.perc / root.procScale)
                            height: parent.height
                            radius: height / 2
                            color: Colours.secondary

                            Behavior on width {
                                enabled: !Appearance.reduceMotion
                                NumberAnimation {
                                    duration: Appearance.dashboard.procMove
                                }
                            }
                        }
                    }

                    Text {
                        text: `${Math.round(proc.modelData.perc)}%`
                        horizontalAlignment: Text.AlignRight
                        font.family: Appearance.font.mono
                        font.pixelSize: Appearance.dashboard.hourValue
                        color: Colours.outline
                        Layout.preferredWidth: Appearance.dashboard.procValue
                    }
                }
            }
        }
    }

    // ---- top -----------------------------------------------------------------
    Component {
        id: topLayout

        ColumnLayout {
            spacing: Appearance.dashboard.gap

            RowLayout {
                spacing: Appearance.dashboard.gap
                Layout.fillWidth: true

                Repeater {
                    model: root.rings

                    Tile {
                        id: ringCard

                        required property var modelData

                        implicitHeight: Appearance.dashboard.ringTop + Appearance.dashboard.ringPad * 2
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Appearance.dashboard.ringPad
                            spacing: Appearance.dashboard.ringGap

                            Meter {
                                spec: ringCard.modelData
                                diameter: Appearance.dashboard.ringTop
                                thickness: Appearance.dashboard.ringStrokeTop
                            }

                            ColumnLayout {
                                spacing: Appearance.dashboard.subGap
                                Layout.fillWidth: true

                                Text {
                                    text: ringCard.modelData.label
                                    font.family: Appearance.font.ui
                                    font.pixelSize: Appearance.dashboard.ringLabelTop
                                    color: Colours.on.surface
                                }

                                Text {
                                    text: ringCard.modelData.sub
                                    font.family: Appearance.font.mono
                                    font.pixelSize: Appearance.dashboard.hourValue
                                    color: Colours.outline
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                spacing: Appearance.dashboard.gap
                Layout.fillWidth: true

                History {
                    Layout.fillWidth: true
                    Layout.preferredWidth: Appearance.dashboard.historyShare
                    Layout.alignment: Qt.AlignTop
                }

                Busiest {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                }
            }

            AiCards {
                side: false
                Layout.fillWidth: true
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    // ---- side ----------------------------------------------------------------
    Component {
        id: sideLayout

        ColumnLayout {
            spacing: Appearance.dashboard.gap

            RowLayout {
                spacing: Appearance.dashboard.gap
                Layout.fillWidth: true

                Repeater {
                    model: root.rings

                    Tile {
                        id: sideRing

                        required property var modelData

                        implicitHeight: sideColumn.implicitHeight + Appearance.dashboard.ringPad * 2
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1

                        ColumnLayout {
                            id: sideColumn

                            anchors.fill: parent
                            anchors.topMargin: Appearance.dashboard.ringPad
                            anchors.bottomMargin: Appearance.dashboard.ringPad
                            anchors.leftMargin: Appearance.dashboard.ringPadSide
                            anchors.rightMargin: Appearance.dashboard.ringPadSide
                            spacing: Appearance.dashboard.gap

                            Meter {
                                spec: sideRing.modelData
                                diameter: Appearance.dashboard.ringSide
                                thickness: Appearance.dashboard.ringStrokeSide
                                valueSize: Appearance.dashboard.ringValueSide
                                unitSize: Appearance.dashboard.ringUnitSide
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: sideRing.modelData.label
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.dashboard.ringLabelSide
                                color: Colours.on.surface
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: sideRing.modelData.subSide
                                font.family: Appearance.font.mono
                                font.pixelSize: Appearance.dashboard.hourLabel
                                color: Colours.outline
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            History {
                Layout.fillWidth: true
            }

            Busiest {
                Layout.fillWidth: true
            }

            AiCards {
                side: true
                Layout.fillWidth: true
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    Loader {
        anchors.fill: parent
        anchors.leftMargin: root.side ? Appearance.dashboard.padSide : Appearance.dashboard.padTop
        anchors.rightMargin: root.side ? Appearance.dashboard.padSide : Appearance.dashboard.padTop
        sourceComponent: root.side ? sideLayout : topLayout
    }
}
