pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.tokens
import qs.components

// Modules -- which items each end of the bar carries, and in what order. The
// three runs are `Config.bar.modules.left / centre / right`, which
// `modules/bar/BarContent.qml` lays out directly, so a chip moved here moves
// on the bar behind the window on the same frame.
//
// Each item is a chip. ‹ and › move it along; past the end of its run they
// carry it into the next one, so an item can travel the whole bar without a
// drag. × takes it off the bar, and "Add" offers what is not on it. A divider
// can appear any number of times; everything else once.
PaneScroll {
    id: root

    readonly property var ends: [
        {
            key: "left",
            label: qsTr("Left")
        },
        {
            key: "centre",
            label: qsTr("Centre")
        },
        {
            key: "right",
            label: qsTr("Right")
        }
    ]

    readonly property var info: ({
            launcher: {
                label: qsTr("Launcher"),
                icon: "apps"
            },
            workspaces: {
                label: qsTr("Workspaces"),
                icon: "grid_view"
            },
            divider: {
                label: qsTr("Divider"),
                icon: "more_vert"
            },
            activeWindow: {
                label: qsTr("Window title"),
                icon: "web_asset"
            },
            clock: {
                label: qsTr("Clock"),
                icon: "schedule"
            },
            media: {
                label: qsTr("Media"),
                icon: "music_note"
            },
            resources: {
                label: qsTr("CPU & memory"),
                icon: "memory"
            },
            tray: {
                label: qsTr("Tray & status"),
                icon: "wifi"
            },
            privacy: {
                label: qsTr("Mic, camera & screen in use"),
                icon: "privacy_tip"
            },
            battery: {
                label: qsTr("Battery"),
                icon: "battery_full"
            },
            power: {
                label: qsTr("Power"),
                icon: "power_settings_new"
            }
        })

    readonly property var placed: [...Config.bar.modules.left, ...Config.bar.modules.centre, ...Config.bar.modules.right]
    // What "Add" offers: everything not on the bar, and always a divider.
    readonly property var addable: Object.keys(root.info).filter(k => k === "divider" || !root.placed.includes(k))

    // Which run's "Add" list is open, if any.
    property string adding: ""

    function listOf(end: string): var {
        return [...Config.bar.modules[end]];
    }

    function write(end: string, list: var): void {
        Config.bar.modules[end] = list;
    }

    function move(endIndex: int, i: int, by: int): void {
        const end = root.ends[endIndex].key;
        const list = root.listOf(end);
        const j = i + by;
        if (j >= 0 && j < list.length) {
            [list[i], list[j]] = [list[j], list[i]];
            root.write(end, list);
        } else if (by < 0 && endIndex > 0) {
            // Off the front: onto the end of the run before.
            const prev = root.ends[endIndex - 1].key;
            const item = list.splice(i, 1)[0];
            root.write(end, list);
            root.write(prev, [...root.listOf(prev), item]);
        } else if (by > 0 && endIndex < root.ends.length - 1) {
            // Off the back: onto the front of the run after.
            const next = root.ends[endIndex + 1].key;
            const item = list.splice(i, 1)[0];
            root.write(end, list);
            root.write(next, [item, ...root.listOf(next)]);
        }
        Persist.commit();
    }

    function remove(end: string, i: int): void {
        const list = root.listOf(end);
        list.splice(i, 1);
        root.write(end, list);
        Persist.commit();
    }

    function add(end: string, name: string): void {
        root.write(end, [...root.listOf(end), name]);
        root.adding = "";
        Persist.commit();
    }

    // The arrangement the bar ships with, the same lists `config/Config.qml`
    // declares.
    function reset(): void {
        Config.bar.modules.left = ["launcher", "workspaces", "divider", "activeWindow"];
        Config.bar.modules.centre = ["clock"];
        Config.bar.modules.right = ["media", "resources", "privacy", "tray", "battery", "power"];
        root.adding = "";
        Persist.now();
    }

    PaneHeader {
        title: qsTr("Modules")

        Pill {
            text: qsTr("Reset")
            tone: "subtle"
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize
            onClicked: root.reset()
        }

        Pill {
            text: qsTr("Apply")
            tone: "filled"
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize
            onClicked: Persist.now()
        }
    }

    Section {
        title: qsTr("On the bar")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGap

        Repeater {
            model: root.ends

            ColumnLayout {
                id: run

                required property var modelData
                required property int index

                readonly property var items: Config.bar.modules[run.modelData.key]

                spacing: Appearance.settings.chipGap

                Layout.fillWidth: true

                RowLayout {
                    spacing: Appearance.space.md

                    Layout.fillWidth: true

                    Text {
                        text: run.modelData.label
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.settings.rowTitleSize
                        color: Colours.on.surface

                        Layout.preferredWidth: Appearance.settings.modulesLabel
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: Math.round((Appearance.settings.chipHeight - height) / 2)
                    }

                    Flow {
                        spacing: Appearance.settings.chipGap

                        Layout.fillWidth: true

                        Repeater {
                            model: run.items

                            Rectangle {
                                id: chip

                                required property string modelData
                                required property int index

                                readonly property var about: root.info[chip.modelData] ?? {
                                    label: chip.modelData,
                                    icon: "extension"
                                }
                                readonly property bool first: run.index === 0 && chip.index === 0
                                readonly property bool last: run.index === root.ends.length - 1 && chip.index === run.items.length - 1

                                implicitWidth: chipRow.implicitWidth + Appearance.settings.chipPad
                                implicitHeight: Appearance.settings.chipHeight
                                radius: Appearance.radius.chip
                                color: Colours.hover
                                border.width: 1
                                border.color: Colours.panelBorder

                                RowLayout {
                                    id: chipRow

                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Appearance.settings.chipPad
                                    spacing: Appearance.space.xs

                                    Icon {
                                        text: chip.about.icon
                                        size: Appearance.size.iconSm
                                        color: Colours.on.surfaceVariant

                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Text {
                                        text: chip.about.label
                                        font.family: Appearance.font.ui
                                        font.pixelSize: Appearance.size.label
                                        color: Colours.on.surface

                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.rightMargin: Appearance.space.xs
                                    }

                                    Pill {
                                        icon: "chevron_left"
                                        tone: "plain"
                                        interactive: !chip.first
                                        pillHeight: Appearance.settings.chipButton
                                        onClicked: root.move(run.index, chip.index, -1)
                                    }

                                    Pill {
                                        icon: "chevron_right"
                                        tone: "plain"
                                        interactive: !chip.last
                                        pillHeight: Appearance.settings.chipButton
                                        onClicked: root.move(run.index, chip.index, 1)
                                    }

                                    Pill {
                                        icon: "close"
                                        tone: "plain"
                                        pillHeight: Appearance.settings.chipButton
                                        onClicked: root.remove(run.modelData.key, chip.index)
                                    }
                                }
                            }
                        }

                        Pill {
                            text: qsTr("Add")
                            icon: root.adding === run.modelData.key ? "expand_less" : "add"
                            tone: "subtle"
                            pillHeight: Appearance.settings.chipHeight
                            fontSize: Appearance.size.label
                            onClicked: root.adding = root.adding === run.modelData.key ? "" : run.modelData.key
                        }
                    }
                }

                // What can go on this run, opened by its "Add".
                Flow {
                    visible: root.adding === run.modelData.key
                    spacing: Appearance.settings.chipGap

                    Layout.fillWidth: true
                    Layout.leftMargin: Appearance.settings.modulesLabel + Appearance.space.md

                    Repeater {
                        model: root.addable

                        Pill {
                            required property string modelData

                            text: root.info[modelData].label
                            icon: root.info[modelData].icon
                            tone: "accent"
                            pillHeight: Appearance.settings.chipHeight
                            fontSize: Appearance.size.label
                            onClicked: root.add(run.modelData.key, modelData)
                        }
                    }
                }
            }
        }

        Text {
            text: Config.bar.vertical ? qsTr("The bar is vertical now: a column has no centre, so the centre run sits just before the last item on the right.") : qsTr("On a vertical bar the centre run moves to just before the last item on the right, since a column has no centre.")
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.label
            color: Colours.outline
            wrapMode: Text.WordWrap

            Layout.fillWidth: true
        }
    }
}
