pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.tokens
import qs.components

// Settings, Bar. Which edge the bar takes, when it gets out of the way, and
// whether there is a dock on the opposite edge.
//
// Every control here writes `Config.bar.*` or `Config.dock.*`, which the bar
// reads directly: `modules/bar/Bar.qml` anchors itself from
// `Config.bar.position`, reserves or ignores its exclusive zone from
// `Config.bar.autohide.mode`, and times its reveal from `.revealDelay`. So
// choosing a different monitor diagram moves the real bar on the next frame,
// with nothing in between.
//
// `bar.floating` is the design's `bar.float` renamed: QML reserves `float` as
// a type name and a property cannot be called it.
//
// In a PaneScroll, like the other long pages: with the Style row and the dock
// it is taller than the window.
PaneScroll {
    id: root

    readonly property var edges: ["top", "left", "right", "bottom"]
    readonly property var edgeLabels: [qsTr("Top"), qsTr("Left"), qsTr("Right"), qsTr("Bottom")]
    readonly property var hideModes: ["never", "when-window-overlaps", "always"]
    readonly property var dockModes: ["always", "autohide", "overview-only"]

    function setPosition(i: int): void {
        Config.bar.position = root.edges[i];
        Persist.commit();
    }

    // The design's defaults, which is what "Reset" restores. They are the same
    // values `config/Config.qml` declares, written here as the set this pane is
    // answerable for rather than read back out of the adapter -- the adapter no
    // longer knows what its defaults were once a file has overridden them.
    function reset(): void {
        Config.bar.position = "left";
        Config.bar.floating = true;
        Config.bar.autohide.mode = "when-window-overlaps";
        Config.bar.autohide.revealDelay = Appearance.bar.revealDelay;
        Config.bar.autohide.keepOnFocusedMonitor = false;
        Config.dock.enabled = true;
        Config.dock.behaviour = "autohide";
        Persist.now();
    }

    PaneHeader {
        title: qsTr("Bar")

        ResetPill {
            id: resetting

            question: qsTr("Put the bar and dock back to their defaults?")
            onConfirmed: root.reset()
        }

        Pill {
            visible: !resetting.asking
            text: qsTr("Apply")
            tone: "filled"
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize
            // Every control on this screen has already moved the bar; this puts
            // the file behind them on disk now rather than a quarter of a
            // second from now.
            onClicked: Persist.now()
        }
    }

    Section {
        title: qsTr("Position")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        RowLayout {
            spacing: Appearance.settings.monitorGap

            Layout.fillWidth: true

            Repeater {
                id: diagrams

                model: root.edges

                MonitorDiagram {
                    id: diagram

                    required property int index
                    required property string modelData

                    edge: diagram.modelData
                    label: root.edgeLabels[diagram.index]
                    selected: Config.bar.position === diagram.modelData
                    flush: !Config.bar.floating

                    Layout.fillWidth: true

                    onChosen: root.setPosition(diagram.index)
                    onMove: by => {
                        const next = Math.max(0, Math.min(root.edges.length - 1, diagram.index + by));
                        root.setPosition(next);
                        const item = diagrams.itemAt(next);
                        if (item)
                            item.forceActiveFocus();
                    }
                }
            }
        }

        Text {
            text: qsTr("Horizontal edges run the clock and tray inline; vertical edges stack them and move the window title into the workspace popout.")
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.label
            color: Colours.outline
            wrapMode: Text.WordWrap

            Layout.fillWidth: true
        }

        // Floating keeps the margin round the bar; attached puts it against
        // its edge, square there and rounded on the side facing in. The bar
        // moves between the two as this changes, like the diagrams above.
        SettingRow {
            title: qsTr("Style")
            subtitle: Config.bar.floating ? qsTr("A gap all round, every corner rounded") : qsTr("Against the edge, rounded on the inside")
            labelWidth: Appearance.settings.labelWidthNarrow

            Item {
                Layout.fillWidth: true
            }

            Segmented {
                // Re-asserted, as on the dashboard: a click writes the rail's
                // own index, which would undo a plain binding.
                readonly property int wanted: Config.bar.floating ? 0 : 1

                sliding: true
                model: [
                    {
                        label: qsTr("Floating"),
                        icon: "rounded_corner"
                    },
                    {
                        label: qsTr("Attached"),
                        // border_left, border_top, ...: the square's side the
                        // bar is on.
                        icon: "border_" + Config.bar.position
                    }
                ]
                currentIndex: wanted
                onWantedChanged: currentIndex = wanted
                segmentWidth: Appearance.settings.tabWidth
                segmentHeight: Appearance.settings.tabHeight
                inset: Appearance.settings.tabInset
                railRadius: Appearance.settings.tabRailRadius
                fontSize: Appearance.settings.tabLabel
                iconSize: Appearance.settings.tabIcon

                onSelected: index => {
                    Config.bar.floating = index === 0;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    Section {
        title: qsTr("Autohide")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("Hide the bar")
            subtitle: qsTr("Push the cursor to the edge to reveal")
            labelWidth: Appearance.settings.labelWidthNarrow

            Item {
                Layout.fillWidth: true
            }

            Segmented {
                // See AppearancePane's header for why the value is re-asserted
                // rather than only bound: the control is a view of a file, and
                // the file can move without it.
                readonly property int wanted: Math.max(0, root.hideModes.indexOf(Config.bar.autohide.mode))

                model: [qsTr("Never"), qsTr("When a window overlaps"), qsTr("Always")]
                currentIndex: wanted
                segmentHeight: Appearance.settings.segmentHeight
                hPadding: Appearance.settings.segmentPad
                railRadius: Appearance.radius.card
                onWantedChanged: currentIndex = wanted
                onSelected: i => {
                    Config.bar.autohide.mode = root.hideModes[i];
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("Reveal delay")
            subtitle: qsTr("Stops accidental pops")
            labelWidth: Appearance.settings.labelWidthNarrow

            SettingSlider {
                readonly property real wanted: Config.bar.autohide.revealDelay / Appearance.settings.revealMax

                value: wanted
                stepSize: Appearance.settings.revealStep / Appearance.settings.revealMax
                onWantedChanged: value = wanted
                onMoved: v => {
                    const step = Appearance.settings.revealStep;
                    Config.bar.autohide.revealDelay = Math.round(v * Appearance.settings.revealMax / step) * step;
                    Persist.commit();
                }
            }

            SettingValue {
                text: qsTr("%1 ms").arg(Config.bar.autohide.revealDelay)

                Layout.preferredWidth: Appearance.settings.valueWidthNarrow
            }
        }

        SettingRow {
            title: qsTr("Keep visible on the focused monitor")
            subtitle: qsTr("Others hide until you move there")

            Toggle {
                readonly property bool wanted: Config.bar.autohide.keepOnFocusedMonitor

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.bar.autohide.keepOnFocusedMonitor = on;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    Section {
        title: qsTr("Dock · optional")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("Show a dock")
            subtitle: qsTr("Pinned apps on the opposite edge to the bar")

            Toggle {
                readonly property bool wanted: Config.dock.enabled

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.dock.enabled = on;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("Pinned & stacks")
            subtitle: qsTr("Any folder can be a stack")
            labelWidth: Appearance.settings.labelWidthNarrow
            gap: Appearance.space.lg

            DockItems {
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: qsTr("drag to reorder")
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.settings.hintSize
                color: Colours.outline

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("Dock behaviour")
            subtitle: qsTr("Slides out under the cursor")
            labelWidth: Appearance.settings.labelWidthNarrow

            Item {
                Layout.fillWidth: true
            }

            Segmented {
                readonly property int wanted: Math.max(0, root.dockModes.indexOf(Config.dock.behaviour))

                model: [qsTr("Always shown"), qsTr("Autohide"), qsTr("Only in overview")]
                currentIndex: wanted
                segmentHeight: Appearance.settings.segmentHeight
                hPadding: Appearance.settings.segmentPad
                railRadius: Appearance.radius.card
                onWantedChanged: currentIndex = wanted
                onSelected: i => {
                    Config.dock.behaviour = root.dockModes[i];
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
