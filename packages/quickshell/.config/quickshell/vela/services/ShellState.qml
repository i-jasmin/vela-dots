pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.services

// Which shell surfaces are open, as plain booleans on one singleton, so a
// keybind, an IPC call and a click all drive the same state.
//
// Everything that can cover the screen is mutually exclusive: opening one closes
// the others. Popouts are not listed here -- a popout belongs to the bar item
// that owns it, and the bar tracks which one is showing.
Singleton {
    id: root

    property bool dashboard: false
    property bool launcher: false
    property bool overview: false
    property bool windowPicker: false
    property bool clipboard: false
    property bool capture: false
    property bool sessions: false
    property bool whatChanged: false
    property bool power: false
    property bool wallpaper: false
    property bool settings: false
    property bool keybinds: false

    readonly property list<string> surfaces: ["dashboard", "launcher", "overview", "windowPicker", "clipboard", "capture", "sessions", "whatChanged", "power", "wallpaper", "settings", "keybinds"]

    readonly property bool any: surfaces.some(s => root[s])

    // Set by the lock module while the session is locked.
    //
    // This is load-bearing, not informational. Hyprland draws wlr-layer-shell
    // **Overlay** surfaces *above* a session lock surface, and almost every
    // panel in this shell is on Overlay -- so anything that opens while locked
    // paints over the lock screen, in front of a screen whose whole job is to
    // show nothing. Refusing here covers the keybind and IPC paths in one
    // place; a surface that can appear without being asked for, such as a
    // notification toast, has to gate on this itself.
    property bool locked: false

    // Asked for by something in `services/` (the power menu's Lock), which
    // cannot reach the lock module in `modules/` directly.
    signal lockRequested

    function requestLock(): void {
        root.lockRequested();
    }

    // A surface the config has switched off. Only `whatChanged` has such a key
    // -- `updates.showWhatChanged` -- and it was in the design's shell.json
    // being read by nothing, which is the worst state for a setting to be in:
    // the settings window could offer it and it would move nothing. Refusing
    // here covers the keybind, the IPC call and the dashboard's health card at
    // once, in the same place the lock refusal lives.
    function enabled(surface: string): bool {
        return surface !== "whatChanged" || Config.updates.showWhatChanged;
    }

    // Switching it off while it is up puts it away, or the key would only be
    // honoured the next time somebody asked for it -- which is a restart in
    // everything but name.
    readonly property bool whatChangedAllowed: Config.updates.showWhatChanged
    onWhatChangedAllowedChanged: {
        if (!root.whatChangedAllowed)
            root.whatChanged = false;
    }

    function open(surface: string): void {
        root.openOn(surface, "");
    }

    // `open`, on a named monitor: a bar button opens its drawer on the bar it
    // was pressed on, which is not always the monitor Hyprland last focused.
    // "" is the focused one.
    function openOn(surface: string, screen: string): void {
        if (!has(surface))
            return;
        if (root.locked) {
            console.warn(`[vela] refusing to open ${surface} while the session is locked`);
            return;
        }
        if (!root.enabled(surface)) {
            console.warn(`[vela] ${surface} is switched off in shell.json`);
            return;
        }
        // Recording a keybind in Settings: Hyprland's binds are off for it,
        // but the tap of super is read from the raw keys and still asks for
        // the overview -- which would close Settings mid-recording.
        if (BindEditor.capturing !== "")
            return;
        closeAll();
        root.place(surface, screen);
        root[surface] = true;
    }

    function close(surface: string): void {
        if (has(surface))
            root[surface] = false;
    }

    function toggle(surface: string): void {
        root.toggleOn(surface, "");
    }

    function toggleOn(surface: string, screen: string): void {
        if (!has(surface))
            return;
        // Open on another monitor is not open here: the button on this bar
        // brings it over rather than only putting it away there.
        const wasOpen = root[surface] && (!screen || !root.attachedSurfaces.includes(surface) || root.drawerScreen === screen);
        closeAll();
        // Closing is always allowed; opening is not, while locked or switched
        // off.
        if (wasOpen || root.locked || !root.enabled(surface))
            return;
        root.place(surface, screen);
        root[surface] = true;
    }

    // Alt-tab. The first press opens the window picker, and says so, so the
    // picker knows alt is being held: it opened *after* alt went down and never
    // sees that key press, only the release that should commit. Every press
    // after that moves the selection -- Hyprland keeps catching alt + tab while
    // the picker has the keyboard, so a plain toggle closed it again.
    property bool altTabbing: false
    property int altTabStart: 1
    signal altTabStep(step: int)

    function altTab(step: int): void {
        if (root.windowPicker) {
            root.altTabStep(step);
            return;
        }
        root.altTabbing = true;
        root.altTabStart = step;
        root.open("windowPicker");
        // Refused (locked): do not leave the flag for the next open.
        root.altTabbing = false;
    }

    // Alt coming up, which commits. The picker hears the release itself once
    // it has the keyboard, but a quick alt + tab is over before then, so
    // binds.lua reports it too: it sees every key, whoever has the keyboard.
    signal altTabReleased

    // Alt-tab from Hyprland (binds.lua), as global shortcuts: events on the
    // shell's own Wayland connection, in the order the keys went. The IPC
    // call below does the same, a process start later.
    GlobalShortcut {
        appid: "vela"
        name: "altTab"
        description: qsTr("Window picker")
        onPressed: root.altTab(1)
    }

    GlobalShortcut {
        appid: "vela"
        name: "altTabBack"
        description: qsTr("Window picker, backwards")
        onPressed: root.altTab(-1)
    }

    GlobalShortcut {
        appid: "vela"
        name: "altTabRelease"
        description: qsTr("Alt released after alt + tab")
        onPressed: root.altTabReleased()
    }

    // The bar's status run folded away behind its arrow -- both bars'
    // `expand_circle_down` -- which hides everything from there up to the
    // clock. A state the bar is left in, not a setting, so it is kept in
    // ~/.local/state/vela/bar.json rather than rewriting shell.json on every
    // click.
    property bool barCollapsed: false

    function setBarCollapsed(on: bool): void {
        if (root.barCollapsed === on)
            return;
        root.barCollapsed = on;
        barStateFile.setText(JSON.stringify({
            collapsed: on
        }));
    }

    FileView {
        id: barStateFile

        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/vela/bar.json`
        watchChanges: false
        atomicWrites: true
        printErrors: false

        onLoaded: {
            try {
                root.barCollapsed = JSON.parse(text()).collapsed === true;
            } catch (e) {
                console.warn(`[vela] bar state unreadable, starting expanded: ${e}`);
            }
        }
        // A fresh install has no ~/.local/state/vela yet.
        onSaveFailed: barStateDir.running = true
    }

    Process {
        id: barStateDir

        command: ["mkdir", "-p", `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/vela`]
        onExited: code => {
            if (code === 0)
                barStateFile.setText(JSON.stringify({
                    collapsed: root.barCollapsed
                }));
        }
    }

    // The dashboard, the popouts, the launcher and the power menu hang off
    // the bar of one monitor, and that bar has to know it: it holds itself
    // out while anything is attached and draws the shared solid surface.
    //
    //   attached         { drawer: monitor } for every attached surface with
    //                    any extent at all -- still there while one retracts,
    //                    so the bar stays solid until it has gone. Written by
    //                    AttachedDrawer through `setAttached`.
    //   drawerScreen     the monitor the dashboard, the launcher or the power
    //                    menu is on
    property var attached: ({})
    readonly property list<string> attachedScreens: Object.values(root.attached)

    // Each monitor's shell window holds its own dashboard, launcher and power
    // menu, and only the one on this monitor opens. It is taken when the
    // surface opens -- the monitor its bar button was pressed on, or the
    // focused one for a keybind -- and kept while it stays open, so the
    // pointer wandering onto the other monitor mid-search does not take the
    // launcher with it.
    property string drawerScreen: ""

    // The focused monitor, falling through to the first screen while
    // Hyprland has not answered yet.
    readonly property string focusedScreen: {
        const screens = Quickshell.screens;
        const focused = Hypr.focusedMonitorName;
        return screens.find(s => s.name === focused)?.name ?? screens[0]?.name ?? "";
    }

    function place(surface: string, screen: string): void {
        if (root.attachedSurfaces.includes(surface))
            root.drawerScreen = screen || root.focusedScreen;
    }

    // A drawer open on a monitor that is unplugged has nowhere left to draw,
    // and would otherwise stay "open" until somebody pressed its key twice.
    Connections {
        target: Quickshell

        function onScreensChanged(): void {
            if (!Quickshell.screens.some(s => s.name === root.drawerScreen))
                root.closeAttached();
        }
    }

    // The surfaces that hang off the bar. A popout is one too, and opening it
    // puts these away (BarPopouts) -- one thing hangs off the bar at a time.
    readonly property list<string> attachedSurfaces: ["dashboard", "launcher", "power"]

    function closeAttached(): void {
        for (const s of root.attachedSurfaces)
            root[s] = false;
    }

    // Every attached drawer, by slot ("dashboard@DP-1"), so one opening where
    // another is still out can take over its outline -- see `takeOver` in
    // modules/attached/AttachedDrawer.qml. A plain table, not a binding
    // source: nothing redraws when a drawer registers.
    property var drawers: ({})

    function registerDrawer(slot: string, drawer: var): void {
        root.drawers[slot] = drawer;
    }

    function unregisterDrawer(slot: string, drawer: var): void {
        if (root.drawers[slot] === drawer)
            delete root.drawers[slot];
    }

    // A drawer other than `except` that is out on `screen`, retracting or not.
    function drawerOutOn(screen: string, except: var): var {
        for (const slot in root.drawers) {
            const d = root.drawers[slot];
            if (d && d !== except && d.screenName === screen && d.out && !d.handedOff)
                return d;
        }
        return null;
    }

    function setAttached(drawer: string, screen: string): void {
        if ((root.attached[drawer] ?? "") === screen)
            return;
        // Replaced rather than edited, so everything bound to it hears.
        const next = Object.assign({}, root.attached);
        if (screen)
            next[drawer] = screen;
        else
            delete next[drawer];
        root.attached = next;
    }

    // The settings window on a given page ("keybinds", "bar", ...): the
    // cheatsheet's "Edit in settings". Settings reads and clears it on open.
    property string settingsPage: ""

    // The dashboard's tab, as the dashboard on screen reports it, and a
    // request for one. The bar items that stand for a tab -- the media chip
    // for Media, cpu/ram for System -- open the dashboard on it.
    property string dashboardTab: "home"
    signal dashboardTabAsked(string tab, string screen)

    // Opens the dashboard on `tab`, on the bar of `screen`. A second click
    // on the same item puts it away; from another tab it changes tab rather
    // than closing. The tab is asked for before the drawer opens, so the
    // drawer opens on it rather than crossing over to it.
    function toggleDashboardOn(tab: string, screen: string): void {
        const target = screen || root.focusedScreen;
        const here = root.dashboard && root.drawerScreen === target;
        if (here && root.dashboardTab === tab) {
            root.close("dashboard");
            return;
        }
        root.dashboardTabAsked(tab, target);
        if (!here)
            root.openOn("dashboard", target);
    }

    // Home's month, out on the dashboard on screen, and a request for it.
    property bool dashboardMonth: false
    signal calendarAsked(string screen)

    // The calendar: the dashboard on Home with its month folded out, on the
    // bar of `screen` -- a right-click on the clock, super + shift + D, and
    // `shell toggle calendar`. Puts it away if that is what is showing
    // there; from anywhere else on the dashboard it goes to the month. Asked
    // for before the drawer opens, so it opens with the month out.
    function toggleCalendarOn(screen: string): void {
        const target = screen || root.focusedScreen;
        const here = root.dashboard && root.drawerScreen === target;
        if (here && root.dashboardTab === "home" && root.dashboardMonth) {
            root.close("dashboard");
            return;
        }
        if (root.locked)
            return;
        root.calendarAsked(target);
        if (!here)
            root.openOn("dashboard", target);
    }

    // The calendar, opened and never closed: a reminder's "Open calendar"
    // should not put away a month that is already out.
    function openCalendarOn(screen: string): void {
        const target = screen || root.focusedScreen;
        if (root.dashboard && root.drawerScreen === target && root.dashboardTab === "home" && root.dashboardMonth)
            return;
        root.toggleCalendarOn(target);
    }

    function openSettings(page: string): void {
        root.settingsPage = page;
        root.open("settings");
    }

    function closeAll(): void {
        for (const s of surfaces)
            root[s] = false;
    }

    function has(surface: string): bool {
        if (surfaces.includes(surface))
            return true;
        console.warn(`[vela] unknown surface: ${surface}`);
        return false;
    }

    // Reachable from Hyprland keybinds and the `vela` CLI:
    //   qs -c vela ipc call shell toggle dashboard
    //
    // "calendar" is still a name here, though it is no longer a surface of
    // its own: it is the dashboard's Home with the month out.
    IpcHandler {
        target: "shell"

        function toggle(surface: string): void {
            if (surface === "calendar")
                root.toggleCalendarOn("");
            else
                root.toggle(surface);
        }

        function open(surface: string): void {
            if (surface !== "calendar")
                root.open(surface);
            else if (!(root.dashboard && root.dashboardTab === "home" && root.dashboardMonth))
                root.toggleCalendarOn("");
        }

        function close(surface: string): void {
            if (surface !== "calendar")
                root.close(surface);
            else if (root.dashboard && root.dashboardTab === "home" && root.dashboardMonth)
                root.close("dashboard");
        }

        function closeAll(): void {
            root.closeAll();
        }

        // Settings on a page by name, "" for the last one shown:
        //     qs -c vela ipc call shell settings keybinds
        function settings(page: string): void {
            root.openSettings(page);
        }

        // qs -c vela ipc call shell altTab 1   (or -1 for shift + alt + tab)
        function altTab(step: int): void {
            root.altTab(step);
        }
    }
}
