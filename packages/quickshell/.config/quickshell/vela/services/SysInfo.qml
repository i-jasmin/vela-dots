pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory, swap, disk, network and thermals.
//
// Percentages are 0-100 reals, byte counts are bytes, and rates are bytes per
// second. Anything that has not been sampled yet reads 0, so a gauge must not
// treat 0 as "measured zero" on first frame -- bind to `available`.
//
// Everything that can come from a file comes from a file. This singleton lives
// for the whole session and samples every few seconds, so a `Process` per tick
// would be thousands of forks an hour on a laptop; the two exceptions (`df`,
// and finding the thermal sensor once) are called out where they happen.
Singleton {
    id: root

    // How often everything here is re-read. shell.json has no sampling key --
    // no settings page exposes such a control, and the settings window is the
    // only thing entitled to add one -- so the cadence is named here rather
    // than inlined. Three seconds is the longest gap at which the bar's CPU
    // figure still tracks what `top` says.
    readonly property int sampleInterval: 3000

    // A CPU percentage is a delta between two /proc/stat reads, so the first
    // read cannot produce one -- it can only establish a baseline. `available`
    // therefore means "a second sample has landed", which is also the point at
    // which every other figure here has been read at least once.
    readonly property bool available: cpuSamples > 1

    property real cpuPerc: 0
    property real cpuTemp: 0
    readonly property int cpuCores: cpuCorePercs.length
    property real loadAvg1: 0
    property real loadAvg5: 0
    property real loadAvg15: 0
    // Per-core percentages, for a bar-per-core meter.
    property var cpuCorePercs: []
    // Rolling window of recent cpuPerc samples for a sparkline; oldest first.
    property var cpuHistory: []

    // --- fast mode ----------------------------------------------------------
    //
    // The dashboard's System tab draws "CPU · last 60 s" as sixty bars and its
    // rings move live, which three-second sampling cannot give. While anything
    // holds fast mode, everything here is read every second, and three more
    // things are measured that nothing else pays for: the one-second series,
    // the clock speed and the busiest processes. Released, it all stops.
    property int fastHolds: 0
    readonly property bool fast: fastHolds > 0

    function holdFast(): void {
        root.fastHolds += 1;
    }

    function releaseFast(): void {
        root.fastHolds = Math.max(0, root.fastHolds - 1);
    }

    // One sample a second, oldest first, only while fast. Started empty each
    // time: a minute-old gap would be drawn as if it were the last minute.
    property var cpuRecent: []
    // Mean clock across cores, in GHz; 0 until read.
    property real cpuGhz: 0
    // The three commands using the most CPU, as a share of the whole machine:
    // [{ name, perc }]. Several processes of one program are summed.
    property var busiest: []

    onFastChanged: {
        root.cpuRecent = [];
        if (root.fast) {
            cpuinfo.reload();
            topProc.running = true;
        }
    }

    property real memUsed: 0
    property real memTotal: 0
    readonly property real memPerc: memTotal > 0 ? memUsed / memTotal * 100 : 0
    property real swapUsed: 0
    property real swapTotal: 0
    readonly property real swapPerc: swapTotal > 0 ? swapUsed / swapTotal * 100 : 0
    property var memHistory: []

    // `/` specifically, which is what a single disk gauge means.
    readonly property var rootDisk: disks.find(d => d.mount === "/") ?? null
    readonly property real diskUsed: rootDisk?.used ?? 0
    readonly property real diskTotal: rootDisk?.total ?? 0
    readonly property real diskPerc: rootDisk?.perc ?? 0
    // [{ mount, device, used, total, perc }]
    property var disks: []

    // GPU busy, 0-100. See the rc6 block below for where the figure comes from
    // and which GPU it describes on a machine with two.
    property real gpuPerc: 0
    property string gpuName: ""
    readonly property bool gpuAvailable: gpuPath !== ""
    property var gpuHistory: []

    // Every fan the platform driver exposes, in RPM. `fanRpm` is the fastest of
    // them, which is the one number the dashboard has room for -- the loud fan
    // is the one worth naming.
    property var fanRpms: []
    readonly property int fanRpm: fanRpms.length > 0 ? Math.max(...fanRpms) : 0
    readonly property bool fanAvailable: fanRpms.length > 0

    property real netUp: 0
    property real netDown: 0
    property string netInterface: ""
    property var netUpHistory: []
    property var netDownHistory: []

    property int uptime: 0
    property string kernel: ""
    property string distro: ""
    property string hostname: ""

    // Sixty samples: at the default 3s interval that is the last three minutes,
    // which is long enough for a sparkline to show the shape of a build or a
    // page load and short enough that the whole window is still "now". Widening
    // it costs nothing but stops the trace saying anything about the present.
    readonly property int historyLength: 60

    // How many /proc/stat reads have completed. Two is the minimum for a
    // percentage; see `available`.
    property int cpuSamples: 0

    // Per-CPU-line jiffy totals from the previous read, index 0 being the
    // aggregate `cpu` line and the rest the individual cores.
    property var lastTotals: []
    property var lastIdles: []

    // Byte counters plus the wall-clock millisecond they were read at. The
    // FileViews load asynchronously, so the gap between two reads is not
    // reliably the timer interval and has to be measured.
    property real lastRx: 0
    property real lastTx: 0
    property real lastRxAt: 0
    property real lastTxAt: 0

    // Resolved once at startup; empty until then. See thermalProbe.
    property string thermalPath: ""

    // Likewise for the GPU and the fans -- see gpuProbe and fanProbe.
    property string gpuPath: ""
    property var fanPaths: []

    // The rc6 counter and the wall-clock millisecond it was read at. Like the
    // network counters, the gap between two reads is not reliably the timer
    // interval and has to be measured rather than assumed.
    property real lastRc6: 0
    property real lastRc6At: 0

    function formatBytes(bytes: real, decimals: int): string {
        if (!bytes || bytes < 1)
            return "0 B";
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        const i = Math.min(units.length - 1, Math.floor(Math.log(bytes) / Math.log(1024)));
        const d = decimals === undefined ? 1 : decimals;
        return `${(bytes / Math.pow(1024, i)).toFixed(i === 0 ? 0 : d)} ${units[i]}`;
    }

    function formatRate(bytesPerSec: real): string {
        return `${formatBytes(bytesPerSec, 1)}/s`;
    }

    function formatUptime(): string {
        const d = Math.floor(uptime / 86400);
        const h = Math.floor((uptime % 86400) / 3600);
        const m = Math.floor((uptime % 3600) / 60);
        if (d > 0)
            return `${d}d ${h}h`;
        if (h > 0)
            return `${h}h ${m}m`;
        return `${m}m`;
    }

    // A `var` array mutated in place does not notify, so every history append
    // has to produce a new array. Trimming from the front here keeps the
    // window fixed and the oldest sample first, which is the order a sparkline
    // draws in.
    function roll(arr: var, value: real): var {
        const next = arr.concat(value);
        return next.length > historyLength ? next.slice(next.length - historyLength) : next;
    }

    function sample(): void {
        stat.reload();
        meminfo.reload();
        loadavg.reload();
        uptimeFile.reload();
        route.reload();
        if (root.netInterface) {
            rx.reload();
            tx.reload();
        }
        if (root.thermalPath)
            thermal.reload();
        if (root.gpuPath)
            rc6.reload();
        for (let i = 0; i < fans.count; i++)
            fans.objectAt(i).reload();
        if (root.fast)
            cpuinfo.reload();
    }

    function setFan(index: int, rpm: int): void {
        const next = root.fanRpms.slice();
        while (next.length <= index)
            next.push(0);
        next[index] = rpm;
        root.fanRpms = next;
    }

    Timer {
        running: true
        interval: root.fast ? 1000 : root.sampleInterval
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    FileView {
        id: cpuinfo

        path: "/proc/cpuinfo"
        onLoaded: {
            const mhz = [];
            for (const line of text().split("\n")) {
                const m = line.match(/^cpu MHz\s*:\s*([\d.]+)/);
                if (m)
                    mhz.push(parseFloat(m[1]));
            }
            root.cpuGhz = mhz.length > 0 ? mhz.reduce((a, b) => a + b, 0) / mhz.length / 1000 : 0;
        }
    }

    // Busiest processes. `top` rather than `ps`: ps's %CPU is an average over
    // each process's whole life, so a browser idle for an hour after a busy
    // start still tops the list. top's second frame is measured over the
    // second between the two, which is "now". C locale so a comma never
    // stands in for the decimal point.
    Process {
        id: topProc

        command: ["top", "-b", "-n", "2", "-d", "1", "-w", "512", "-o", "%CPU"]
        environment: ({
                LC_ALL: "C"
            })

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                let header = -1;
                for (let i = 0; i < lines.length; i++)
                    if (lines[i].trim().startsWith("PID"))
                        header = i;
                if (header < 0)
                    return;
                const cores = Math.max(1, root.cpuCores);
                const byName = {};
                for (let i = header + 1; i < lines.length; i++) {
                    const f = lines[i].trim().split(/\s+/);
                    if (f.length < 12)
                        break;
                    const name = f.slice(11).join(" ");
                    const perc = parseFloat(f[8]) || 0;
                    if (name === "top" || perc <= 0)
                        continue;
                    byName[name] = (byName[name] ?? 0) + perc / cores;
                }
                root.busiest = Object.keys(byName).map(n => ({
                            name: n,
                            perc: byName[n]
                        })).sort((a, b) => b.perc - a.perc).slice(0, 3);
            }
        }
    }

    // top takes a second to measure, so it is re-run a beat after each answer
    // rather than on the sampling tick.
    Timer {
        running: root.fast && !topProc.running
        interval: 2000
        onTriggered: topProc.running = true
    }

    // The second /proc/stat read is what turns a baseline into a percentage, so
    // at the configured interval nothing would be measurable for three seconds
    // and every gauge would sit in its empty state. One extra read shortly after
    // launch gets a real -- if short-windowed, and so noisier -- figure up
    // straight away; the regular cadence takes over from there.
    Timer {
        running: true
        interval: 250
        onTriggered: root.sample()
    }

    FileView {
        id: stat

        path: "/proc/stat"
        onLoaded: {
            const lines = text().split("\n");
            const totals = [];
            const idles = [];

            for (let i = 0; i < lines.length; i++) {
                const line = lines[i];
                // The cpu* block is contiguous and first; the moment a line is
                // something else (intr, ctxt, ...) there are no more cores.
                if (!line.startsWith("cpu"))
                    break;
                const f = line.split(/\s+/);
                // user nice system idle iowait irq softirq steal guest guest_nice.
                // Only the first eight are summed: guest time is already counted
                // inside user and nice, so including it inflates the total and
                // quietly deflates every percentage.
                let total = 0;
                for (let j = 1; j <= 8 && j < f.length; j++)
                    total += parseInt(f[j]) || 0;
                // iowait is idle as far as a "how busy is the machine" gauge is
                // concerned -- the CPU has nothing to run either way.
                const idle = (parseInt(f[4]) || 0) + (parseInt(f[5]) || 0);
                totals.push(total);
                idles.push(idle);
            }

            if (totals.length === 0)
                return;

            const prevTotals = root.lastTotals;
            const prevIdles = root.lastIdles;
            root.lastTotals = totals;
            root.lastIdles = idles;

            if (prevTotals.length !== totals.length) {
                // First read, or the core count changed under us (hotplug).
                // Either way there is no comparable baseline to subtract.
                root.cpuSamples = 1;
                return;
            }

            const percFor = i => {
                const dTotal = totals[i] - prevTotals[i];
                const dIdle = idles[i] - prevIdles[i];
                if (dTotal <= 0)
                    return -1;
                return Math.max(0, Math.min(100, (1 - dIdle / dTotal) * 100));
            };

            const aggregate = percFor(0);
            // Two reads inside the same jiffy measure nothing. Reporting the 0
            // that falls out of the arithmetic would be indistinguishable from
            // a genuinely idle machine, so the previous figure stands instead.
            if (aggregate < 0)
                return;

            const cores = [];
            for (let i = 1; i < totals.length; i++) {
                const p = percFor(i);
                cores.push(p < 0 ? (root.cpuCorePercs[i - 1] ?? 0) : p);
            }

            root.cpuPerc = aggregate;
            root.cpuCorePercs = cores;
            root.cpuHistory = root.roll(root.cpuHistory, aggregate);
            if (root.fast)
                root.cpuRecent = root.roll(root.cpuRecent, aggregate);
            root.cpuSamples++;
        }
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        onLoaded: {
            const fields = {};
            const lines = text().split("\n");
            for (let i = 0; i < lines.length; i++) {
                const colon = lines[i].indexOf(":");
                if (colon > 0)
                    fields[lines[i].slice(0, colon)] = (parseInt(lines[i].slice(colon + 1)) || 0) * 1024;
            }

            root.memTotal = fields.MemTotal ?? 0;
            // MemAvailable, not MemFree: the kernel's own estimate of what a new
            // allocation could get hold of, so reclaimable cache does not read
            // as used the way `free` used to show it.
            root.memUsed = Math.max(0, (fields.MemTotal ?? 0) - (fields.MemAvailable ?? fields.MemFree ?? 0));
            root.swapTotal = fields.SwapTotal ?? 0;
            root.swapUsed = Math.max(0, (fields.SwapTotal ?? 0) - (fields.SwapFree ?? 0));

            if (root.memTotal > 0)
                root.memHistory = root.roll(root.memHistory, root.memUsed / root.memTotal * 100);
        }
    }

    FileView {
        id: loadavg

        path: "/proc/loadavg"
        onLoaded: {
            const f = text().trim().split(/\s+/);
            root.loadAvg1 = parseFloat(f[0]) || 0;
            root.loadAvg5 = parseFloat(f[1]) || 0;
            root.loadAvg15 = parseFloat(f[2]) || 0;
        }
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        onLoaded: root.uptime = Math.floor(parseFloat(text().split(" ")[0]) || 0)
    }

    // Constant for the life of the session, so these three load once and are
    // never reloaded.
    FileView {
        path: "/proc/sys/kernel/osrelease"
        onLoaded: root.kernel = text().trim()
    }

    FileView {
        path: "/proc/sys/kernel/hostname"
        onLoaded: root.hostname = text().trim()
    }

    FileView {
        path: "/etc/os-release"
        printErrors: false
        onLoaded: {
            const m = text().match(/^PRETTY_NAME="?(.*?)"?$/m);
            root.distro = m ? m[1] : "";
        }
    }

    // --- network --------------------------------------------------------
    //
    // Rates are only interesting for the interface actually carrying traffic,
    // and /proc/net/route names it: the row whose destination is 00000000 is
    // the default route. Re-read every tick so a switch from Wi-Fi to wired --
    // or a VPN coming up -- moves the counters with it.
    FileView {
        id: route

        path: "/proc/net/route"
        onLoaded: {
            const lines = text().split("\n");
            let iface = "";
            for (let i = 1; i < lines.length; i++) {
                const f = lines[i].split(/\s+/);
                if (f.length > 2 && f[1] === "00000000") {
                    iface = f[0];
                    break;
                }
            }
            if (iface !== root.netInterface) {
                root.netInterface = iface;
                // The new interface's counters are unrelated to the old ones;
                // subtracting across the change would invent a huge spike.
                root.lastRxAt = 0;
                root.lastTxAt = 0;
                root.netUp = 0;
                root.netDown = 0;
            }
        }
        onLoadFailed: root.netInterface = ""
    }

    FileView {
        id: rx

        path: root.netInterface ? `/sys/class/net/${root.netInterface}/statistics/rx_bytes` : ""
        // An interface can vanish between the route read and this one; that is
        // ordinary on a roaming laptop and not worth a log line.
        printErrors: false
        onLoaded: {
            const now = Date.now();
            const value = parseFloat(text()) || 0;
            if (root.lastRxAt > 0 && now > root.lastRxAt)
                root.netDown = Math.max(0, (value - root.lastRx) * 1000 / (now - root.lastRxAt));
            root.lastRx = value;
            root.lastRxAt = now;
            root.netDownHistory = root.roll(root.netDownHistory, root.netDown);
        }
    }

    FileView {
        id: tx

        path: root.netInterface ? `/sys/class/net/${root.netInterface}/statistics/tx_bytes` : ""
        printErrors: false
        onLoaded: {
            const now = Date.now();
            const value = parseFloat(text()) || 0;
            if (root.lastTxAt > 0 && now > root.lastTxAt)
                root.netUp = Math.max(0, (value - root.lastTx) * 1000 / (now - root.lastTxAt));
            root.lastTx = value;
            root.lastTxAt = now;
            root.netUpHistory = root.roll(root.netUpHistory, root.netUp);
        }
    }

    // --- thermals -------------------------------------------------------
    //
    // hwmon numbering is assigned in probe order and changes between boots, so
    // the sensor cannot be a fixed path and a directory cannot be listed from
    // QML. One shell pass at startup resolves it; after that it is an ordinary
    // file read like everything else here.
    //
    // Package temperature is preferred over acpitz: acpitz is a board sensor
    // that lags the die badly, and on one chassis read several degrees low.
    Process {
        id: thermalProbe

        running: true
        command: ["sh", "-c", `
            for d in /sys/class/hwmon/*; do
                case "$(cat "$d/name" 2>/dev/null)" in
                coretemp|k10temp|zenpower)
                    for l in "$d"/temp*_label; do
                        [ -e "$l" ] || continue
                        case "$(cat "$l")" in
                        "Package id 0"|Tctl|Tdie) echo "$l" | sed 's/_label$/_input/'; exit 0 ;;
                        esac
                    done
                    echo "$d/temp1_input"; exit 0 ;;
                esac
            done
            for z in /sys/class/thermal/thermal_zone*; do
                [ "$(cat "$z/type" 2>/dev/null)" = x86_pkg_temp ] && { echo "$z/temp"; exit 0; }
            done
            for z in /sys/class/thermal/thermal_zone*; do
                [ "$(cat "$z/type" 2>/dev/null)" = acpitz ] && { echo "$z/temp"; exit 0; }
            done
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                root.thermalPath = text.trim();
                if (root.thermalPath)
                    thermal.reload();
            }
        }
    }

    FileView {
        id: thermal

        path: root.thermalPath
        printErrors: false
        // Both hwmon and thermal_zone report millidegrees Celsius.
        onLoaded: root.cpuTemp = (parseFloat(text()) || 0) / 1000
        onLoadFailed: root.cpuTemp = 0
    }

    // --- gpu ------------------------------------------------------------
    //
    // There is no utilisation counter in i915 sysfs, but there is an RC6
    // residency counter: milliseconds the render engine has spent in its
    // deepest sleep state. Busy time is the wall clock minus that, which is the
    // same figure intel_gpu_top prints and needs no privileges, no fork and no
    // per-tick process.
    //
    // On a machine with an Intel and an NVIDIA GPU, the Intel one drives the
    // display, so it is the one a "GPU" arc on the dashboard means. The
    // discrete NVIDIA one sits in D3cold whenever nothing is using it, and the
    // only way to read its utilisation is nvidia-smi, which *wakes it* --
    // polling it every few seconds would keep a 35W GPU resident for the sake
    // of a number that reads 0. It is deliberately not sampled.
    Process {
        id: gpuProbe

        running: true
        command: ["sh", "-c", `
            for c in /sys/class/drm/card*; do
                for f in "$c"/gt/gt*/rc6_residency_ms "$c"/power/rc6_residency_ms; do
                    [ -r "$f" ] || continue
                    d=$(sed -n 's/^DRIVER=//p' "$c/device/uevent" 2>/dev/null)
                    [ -n "$d" ] || d=gpu
                    echo "$f"
                    echo "$d"
                    exit 0
                done
            done
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length < 1 || !lines[0])
                    return;
                root.gpuName = lines[1] ?? "gpu";
                root.gpuPath = lines[0];
                rc6.reload();
            }
        }

        stderr: StdioCollector {}
    }

    FileView {
        id: rc6

        path: root.gpuPath
        printErrors: false
        onLoaded: {
            const now = Date.now();
            const value = parseFloat(text()) || 0;
            if (root.lastRc6At > 0 && now > root.lastRc6At) {
                const elapsed = now - root.lastRc6At;
                const asleep = Math.max(0, value - root.lastRc6);
                root.gpuPerc = Math.max(0, Math.min(100, (1 - asleep / elapsed) * 100));
                root.gpuHistory = root.roll(root.gpuHistory, root.gpuPerc);
            }
            root.lastRc6 = value;
            root.lastRc6At = now;
        }
        onLoadFailed: root.gpuPath = ""
    }

    // --- fans -----------------------------------------------------------
    //
    // hwmon numbering is assigned in probe order, so like the thermal sensor
    // the fans cannot be a fixed path. Every fan*_input under every hwmon is
    // taken: a platform driver can expose two, and which of them is the CPU fan
    // is not something the kernel says.
    Process {
        id: fanProbe

        running: true
        command: ["sh", "-c", `
            for f in /sys/class/hwmon/*/fan*_input; do
                [ -r "$f" ] && echo "$f"
            done
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.trim().split("\n").filter(l => !!l);
                root.fanPaths = found;
                root.fanRpms = found.map(() => 0);
            }
        }

        stderr: StdioCollector {}
    }

    // One FileView per fan, built from the probe's answer rather than written
    // out N times for an N nobody knows in advance.
    Instantiator {
        id: fans

        model: root.fanPaths

        delegate: FileView {
            required property int index
            required property string modelData

            path: modelData
            printErrors: false
            onLoaded: root.setFan(index, parseInt(text()) || 0)
            onLoadFailed: root.setFan(index, 0)
        }
    }

    // --- disks ----------------------------------------------------------
    //
    // There is no free-space figure anywhere under /proc or /sys -- it needs
    // statvfs, which QML cannot call -- so this is the one sampler that has to
    // fork. It runs a minute apart rather than every three seconds because
    // disk usage moves in megabytes per minute at worst, and a fork every tick
    // forever is exactly what this file is otherwise written to avoid.
    Timer {
        running: true
        interval: 60000
        repeat: true
        triggeredOnStart: true
        onTriggered: df.running = true
    }

    Process {
        id: df

        command: ["df", "-B1", "--output=source,target,size,used"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const found = [];
                const seen = {};
                for (let i = 1; i < lines.length; i++) {
                    const f = lines[i].trim().split(/\s+/);
                    if (f.length < 4)
                        continue;
                    const device = f[0];
                    // Real block devices only: tmpfs, devtmpfs, efivarfs and the
                    // rest are kernel bookkeeping, and a loop device is a mounted
                    // image rather than storage the user can fill.
                    if (!device.startsWith("/dev/") || device.startsWith("/dev/loop"))
                        continue;
                    // btrfs mounts every subvolume off the same device with the
                    // same totals; one row per device is what a disk list means.
                    if (seen[device])
                        continue;
                    const total = parseFloat(f[2]) || 0;
                    const used = parseFloat(f[3]) || 0;
                    if (total <= 0)
                        continue;
                    seen[device] = true;
                    found.push({
                        mount: f[1],
                        device: device,
                        used: used,
                        total: total,
                        perc: used / total * 100
                    });
                }
                root.disks = found;
            }
        }
    }
}
