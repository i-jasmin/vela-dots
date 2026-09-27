pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Live view of ~/.config/vela/shell.json.
//
// Every key here must take effect without restarting the shell: the settings
// window writes this file and holds no state of its own, so a control that
// needed a restart would be a control the settings window cannot honestly
// offer. Defaults below are the source of truth for a valid config; a missing
// file or key falls back to them silently.
Singleton {
    id: root

    readonly property AppearanceCfg appearance: adapter.appearance
    readonly property BarCfg bar: adapter.bar
    readonly property DockCfg dock: adapter.dock
    readonly property DashboardCfg dashboard: adapter.dashboard
    readonly property LauncherCfg launcher: adapter.launcher
    readonly property NotificationsCfg notifications: adapter.notifications
    readonly property ClipboardCfg clipboard: adapter.clipboard
    readonly property BackgroundCfg background: adapter.background
    readonly property CaptureCfg capture: adapter.capture
    readonly property SessionsCfg sessions: adapter.sessions
    readonly property LockCfg lock: adapter.lock
    readonly property CalendarCfg calendar: adapter.calendar
    readonly property WeatherCfg weather: adapter.weather
    readonly property UpdatesCfg updates: adapter.updates
    readonly property Keybinds keybinds: adapter.keybinds

    readonly property string path: `${Quickshell.env("HOME")}/.config/vela/shell.json`

    component EveningWarmth: JsonObject {
        property bool enabled: true
        property int fromKelvin: 6500
        property int toKelvin: 3400
        property int rampMinutes: 90
        // "sunset" | "civil-dusk" -- where the ramp begins. `services/Sun.qml`
        // moves only the ramp; the sunset the weather card prints stays the
        // true one. Anything unrecognised means sunset.
        property string startsAt: "sunset"
        // The screen as well as the palette: hyprsunset follows the same
        // curve, from `fromKelvin` at the start of the ramp to `toKelvin` at
        // its end (`services/NightLight.qml`). Off unless asked for, because
        // it changes every pixel, photographs included.
        property bool screen: false
    }

    component AppearanceCfg: JsonObject {
        property string scheme: "scheme-tonal-spot"
        // "light" | "dark" | "auto"
        property string mode: "dark"
        property bool generateFromWallpaper: true
        property real radiusScale: 1.0

        // Panel opacity has a floor, and it is a contrast floor rather than a
        // taste one. Text is drawn on `Colours.panel` -- `panelBase` composited
        // at this alpha over a blurred wallpaper -- so the alpha is what decides
        // whether text holds its 4.5:1 contrast. Measured against a worst-case
        // bright wallpaper on the dark scheme: `on.surface` reads 7.48:1 at the
        // shipped 0.82 and 3.50:1 at 0.60. Below the floor the shell stops being
        // readable, including the settings window holding the slider that got it
        // there -- which is a state a user cannot get out of.
        //
        // It is clamped here rather than inside `Colours.panel` so that the
        // number the settings window reads back is the number being drawn. A
        // slider dragged under the floor snaps to it, visibly, instead of
        // reporting a value the shell is quietly ignoring.
        //
        // The floor is not a guarantee for the whole ramp, and it is worth
        // being exact about how far short it falls. Measured against a
        // worst-case white wallpaper showing through the panel, dark scheme:
        //
        //   alpha   outline   on.surfaceVariant   on.surface
        //    0.70      1.99                3.71         4.90
        //    0.82      3.04                5.68         7.51
        //    1.00      5.39               10.06        13.29
        //
        // So the floor keeps primary text above 4.5:1 and nothing else. The
        // third rung would need alpha 0.935 -- effectively opaque, which is not
        // the design -- so a translucent panel and `outline` as secondary text
        // cannot both hold the floor over an arbitrary wallpaper. The design
        // itself is drawn opaque, where `outline` reads 5.39:1, so this is a
        // case it did not model rather than one it got wrong. The ramp is left
        // as designed.
        readonly property real minPanelOpacity: 0.7

        property real panelOpacity: 0.82
        onPanelOpacityChanged: {
            const floored = Math.max(minPanelOpacity, Math.min(1, panelOpacity));
            if (panelOpacity !== floored)
                panelOpacity = floored;
        }

        // How the shell moves (Settings, Appearance, Motion). `animations`
        // false is none at all; `reduceMotion` keeps the fades and drops the
        // travel; `animationSpeed` divides every duration -- 2 is twice as
        // quick, 0.5 half as -- the shell's, and Hyprland's window and
        // workspace animations too (hypr/conf/general.lua reads it).
        property bool reduceMotion: false
        property bool animations: true
        property real animationSpeed: 1
        onAnimationSpeedChanged: {
            const clamped = Math.max(0.25, Math.min(4, animationSpeed));
            if (animationSpeed !== clamped)
                animationSpeed = clamped;
        }
        property EveningWarmth eveningWarmth: EveningWarmth {}
    }

    component Autohide: JsonObject {
        // "never" | "when-window-overlaps" | "always"
        property string mode: "when-window-overlaps"
        property int revealDelay: 120
        property bool keepOnFocusedMonitor: false
    }

    component BarModules: JsonObject {
        // Read in order. The names map to delegates in modules/bar/.
        property list<string> left: ["launcher", "workspaces", "divider", "activeWindow"]
        property list<string> centre: ["clock"]
        property list<string> right: ["media", "resources", "privacy", "tray", "battery", "power"]
    }

    component BarWorkspaces: JsonObject {
        property int count: 5
        // The active pill stretches rather than only recolouring.
        property bool stretchActive: true
        property int hideEmptyAfter: 5
    }

    component PerMonitor: JsonObject {
        property bool enabled: true
        property real dimUnfocused: 0.62
    }

    component BarCfg: JsonObject {
        // "left" | "right" | "top" | "bottom". One component, rotated.
        property string position: "left"
        // The bar has two thicknesses, not one: the design's table gives 58px
        // on its side and 40px along the top. A single key could not carry both
        // -- with `"thickness": 58` and a horizontal bar every overlay reserved
        // 68px against a 50px bar, an 18px error measured on ten surfaces. So
        // the orientations are separate keys and `thickness` is derived from
        // `position`, the way `vertical` is.
        property int thicknessVertical: 58
        property int thicknessHorizontal: 40
        // `floating`, not the design's `float`: QML reserves `float` as a type
        // name and a property cannot be called it. The JSON key is renamed to
        // match, since this config file is ours to define.
        property bool floating: true
        property int margin: 10
        property Autohide autohide: Autohide {}
        property BarModules modules: BarModules {}
        property BarWorkspaces workspaces: BarWorkspaces {}
        property PerMonitor perMonitor: PerMonitor {}

        readonly property bool vertical: position === "left" || position === "right"

        // The single number everything else asks for. Every surface that has
        // to keep clear of the bar reads `footprint`; nothing recomputes it.
        readonly property int thickness: vertical ? thicknessVertical : thicknessHorizontal
        readonly property int footprint: thickness + (floating ? margin : 0)
    }

    component DockCfg: JsonObject {
        property bool enabled: true
        // "top" | "bottom" only. The design draws a bottom-centred strip and
        // the dock reads this as `position === "top"`; "left" or "right" is
        // accepted by the file and silently drawn at the bottom.
        property string position: "bottom"
        // "always" | "autohide" | "overview-only"
        property string behaviour: "autohide"
        property bool magnify: true
        property list<string> pinned: ["kitty.desktop", "google-chrome.desktop", "org.gnome.Nautilus.desktop"]
        property list<var> stacks: [
            {
                "path": "~/Downloads",
                "icon": "download",
                "view": "grid",
                "recent": 6
            },
            {
                "path": "trash",
                "icon": "delete",
                "view": "grid"
            }
        ]
        property bool includeRunning: true
    }

    component FocusTimer: JsonObject {
        property int minutes: 25
        property int sessions: 4
        property bool holdNotifications: true
        // The dashboard's "Countdown in the bar": the bar clock shows the
        // session's time left in place of the time while one runs.
        property bool countdownInBar: false
    }

    // The drawer's four tabs are fixed -- one job each, nothing repeated --
    // so there is no tab list to configure any more.
    component DashboardCfg: JsonObject {
        property string profilePicture: "~/.face"
        property FocusTimer focusTimer: FocusTimer {}
    }

    component LauncherCfg: JsonObject {
        property int maxResults: 8
        property list<string> sources: ["apps", "commands", "web"]
        property string webSearch: "https://duckduckgo.com/?q="
        property string wallpaperDir: "~/Pictures/Wallpapers"
        // Shortcuts in the search field (`modules/launcher/Search.qml`). An
        // answer row for a sum or a conversion -- `12*7`, `5 km in mi`, or
        // anything after `=`; `:` and a word for emoji; `;` and a word for
        // the clipboard history.
        property bool calculator: true
        property bool emoji: true
        property bool clipboard: true
    }

    component Digest: JsonObject {
        property bool enabled: true
        property int intervalMinutes: 60
    }

    component NotificationsCfg: JsonObject {
        property string position: "top-right"
        property int timeout: 6000
        property bool urgentBypassesFocus: true
        // How many notification *cards* the stack shows at once -- and since
        // grouping, a card is one application.
        property int maxVisible: 4
        // Fraction of a card's width a swipe must cross to dismiss it.
        property real swipeThreshold: 0.3
        property Digest digest: Digest {}
    }

    component ClipboardCfg: JsonObject {
        property int keep: 200
        property list<string> detectTypes: ["text", "image", "colour", "link"]
        property list<string> pinned: []
    }

    // How the wallpaper arrives. The design has no screen for this -- a
    // wallpaper is not a panel -- so its "no decorative motion" rule is not
    // what governs it.
    component BackgroundCfg: JsonObject {
        // "grow" | "wipe" | "fade" | "none"
        property string transition: "grow"
        property int transitionMs: 900
        // Where a grow starts from: "cursor" | "centre".
        property string transitionOrigin: "cursor"
    }

    component CaptureCfg: JsonObject {
        property string saveDir: "~/Pictures/Screenshots"
        property string recordDir: "~/Videos/Recordings"
        property string defaultAction: "copy"
        property string ocrLanguage: "eng"
    }

    component SessionsCfg: JsonObject {
        // Bring the last session back the first time the shell starts under a
        // new Hyprland (services/Sessions.qml).
        property bool restoreOnLogin: true
        // Record each window's working directory when a layout is saved, so a
        // terminal restores into the folder it was left in.
        property bool captureWorkingDirectory: true
    }

    component LockCfg: JsonObject {
        property bool showMedia: true
        property list<string> showStats: ["weather", "events", "unread", "battery"]
        property bool audioReactiveArc: true
        property bool fingerprint: true
    }

    component CalendarCfg: JsonObject {
        property string backend: "khal"
        property string syncCommand: "vela calendar sync"
        property int syncMinutes: 15
        // Minutes before a timed event its reminder comes, for events with no
        // reminder of their own; 0 is as it starts, -1 is none.
        property int reminderMinutes: 10
        // Whether an event's own reminders ("15 minutes before", set in its
        // calendar app) are used rather than the default.
        property bool eventAlarms: true
        // The calendar new events go to, by name (any case); "" is the
        // first one that takes events.
        property string newEvents: ""
        property list<var> sources: []
    }

    component WeatherCfg: JsonObject {
        property string location: "auto"
        property string units: "metric"
    }

    component UpdatesCfg: JsonObject {
        // Fedora, not Arch: the design's `checkupdates` and `paru -Qua` are
        // pacman tooling and do not exist on Fedora.
        property string checkCommand: "dnf5 check-update --refresh"
        // Deliberately inert: there is no AUR on Fedora, and the distinction
        // the design draws with it -- distribution packages against everything
        // else -- is `Updates.thirdPartyCount`, which comes out of
        // `checkCommand`'s own repo column. The key is kept so an Arch config
        // still validates; it is read by nothing here.
        property string aurCommand: ""
        // Off for an ext4 root: there is no pre-upgrade snapshot to take and
        // nothing for the rollback button in "what changed" to roll back to.
        property bool snapshotBefore: false
        // Gates the surface itself, in `services/ShellState.qml`, so the
        // keybind and the IPC call both refuse -- and one that is already open
        // closes when this goes false.
        property bool showWhatChanged: true
    }

    // Listed so the shell can render its own keybinds in the launcher and the
    // overview legend. Hyprland owns the actual
    // binding; these strings are labels, not behaviour -- editing one renames a
    // caption, it does not rebind anything.
    //
    // Three are drawn: `sessionSave` by the sessions surface, `wallpaper` and
    // `wallpaperRevert` by the wallpaper switcher. The rest are read by
    // nothing, because the surfaces that would print them draw intrinsic keys
    // instead -- the launcher's esc and return, the overview's super and 1-9 --
    // and the dashboard prints no keybind at all.
    component Keybinds: JsonObject {
        property string launcher: "super + space"
        property string dashboard: "super + D"
        property string overview: "super (tap)"
        property string windowPicker: "alt + tab"
        property string clipboard: "super + V"
        property string capture: "super + shift + S"
        property string sessionSave: "super + alt + S"
        property string sessionRestore: "super + alt + R"
        property string wallpaper: "super + W"
        property string wallpaperRevert: "super + shift + W"
        property string power: "super + escape"
        property string lock: "super + L"
    }

    // Persist the current adapter state back to shell.json. The settings window
    // is required to hold no state of its own, and the clipboard's pins have to
    // survive a restart -- but `Config` owns the only FileView, so without this
    // both are one-way reads.
    function save(): void {
        root.scrubbed = false;
        file.writeAdapter();
    }

    // `writeAdapter()` serialises the adapter and nothing but the adapter, and
    // two things follow -- both measured against a minimal FileView rather than
    // assumed. The `$comment` keys this file ships with are not properties, so
    // the first settings-window write deleted them. And readonly derived
    // properties *are* serialised, so `"vertical": false` appeared next to
    // `position`: a key the shell writes, that looks settable, and that is
    // ignored on load. A config file may not contain a key that does nothing.
    //
    // So every write is followed by a scrub. `saved` is the hook: by the time
    // it fires `text()` is the newly written content -- it is still stale when
    // `writeAdapter()` returns -- and a write of our own does not re-trigger
    // `fileChanged`, so this settles after one pass.
    readonly property var derivedKeys: ({
            appearance: ["minPanelOpacity"],
            bar: ["vertical", "thickness", "footprint"]
        })

    property var comments: ({})
    property bool scrubbed: false

    function rememberComments(): void {
        let doc;
        try {
            doc = JSON.parse(file.text());
        } catch (e) {
            return;
        }

        const found = {};
        const walk = (node, path) => {
            if (!node || typeof node !== "object" || Array.isArray(node))
                return;
            if (typeof node.$comment === "string")
                found[path] = node.$comment;
            for (const key in node)
                walk(node[key], path === "" ? key : `${path}.${key}`);
        };
        walk(doc, "");

        // A file already stripped of its comments must not be allowed to erase
        // the ones we are holding for it.
        if (Object.keys(found).length > 0)
            root.comments = found;
    }

    function restoreComments(node: var, path: string): var {
        if (!node || typeof node !== "object" || Array.isArray(node))
            return node;

        const out = {};
        if (root.comments[path] !== undefined)
            out.$comment = root.comments[path];
        for (const key in node) {
            if (key === "$comment")
                continue;
            out[key] = root.restoreComments(node[key], path === "" ? key : `${path}.${key}`);
        }
        return out;
    }

    function nodeAt(doc: var, path: string): var {
        let node = doc;
        for (const part of (path === "" ? [] : path.split("."))) {
            if (!node || typeof node !== "object")
                return null;
            node = node[part];
        }
        return node && typeof node === "object" ? node : null;
    }

    function scrub(): void {
        // `saved` fires for our own `setText` as well, and `text()` is the
        // pre-write content when it does -- so deciding by comparing texts can
        // never terminate. Measured: it rewrote the file 1498 times in two
        // seconds. The scrub therefore decides structurally whether it has
        // anything to do, and refuses to run twice for one save.
        if (root.scrubbed) {
            root.scrubbed = false;
            return;
        }

        let doc;
        try {
            doc = JSON.parse(file.text());
        } catch (e) {
            return;
        }

        let dirty = false;

        for (const section in root.derivedKeys) {
            if (!doc[section])
                continue;
            for (const key of root.derivedKeys[section]) {
                if (doc[section][key] === undefined)
                    continue;
                delete doc[section][key];
                dirty = true;
            }
        }

        for (const path in root.comments) {
            const node = root.nodeAt(doc, path);
            if (node && node.$comment !== root.comments[path])
                dirty = true;
        }

        if (!dirty)
            return;

        root.scrubbed = true;
        file.setText(`${JSON.stringify(root.restoreComments(doc, ""), null, 4)}\n`);
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.rememberComments()
        onSaved: root.scrub()
        onLoadFailed: err => console.warn(`[vela] shell.json unreadable (${err}), using defaults: ${root.path}`)

        adapter: JsonAdapter {
            id: adapter

            property AppearanceCfg appearance: AppearanceCfg {}
            property BarCfg bar: BarCfg {}
            property DockCfg dock: DockCfg {}
            property DashboardCfg dashboard: DashboardCfg {}
            property LauncherCfg launcher: LauncherCfg {}
            property NotificationsCfg notifications: NotificationsCfg {}
            property ClipboardCfg clipboard: ClipboardCfg {}
            property BackgroundCfg background: BackgroundCfg {}
            property CaptureCfg capture: CaptureCfg {}
            property SessionsCfg sessions: SessionsCfg {}
            property LockCfg lock: LockCfg {}
            property CalendarCfg calendar: CalendarCfg {}
            property WeatherCfg weather: WeatherCfg {}
            property UpdatesCfg updates: UpdatesCfg {}
            property Keybinds keybinds: Keybinds {}
        }
    }
}
