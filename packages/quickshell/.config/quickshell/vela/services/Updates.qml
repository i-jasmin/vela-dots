pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Pending package updates: the line in the dashboard's System tab, and the
// "what changed" overlay it opens.
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

    // Whether to look at all: Settings, General, "Check for updates". Off,
    // nothing here runs, and the System tab's line and "what changed" go.
    readonly property bool enabled: Config.updates.showWhatChanged

    // How often to look. shell.json has no `updates.intervalMinutes` -- no
    // settings page exposes one -- and the settings window is the only thing
    // entitled to add a key, so the cadence is named here instead of inlined.
    // Six hours, because the command vela ships forces a metadata refresh, and
    // Fedora's updates repository is set to go stale after six hours anyway
    // (`metadata_expire=6h`): hourly, it went to the mirrors six times as
    // often as dnf itself would. Updating by hand is noticed sooner (`look`).
    readonly property int intervalMinutes: 360

    // The configured checker exists and answered. False means the tool is not
    // installed, and the UI should say nothing rather than "0 updates".
    property bool available: false
    property bool checking: false
    property string tool: ""

    // What the last check could not do. `failed` is why it could not check at
    // all -- dnf stopped with an error, or reached no repository -- and then
    // there is no list. Otherwise the list stands, short of the repositories
    // whose signing key this user has not accepted yet (by the key's name;
    // `dnf5 check-update` in a terminal asks, once) and the ones that did not
    // answer.
    property string failed: ""
    property var keys: []
    property var unreachable: []

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

    property date lastChecked: new Date(0)
    readonly property bool everChecked: lastChecked.getTime() > 0

    // Something to say in the System tab: the check is on and has answered.
    readonly property bool shown: root.enabled && root.available && root.everChecked

    // When the rpm database last changed, as of the last check. Installing or
    // updating anything changes it; reading it does not.
    property string rpmStamp: ""

    function refresh(): void {
        if (checking || !root.enabled)
            return;
        checking = true;
        proc.running = true;
    }

    // Asked as the System tab opens: if packages were installed or updated
    // since the last check -- a `dnf upgrade` in a terminal -- check again,
    // rather than go on showing what was waiting before it for hours. A stat,
    // not a check, unless something changed.
    function look(): void {
        if (root.enabled && root.everChecked && !root.checking && !stamp.running)
            stamp.running = true;
    }

    // Switched on in Settings: look now, rather than in six hours. Not while
    // the session is starting -- shell.json loading moves the switch too, and
    // the first check waits for the desktop to settle (below).
    onEnabledChanged: {
        if (root.enabled && root.settled)
            root.refresh();
        else if (!root.enabled)
            proc.running = false;
    }

    // Updating is dnf's to do, in a terminal where it can be watched: what it
    // is about to change, its question before it does, the password. Offered
    // for the checker vela ships, whose upgrade command is known.
    readonly property bool canUpgrade: root.tool === "dnf5" || root.tool === "dnf"

    // The terminal, on `sudo dnf upgrade --refresh`. Once dnf is done it asks
    // the shell to check again (`updates check`, below), so the count on the
    // bar goes without waiting six hours, and it waits for Enter, so what dnf
    // said can still be read. Detached: restarting the shell must not take a
    // running upgrade down with it.
    function upgrade(): void {
        if (root.canUpgrade)
            Quickshell.execDetached([Apps.terminal, "--title", qsTr("Updating Fedora"), "-e", "sh", "-c", root.upgradeScript, "sh", root.tool]);
    }

    readonly property string upgradeScript: `
        sudo "$1" upgrade --refresh
        code=$?
        echo
        if [ "$code" -eq 0 ]; then echo "Done."; else echo "dnf stopped (exit $code)."; fi
        qs -c vela ipc call updates check >/dev/null 2>&1
        printf 'Press Enter to close this window. '
        read -r _
    `

    // Check now, from a terminal or a keybind -- and from the update window
    // above, once dnf is done:
    //   qs -c vela ipc call updates check
    IpcHandler {
        target: "updates"

        function check(): void {
            root.refresh();
        }
    }

    // The rpm database and its write-ahead log, wherever this Fedora keeps
    // them (/var/lib/rpm is a link to the first on a current one): the newest
    // modification time of the lot.
    readonly property string stampScript: "stat -c %Y /usr/lib/sysimage/rpm/rpmdb.sqlite /usr/lib/sysimage/rpm/rpmdb.sqlite-wal /var/lib/rpm/rpmdb.sqlite /var/lib/rpm/rpmdb.sqlite-wal 2>/dev/null | sort -n | tail -1"

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
        running: root.enabled
        interval: root.intervalMinutes * 60000
        repeat: true
        onTriggered: root.refresh()
    }

    // A check costs a metadata refresh over the network, which on a cold cache
    // is the better part of a minute -- doing it at `Component.onCompleted`
    // would compete with everything else the session is starting. Two minutes
    // in, the desktop is settled and the dashboard has a real figure without
    // anyone having opened it; the six-hourly timer takes over from there.
    property bool settled: false

    Timer {
        running: true
        interval: 120000
        onTriggered: {
            root.settled = true;
            root.refresh();
        }
    }

    Process {
        id: stamp

        command: ["sh", "-c", root.stampScript]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== root.rpmStamp)
                    root.refresh();
            }
        }
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
            # Nothing can answer dnf here, and a question left waiting on an
            # open input waits forever: the check never ends and the line
            # never comes. Closed, a question -- a repository's signing key to
            # accept -- is answered no, and that repository is left out.
            exec </dev/null

            set -- $CHECK
            TOOL=$1
            if ! command -v "$TOOL" >/dev/null 2>&1; then
                printf 'T\\tmissing\\t%s\\n' "$TOOL"
            else
                printf 'T\\tok\\t%s\\n' "$TOOL"

                # A repository left out -- its key refused, as above, or not
                # answering -- does not change the exit code (Fedora skips an
                # unavailable repository), so what was left out, and why, is
                # read off what dnf says on the way.
                ERRF=$(mktemp)
                OUT=$(sh -c "$CHECK" 2>"$ERRF")
                printf 'X\\t%s\\n' "$?"
                awk '
                    /^Importing OpenPGP key/ { key = 1; next }
                    key && /UserID/ { sub(/^[^"]*"/, ""); sub(/".*$/, ""); print "S\\tkey\\t" $0; key = 0; next }
                    /\\?\\?\\?%/ { r = $0; sub(/^ +/, "", r); sub(/ +\\?\\?\\?%.*$/, "", r); print "S\\tdown\\t" r; next }
                    / 100% / { loaded++ }
                    /^Error: / { err = $0 }
                    END { print "L\\t" loaded + 0; if (err != "") print "F\\t" err }
                ' "$ERRF"
                rm -f "$ERRF"
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

            # The rpm database as this answer saw it, for look().
            printf 'R\\t%s\\n' "$(${root.stampScript})"
        `, "sh", Config.updates.checkCommand]

        stdout: StdioCollector {
            onStreamFinished: {
                const rows = [];
                const installed = {};
                const advisories = {};
                const keys = [];
                const down = [];
                let code = 0;
                let loaded = -1;
                let error = "";

                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    switch (f[0]) {
                    case "X":
                        code = Number(f[1]);
                        break;
                    case "S":
                        (f[1] === "key" ? keys : down).push(f[2] ?? "");
                        break;
                    case "L":
                        loaded = Number(f[1]);
                        break;
                    case "F":
                        error = (f[1] ?? "").replace(/^Error: /, "");
                        break;
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
                    case "R":
                        root.rpmStamp = (f[1] ?? "").trim();
                        break;
                    }
                }

                // dnf5 exits 100 with updates waiting and 0 without.
                root.failed = code !== 0 && code !== 100 ? (error || qsTr("dnf stopped with an error")) : loaded === 0 && down.length > 0 ? qsTr("No repository could be reached") : "";
                root.keys = [...new Set(keys)];
                root.unreachable = [...new Set(down)];

                root.updates = root.failed ? [] : rows.map(r => {
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
