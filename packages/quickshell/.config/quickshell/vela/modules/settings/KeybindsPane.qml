import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.tokens
import qs.components

// Where the cheatsheet's "Edit in settings" lands.
//
// There is no bind editor here, and deliberately: the binds are Lua in
// binds.lua, Hyprland reloads that file on save, and the cheatsheet reads the
// result live. A second copy of them held in shell.json would be the one thing
// the cheatsheet exists to rule out -- a list that can drift from the config.
// So this page says where they live, how a description places a bind, and
// opens the file.
ColumnLayout {
    id: root

    readonly property string path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/hypr/conf/binds.lua`

    spacing: Appearance.settings.paneGap

    Component.onCompleted: Binds.refresh()

    PaneHeader {
        title: qsTr("Keybinds")

        Pill {
            text: qsTr("Open binds.lua")
            tone: "filled"
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize
            onClicked: Files.open(root.path)
        }
    }

    Section {
        title: qsTr("Where they live")

        SettingRow {
            title: qsTr("Binds")
            detail: root.path
            subtitle: qsTr("Hyprland reloads the file when it is saved, and the cheatsheet (super + <) reads what Hyprland has, every time it opens.")
            labelGap: Appearance.settings.labelGap
        }

        SettingRow {
            title: qsTr("Descriptions")
            subtitle: qsTr("A bind's description places it: “Group: Action” is a row in that group, “Group › Action” a quieter secondary row. A bind without one is listed under Unsorted with its raw dispatcher.")
            labelGap: Appearance.settings.labelGap
        }
    }

    Section {
        title: qsTr("Bound now")

        SettingRow {
            title: qsTr("%1 binds").arg(Binds.count)
            subtitle: Binds.groups.map(g => `${g.name} ${g.rows.length}`).join(" · ")
            labelGap: Appearance.settings.labelGap
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
