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

    // A tray icon is checked with `AppIcons.usable` before it is drawn: an
    // icon name the theme does not have would otherwise be a magenta square.

    // A menu entry's label as text. Quickshell marks a label's access key
    // (`_Quit`) up as `<u>Q</u>uit`, which a menu only underlines while Alt
    // is held, and the shell's menus have no access keys.
    function label(text: string): string {
        return (text ?? "").replace(/<\/?u>/g, "");
    }
}
