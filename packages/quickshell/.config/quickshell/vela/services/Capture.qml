pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Screenshots, recordings and OCR for the capture overlay.
//
// The overlay draws the region and picks the verb; every verb is a process, and
// a module may not run one, so they live here. One call site: `run()`.
//
// COORDINATES. The overlay works in the coordinate space of its own layer-shell
// surface, which starts at 0,0 on whichever monitor it covers. `grim -g` wants
// the compositor's global space, where a second monitor starts at its own
// origin. Passing window-local coordinates straight through silently captures
// the wrong part of the wrong screen on any multi-monitor setup, so `run()`
// takes the monitor's name and adds its origin itself.
Singleton {
    id: root

    readonly property bool recording: recorder.running
    property int elapsed: 0
    // Where the recording will land, so the chip can offer to open it.
    property string lastFile: ""
    property string lastError: ""

    signal finished(string verb, string file)
    signal failed(string verb, string reason)

    function expand(path: string): string {
        return path.replace(/^~/, Quickshell.env("HOME"));
    }

    function stamp(): string {
        const d = new Date();
        const p = n => `${n}`.padStart(2, "0");
        return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}_${p(d.getHours())}-${p(d.getMinutes())}-${p(d.getSeconds())}`;
    }

    // `x` and `y` are window-local; `screenName` names the monitor the overlay
    // is on. Everything below works in global coordinates from here.
    function geometry(x: real, y: real, w: real, h: real, screenName: string): string {
        const mon = Hypr.monitorFor(screenName);
        const ox = mon?.x ?? 0;
        const oy = mon?.y ?? 0;
        return `${Math.round(x + ox)},${Math.round(y + oy)} ${Math.round(w)}x${Math.round(h)}`;
    }

    function run(verb: string, x: real, y: real, w: real, h: real, screenName: string): void {
        if (w < 1 || h < 1) {
            root.failed(verb, "empty region");
            return;
        }
        const g = root.geometry(x, y, w, h, screenName);

        if (verb === "stop") {
            root.stop();
            return;
        }

        if (verb === "record" || verb === "gif") {
            root.startRecording(verb, g);
            return;
        }

        const shots = expand(Config.capture.saveDir);
        const file = `${shots}/${root.stamp()}.png`;

        switch (verb) {
        case "copy":
            // grim writes PNG on stdout with `-`; wl-copy needs the type told.
            root.shoot(verb, "", ["sh", "-c", `grim -g '${g}' - | wl-copy --type image/png`]);
            break;
        case "save":
            root.shoot(verb, file, ["sh", "-c", `mkdir -p '${shots}' && grim -g '${g}' '${file}'`]);
            break;
        case "annotate":
            // swappy reads the shot on stdin and owns the save itself.
            root.shoot(verb, "", ["sh", "-c", `grim -g '${g}' - | swappy -f -`]);
            break;
        case "ocr":
            // tesseract's stdout is the text; the trailing newline it adds is
            // not wanted in a paste.
            // pipefail, and tesseract checked for up front: the exit status of
            // a pipeline is its last command's, so a missing tesseract used to
            // report success and replace the clipboard with nothing.
            root.shoot(verb, "", ["bash", "-o", "pipefail", "-c", `command -v tesseract >/dev/null || { echo "tesseract is not installed" >&2; exit 127; }; grim -g '${g}' - | tesseract - - -l ${Config.capture.ocrLanguage} 2>/dev/null | sed -e :a -e '/^\\n*$/{$d;N;};/\\n$/ba' | wl-copy`]);
            break;
        default:
            root.failed(verb, `unknown verb "${verb}"`);
            return;
        }
    }

    // Each shot is a process of its own, which knows its own verb and file.
    // They used to share one, and `exec()` on a process that is still running
    // ends it first: a second shot while swappy or tesseract still had the
    // first open reported that first one as a failed capture, under the
    // second's name, and the second then finished with no verb at all.
    function shoot(verb: string, file: string, command: var): void {
        root.lastFile = file;
        shotProcess.createObject(root, {
            verb: verb,
            file: file,
            command: command
        });
    }

    property string recordVerb: ""

    function startRecording(verb: string, g: string): void {
        if (recorder.running)
            return;
        const dir = expand(Config.capture.recordDir);
        const ext = verb === "gif" ? "gif" : "mp4";
        const file = `${dir}/${root.stamp()}.${ext}`;
        root.lastFile = file;
        root.recordVerb = verb;
        root.elapsed = 0;
        // GIF at 12 fps, through wf-recorder's filter: a GIF at the screen's
        // own rate is several times the size for motion nobody can see.
        // There is no palettegen/paletteuse pass, and cannot be one here:
        // palettegen only writes its palette at the end of the stream, which
        // wf-recorder never passes through its filters when it is stopped --
        // measured, the file came out empty. ffmpeg's fixed rgb8 palette it is.
        const cmd = verb === "gif" ? `mkdir -p '${dir}' && wf-recorder -g '${g}' -c gif -F fps=12 -f '${file}'` : `mkdir -p '${dir}' && wf-recorder -g '${g}' -f '${file}'`;
        recorder.command = ["sh", "-c", cmd];
        recorder.running = true;
    }

    // wf-recorder finalises its container on SIGINT. Killing it any harder
    // leaves an unplayable file, which is worse than no recording at all.
    function stop(): void {
        if (recorder.running)
            recorder.signal(2);
    }

    // Nothing on screen listened to `failed`, so a missing tool meant a
    // capture that silently did nothing. The shell is the notification server,
    // so a notification is the one place every surface already shows.
    readonly property var tools: ({
            annotate: "swappy",
            ocr: "tesseract",
            record: "wf-recorder",
            gif: "wf-recorder"
        })

    onFailed: (verb, reason) => {
        if (reason === "empty region")
            return;
        const tool = root.tools[verb] ?? "grim";
        const body = reason === "exited 127" ? qsTr("%1 is not installed").arg(tool) : (root.lastError || reason);
        Quickshell.execDetached(["notify-send", "-a", "vela", "-i", "dialog-error", qsTr("Capture failed"), body]);
    }

    Component {
        id: shotProcess

        Process {
            id: proc

            required property string verb
            required property string file

            running: true

            onExited: code => {
                if (code === 0)
                    root.finished(proc.verb, proc.file);
                else
                    root.failed(proc.verb, `exited ${code}`);
                proc.destroy();
            }

            stderr: StdioCollector {
                onStreamFinished: {
                    if (text.trim())
                        root.lastError = text.trim();
                }
            }
        }
    }

    Process {
        id: recorder

        onExited: code => {
            // 0 on a clean stop, 130 when SIGINT ended it -- both are success.
            if (code === 0 || code === 130)
                root.finished(root.recordVerb, root.lastFile);
            else
                root.failed(root.recordVerb, `exited ${code}`);
            root.recordVerb = "";
            root.elapsed = 0;
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.lastError = text.trim();
            }
        }
    }

    Timer {
        running: root.recording
        repeat: true
        interval: 1000
        onTriggered: root.elapsed++
    }
}
