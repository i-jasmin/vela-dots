pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.tokens
import qs.components

// Launcher -- what the launcher searches, how much of it it shows, the
// shortcuts its field understands, and where a web search goes. Every control writes `Config.launcher.*`, which
// `modules/launcher/Search.qml` reads on every query, so the next keystroke in
// the launcher uses the new setting.
PaneScroll {
    id: root

    // The launcher lists its sources in this order, and a source switched back
    // on returns to its place in it rather than joining the end.
    readonly property var sourceOrder: ["apps", "commands", "web"]

    readonly property var engines: [
        {
            label: "DuckDuckGo",
            url: "https://duckduckgo.com/?q="
        },
        {
            label: "Google",
            url: "https://www.google.com/search?q="
        },
        {
            label: "Brave",
            url: "https://search.brave.com/search?q="
        },
        {
            label: "Startpage",
            url: "https://www.startpage.com/do/search?q="
        }
    ]
    readonly property int engineIndex: root.engines.findIndex(e => e.url === Config.launcher.webSearch)

    function setSource(name: string, on: bool): void {
        const now = Config.launcher.sources;
        Config.launcher.sources = root.sourceOrder.filter(s => s === name ? on : now.includes(s));
        Persist.commit();
    }

    function setWebSearch(url: string): void {
        Config.launcher.webSearch = url;
        Persist.commit();
    }

    PaneHeader {
        title: qsTr("Launcher")

        Pill {
            text: qsTr("Apply")
            tone: "filled"
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize
            onClicked: Persist.now()
        }
    }

    Section {
        title: qsTr("What it searches")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        Repeater {
            model: [
                {
                    key: "apps",
                    title: qsTr("Applications"),
                    subtitle: qsTr("Everything with a desktop entry")
                },
                {
                    key: "commands",
                    title: qsTr("Commands"),
                    subtitle: qsTr("Programs on your $PATH, run in a terminal")
                },
                {
                    key: "web",
                    title: qsTr("Web search"),
                    subtitle: qsTr("Always the last row, so it is there when nothing else matches")
                }
            ]

            SettingRow {
                id: source

                required property var modelData

                title: source.modelData.title
                subtitle: source.modelData.subtitle

                Toggle {
                    readonly property bool wanted: Config.launcher.sources.includes(source.modelData.key)

                    checked: wanted
                    onWantedChanged: checked = wanted
                    onToggled: on => root.setSource(source.modelData.key, on)

                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        SettingRow {
            title: qsTr("Results")
            subtitle: qsTr("How many rows the list shows")
            labelWidth: Appearance.settings.labelWidthNarrow

            Slider {
                readonly property int span: Appearance.settings.maxResultsMax - Appearance.settings.maxResultsMin
                readonly property real wanted: (Config.launcher.maxResults - Appearance.settings.maxResultsMin) / span

                value: wanted
                handleWidth: Appearance.settings.sliderHandle
                handleHeight: Appearance.settings.sliderHandle
                stepSize: 1 / span
                onWantedChanged: value = wanted
                onMoved: v => {
                    Config.launcher.maxResults = Appearance.settings.maxResultsMin + Math.round(v * span);
                    Persist.commit();
                }

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            SettingValue {
                text: `${Config.launcher.maxResults}`

                Layout.preferredWidth: Appearance.settings.valueWidthNarrow
            }
        }
    }

    // Switched off, a prefix is just a character again: `:` searches for a
    // colon like anything else.
    Section {
        title: qsTr("Shortcuts in the search field")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        Repeater {
            model: [
                {
                    key: "calculator",
                    title: qsTr("Answers"),
                    subtitle: qsTr("Sums like 12*7 and conversions like 5 km in mi answer first; = makes anything a sum")
                },
                {
                    key: "emoji",
                    title: qsTr("Emoji"),
                    subtitle: qsTr("Type : and a word, say :tada; enter types it where you were")
                },
                {
                    key: "clipboard",
                    title: qsTr("Clipboard"),
                    subtitle: qsTr("Type ; and a word to search what you copied; enter pastes it")
                }
            ]

            SettingRow {
                id: shortcut

                required property var modelData

                title: shortcut.modelData.title
                subtitle: shortcut.modelData.subtitle

                Toggle {
                    readonly property bool wanted: Config.launcher[shortcut.modelData.key]

                    checked: wanted
                    onWantedChanged: checked = wanted
                    onToggled: on => {
                        Config.launcher[shortcut.modelData.key] = on;
                        Persist.commit();
                    }

                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    Section {
        title: qsTr("Web search")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            enabled: Config.launcher.sources.includes("web")
            opacity: enabled ? 1 : Appearance.dashboard.disabledOpacity
            title: qsTr("Search with")

            Segmented {
                // "Custom" when the address is not one of the four.
                readonly property int wanted: root.engineIndex >= 0 ? root.engineIndex : root.engines.length

                model: [...root.engines.map(e => e.label), qsTr("Custom")]
                currentIndex: wanted
                segmentHeight: Appearance.settings.segmentHeight
                hPadding: Appearance.settings.segmentPad
                railRadius: Appearance.radius.card
                onWantedChanged: currentIndex = wanted
                onSelected: i => {
                    if (i < root.engines.length)
                        root.setWebSearch(root.engines[i].url);
                    else
                        address.edit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            enabled: Config.launcher.sources.includes("web")
            opacity: enabled ? 1 : Appearance.dashboard.disabledOpacity
            title: qsTr("Address")
            subtitle: qsTr("What you typed is added to the end")
            SettingField {
                id: address

                wanted: Config.launcher.webSearch
                placeholder: "https://duckduckgo.com/?q="
                mono: true
                onCommitted: text => root.setWebSearch(text === "" ? root.engines[0].url : text)

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
