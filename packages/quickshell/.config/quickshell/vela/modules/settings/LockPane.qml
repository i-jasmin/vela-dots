pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.tokens
import qs.components

// Lock screen -- when it locks by itself, what it shows around the password
// field, and whether it offers the fingerprint reader. The display controls
// write `Config.lock.*`, which `modules/lock` reads when it draws, so the next
// lock shows the change. The timeouts are not in shell.json at all: they are
// hypridle's, and `services/Hypridle.qml` reads and writes them in hypridle's
// own file.
//
// A laptop has two sets of timeouts, one for on power and one for on battery,
// and a pair of tabs over the sliders picks which set they show -- the
// dashboard's tab strip, a size down. A desktop is always on power, has one
// set, and no tabs.
PaneScroll {
    id: root

    // The places a timeout slider stops, in seconds idle, with "never" at the
    // far end. A value set by hand that is not one of them still reads true
    // beside the slider; the handle sits at the nearest stop.
    readonly property var stops: [30, 60, 90, 120, 150, 180, 240, 300, 330, 360, 420, 480, 600, 900, 1200, 1800, 2700, 3600, 0]

    function stopOf(seconds: int): int {
        if (seconds <= 0)
            return root.stops.length - 1;
        let best = 0;
        for (let i = 0; i < root.stops.length - 1; i++)
            if (Math.abs(root.stops[i] - seconds) < Math.abs(root.stops[best] - seconds))
                best = i;
        return best;
    }

    // "30 s", "2.5 min", "1 h", "Never".
    function duration(seconds: int): string {
        if (seconds <= 0)
            return qsTr("Never");
        if (seconds < 60)
            return qsTr("%1 s").arg(seconds);
        if (seconds < 3600)
            return qsTr("%1 min").arg(+(seconds / 60).toFixed(1));
        return qsTr("%1 h").arg(+(seconds / 3600).toFixed(1));
    }

    // The lock screen draws its stats in this order; one switched back on
    // returns to its place rather than joining the end.
    readonly property var statOrder: ["weather", "events", "unread", "battery"]

    // Which set of timeouts the sliders show. The page opens on the one in
    // force, and stays where it was put if the power cord comes or goes
    // while it is open.
    property string idleSource: "power"
    // Just switched: the handles glide to the other set's places rather than
    // jump -- and only then, as a drag has to stay under the pointer.
    property bool idleSwitching: false

    function showIdle(source: string): void {
        if (source === root.idleSource)
            return;
        root.idleSwitching = true;
        root.idleSource = source;
        switched.restart();
    }

    Timer {
        id: switched

        interval: Appearance.anim.normal
        onTriggered: root.idleSwitching = false
    }

    // When the page is made, and each time the settings window opens on it
    // again -- the window keeps its page: hypridle may have been started or
    // stopped since the shell last looked, and the laptop plugged in or not.
    function refresh(): void {
        Hypridle.check();
        root.idleSource = Hypridle.source;
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: ShellState

        function onSettingsChanged(): void {
            if (ShellState.settings)
                root.refresh();
        }
    }

    function setStat(name: string, on: bool): void {
        const now = Config.lock.showStats;
        Config.lock.showStats = root.statOrder.filter(s => s === name ? on : now.includes(s));
        Persist.commit();
    }

    PaneHeader {
        title: qsTr("Lock screen")

        Pill {
            text: qsTr("Apply")
            tone: "filled"
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize
            onClicked: Persist.now()
        }
    }

    Section {
        title: qsTr("When you step away")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        // Why the sliders are missing or will not take effect yet.
        SettingRow {
            visible: !Hypridle.available || !Hypridle.running
            title: !Hypridle.available ? qsTr("hypridle.conf has no timeouts block") : qsTr("hypridle is not running")
            subtitle: !Hypridle.available ? qsTr("Put back the lines between # vela: timeouts begin and end in ~/.config/hypr/hypridle.conf") : qsTr("These are saved, and apply when it starts — Hyprland starts it at login")
        }

        // On a laptop: which set the sliders are for, and which is in force.
        RowLayout {
            visible: Power.available
            enabled: Hypridle.available
            opacity: enabled ? 1 : Appearance.dashboard.disabledOpacity
            spacing: Appearance.settings.rowGap

            Layout.fillWidth: true

            Segmented {
                // Re-asserted, as on the dashboard: a click writes the rail's
                // own index, which would undo a plain binding.
                readonly property int wanted: root.idleSource === "battery" ? 1 : 0

                sliding: true
                model: [
                    {
                        label: qsTr("On power"),
                        icon: "power"
                    },
                    {
                        label: qsTr("On battery"),
                        icon: "battery_full"
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

                onSelected: index => root.showIdle(index === 1 ? "battery" : "power")

                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: Hypridle.source === "battery" ? qsTr("Running on battery now") : qsTr("Plugged in now")
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.label
                color: Colours.outline
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Repeater {
            model: [
                {
                    key: "dim",
                    title: qsTr("Dim the screen"),
                    subtitle: qsTr("Backlight to 10%, as a warning")
                },
                {
                    key: "lock",
                    title: qsTr("Lock"),
                    subtitle: qsTr("The same lock as super + L")
                },
                {
                    key: "screenOff",
                    title: qsTr("Turn the screen off"),
                    subtitle: qsTr("Any key or the mouse wakes it")
                },
                {
                    key: "suspend",
                    title: qsTr("Suspend"),
                    subtitle: qsTr("Locked first, so it wakes locked")
                }
            ]

            SettingRow {
                id: timeout

                required property var modelData

                readonly property int seconds: Hypridle[root.idleSource][timeout.modelData.key]
                readonly property int lockAt: Hypridle[root.idleSource].lock

                enabled: Hypridle.available
                opacity: enabled ? 1 : Appearance.dashboard.disabledOpacity
                title: timeout.modelData.title
                // The one order that goes wrong without saying so: the panel
                // going dark before the lock is up shows the desktop on wake.
                subtitle: timeout.modelData.key === "screenOff" && timeout.seconds > 0 && timeout.lockAt > 0 && timeout.seconds < timeout.lockAt ? qsTr("Before it locks — the desktop shows on wake") : timeout.modelData.subtitle
                labelWidth: Appearance.settings.labelWidthNarrow

                SettingSlider {
                    readonly property int span: root.stops.length - 1
                    readonly property real wanted: root.stopOf(timeout.seconds) / span

                    value: wanted
                    stepSize: 1 / span
                    onWantedChanged: value = wanted
                    onMoved: v => Hypridle.set(root.idleSource, timeout.modelData.key, root.stops[Math.round(v * span)])

                    Behavior on value {
                        enabled: root.idleSwitching

                        NumberAnimation {
                            duration: Appearance.anim.normal
                            easing.type: Appearance.anim.enterEasing
                        }
                    }
                }

                SettingValue {
                    text: root.duration(timeout.seconds)

                    Layout.preferredWidth: Appearance.settings.valueWidthNarrow
                }
            }
        }
    }

    Section {
        title: qsTr("What it shows")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        Repeater {
            model: [
                {
                    key: "weather",
                    title: qsTr("Weather"),
                    subtitle: qsTr("Now, from the location on the General page")
                },
                {
                    key: "events",
                    title: qsTr("Next event"),
                    subtitle: qsTr("From your calendar")
                },
                {
                    key: "unread",
                    title: qsTr("Unread notifications"),
                    subtitle: qsTr("A count, never what they say")
                },
                {
                    key: "battery",
                    title: qsTr("Battery"),
                    subtitle: qsTr("Charge, on a machine that has one")
                }
            ]

            SettingRow {
                id: stat

                required property var modelData

                title: stat.modelData.title
                subtitle: stat.modelData.subtitle

                Toggle {
                    readonly property bool wanted: Config.lock.showStats.includes(stat.modelData.key)

                    checked: wanted
                    onWantedChanged: checked = wanted
                    onToggled: on => root.setStat(stat.modelData.key, on)

                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        SettingRow {
            title: qsTr("What is playing")
            subtitle: qsTr("The track and its controls, while something plays")

            Toggle {
                readonly property bool wanted: Config.lock.showMedia

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.lock.showMedia = on;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("Ring that moves with the music")
            subtitle: qsTr("The arc round the clock turns while something plays, faster and brighter as the music gets louder")

            Toggle {
                readonly property bool wanted: Config.lock.audioReactiveArc

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.lock.audioReactiveArc = on;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    Section {
        title: qsTr("Unlocking")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("Offer the fingerprint reader")
            subtitle: qsTr("Shown when the system's login asks for a finger (fprintd); the password always works")

            Toggle {
                readonly property bool wanted: Config.lock.fingerprint

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.lock.fingerprint = on;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
