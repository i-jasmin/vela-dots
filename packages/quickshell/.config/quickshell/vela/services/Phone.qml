pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The phone, through KDE Connect.
//
// KDE Connect's background service (kdeconnectd) does all the talking to the
// phone; `vela phone` asks it things over D-Bus, and `vela phone watch` prints
// what it knows as one line of JSON each time that changes. This reads those
// lines, and runs `vela phone <verb> <device>` for anything the bar's item,
// its popout or Settings, Phone asks of it.
//
// NOT INSTALLED WITH VELA. Settings, Phone, Set up installs it (`vela phone
// setup`, in a terminal). Until it is there nothing here runs: the watcher is
// a Python process for as long as it is on, and a machine with no phone
// should not pay for one.
//
// WHAT IT DOES NOT COVER. The phone's notifications come in through the
// ordinary notification server -- kdeconnectd posts every one -- and are
// `Notifs`'. Its music is an MPRIS player kdeconnectd publishes, and
// `Players`'. Neither needs anything from here.
Singleton {
    id: root

    // Whether KDE Connect is on this machine at all, and whether it is up.
    property bool installed: false
    property bool running: false
    // This PC's name, as phones see it.
    property string name: ""
    // Every device KDE Connect knows: paired ones, and the unpaired ones it
    // can see on the network. Each is `vela phone status`'s device object.
    property var devices: []
    // The files phones sent most recently, newest first.
    property var received: []
    // Why the watcher stopped, when it did: a missing package, as a sentence.
    property string problem: ""

    readonly property var paired: root.devices.filter(d => d.paired)
    // The phone the bar and the popout are about: a paired phone in reach
    // (before a tablet that is), else any paired device in reach, else the
    // first paired one at all.
    readonly property var phone: root.paired.find(d => d.reachable && d.type === "phone") ?? root.paired.find(d => d.reachable) ?? root.paired[0] ?? null
    readonly property bool connected: root.running && (root.phone?.reachable ?? false)
    // Asking to be paired with this PC; and unpaired ones in reach.
    readonly property var requests: root.devices.filter(d => d.incoming)
    readonly property var nearby: root.devices.filter(d => !d.paired && !d.incoming && d.reachable)

    readonly property int battery: root.phone?.battery?.charge ?? -1
    readonly property bool charging: root.phone?.battery?.charging ?? false

    function has(plugin: string): bool {
        return root.phone?.plugins.includes(plugin) ?? false;
    }

    // The glyph for a device, by the type KDE Connect gives it.
    function iconFor(device: var): string {
        switch (device?.type) {
        case "tablet":
            return "tablet_android";
        case "laptop":
            return "laptop";
        case "desktop":
            return "desktop_windows";
        case "tv":
            return "tv";
        default:
            return "smartphone";
        }
    }

    // Charge as a glyph: one of the seven bars, with the bolt while charging.
    function batteryIcon(charge: int, charging: bool): string {
        if (charge < 0)
            return "battery_unknown";
        if (charge >= 95)
            return charging ? "battery_charging_full" : "battery_full";
        const bars = Math.max(0, Math.min(6, Math.floor(charge / 100 * 7)));
        const steps = [20, 20, 30, 50, 60, 80, 90];
        return charging ? `battery_charging_${steps[bars]}` : `battery_${bars}_bar`;
    }

    // --- What it does ------------------------------------------------------

    // Detached, so a file chooser left open does not hold anything up; what
    // went wrong, if anything did, comes back as a notification rather than
    // into a log nobody reads. A failure with nothing to say is one KDE
    // Connect has already announced (`vela phone browse`), and is not
    // announced twice.
    function run(args: var): void {
        Quickshell.execDetached(["sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; err=$(vela phone "$@" 2>&1 >/dev/null) || [ -z "$err" ] || notify-send -a vela -i dialog-error "$0" "${err#vela: }"', qsTr("Phone"), ...args]);
    }

    function ring(): void {
        if (root.phone)
            root.run(["ring", root.phone.id]);
    }

    // The desktop's own file chooser, then off to the phone.
    function pickFiles(): void {
        if (root.phone)
            root.run(["pick", root.phone.id]);
    }

    function sendClipboard(): void {
        if (root.phone)
            root.run(["clipboard", root.phone.id]);
    }

    // The phone's storage, mounted over SFTP and opened in Files.
    function browse(): void {
        if (root.phone)
            root.run(["browse", root.phone.id]);
    }

    function pair(id: string): void {
        root.run(["pair", id]);
    }

    function refuse(id: string): void {
        root.run(["refuse", id]);
    }

    function unpair(id: string): void {
        root.run(["unpair", id]);
    }

    function setAutoShare(id: string, on: bool): void {
        root.run(["autoshare", id, on ? "on" : "off"]);
    }

    function open(path: string): void {
        Quickshell.execDetached(["xdg-open", path]);
    }

    // In a terminal: dnf asks before it installs, and sudo for the password.
    // When it is done it tells the shell, which looks again and puts the
    // phone on the bar.
    function setup(): void {
        Quickshell.execDetached([Apps.terminal, "--title", qsTr("Setting up KDE Connect"), "-e", "sh", "-c", root.setupScript]);
    }

    readonly property string setupScript: `
        PATH="$HOME/.local/bin:$PATH" vela phone setup
        qs -c vela ipc call phone setUp >/dev/null 2>&1
        echo
        printf 'Press Enter to close this window. '
        read -r _
    `

    // --- The bar ----------------------------------------------------------

    readonly property bool onBar: [...Config.bar.modules.left, ...Config.bar.modules.centre, ...Config.bar.modules.right].includes("phone")

    // Before the status glyphs, where a device's state sits; at the end of
    // the run if there are none.
    function showOnBar(on: bool): void {
        const ends = ["left", "centre", "right"];
        if (!on) {
            for (const end of ends)
                Config.bar.modules[end] = Config.bar.modules[end].filter(m => m !== "phone");
        } else if (!root.onBar) {
            const right = [...Config.bar.modules.right];
            const tray = right.indexOf("tray");
            right.splice(tray >= 0 ? tray : right.length, 0, "phone");
            Config.bar.modules.right = right;
        }
        Config.save();
    }

    // --- Watching -----------------------------------------------------------

    function check(): void {
        if (!probe.running)
            probe.running = true;
    }

    // Set up has finished, and the phone goes on the bar if it worked: a dnf
    // that was cancelled or failed leaves the bar as it was.
    property bool placeOnBar: false

    // Installed is the D-Bus service file kdeconnectd ships, which is also
    // what lets the watcher start it. Looked at again after Set up, and
    // whenever Settings, Phone opens.
    Process {
        id: probe

        command: ["sh", "-c", "test -e /usr/share/dbus-1/services/org.kde.kdeconnect.service || command -v kdeconnectd >/dev/null"]
        onExited: code => {
            root.installed = code === 0;
            if (root.placeOnBar && root.installed && !root.onBar)
                root.showOnBar(true);
            root.placeOnBar = false;
        }
        running: true
    }

    // setpriv: Quickshell leaves its children running when it stops, and the
    // watcher would outlive every restart of the shell (see Clipboard).
    Process {
        id: watcher

        command: ["setpriv", "--pdeathsig", "TERM", "--", "sh", "-c", 'PATH="$HOME/.local/bin:$PATH" exec vela phone watch']

        stdout: SplitParser {
            onRead: data => {
                let s;
                try {
                    s = JSON.parse(data);
                } catch (e) {
                    return;
                }
                root.problem = "";
                root.installed = s.installed;
                root.running = s.running;
                root.name = s.name ?? "";
                root.devices = s.devices ?? [];
                root.received = s.received ?? [];
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const line = this.text.trim().split("\n").pop() ?? "";
                if (line)
                    root.problem = line.replace(/^vela:\s*/, "");
            }
        }

        // It only stops on its own if it cannot run at all -- python3-gobject
        // missing -- or the session bus went away. Tried again after a while
        // rather than in a loop.
        onExited: code => {
            root.running = false;
            if (root.installed)
                retry.restart();
        }

        running: root.installed
    }

    Timer {
        id: retry

        interval: 60000
        onTriggered: watcher.running = root.installed
    }

    IpcHandler {
        target: "phone"

        // `vela phone setup` is done: look again, and put the phone on the
        // bar if KDE Connect is there now.
        function setUp(): void {
            root.placeOnBar = true;
            root.check();
        }

        function ring(): void {
            root.ring();
        }

        function sendClipboard(): void {
            root.sendClipboard();
        }
    }
}
