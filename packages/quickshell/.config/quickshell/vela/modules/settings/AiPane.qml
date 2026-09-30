pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.tokens
import qs.services
import qs.components

// AI tools -- Claude Code and Codex: their cards in the System tab, the bar's
// pill, and connecting each tool so vela hears from it.
//
// Connecting is not a vela setting: it is the tool's own settings file, which
// `vela ai connect` and `disconnect` edit (and back up first), so the state
// shown is read back from those files (`AiUsage.status.connected`) rather
// than remembered here.
PaneScroll {
    id: root

    // The tool being connected or disconnected, and what went wrong last.
    property string busy: ""
    property string problem: ""

    function run(action: string, tool: string): void {
        root.busy = tool;
        root.problem = "";
        runner.command = ["sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; exec vela ai "$1" "$2"', "vela", action, tool];
        runner.running = true;
    }

    readonly property bool pillPlaced: [...Config.bar.modules.left, ...Config.bar.modules.centre, ...Config.bar.modules.right].includes("ai")

    // On: first in the right-hand run, which puts it before the arrow that
    // folds the run away (`BarContent.unfolded`), so folding the bar never
    // hides a session that is working or waiting. Off: out of every run.
    function setPill(on: bool): void {
        for (const end of ["left", "centre", "right"])
            Config.bar.modules[end] = [...Config.bar.modules[end]].filter(m => m !== "ai");
        if (on)
            Config.bar.modules.right = ["ai", ...Config.bar.modules.right];
        Persist.commit();
    }

    Process {
        id: runner

        stderr: StdioCollector {
            id: errors
        }
        onExited: code => {
            if (code !== 0)
                root.problem = errors.text.trim() || qsTr("It did not work (exit %1).").arg(code);
            root.busy = "";
            AiUsage.refresh();
        }
    }

    component ConnectControls: RowLayout {
        id: controls

        required property string tool
        readonly property bool connected: !!AiUsage.status?.connected?.[controls.tool]

        spacing: Appearance.settings.rowGap
        Layout.alignment: Qt.AlignVCenter

        Icon {
            visible: controls.connected
            text: "check_circle"
            fill: 1
            size: Appearance.size.iconXs
            color: Colours.primary
        }

        Text {
            text: controls.connected ? qsTr("Connected") : qsTr("Not connected")
            font.family: Appearance.font.mono
            font.pixelSize: Appearance.size.label
            color: controls.connected ? Colours.primary : Colours.outline
        }

        Pill {
            text: root.busy === controls.tool ? (controls.connected ? qsTr("Disconnecting…") : qsTr("Connecting…")) : controls.connected ? qsTr("Disconnect") : qsTr("Connect")
            icon: controls.connected ? "" : "link"
            tone: controls.connected ? "subtle" : "filled"
            interactive: root.busy === ""
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize
            onClicked: root.run(controls.connected ? "disconnect" : "connect", controls.tool)
        }
    }

    PaneHeader {
        title: qsTr("AI tools")

        Pill {
            text: qsTr("Apply")
            tone: "filled"
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize
            onClicked: Persist.now()
        }
    }

    Section {
        title: qsTr("Claude Code")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("Live status, model and effort")
            subtitle: qsTr("Adds vela's status line and a few hooks to ~/.claude/settings.json, saving the file first. The session and week then move with every reply, and the card shows the model and its effort. A status line you already had keeps running after vela's. With any status line, Claude Code shows fewer keyboard hints under the prompt.")

            ConnectControls {
                tool: "claude"
            }
        }

        SettingRow {
            title: qsTr("Everything /usage shows")
            subtitle: qsTr("Asks your own Claude Code, the way /usage does, for every window (a model's own week, like Fable's, included) and your plan. It runs Claude Code for a moment every five minutes while you use it; nothing is sent to a model. Experimental in Claude Code, so an update may stop it.")

            Toggle {
                readonly property bool wanted: Config.ai.claudeUsage

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.ai.claudeUsage = on;
                    Persist.commit();
                }
                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("Card in the System tab")
            subtitle: qsTr("Your plan's windows, each with its reset")

            Toggle {
                readonly property bool wanted: Config.ai.claude

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.ai.claude = on;
                    Persist.commit();
                }
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    Section {
        title: qsTr("Codex")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("Card in the System tab")
            subtitle: qsTr("Read from Codex's own session files in ~/.codex/sessions. Nothing to set up.")

            Toggle {
                readonly property bool wanted: Config.ai.codex

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.ai.codex = on;
                    Persist.commit();
                }
                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("Live status")
            subtitle: qsTr("Adds a few hooks to ~/.codex/hooks.json, saving the file first. Codex asks you to trust them once (or see /hooks). A Business admin can turn personal hooks off; the usage still shows.")

            ConnectControls {
                tool: "codex"
            }
        }
    }

    Section {
        title: qsTr("Both")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("Tell me at 90%")
            subtitle: qsTr("One notification as a window is almost used up")

            Toggle {
                readonly property bool wanted: Config.ai.notifyNearLimit

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.ai.notifyNearLimit = on;
                    Persist.commit();
                }
                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("Pill in the bar")
            subtitle: qsTr("While a session works, waits on you or has just finished. Move it in Modules.")

            Toggle {
                readonly property bool wanted: root.pillPlaced

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => root.setPill(on)
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    Text {
        visible: root.problem !== ""
        text: root.problem
        font.family: Appearance.font.mono
        font.pixelSize: Appearance.size.label
        color: Colours.error
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Text {
        text: qsTr("vela never reads your login or sends anything anywhere: it shows the numbers these tools already have, and asks Claude Code the way /usage does.")
        font.family: Appearance.font.ui
        font.pixelSize: Appearance.size.label
        color: Colours.outline
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}
