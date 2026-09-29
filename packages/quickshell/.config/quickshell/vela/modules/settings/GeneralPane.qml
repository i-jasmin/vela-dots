pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.tokens
import qs.components

// General -- the settings that belong to no one surface: where you are, the
// units you read, the evening warmth that follows your sunset, your picture,
// the folders the shell reads and writes, and what happens at login and after
// an update.
//
// Not in the design, which names seven pages and draws two. Everything here was
// already a key in shell.json with nowhere in the window to set it; the page is
// those keys, in the same parts the Appearance and Bar pages are built from,
// and every control writes `Config` directly (see AppearancePane's header for
// the `wanted` pattern each one follows).
PaneScroll {
    id: root

    readonly property var starts: ["sunset", "civil-dusk"]

    // The location is either "auto" -- wttr.in places you by your connection's
    // address -- or a city you name. Held here as well as in the file so that
    // choosing "A city" can open an empty field before anything is written.
    property bool cityMode: Config.weather.location !== "auto"

    function setLocation(text: string): void {
        Config.weather.location = text === "" ? "auto" : text;
        root.cityMode = text !== "";
        Persist.commit();
    }

    // A path as a person writes it: $HOME folded back to ~.
    function tilde(p: string): string {
        const home = Quickshell.env("HOME");
        return home && p.startsWith(home) ? "~" + p.slice(home.length) : p;
    }

    PaneHeader {
        title: qsTr("General")

        Pill {
            text: qsTr("Apply")
            tone: "filled"
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize
            onClicked: Persist.now()
        }
    }

    // ---- location --------------------------------------------------------
    Section {
        title: qsTr("Location")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("Where you are")
            subtitle: qsTr("For the weather, and the sunset evening warmth starts from")
            Segmented {
                readonly property int wanted: root.cityMode ? 1 : 0

                model: [qsTr("Automatic"), qsTr("A city")]
                currentIndex: wanted
                segmentHeight: Appearance.settings.segmentHeight
                hPadding: Appearance.settings.segmentPad
                railRadius: Appearance.radius.card
                onWantedChanged: currentIndex = wanted
                onSelected: i => {
                    if (i === 0) {
                        root.setLocation("");
                    } else {
                        root.cityMode = true;
                        // Once the row it sits in is showing.
                        Qt.callLater(() => city.edit());
                    }
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            visible: root.cityMode
            title: qsTr("City")
            subtitle: qsTr("Any place wttr.in knows: a city, a postcode, an airport code")
            SettingField {
                id: city

                wanted: Config.weather.location === "auto" ? "" : Config.weather.location
                placeholder: qsTr("e.g. Hamburg")
                onCommitted: text => root.setLocation(text)

                Layout.alignment: Qt.AlignVCenter
            }
        }

        // What the shell is actually using, because "Automatic" is only as good
        // as the address it guessed from -- a VPN puts you in another country.
        SettingRow {
            title: Weather.loading ? qsTr("Looking up…") : Weather.error !== "" && !Weather.available ? qsTr("No weather yet") : Weather.location !== "" ? [Weather.location, Weather.country].filter(s => s).join(", ") : qsTr("Not located yet")
            detail: Weather.latitude !== 0 || Weather.longitude !== 0 ? `${Weather.latitude.toFixed(2)}, ${Weather.longitude.toFixed(2)}` : ""
            subtitle: Weather.error !== "" ? Weather.error : root.cityMode ? qsTr("Showing the city you set") : qsTr("Guessed from your internet connection — a VPN moves it")
            labelGap: Appearance.settings.labelGap

            Pill {
                text: qsTr("Refresh")
                icon: "refresh"
                tone: "subtle"
                interactive: !Weather.loading
                pillHeight: Appearance.settings.segmentHeight
                fontSize: Appearance.settings.actionSize
                onClicked: Weather.refresh()

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("Units")
            subtitle: qsTr("Temperatures on the dashboard and the lock screen")
            Segmented {
                readonly property int wanted: Config.weather.units === "imperial" ? 1 : 0

                model: [qsTr("Metric · °C"), qsTr("Imperial · °F")]
                currentIndex: wanted
                segmentHeight: Appearance.settings.segmentHeight
                hPadding: Appearance.settings.segmentPad
                railRadius: Appearance.radius.card
                onWantedChanged: currentIndex = wanted
                onSelected: i => {
                    Config.weather.units = i === 1 ? "imperial" : "metric";
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // ---- evening warmth ------------------------------------------------------
    Section {
        title: qsTr("Evening warmth")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("Warm the colours in the evening")
            subtitle: Sun.available ? qsTr("Sunset today %1 · %2").arg(Qt.formatDateTime(Sun.sunset, "hh:mm")).arg(Sun.label) : qsTr("Needs a location to know when sunset is")

            Toggle {
                readonly property bool wanted: Config.appearance.eveningWarmth.enabled

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.appearance.eveningWarmth.enabled = on;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            enabled: Config.appearance.eveningWarmth.enabled
            opacity: enabled ? 1 : Appearance.dashboard.disabledOpacity
            title: qsTr("Starts at")
            subtitle: qsTr("Civil dusk is about half an hour later, when it is properly dark")
            Segmented {
                readonly property int wanted: Math.max(0, root.starts.indexOf(Config.appearance.eveningWarmth.startsAt))

                model: [qsTr("Sunset"), qsTr("Civil dusk")]
                currentIndex: wanted
                segmentHeight: Appearance.settings.segmentHeight
                hPadding: Appearance.settings.segmentPad
                railRadius: Appearance.radius.card
                onWantedChanged: currentIndex = wanted
                onSelected: i => {
                    Config.appearance.eveningWarmth.startsAt = root.starts[i];
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            enabled: Config.appearance.eveningWarmth.enabled
            opacity: enabled ? 1 : Appearance.dashboard.disabledOpacity
            title: qsTr("Takes")
            subtitle: qsTr("From neutral to fully warm")
            labelWidth: Appearance.settings.labelWidthNarrow

            Slider {
                readonly property int span: Appearance.settings.rampMax - Appearance.settings.rampMin
                readonly property real wanted: (Config.appearance.eveningWarmth.rampMinutes - Appearance.settings.rampMin) / span

                value: wanted
                handleWidth: Appearance.settings.sliderHandle
                handleHeight: Appearance.settings.sliderHandle
                stepSize: Appearance.settings.rampStep / span
                onWantedChanged: value = wanted
                onMoved: v => {
                    const step = Appearance.settings.rampStep;
                    Config.appearance.eveningWarmth.rampMinutes = Appearance.settings.rampMin + Math.round(v * span / step) * step;
                    Persist.commit();
                }

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            SettingValue {
                text: qsTr("%1 min").arg(Config.appearance.eveningWarmth.rampMinutes)

                Layout.preferredWidth: Appearance.settings.valueWidthNarrow
            }
        }

        // How far the shell's colours go, not the screen's (that is the
        // kelvin, below): at a third the wallpaper's colour is still plainly
        // there at night, warmed; at 100% every palette turns the same amber.
        SettingRow {
            enabled: Config.appearance.eveningWarmth.enabled
            opacity: enabled ? 1 : Appearance.dashboard.disabledOpacity
            title: qsTr("How warm")
            subtitle: qsTr("Lower keeps more of the wallpaper's colour")
            labelWidth: Appearance.settings.labelWidthNarrow

            Slider {
                readonly property real wanted: Config.appearance.eveningWarmth.strength

                value: wanted
                handleWidth: Appearance.settings.sliderHandle
                handleHeight: Appearance.settings.sliderHandle
                stepSize: Appearance.settings.warmthStep
                onWantedChanged: value = wanted
                onMoved: v => {
                    const step = Appearance.settings.warmthStep;
                    Config.appearance.eveningWarmth.strength = Math.round(v / step) * step;
                    Persist.commit();
                }

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            SettingValue {
                text: qsTr("%1 %").arg(Math.round(Config.appearance.eveningWarmth.strength * 100))

                Layout.preferredWidth: Appearance.settings.valueWidthNarrow
            }
        }

        // The palette warms by moving its hues; this warms the pixels, every
        // window included, through hyprsunset.
        SettingRow {
            enabled: Config.appearance.eveningWarmth.enabled && NightLight.available
            opacity: enabled ? 1 : Appearance.dashboard.disabledOpacity
            title: qsTr("Warm the screen too")
            subtitle: {
                if (!NightLight.available)
                    return qsTr("Needs hyprsunset installed");
                if (NightLight.held)
                    return NightLight.night ? qsTr("Set by hand until sunrise") : qsTr("Set by hand until the evening");
                return qsTr("Night light on the same curve, every window included");
            }

            Pill {
                visible: NightLight.held
                text: qsTr("Resume")
                tone: "subtle"
                pillHeight: Appearance.settings.segmentHeight
                fontSize: Appearance.settings.actionSize
                onClicked: NightLight.resume()

                Layout.alignment: Qt.AlignVCenter
            }

            Toggle {
                readonly property bool wanted: Config.appearance.eveningWarmth.screen

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.appearance.eveningWarmth.screen = on;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            enabled: Config.appearance.eveningWarmth.enabled && Config.appearance.eveningWarmth.screen && NightLight.available
            opacity: enabled ? 1 : Appearance.dashboard.disabledOpacity
            title: qsTr("At its warmest")
            subtitle: qsTr("Daylight is 6500 K")
            labelWidth: Appearance.settings.labelWidthNarrow

            Slider {
                readonly property int span: Appearance.settings.kelvinMax - Appearance.settings.kelvinMin
                readonly property real wanted: (Config.appearance.eveningWarmth.toKelvin - Appearance.settings.kelvinMin) / span

                value: wanted
                handleWidth: Appearance.settings.sliderHandle
                handleHeight: Appearance.settings.sliderHandle
                stepSize: Appearance.settings.kelvinStep / span
                onWantedChanged: value = wanted
                onMoved: v => {
                    const step = Appearance.settings.kelvinStep;
                    Config.appearance.eveningWarmth.toKelvin = Appearance.settings.kelvinMin + Math.round(v * span / step) * step;
                    Persist.commit();
                }

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            SettingValue {
                text: qsTr("%1 K").arg(Config.appearance.eveningWarmth.toKelvin)

                Layout.preferredWidth: Appearance.settings.valueWidthNarrow
            }
        }
    }

    // ---- you -------------------------------------------------------------------
    Section {
        title: qsTr("You")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("Profile picture")
            subtitle: qsTr("On the dashboard and the lock screen. ~/.face is the usual place")
            SettingField {
                wanted: Config.dashboard.profilePicture
                placeholder: "~/.face"
                mono: true
                onCommitted: text => {
                    Config.dashboard.profilePicture = text === "" ? "~/.face" : text;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // ---- folders -----------------------------------------------------------------
    Section {
        title: qsTr("Folders")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("Wallpapers")
            subtitle: qsTr("What the wallpaper switcher shows")
            SettingField {
                wanted: root.tilde(Config.launcher.wallpaperDir)
                placeholder: "~/Pictures/Wallpapers"
                mono: true
                onCommitted: text => {
                    Config.launcher.wallpaperDir = text === "" ? "~/Pictures/Wallpapers" : text;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("Screenshots")
            subtitle: qsTr("Where a saved capture goes")
            SettingField {
                wanted: root.tilde(Config.capture.saveDir)
                placeholder: "~/Pictures/Screenshots"
                mono: true
                onCommitted: text => {
                    Config.capture.saveDir = text === "" ? "~/Pictures/Screenshots" : text;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("Recordings")
            subtitle: qsTr("Screen recordings and GIFs")
            SettingField {
                wanted: root.tilde(Config.capture.recordDir)
                placeholder: "~/Videos/Recordings"
                mono: true
                onCommitted: text => {
                    Config.capture.recordDir = text === "" ? "~/Videos/Recordings" : text;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // ---- sessions and updates ------------------------------------------------------
    Section {
        title: qsTr("Login and updates")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("Restore the last session at login")
            subtitle: qsTr("Reopens the apps you had, where you had them")

            Toggle {
                readonly property bool wanted: Config.sessions.restoreOnLogin

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.sessions.restoreOnLogin = on;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("Remember terminal folders")
            subtitle: qsTr("A restored terminal opens where it was working")

            Toggle {
                readonly property bool wanted: Config.sessions.captureWorkingDirectory

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.sessions.captureWorkingDirectory = on;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("Show what changed after an update")
            subtitle: qsTr("The notable packages, once, the next time you log in")

            Toggle {
                readonly property bool wanted: Config.updates.showWhatChanged

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.updates.showWhatChanged = on;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
