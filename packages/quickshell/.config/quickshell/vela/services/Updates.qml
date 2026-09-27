pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Pending package updates -- the whole of the "what changed" overlay.
//
// The design assumes Arch: `checkupdates` for the repos and `paru -Qua` for
// the AUR. vela targets Fedora, so `Config.updates.checkCommand` is
// `dnf5 check-update --refresh` and there is no AUR. Nothing here is
// pacman-shaped: the command comes from the config, and what is parsed is the
// `name.arch  version  repo` table that both dnf5 and checkupdates happen to
// print, so pointing the config at either works.
//
// One process does the whole job, because every part of it needs the package
// list the first part produces, and three processes would mean three round
// trips and three chances to disagree with each other. It writes tab-separated
// records with a one-letter tag so the QML side is a switch rather than a
// parser.
Singleton {
    id: root

    // How often to look. shell.json has no `updates.intervalMinutes` -- no
    // settings page exposes one -- and the settings window is the only thing
    // entitled to add a key, so the cadence is named here instead of inlined.
    // An hour is the shortest interval that is not rude to a mirror.
    readonly property int intervalMinutes: 60

    // The configured checker exists and answered. False means the tool is not
    // installed, and the UI should say nothing rather than "0 updates".
    property bool available: false
    property bool checking: false
    property string tool: ""

    // [{ id, name, arch, oldVersion, newVersion, repo, source, security,
    //    severity, action, notable }]
    property var updates: []
    readonly property int count: updates.length
    readonly property int securityCount: updates.filter(u => u.security).length

    // The design's health chip reads "14 updates / 3 from AUR". There is no AUR
    // here; the same distinction on Fedora is between the distribution's own
    // repos and everything else -- copr, rpmfusion, a vendor repo -- which is
    // the line that actually matters when deciding whether to apply an update
    // unattended.
    readonly property int thirdPartyCount: updates.filter(u => u.source !== "fedora").length
    readonly property string sourceNote: {
        if (thirdPartyCount === 0)
            return "";
        const repos = [...new Set(updates.filter(u => u.source !== "fedora").map(u => u.source))];
        return repos.length === 1 ? `${thirdPartyCount} from ${repos[0]}` : `${thirdPartyCount} from ${repos.length} third-party repos`;
    }

    // The design splits the list in two: the handful that need the user to do
    // something, and the rest as a version diff. What needs doing is a property
    // of the package, not of the panel, so it is decided here.
    readonly property var notable: updates.filter(u => u.notable)
    readonly property var routine: updates.filter(u => !u.notable)

    // --- reboot ---------------------------------------------------------
    //
    // The reboot banner names both kernels, so both are kept rather than just
    // the verdict. The running one is what /proc says; the installed one is the
    // newest module tree on disk, which is what the next boot will pick.
    property string runningKernel: ""
    property string newestKernel: ""
    readonly property bool rebootRequired: !!runningKernel && !!newestKernel && runningKernel !== newestKernel

    // --- snapshots ------------------------------------------------------
    //
    // The design's footer offers a rollback to the pre-upgrade btrfs snapshot.
    // Where root is ext4, there is no snapshot to take and nothing to roll back
    // to. Saying so is the whole feature: a rollback button that does nothing
    // is worse than an absent one, and the dashboard's "Snapshot 2h ago" row
    // has to be able to read "Not available" instead.
    readonly property bool snapshotAvailable: false

    // `updates.snapshotBefore` was in the design's shell.json and was read by
    // nothing. It cannot be honoured here -- there is no subvolume to snapshot
    // -- but a key nothing reads is worse than one that cannot be granted, so
    // it is consulted and the refusal is said out loud. With the key off (the
    // shipped default) the reason is unchanged.
    readonly property bool snapshotRequested: Config.updates.snapshotBefore
    readonly property bool willSnapshot: root.snapshotRequested && root.snapshotAvailable
    // Not "root is ext4": Fedora's default root is btrfs, and what is missing is
    // the snapshot step itself, which vela does not take.
    readonly property string snapshotReason: root.snapshotRequested && !root.snapshotAvailable ? qsTr("Asked for, but vela does not take snapshots yet") : qsTr("No pre-upgrade snapshots")

    property date lastChecked: new Date(0)
    readonly property bool everChecked: lastChecked.getTime() > 0

    function refresh(): void {
        if (checking)
            return;
        checking = true;
        proc.running = true;
    }

    // Base Fedora repos, as dnf5 names them. Anything else is third party.
    function sourceOf(repo: string): string {
        const r = (repo ?? "").toLowerCase();
        if (r === "updates" || r === "fedora" || r.startsWith("updates-") || r.startsWith("fedora-"))
            return "fedora";
        if (r.startsWith("copr:"))
            return "copr";
        if (r.startsWith("rpmfusion"))
            return "rpmfusion";
        // `@commandline`, a vendor repo, whatever the user added.
        return r.replace(/^@/, "") || "other";
    }

    // What the user has to do after this package lands. The "Worth knowing"
    // card is exactly the set where this is not empty.
    function actionFor(name: string): string {
        const n = (name ?? "").toLowerCase();
        if (/^kernel(-|$)|^linux-firmware$|^systemd$|^glibc$|^dbus$/.test(n))
            return "Needs reboot";
        if (/^hyprland|^aquamarine$|^xdg-desktop-portal-hyprland$|^wayland$/.test(n))
            return "Restart the compositor to apply";
        if (/^quickshell/.test(n))
            return "Shell reloaded automatically";
        return "";
    }

    // fzf-0.74.4-1.fc43.x86_64 -> fzf.x86_64, so an advisory can be matched to
    // the row it belongs to. NEVRA has no separator the name cannot contain, so
    // this peels from the right: arch after the last dot, then release and
    // version as the last two hyphen-separated fields.
    function idFromNevra(nevra: string): string {
        const dot = nevra.lastIndexOf(".");
        if (dot < 0)
            return "";
        const arch = nevra.slice(dot + 1);
        const nvr = nevra.slice(0, dot);
        const parts = nvr.split("-");
        if (parts.length < 3)
            return `${nvr}.${arch}`;
        return `${parts.slice(0, parts.length - 2).join("-")}.${arch}`;
    }

    Timer {
        running: true
        interval: root.intervalMinutes * 60000
        repeat: true
        onTriggered: root.refresh()
    }

    // A check costs a metadata refresh over the network, which on a cold cache
    // is the better part of a minute -- doing it at `Component.onCompleted`
    // would compete with everything else the session is starting. Two minutes
    // in, the desktop is settled and the dashboard has a real figure without
    // anyone having opened it; the hourly timer takes over from there.
    Timer {
        running: true
        interval: 120000
        onTriggered: root.refresh()
    }

    Process {
        id: proc

        // Not `eval`: the configured string is run by a nested shell, so a
        // pipeline or a different tool works without this script quoting it.
        //
        // `set -- $CHECK` word-splits deliberately -- the first word is the
        // binary, and it is checked before anything is run so that an uninstalled
        // tool reports as absent rather than as zero updates.
        command: ["sh", "-c", `
            set -u
            export LC_ALL=C
            CHECK=$1

            set -- $CHECK
            TOOL=$1
            if ! command -v "$TOOL" >/dev/null 2>&1; then
                printf 'T\\tmissing\\t%s\\n' "$TOOL"
            else
                printf 'T\\tok\\t%s\\n' "$TOOL"

                OUT=$(sh -c "$CHECK" 2>/dev/null)
                # dnf5 ends with an "Obsoleting packages" table in the same
                # three-column shape, which is not a list of upgrades.
                PKGS=$(printf '%s\\n' "$OUT" | awk '
                    /^Obsoleting/ { exit }
                    NF == 3 && $1 ~ /\\.[A-Za-z0-9_]+$/ { print $1 "\\t" $2 "\\t" $3 }
                ')
                printf '%s' "$PKGS" | awk 'NF { print "U\\t" $0 }'

                NAMES=$(printf '%s' "$PKGS" | cut -f1)
                if [ -n "$NAMES" ]; then
                    # One rpm call for the whole list: the new version is in the
                    # table above, the old one is only on disk.
                    rpm -q --qf 'I\\t%{NAME}.%{ARCH}\\t%{EVR}\\n' $NAMES 2>/dev/null | grep -v 'not installed'
                    # Advisory id, type, severity, NEVRA, date. Absent on a
                    # repo without updateinfo metadata, which is not an error.
                    dnf5 updateinfo list --quiet 2>/dev/null | awk '$1 != "Name" && NF >= 4 { print "A\\t" $4 "\\t" $2 "\\t" $3 }'
                fi
            fi

            # The reboot banner in "what changed": what is running against the newest
            # module tree installed, which is what the next boot would pick.
            printf 'K\\t%s\\t%s\\n' "$(uname -r)" "$(ls -1 /lib/modules 2>/dev/null | sort -V | tail -1)"
        `, "sh", Config.updates.checkCommand]

        stdout: StdioCollector {
            onStreamFinished: {
                const rows = [];
                const installed = {};
                const advisories = {};

                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    switch (f[0]) {
                    case "T":
                        root.available = f[1] === "ok";
                        root.tool = f[2] ?? "";
                        break;
                    case "U":
                        rows.push({
                            id: f[1],
                            newVersion: f[2],
                            repo: f[3]
                        });
                        break;
                    case "I":
                        installed[f[1]] = f[2];
                        break;
                    case "A":
                        advisories[root.idFromNevra(f[1])] = {
                            type: f[2],
                            severity: f[3]
                        };
                        break;
                    case "K":
                        root.runningKernel = f[1] ?? "";
                        root.newestKernel = f[2] ?? "";
                        break;
                    }
                }

                root.updates = rows.map(r => {
                    const dot = r.id.lastIndexOf(".");
                    const name = dot > 0 ? r.id.slice(0, dot) : r.id;
                    const advisory = advisories[r.id] ?? null;
                    const action = root.actionFor(name);
                    return {
                        id: r.id,
                        name: name,
                        arch: dot > 0 ? r.id.slice(dot + 1) : "",
                        oldVersion: installed[r.id] ?? "",
                        newVersion: r.newVersion,
                        repo: r.repo,
                        source: root.sourceOf(r.repo),
                        security: advisory?.type === "security",
                        // "None" is what dnf5 prints for an advisory without a
                        // severity, which is not the same as an empty one.
                        severity: advisory && advisory.severity !== "None" ? advisory.severity : "",
                        action: action,
                        notable: !!action
                    };
                });

                root.lastChecked = new Date();
                root.checking = false;
            }
        }

        // dnf5 narrates its repository loading on stderr even with --quiet.
        stderr: StdioCollector {}

        onExited: root.checking = false
    }

    // A metadata refresh can be a minute long; leaving one running past a
    // reload would hold a repo lock nothing is waiting on.
    Component.onDestruction: proc.running = false
}
