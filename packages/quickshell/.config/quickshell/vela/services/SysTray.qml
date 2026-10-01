pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// The apps in the tray, for the bar's tray icons and the menus the shell draws
// for them (modules/popouts/TrayMenu.qml).
//
// `SysTray` rather than `Tray`: a singleton of that name would shadow the bar's
// own `Tray.qml` in every file that imports both, the race that made the
// network and Bluetooth services `Net` and `Bt`.
Singleton {
    id: root

    // Passive items are an app saying it has nothing to show right now.
    readonly property var items: SystemTray.items.values.filter(i => i.status !== Status.Passive)

    // Quickshell answers `image://icon/<name>` even for a name the theme does
    // not have, with a placeholder that reports itself as loaded -- so an icon
    // has to be checked against the theme before it is handed to an Image or
    // the bar grows a magenta square.
    //
    // An icon that ships its own directory (`?path=`, which is how Electron
    // apps and anything installed outside the icon theme send one) is resolved
    // by Quickshell's provider from that directory, so it is passed through:
    // checking its bare name against the theme turned Discord, Slack or
    // VS Code into the placeholder glyph. So is an icon sent as image data,
    // which has no name to check.
    function usable(source: string): bool {
        if (!source)
            return false;
        const prefix = "image://icon/";
        const at = source.indexOf(prefix);
        if (at === -1 || source.includes("?path="))
            return true;
        const name = source.slice(at + prefix.length).split("?")[0];
        return name.length > 0 && Quickshell.iconPath(name, true) !== "";
    }

    // A menu entry's label as text. Quickshell marks a label's access key
    // (`_Quit`) up as `<u>Q</u>uit`, which a menu only underlines while Alt
    // is held, and the shell's menus have no access keys.
    function label(text: string): string {
        return (text ?? "").replace(/<\/?u>/g, "");
    }
}
