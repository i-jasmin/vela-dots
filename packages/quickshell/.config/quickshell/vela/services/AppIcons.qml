pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// What an application looks like: the real icon from an icon theme, when one is
// chosen in Settings (Appearance, App icons), or nothing -- and then whatever
// draws it falls back to the Material symbol the design gives it (`Apps`,
// `Hypr.symbolFor`). `components/AppIcon.qml` is the one place that decides
// between the two.
//
// THE THEME IS THE ONE THIS SHELL STARTED WITH. Quickshell reads QS_ICON_THEME
// once, as it starts, and resolves every `image://icon/` name against it for
// the rest of its life; there is no changing it from here. So the setting is
// `Config.appearance.iconTheme`, and what is drawn is `running` -- the two only
// differ in the second between a choice and the restart that applies it, or
// when shell.json was edited by hand. `vela icon-theme` is what applies one:
// it writes the setting, sets GTK apps to the same theme, and restarts the
// shell with it (`vela shell start` passes it on).
Singleton {
    id: root

    // The theme drawn now, "" for vela's own symbols.
    readonly property string running: Quickshell.env("QS_ICON_THEME") ?? ""
    readonly property bool themed: root.running !== ""
    // Chosen, but not what this shell started with.
    readonly property bool pending: (Config.appearance.iconTheme ?? "") !== root.running

    // The themes installed, for Settings: [{ id, name, path, preview }], where
    // `preview` is a few of the theme's own application icons as file paths.
    // Read when Settings asks, not at startup -- it is a walk of every icon
    // folder on the machine, and nothing else needs it.
    property var themes: []
    property bool scanned: false

    // An icon as a desktop entry or a window names it -- "firefox", or a
    // path -- as an image source, or "" when there is no theme to draw it from
    // or the theme has nothing by that name. Checked rather than handed over
    // blind: `image://icon/` answers a name it does not have with a magenta
    // placeholder that reports itself as loaded.
    function source(icon: string): string {
        if (!root.themed || !icon)
            return "";
        if (icon.startsWith("/"))
            return `file://${icon}`;
        return Quickshell.iconPath(icon, true);
    }

    function forEntry(entry: var): string {
        return root.source(entry?.icon ?? "");
    }

    // A window class, or a notification's app name: through the desktop entry
    // it belongs to, then as an icon name of its own -- "kitty" and "firefox"
    // are both.
    function forClass(appClass: string): string {
        if (!root.themed || !appClass)
            return "";
        return root.forEntry(Hypr.entryFor(appClass)) || root.source(appClass) || root.source(appClass.toLowerCase());
    }

    function forClient(client: var): string {
        return root.forClass(Hypr.classOf(client));
    }

    function scan(): void {
        if (!lister.running)
            lister.running = true;
    }

    // Choose a theme, "" for vela's symbols. The shell this runs in is
    // restarted by it, and Settings opened again on Appearance.
    function use(id: string): void {
        Quickshell.execDetached(["sh", "-c", 'PATH="$HOME/.local/bin:$PATH" exec vela icon-theme "$1" --settings', "vela", id || "vela"]);
    }

    // `running` is never declared inline: Quickshell starts a Process the
    // instant that property is set, before `stdout` is attached.
    Process {
        id: lister

        command: ["sh", "-c", 'PATH="$HOME/.local/bin:$PATH" exec vela icon-theme --json']

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.themes = JSON.parse(this.text).themes ?? [];
                } catch (e) {
                    root.themes = [];
                }
                root.scanned = true;
            }
        }
    }
}
