pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.tokens
import qs.components

// Notifications -- where the cards appear, how long they stay, how many stack,
// and the digest a focus session collects them into. Every control writes
// `Config.notifications.*`, which `services/Notifs.qml` and the popup window
// read directly, so a change moves the next card (or the ones on screen).
//
// Do not disturb is the one control here that is not a setting: it is the
// service's live state, the same switch the keybind and `vela` flip, and it
// does not survive a restart.
PaneScroll {
    id: root

    readonly property var intervals: [15, 30, 60, 120]

    // "top-right" and friends. Centred is the bare edge -- "top", "bottom" --
    // which is how the popup window reads it.
    readonly property string edge: Config.notifications.position.startsWith("bottom") ? "bottom" : "top"
    readonly property string side: Config.notifications.position.endsWith("left") ? "left" : Config.notifications.position.endsWith("right") ? "right" : "centre"

    function setPosition(edge: string, side: string): void {
        Config.notifications.position = side === "centre" ? edge : `${edge}-${side}`;
        Persist.commit();
    }

    PaneHeader {
        title: qsTr("Notifications")

        Pill {
            text: qsTr("Apply")
            tone: "filled"
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize
            onClicked: Persist.now()
        }
    }

    Section {
        title: qsTr("Right now")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("Do not disturb")
            subtitle: Notifs.doNotDisturb ? (Config.notifications.urgentBypassesFocus ? qsTr("Only urgent ones pop up; everything still lands in the history") : qsTr("Nothing pops up; everything still lands in the history")) : qsTr("Cards pop up as they arrive")

            Toggle {
                readonly property bool wanted: Notifs.doNotDisturb

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => Notifs.doNotDisturb = on

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: Notifs.list.length === 1 ? qsTr("1 notification kept") : qsTr("%1 notifications kept").arg(Notifs.list.length)
            subtitle: qsTr("The newest %1 stay in the history until you clear them").arg(Notifs.maxHistory)

            Pill {
                text: qsTr("Clear all")
                tone: "subtle"
                interactive: Notifs.list.length > 0
                pillHeight: Appearance.settings.segmentHeight
                fontSize: Appearance.settings.actionSize
                onClicked: Notifs.clear()

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    Section {
        title: qsTr("Cards")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("Position")
            subtitle: qsTr("Which corner, or the middle of an edge")
            Segmented {
                readonly property int wanted: root.edge === "bottom" ? 1 : 0

                model: [qsTr("Top"), qsTr("Bottom")]
                currentIndex: wanted
                segmentHeight: Appearance.settings.segmentHeight
                hPadding: Appearance.settings.segmentPad
                railRadius: Appearance.radius.card
                onWantedChanged: currentIndex = wanted
                onSelected: i => root.setPosition(i === 1 ? "bottom" : "top", root.side)

                Layout.alignment: Qt.AlignVCenter
            }

            Segmented {
                readonly property var sides: ["left", "centre", "right"]
                readonly property int wanted: sides.indexOf(root.side)

                model: [qsTr("Left"), qsTr("Centre"), qsTr("Right")]
                currentIndex: wanted
                segmentHeight: Appearance.settings.segmentHeight
                hPadding: Appearance.settings.segmentPad
                railRadius: Appearance.radius.card
                onWantedChanged: currentIndex = wanted
                onSelected: i => root.setPosition(root.edge, sides[i])

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("Stay on screen")
            subtitle: qsTr("Urgent ones stay until dealt with")
            labelWidth: Appearance.settings.labelWidthNarrow

            Slider {
                readonly property int span: Appearance.settings.timeoutMax - Appearance.settings.timeoutMin
                readonly property real wanted: (Config.notifications.timeout - Appearance.settings.timeoutMin) / span

                value: wanted
                handleWidth: Appearance.settings.sliderHandle
                handleHeight: Appearance.settings.sliderHandle
                stepSize: Appearance.settings.timeoutStep / span
                onWantedChanged: value = wanted
                onMoved: v => {
                    const step = Appearance.settings.timeoutStep;
                    Config.notifications.timeout = Appearance.settings.timeoutMin + Math.round(v * span / step) * step;
                    Persist.commit();
                }

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            SettingValue {
                text: qsTr("%1 s").arg(Math.round(Config.notifications.timeout / 1000))

                Layout.preferredWidth: Appearance.settings.valueWidthNarrow
            }
        }

        SettingRow {
            title: qsTr("At most")
            subtitle: qsTr("Cards at once; each app is one card")
            labelWidth: Appearance.settings.labelWidthNarrow

            Slider {
                readonly property int span: Appearance.settings.maxVisibleMax - 1
                readonly property real wanted: (Config.notifications.maxVisible - 1) / span

                value: wanted
                handleWidth: Appearance.settings.sliderHandle
                handleHeight: Appearance.settings.sliderHandle
                stepSize: 1 / span
                onWantedChanged: value = wanted
                onMoved: v => {
                    Config.notifications.maxVisible = 1 + Math.round(v * span);
                    Persist.commit();
                }

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            SettingValue {
                text: `${Config.notifications.maxVisible}`

                Layout.preferredWidth: Appearance.settings.valueWidthNarrow
            }
        }
    }

    Section {
        title: qsTr("Focus and the digest")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("Collect them into a digest")
            subtitle: qsTr("While a focus session holds notifications, they wait for one card instead of popping up")

            Toggle {
                readonly property bool wanted: Config.notifications.digest.enabled

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.notifications.digest.enabled = on;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            enabled: Config.notifications.digest.enabled
            opacity: enabled ? 1 : Appearance.dashboard.disabledOpacity
            title: qsTr("Deliver it every")
            subtitle: qsTr("And when the session ends, whichever comes first")
            Segmented {
                readonly property int wanted: Math.max(0, root.intervals.indexOf(Config.notifications.digest.intervalMinutes))

                model: [qsTr("15 min"), qsTr("30 min"), qsTr("1 hour"), qsTr("2 hours")]
                currentIndex: wanted
                segmentHeight: Appearance.settings.segmentHeight
                hPadding: Appearance.settings.segmentPad
                railRadius: Appearance.radius.card
                onWantedChanged: currentIndex = wanted
                onSelected: i => {
                    Config.notifications.digest.intervalMinutes = root.intervals[i];
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("Urgent ones get through")
            subtitle: qsTr("A critical one — a battery about to run out — pops up even under do not disturb or while focus holds the rest")

            Toggle {
                readonly property bool wanted: Config.notifications.urgentBypassesFocus

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.notifications.urgentBypassesFocus = on;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
