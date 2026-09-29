pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.tokens
import qs.components

// Settings, Keybinds: every bind vela has, on the keys it is on, and binds of
// your own.
//
// Click a bind's keys and press new ones. Changes wait until Apply, which
// writes ~/.config/vela/keybinds.json and reloads Hyprland; binds.lua stays
// the defaults, and an update of the dots never touches your file
// (hypr/conf/keybinds.lua has the details). Two binds on the same keys are
// both drawn in red, and Apply waits until they differ -- which is what lets a
// pair be swapped through a moment of both on one combination.
//
// The rows come from the list Hyprland writes as it loads the config
// (BindEditor.defaults), so a bind added to binds.lua is here the next time
// it loads, with nothing to keep in step.
PaneScroll {
    id: root

    readonly property string filter: search.text.trim().toLowerCase()

    // The groups present, in the cheatsheet's order, then any others.
    readonly property var groups: {
        const names = BindEditor.groupOrder.filter(g => BindEditor.rows.some(r => r.group === g));
        for (const r of BindEditor.rows)
            if (!r.custom && !names.includes(r.group))
                names.push(r.group);
        return names;
    }

    function matches(row: var): bool {
        if (root.filter === "")
            return true;
        const hay = `${row.group} ${row.action} ${BindEditor.capsOf(row).join(" ")} ${row.keys}`.toLowerCase();
        return root.filter.split(/\s+/).every(w => hay.includes(w));
    }

    // One sentence on the state of things, most urgent first, or nothing.
    readonly property string status: {
        if (BindEditor.manifestMissing)
            return qsTr("Hyprland has not written its list of keybinds yet. Run hyprctl reload; if the list still does not come, the Hyprland config loaded is older than this shell.");
        if (BindEditor.clashCount > 0)
            return BindEditor.clashCount === 1 ? qsTr("Two keybinds are on the same keys. Change one of them to apply.") : qsTr("%1 key combinations are on more than one keybind. Change them to apply.").arg(BindEditor.clashCount);
        if (BindEditor.incompleteCount > 0)
            return qsTr("A keybind of yours needs keys and a command before it can be applied.");
        if (BindEditor.userUnreadable)
            return qsTr("keybinds.json could not be read, so Hyprland is on the defaults. Apply writes it afresh.");
        if (BindEditor.dirty)
            return qsTr("Not applied yet: Apply writes them and reloads Hyprland.");
        return "";
    }
    readonly property bool statusIsError: BindEditor.manifestMissing || BindEditor.clashCount > 0 || BindEditor.userUnreadable

    PaneHeader {
        title: qsTr("Keybinds")

        ResetPill {
            id: resetting

            visible: BindEditor.changedCount > 0 || resetting.asking
            question: qsTr("Every vela keybind back to its default? Yours stay.")
            onConfirmed: BindEditor.restoreAll()
        }

        Pill {
            visible: BindEditor.dirty && !resetting.asking
            text: qsTr("Discard")
            tone: "subtle"
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize
            onClicked: BindEditor.discard()
        }

        Pill {
            visible: !resetting.asking
            enabled: BindEditor.canApply
            text: BindEditor.applying ? qsTr("Applying…") : qsTr("Apply")
            tone: "filled"
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize
            onClicked: BindEditor.apply()
        }
    }

    // What is wrong or waiting, and anything Hyprland refused.
    ColumnLayout {
        visible: root.status !== "" || BindEditor.problems.length > 0
        spacing: Appearance.settings.labelGap

        Layout.fillWidth: true

        Text {
            visible: root.status !== ""
            text: root.status
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.label
            color: root.statusIsError ? Colours.error : Colours.on.surfaceVariant
            wrapMode: Text.WordWrap

            Layout.fillWidth: true
        }

        Repeater {
            model: BindEditor.problems

            Text {
                required property string modelData

                text: modelData
                font.family: Appearance.font.mono
                font.pixelSize: Appearance.size.label
                color: Colours.error
                wrapMode: Text.WrapAnywhere

                Layout.fillWidth: true
            }
        }
    }

    RowLayout {
        spacing: Appearance.space.sm

        Layout.fillWidth: true

        SettingField {
            id: search

            placeholder: qsTr("Filter: an action or a key")
            implicitWidth: Appearance.settings.bindFilterWidth
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: qsTr("Click a bind's keys, then press new ones")
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.label
            color: Colours.outline
        }
    }

    Repeater {
        model: root.groups

        Section {
            id: group

            required property string modelData

            // Ids, which ScriptModel compares by value: an edit changes a
            // row's keys, not which rows there are, so the rows -- and the
            // one being recorded -- stay put.
            readonly property var ids: BindEditor.rows.filter(r => !r.custom && r.group === group.modelData && root.matches(r)).map(r => r.id)

            visible: group.ids.length > 0
            title: group.modelData
            padding: Appearance.space.panelPadding
            gap: Appearance.settings.cardGapTight

            Repeater {
                model: ScriptModel {
                    values: group.ids
                }

                BindRow {
                    required property string modelData

                    row: BindEditor.rows.find(r => r.id === modelData) ?? {
                        id: modelData,
                        action: "",
                        keys: "",
                        defaultKeys: "",
                        family: null,
                        fixed: "",
                        changed: false,
                        off: true
                    }
                }
            }
        }
    }

    Section {
        title: qsTr("Your own")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        Text {
            text: qsTr("Keys that run a command: an app (code, firefox), or a script of yours. They are listed in the cheatsheet under Custom.")
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.label
            color: Colours.outline
            wrapMode: Text.WordWrap

            Layout.fillWidth: true
        }

        Repeater {
            id: customs

            model: (BindEditor.pending.custom ?? []).length

            CustomBindRow {}
        }

        Pill {
            text: qsTr("Add a keybind")
            icon: "add"
            tone: "subtle"
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize

            onClicked: {
                const at = BindEditor.addCustom();
                Qt.callLater(() => {
                    const item = customs.itemAt(at);
                    if (item)
                        item.editName();
                });
            }
        }
    }

    // Where the defaults live, for anyone who would rather read them.
    SettingRow {
        title: qsTr("The defaults")
        detail: "~/.config/hypr/conf/binds.lua"
        subtitle: qsTr("Yours are kept apart from them, in ~/.config/vela/keybinds.json, so an update never resets them.")
        labelGap: Appearance.settings.labelGap

        Pill {
            text: qsTr("Open binds.lua")
            tone: "subtle"
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize
            onClicked: Files.open(`${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/hypr/conf/binds.lua`)
        }
    }
}
