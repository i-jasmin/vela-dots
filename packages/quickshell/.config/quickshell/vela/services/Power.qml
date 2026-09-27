pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.services

// Battery and power profile -- everything the bar's Power popout shows, and
// the icon-over-percentage on the vertical bar.
//
// Battery and profile were two files. They are one because the popout is one:
// it reads the charge, the three profiles and the draw/health/charge-limit rows
// off a single object, and splitting them only meant every consumer imported
// both.
//
// Named Power, not PowerProfiles: Quickshell.Services.UPower already exports a
// `PowerProfiles` singleton and a `PowerProfile` enum, and a same-named file
// here silently wins the import race in any file that imports both -- which is
// exactly the trap `Bt` and `Net` are named around.
//
// Everything is stated in the units the UI wants: percent is 0-100, watts are
// watts, seconds are seconds. UPower's own fractional percentage is converted
// here once so nothing downstream has to remember it.
Singleton {
    id: root

    // --- thresholds -----------------------------------------------------
    //
    // shell.json has no battery group -- no settings page exposes a warning
    // level, and the settings window is the only thing entitled to add a key.
    // These are the levels the warnings below fire at; they are named rather
    // than inlined so that adding `battery.warnAt` later is one edit.
    readonly property int warnAt: 20
    readonly property int criticalAt: 10
    // The last call: a laptop past this is minutes from UPower's own critical
    // action, which hibernates or powers off.
    readonly property int emptyAt: 5

    // --- charge ---------------------------------------------------------

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool available: device?.isLaptopBattery ?? false

    // UPower reports 0-1; everything in the UI wants 0-100. Declaring this
    // `int` against the raw fraction would silently truncate every charge to 0.
    readonly property int percent: Math.round((device?.percentage ?? 0) * 100)
    readonly property bool charging: (device?.state ?? 0) === UPowerDeviceState.Charging
    readonly property bool full: (device?.state ?? 0) === UPowerDeviceState.FullyCharged
    // On AC, from UPower itself. `charging || full` missed "pending charge",
    // which is what a laptop at its charge limit reports while plugged in: the
    // icon showed battery bars and the low-battery warnings could fire on AC.
    readonly property bool plugged: available && !UPower.onBattery

    readonly property bool low: available && !plugged && percent <= warnAt
    readonly property bool critical: available && !plugged && percent <= criticalAt

    // Seconds until empty/full, whichever applies. 0 means UPower has not
    // gathered enough samples yet, which is normal for the first minute.
    readonly property int secondsRemaining: charging ? (device?.timeToFull ?? 0) : (device?.timeToEmpty ?? 0)

    readonly property string remainingText: {
        if (!available || secondsRemaining <= 0)
            return "";
        const h = Math.floor(secondsRemaining / 3600);
        const m = Math.floor((secondsRemaining % 3600) / 60);
        const label = charging ? "until full" : "remaining";
        return h > 0 ? `${h}h ${m}m ${label}` : `${m}m ${label}`;
    }

    // --- warnings -------------------------------------------------------
    //
    // UPower measures; it does not warn. On GNOME the desktop does that, and
    // here nothing did, so a laptop ran down to 3% in silence. These go out as
    // ordinary notifications -- over the session bus, to this shell's own
    // server -- so they land in the history, the bell dots for them, and do
    // not disturb and focus treat them like anything else: the two
    // critical ones get through, as every critical notification may.
    //
    // Each level is announced once per discharge, and takes the last one
    // away rather than stacking beside it; plugging in takes the warning away
    // too. A new notification each time rather than a replacement: replacing
    // updates the card in place, and once that card has gone from the screen
    // -- timed out, dismissed, cleared by do not disturb -- the update is
    // silent, which is the one thing a 5% warning must not be.
    readonly property int level: !available || plugged ? 101 : percent <= emptyAt ? emptyAt : percent <= criticalAt ? criticalAt : percent <= warnAt ? warnAt : 101
    // The lowest level already announced since the charger was last in.
    property int announced: 101
    property bool stuckAnnounced: false
    // UPower fills in over the first moments of a session, and a zero read
    // before then would announce an empty battery. Anything still below a
    // level once it has settled is real, and is announced then.
    property bool armed: false

    onLevelChanged: root.checkWarnings()
    onGaugeStuckChanged: root.checkWarnings()

    function checkWarnings(): void {
        if (!root.armed)
            return;
        if (!root.available || root.plugged) {
            if (root.announced < 101 || root.stuckAnnounced)
                Notifs.dismissGroup(root.warningApp);
            root.announced = 101;
            root.stuckAnnounced = false;
            return;
        }
        if (root.level < root.announced) {
            root.announced = root.level;
            const left = root.remainingText ? ` · ${root.remainingText}` : "";
            if (root.level === root.emptyAt)
                root.warn(2, "battery-empty", qsTr("Battery almost empty"), qsTr("%1% left — plug in now, or it will shut down or hibernate by itself").arg(root.percent));
            else if (root.level === root.criticalAt)
                root.warn(2, "battery-caution", qsTr("Battery critically low"), qsTr("%1% left%2 — plug in soon").arg(root.percent).arg(left));
            else
                root.warn(1, "battery-low", qsTr("Battery low"), qsTr("%1% left%2").arg(root.percent).arg(left));
        } else if (root.gaugeStuck && !root.stuckAnnounced) {
            // The one case the percentage cannot warn about, because it is the
            // number that has stopped.
            root.stuckAnnounced = true;
            root.warn(1, "battery-caution", qsTr("Battery reading may be wrong"), qsTr("Stuck at %1% while the voltage keeps falling — plug in soon").arg(root.percent));
        }
    }

    readonly property string warningApp: qsTr("Battery")

    // urgency: 1 normal, 2 critical. The `--` matters: without it gdbus reads
    // the trailing -1 (the server's default timeout) as an option and prints
    // its usage instead of calling anything.
    function warn(urgency: int, icon: string, summary: string, body: string): void {
        Notifs.dismissGroup(root.warningApp);
        notify.command = ["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify", "--", root.warningApp, "0", icon, summary, body, "[]", `{'urgency': <byte ${urgency}>}`, "-1"];
        notify.running = true;
    }

    Timer {
        interval: 8000
        running: true
        onTriggered: {
            root.armed = true;
            root.checkWarnings();
        }
    }

    Process {
        id: notify

        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                console.warn(`[vela] battery warning not sent: ${text.trim().split("\n")[0]}`)
        }
    }

    // --- draw -----------------------------------------------------------
    //
    // Watts in or out, as the firmware reports them. Zero is not a measurement:
    // a battery sitting at full on mains stops reporting a rate entirely -- the
    // sysfs `power_now` read fails with ENODEV rather than returning 0 -- so the
    // popout's Draw row has to be able to say "--" instead of an honest-looking
    // 0.0 W.
    readonly property real watts: device?.changeRate ?? 0
    readonly property bool measuring: watts > 0
    readonly property string drawText: measuring ? `${watts.toFixed(1)} W` : "--"

    // --- health ---------------------------------------------------------
    //
    // Energy the pack can hold now against what it shipped with.
    //
    // Not UPower's own figure: `healthSupported` read false on one battery
    // although UPower's own `capacity` field said 97.0758%, so binding to it
    // would have shown "--" on a machine that knows the answer. The kernel
    // reports the two numbers it is computed from, and a gauge measuring in
    // amp-hours rather than watt-hours names them CHARGE_FULL instead of
    // ENERGY_FULL -- the ratio is the same either way.
    readonly property real fullNow: raw.ENERGY_FULL ?? raw.CHARGE_FULL ?? 0
    readonly property real fullDesign: raw.ENERGY_FULL_DESIGN ?? raw.CHARGE_FULL_DESIGN ?? 0
    readonly property int health: {
        if (fullDesign > 0)
            return Math.round(fullNow / fullDesign * 100);
        return device?.healthSupported ? Math.round(device.healthPercentage) : 0;
    }
    readonly property int cycles: raw.CYCLE_COUNT ?? 0
    readonly property bool healthAvailable: available && health > 0
    readonly property string healthText: {
        if (!healthAvailable)
            return "--";
        return cycles > 0 ? `${health}% · ${cycles} cycles` : `${health}%`;
    }

    // --- charge limit ---------------------------------------------------
    //
    // The kernel's standard name for a charge ceiling. Only some firmware
    // exposes it -- there is no ACPI standard behind it, and the laptops that
    // do offer it do so through their own platform driver -- so the popout's
    // Charge limit row has to be able to read "not supported" rather than
    // invent an 80% that nothing is enforcing.
    readonly property int chargeLimit: raw.CHARGE_CONTROL_END_THRESHOLD ?? 0
    readonly property bool chargeLimitAvailable: chargeLimit > 0
    readonly property string chargeLimitText: chargeLimitAvailable ? `${chargeLimit}%` : "Not supported"

    // --- stuck gauge detection ------------------------------------------
    //
    // Some embedded controllers stop updating the charge figure while the
    // battery keeps draining. Everything that reads UPower then agrees on a
    // number that is simply wrong, and every low-battery safeguard -- UPower's
    // own critical action included -- keys off it, so the machine dies without
    // a warning.
    //
    // Pack voltage is measured separately by the fuel gauge and keeps moving
    // when the percentage does not, which makes it the one available check on
    // whether the percentage can be believed.
    //
    // displayDevice is a synthetic aggregate and carries an *empty* nativePath,
    // not a null one -- so `??` does not fall back and the path collapses to the
    // directory itself. The physical battery has to be found among the devices.
    readonly property UPowerDevice physical: UPower.devices.values.find(d => d.isLaptopBattery && d.nativePath) ?? null
    readonly property string sysfsPath: `/sys/class/power_supply/${physical?.nativePath || "BAT0"}`

    readonly property int millivolts: Math.round((raw.VOLTAGE_NOW ?? 0) / 1000)
    property int lastPercent: -1
    property int lastMillivolts: 0
    property int stillSamples: 0
    property int voltageDrop: 0

    // Percentage has not moved across several minutes while the pack voltage
    // has fallen measurably. One or the other alone is unremarkable.
    readonly property bool gaugeStuck: available && !plugged && stillSamples >= 6 && voltageDrop >= 60

    // --- sysfs ----------------------------------------------------------
    //
    // Every numeric power_supply attribute, as the kernel's own uevent file
    // lists them, with the POWER_SUPPLY_ prefix dropped. One read instead of
    // five: it is also the only way to tell "this firmware does not expose a
    // charge ceiling" from "this file happens not to have loaded yet", because
    // a missing key and a missing file are then the same thing.
    property var raw: ({})

    FileView {
        id: battery

        path: `${root.sysfsPath}/uevent`
        // sysfs does notify on a power_supply change, which is what moves the
        // voltage between the 30s samples below.
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: root.raw = ({})
        onLoaded: {
            const out = {};
            for (const line of text().split("\n")) {
                if (!line.startsWith("POWER_SUPPLY_"))
                    continue;
                const eq = line.indexOf("=");
                if (eq < 0)
                    continue;
                const key = line.slice("POWER_SUPPLY_".length, eq);
                const value = line.slice(eq + 1);
                // Only the numeric attributes; STATUS, TECHNOLOGY and the rest
                // are strings UPower already models better.
                if (/^-?[0-9]+$/.test(value))
                    out[key] = parseInt(value);
            }
            root.raw = out;
        }
    }

    Timer {
        running: root.available
        interval: 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // Belt and braces: if the inotify watch on sysfs does not fire,
            // the stuck-gauge detector would compare a value against itself
            // forever and never report anything.
            battery.reload();

            if (root.plugged || root.millivolts <= 0) {
                root.stillSamples = 0;
                root.voltageDrop = 0;
                root.lastPercent = root.percent;
                root.lastMillivolts = root.millivolts;
                return;
            }
            if (root.lastPercent === root.percent) {
                root.stillSamples++;
                if (root.lastMillivolts > 0)
                    root.voltageDrop += Math.max(0, root.lastMillivolts - root.millivolts);
            } else {
                root.stillSamples = 0;
                root.voltageDrop = 0;
            }
            root.lastPercent = root.percent;
            root.lastMillivolts = root.millivolts;
        }
    }

    readonly property string icon: {
        if (!available)
            return "power";
        if (gaugeStuck)
            return "battery_unknown";
        if (full)
            return "battery_full";
        if (charging)
            return "battery_charging_full";
        // Material Symbols ships discrete bars rather than a scalable glyph.
        const bars = ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar", "battery_5_bar", "battery_6_bar"];
        return bars[Math.min(bars.length - 1, Math.floor(percent / 100 * bars.length))];
    }

    // --- power profiles -------------------------------------------------
    //
    // power-profiles-daemon, over D-Bus. The D-Bus work is Quickshell's: its
    // UPower module already owns a live connection to net.hadess.PowerProfiles,
    // so this is a translation layer -- enum to contract string, and an honest
    // `profilesAvailable`.

    // Quickshell's PowerProfiles reports Balanced whether the daemon is absent
    // or genuinely balanced, so it cannot answer "is there a daemon". The one
    // reliable answer is asking the bus, which also returns the real profile
    // list: not every machine offers `performance`, and a segmented control
    // with an option the daemon will refuse is a dead third of the control.
    property bool profilesAvailable: false
    property var profiles: ["power-saver", "balanced", "performance"]

    // "power-saver" | "balanced" | "performance"
    readonly property string profile: {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:
            return "power-saver";
        case PowerProfile.Performance:
            return "performance";
        default:
            return "balanced";
        }
    }

    readonly property string degradedReason: {
        switch (PowerProfiles.degradationReason) {
        case PerformanceDegradationReason.LapDetected:
            return "Lap detected";
        case PerformanceDegradationReason.HighTemperature:
            return "High temperature";
        default:
            return "";
        }
    }

    readonly property string profileIcon: profile === "power-saver" ? "energy_savings_leaf" : profile === "performance" ? "rocket_launch" : "balance"

    // The design labels the segmented options Saver / Balanced / Performance --
    // short enough for a 292px popout split three ways. The long form is what
    // the dashboard's health chip shows.
    function shortLabel(name: string): string {
        return name === "power-saver" ? "Saver" : name === "performance" ? "Performance" : "Balanced";
    }

    function longLabel(name: string): string {
        return name === "power-saver" ? "Power saver" : name === "performance" ? "Performance" : "Balanced";
    }

    readonly property string profileLabel: longLabel(profile)

    // How many times the bus has been asked whether the daemon is there.
    property int probes: 0

    function setProfile(name: string): void {
        if (!profilesAvailable || !profiles.includes(name))
            return;
        switch (name) {
        case "power-saver":
            PowerProfiles.profile = PowerProfile.PowerSaver;
            break;
        case "performance":
            PowerProfiles.profile = PowerProfile.Performance;
            break;
        default:
            PowerProfiles.profile = PowerProfile.Balanced;
            break;
        }
    }

    // Steps through what the daemon actually offers, in its own order, so a
    // two-profile machine wraps after balanced rather than sticking.
    function cycleProfile(): void {
        if (!profilesAvailable || profiles.length === 0)
            return;
        const i = profiles.indexOf(profile);
        setProfile(profiles[(i + 1) % profiles.length]);
    }

    Timer {
        // The daemon and the shell both come up with the session and neither
        // waits for the other, so one failed probe at startup is not proof of
        // absence. Three attempts covers a slow start; past that the daemon is
        // not installed and polling on forever would be waste.
        running: !root.profilesAvailable && root.probes < 3
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.probes++;
            probe.running = true;
        }
    }

    Process {
        id: probe

        command: ["busctl", "--system", "--json=short", "get-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "Profiles"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // aa{sv}: one dict per profile, each with a Profile name and
                    // the driver backing it. On Fedora the provider is tuned-ppd
                    // rather than power-profiles-daemon itself, which is exactly
                    // why this asks the interface rather than looking for a
                    // particular service.
                    const entries = JSON.parse(text).data;
                    const names = entries.map(e => e.Profile?.data).filter(n => !!n);
                    if (names.length === 0)
                        return;
                    root.profiles = names;
                    root.profilesAvailable = true;
                } catch (e) {
                    // No daemon, or a reply in a shape this does not understand.
                    // Either way there is nothing safe to drive.
                }
            }
        }

        // busctl writes a perfectly ordinary "not provided by any .service
        // file" to stderr when the daemon is absent, which is not a fault.
        stderr: StdioCollector {}
    }
}
