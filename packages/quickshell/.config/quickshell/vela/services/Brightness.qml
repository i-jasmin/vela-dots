pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Backlight. Reads straight from sysfs -- watched, so the laptop's own
// brightness keys show up immediately -- and writes through brightnessctl,
// which carries the udev rules needed to do so unprivileged.
//
// The device is discovered rather than configured: whichever one brightnessctl
// itself picks when it is given none, which is the one the brightness keys in
// binds.lua drive. A laptop with two -- acpi_video0 and intel_backlight --
// otherwise had the OSD and the slider showing and setting one while the keys
// moved the other. Without brightnessctl, the first entry under
// /sys/class/backlight. A desktop with no backlight simply reports available:
// false and is left out of every surface that shows it.
Singleton {
    id: root

    property string device: ""

    readonly property string sysfs: device ? `/sys/class/backlight/${device}` : ""

    property int raw: 0
    property int max: 0

    readonly property bool available: device !== "" && max > 0
    readonly property real value: available ? raw / max : 0
    readonly property int percent: Math.round(value * 100)

    readonly property string icon: {
        if (value >= 0.66)
            return "brightness_high";
        if (value >= 0.33)
            return "brightness_medium";
        return "brightness_low";
    }

    function setPercent(p: int): void {
        if (!available)
            return;
        const clamped = Math.max(1, Math.min(100, Math.round(p)));
        setProc.command = ["brightnessctl", "-d", root.device, "-q", "set", `${clamped}%`];
        setProc.running = true;
    }

    function changePercent(delta: int): void {
        setPercent(percent + delta);
    }

    Process {
        id: setProc
    }

    // `running` goes last. Quickshell starts the process the moment the property
    // is assigned, and QML assigns an object's properties in declaration order,
    // so anything declared after it -- the command, the stdout parser -- is
    // attached to a process that has already run, and the output is lost.
    Process {
        command: ["sh", "-c", "d=$(brightnessctl -m -c backlight info 2>/dev/null | cut -d, -f1); [ -n \"$d\" ] || d=$(ls -1 /sys/class/backlight 2>/dev/null | head -n 1); echo \"$d\""]

        stdout: StdioCollector {
            onStreamFinished: {
                root.device = text.trim();
                if (!root.device)
                    console.warn("[vela] no backlight under /sys/class/backlight; brightness control hidden");
            }
        }

        running: true
    }

    FileView {
        path: root.sysfs ? `${root.sysfs}/brightness` : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.raw = parseInt(text()) || 0
        onLoadFailed: root.raw = 0
    }

    FileView {
        path: root.sysfs ? `${root.sysfs}/max_brightness` : ""
        printErrors: false
        onLoaded: root.max = parseInt(text()) || 0
        onLoadFailed: root.max = 0
    }
}
