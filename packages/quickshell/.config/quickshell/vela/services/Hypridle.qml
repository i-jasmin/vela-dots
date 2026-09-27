pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// When the screen dims, locks, goes dark and the machine suspends: hypridle's
// four listeners, read from and written to its own config file.
//
// The file stays the one place these live. shell.json has no copy, so there
// is nothing to drift: the settings page reads the timeouts out of
// `~/.config/hypr/hypridle.conf`, and writes them back into the block between
// its `# vela: timeouts begin` and `# vela: timeouts end` lines, leaving the
// rest of the file -- the general block, the comments -- as it was. A listener
// is told apart by its on-timeout command, and one that is missing is "never".
//
// ON POWER AND ON BATTERY. A laptop keeps two sets, `power` and `battery`.
// hypridle has no idea of either, so where the two differ a listener is
// written for each, and each checks as it fires whether it is the one that
// applies (`if vela idle on battery; then ...; fi`, see the vela script).
// Where they agree there is one listener with no check, exactly as before --
// so a file nobody split reads and writes back unchanged, and a desktop,
// which only ever edits `power`, carries a battery set it never uses.
//
// hypridle reads its config once, at start, so a change is followed by a
// restart -- but only of a hypridle that was running: this does not start one
// somebody chose not to run.
Singleton {
    id: root

    readonly property string path: `${Quickshell.env("HOME")}/.config/hypr/hypridle.conf`

    // Seconds idle, 0 for never, for each power source.
    property var power: root.none()
    property var battery: root.none()

    // The ones in force now: the battery set on a laptop running off its
    // battery, the power set otherwise.
    readonly property string source: Power.available && !Power.plugged ? "battery" : "power"
    readonly property var current: root.source === "battery" ? root.battery : root.power
    readonly property int dim: root.current.dim
    readonly property int lock: root.current.lock
    readonly property int screenOff: root.current.screenOff
    readonly property int suspend: root.current.suspend

    // The file was read and has the block to write into. Without it the page
    // explains rather than offering controls that would write nowhere.
    property bool available: false
    property bool running: false

    readonly property var order: ["dim", "lock", "screenOff", "suspend"]

    // The listener each one writes: its comment and its commands, exactly as
    // the shipped file has them, so a round trip through the settings page
    // leaves an unchanged file unchanged.
    readonly property var listeners: ({
            dim: {
                title: "Dim the backlight",
                comment: ["Dim the backlight as a warning. -s saves the current level so -r can put it", "back exactly, including if you were already at 5%."],
                commands: ["on-timeout = brightnessctl -s set 10%", "on-resume = brightnessctl -r"]
            },
            lock: {
                title: "Lock",
                comment: ["Lock."],
                commands: ["on-timeout = loginctl lock-session"]
            },
            screenOff: {
                title: "Screen off",
                comment: ["Screen off. Separate from the lock so the lock screen is already up behind", "it when the panel comes back."],
                commands: ["on-timeout = $screenOff", "on-resume = $screenOn"]
            },
            suspend: {
                title: "Suspend",
                comment: ["Suspend."],
                commands: ["on-timeout = $suspend"]
            }
        })

    // A listener for only one source runs its command inside a check. An
    // `if`, not `&&`: the suspend command is itself `systemctl suspend ||
    // loginctl suspend`, and `check && a || b` runs b when the check fails.
    function guard(source: string, command: string): string {
        return `if vela idle on ${source}; then ${command}; fi`;
    }

    // Said once at the top of the block, when anything in it is split.
    readonly property var splitNote: ["A listener that runs its command inside `if vela idle on battery` is only", "for when the laptop runs off its battery, one inside `if vela idle on power`", "only for when it is plugged in. One with neither is for both."]

    // Dim, when it is split: `vela idle dim` saves the level only once in an
    // idle stretch, so a second dim listener firing after the power cord is
    // pulled does not make 10% the level to go back to.
    readonly property var splitDim: ["on-timeout = vela idle dim", "on-resume = vela idle undim"]

    readonly property string begin: "# vela: timeouts begin"
    readonly property string end: "# vela: timeouts end"

    // Whether hypridle is running, asked again.
    function check(): void {
        probe.running = true;
    }

    function none(): var {
        return {
            dim: 0,
            lock: 0,
            screenOff: 0,
            suspend: 0
        };
    }

    // One timeout of one source, "power" or "battery". The set is replaced
    // whole, so everything bound to it hears.
    function set(source: string, which: string, seconds: int): void {
        if (!root.available || root[source][which] === seconds)
            return;
        const next = Object.assign({}, root[source]);
        next[which] = seconds;
        root[source] = next;
        save.restart();
    }

    // The source a listener's command checks for, "" for none, and the
    // command without the check.
    function guardOf(command: string): string {
        return command.match(/^if\s+vela idle on (power|battery)\s*;\s*then\s.*;\s*fi\s*$/)?.[1] ?? "";
    }
    function unguarded(command: string): string {
        return command.replace(/^if\s+vela idle on (?:power|battery)\s*;\s*then\s+(.*?)\s*;\s*fi\s*$/, "$1");
    }

    // Which of the four a listener is, from what it runs.
    function kindOf(onTimeout: string): string {
        if (/brightnessctl|vela idle dim/.test(onTimeout))
            return "dim";
        if (/lock-session|\$lock\b|hyprlock|ipc call lock/.test(onTimeout))
            return "lock";
        if (/\$screenOff|dpms/.test(onTimeout))
            return "screenOff";
        if (/\$suspend|suspend/.test(onTimeout))
            return "suspend";
        return "";
    }

    function parse(text: string): void {
        const from = text.indexOf(root.begin);
        const to = text.indexOf(root.end);
        root.available = from !== -1 && to > from;
        if (!root.available)
            return;

        // A listener with no check is for both; one with a check is for its
        // source, and wins there over one for both.
        const found = {
            both: {},
            power: {},
            battery: {}
        };
        const block = text.slice(from, to);
        const listener = /listener\s*\{([^}]*)\}/g;
        for (let m = listener.exec(block); m !== null; m = listener.exec(block)) {
            const timeout = parseInt(m[1].match(/(?:^|\n)\s*timeout\s*=\s*(\d+)/)?.[1] ?? "0");
            const command = m[1].match(/on-timeout\s*=\s*(.*)/)?.[1] ?? "";
            const source = root.guardOf(command) || "both";
            const kind = root.kindOf(root.unguarded(command));
            if (kind && timeout > 0)
                found[source][kind] = timeout;
        }
        const read = s => {
            const out = root.none();
            for (const k of root.order)
                out[k] = found[s][k] ?? found.both[k] ?? 0;
            return out;
        };
        root.power = read("power");
        root.battery = read("battery");
    }

    function render(): string {
        const out = [root.begin, ""];
        // A listener for both is written as it always was; one for a single
        // source says which, and checks before it acts.
        const write = (k, seconds, source) => {
            const l = root.listeners[k];
            if (!source) {
                out.push(...l.comment.map(c => `# ${c}`), "listener {", `    timeout = ${seconds}`, ...l.commands.map(c => `    ${c}`), "}", "");
                return;
            }
            const commands = (k === "dim" ? root.splitDim : l.commands).map(c => c.replace(/^on-timeout = (.*)$/, (_, command) => `on-timeout = ${root.guard(source, command)}`));
            out.push(`# ${l.title}, ${source === "battery" ? "on battery" : "on power"}.`, "listener {", `    timeout = ${seconds}`, ...commands.map(c => `    ${c}`), "}", "");
        };
        if (root.order.some(k => root.power[k] !== root.battery[k]))
            out.push(...root.splitNote.map(c => `# ${c}`), "");
        for (const k of root.order) {
            if (root.power[k] === root.battery[k]) {
                if (root.power[k] > 0)
                    write(k, root.power[k], "");
                continue;
            }
            for (const s of ["power", "battery"])
                if (root[s][k] > 0)
                    write(k, root[s][k], s);
        }
        out.push(root.end);
        return out.join("\n");
    }

    // A slider drags through several values a second; the file is written,
    // and hypridle restarted, once it stops.
    Timer {
        id: save

        interval: 600
        onTriggered: {
            const text = file.text();
            const from = text.indexOf(root.begin);
            const to = text.indexOf(root.end);
            if (from === -1 || to < from)
                return;
            file.setText(text.slice(0, from) + root.render() + text.slice(to + root.end.length));
            restart.running = true;
        }
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        printErrors: false

        onLoaded: root.parse(file.text())
        onFileChanged: file.reload()
        onLoadFailed: root.available = false
    }

    // Waits for the old one to go before starting the new one: two hypridles
    // would each run every listener.
    Process {
        id: restart

        command: ["sh", "-c", "pgrep -x hypridle >/dev/null || exit 1; pkill -x hypridle; for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -x hypridle >/dev/null || break; sleep 0.1; done; setsid -f hypridle >/dev/null 2>&1"]
        onExited: probe.running = true
    }

    Process {
        id: probe

        running: true
        command: ["pgrep", "-x", "hypridle"]
        onExited: code => root.running = code === 0
    }
}
