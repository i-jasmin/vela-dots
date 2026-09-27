import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// PAM authentication for the lock screen, reduced to one state and one message
// so the surface never has to follow the conversation itself.
//
// PAM is reached through pam_start_confdir(3), pointed at the stack shipped in
// assets/pam.d, so vela installs with `stow` alone -- nothing under /etc, no
// root. See that file for why it calls pam_unix alone rather than including
// the system stack.
//
// TWO RULES SHAPE EVERYTHING HERE, and both come from the same fact:
// ext-session-lock keeps the session locked even when the lock client dies, and
// the only way out is exiting Hyprland from a TTY.
//
//   1. An attempt always ends with a typeable field. A lock that stops
//      accepting passwords is a lockout, so nothing below can leave the field
//      disabled -- not a hung stack, not a PAM error, not a timeout.
//   2. A wrong password is never counted against the user. Only attempts PAM
//      could not *judge* are counted, and three of those in a row mean the
//      stack itself is broken, at which point the lock is no longer protecting
//      anything and lets go. That only holds while nobody at the keyboard can
//      cause one, which is why the stack is pam_unix alone and why a
//      *timeout* is never counted: a slow module (a fingerprint reader waiting
//      for a finger) is something anyone can make time out.
Scope {
    id: root

    enum State {
        Idle,
        Busy,
        Failed,
        Errored
    }

    readonly property string configName: "vela"
    readonly property string configDir: Quickshell.shellPath("assets/pam.d")
    readonly property string configPath: `${root.configDir}/${root.configName}`

    // Gate for engaging the lock at all. Watched rather than checked once, so
    // removing the stack disables locking rather than breaking it later.
    readonly property bool available: configFile.loaded

    property int state: Auth.Idle
    property string message: ""

    readonly property bool busy: root.state === Auth.Busy
    readonly property bool failed: root.state === Auth.Failed || root.state === Auth.Errored

    // PAM runs in a subprocess and a stack can block for a long time -- a
    // fingerprint prompt with no reader, an LDAP lookup with no network. Give
    // up rather than leave the field spinning with no way back.
    property int timeout: 30000

    // Consecutive attempts PAM could not judge at all. See rule 2 above.
    property int errorRuns: 0
    readonly property int releaseAfter: 3

    // How many wrong passwords have been given since the lock engaged. Shown,
    // never enforced: the count is information for the person typing, not a
    // budget that runs out.
    property int wrongTries: 0

    // The password waiting for PAM to ask for it. The conversation prompts
    // asynchronously, often after the user has already pressed Enter.
    property string pending: ""

    // Last message PAM flagged as an error ("account locked", "2 attempts
    // left"). Preferred over anything invented here.
    property string pamError: ""

    // Whether PAM has ever asked for a finger. `pam_fprintd` is `sufficient` in
    // this distribution's system-auth stack, but it only speaks when a reader
    // exists -- on a machine with none it is skipped in silence. So the
    // surface's fingerprint hint follows what PAM actually asks for rather than
    // a config key, which cannot know what hardware is attached. Sticky: it
    // survives reset(), because the reader does not come and go between
    // attempts. On a machine with no reader -- fprintd answers "No devices
    // available" -- the hint correctly never appears.
    property bool fingerprintPrompted: false

    signal authenticated
    // Authentication has become impossible. The lock is expected to let go.
    signal unusable(reason: string)

    function submit(password: string): void {
        if (root.state === Auth.Busy)
            return;

        // Counted like any other unjudgeable attempt: if the stack vanishes
        // while the lock is up, the release valve below still has to fire.
        if (!root.available) {
            root.errorRuns++;
            root.finish(Auth.Errored, qsTr("No PAM configuration at %1").arg(root.configPath));
            return;
        }

        root.message = "";
        root.pamError = "";
        root.pending = password;
        root.state = Auth.Busy;

        if (pam.start()) {
            watchdog.restart();
        } else {
            root.errorRuns++;
            root.finish(Auth.Errored, qsTr("Could not start authentication"));
        }
    }

    // Back to a blank, typeable field. Called whenever the lock engages, so a
    // previous attempt's error never greets the user.
    function reset(): void {
        watchdog.stop();
        if (pam.active)
            pam.abort();
        root.pending = "";
        root.pamError = "";
        root.message = "";
        root.wrongTries = 0;
        // A new lock starts with a full release valve, not one left one error
        // short by the last session.
        root.errorRuns = 0;
        root.state = Auth.Idle;
    }

    // Back to Idle without forgetting the attempt count -- what the first
    // keystroke after a failure does, so the error clears as the user types.
    function clearMessage(): void {
        if (root.state === Auth.Failed || root.state === Auth.Errored) {
            root.message = "";
            root.state = Auth.Idle;
        }
    }

    function finish(newState: int, text: string): void {
        root.pending = "";
        root.message = text;
        root.state = newState;

        if (root.errorRuns >= root.releaseAfter)
            root.unusable(qsTr("PAM failed %1 times in a row: %2").arg(root.errorRuns).arg(text));
    }

    PamContext {
        id: pam

        config: root.configName
        configDirectory: root.configDir

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;

            respond(root.pending);
            root.pending = "";
        }

        onPamMessage: {
            if (messageIsError)
                root.pamError = message;
            else if (/finger|swipe|reader/i.test(message))
                root.fingerprintPrompted = true;
        }

        // PamError is an enum, not a sentence. The message the user sees comes
        // from the conversation itself; this only has to reach the log.
        onError: err => console.warn(`[vela] lock: PAM error ${err}`)

        onCompleted: res => {
            // A completion that arrives after reset() or after the watchdog
            // gave up is stale: the state it would report is no longer true.
            if (root.state !== Auth.Busy)
                return;

            watchdog.stop();

            if (res === PamResult.Success) {
                root.errorRuns = 0;
                root.wrongTries = 0;
                root.pending = "";
                root.message = "";
                root.state = Auth.Idle;
                root.authenticated();
                return;
            }

            if (res === PamResult.Error) {
                root.errorRuns++;
                root.finish(Auth.Errored, root.pamError || qsTr("Authentication is unavailable"));
            } else if (res === PamResult.MaxTries) {
                // PAM's own limit, not ours, and it is not a lockout: the
                // stack is asked again from scratch on the next attempt.
                root.errorRuns = 0;
                root.wrongTries++;
                root.finish(Auth.Failed, root.pamError || qsTr("Too many attempts — try again"));
            } else {
                root.errorRuns = 0;
                root.wrongTries++;
                root.finish(Auth.Failed, root.pamError || qsTr("Incorrect password"));
            }
        }
    }

    Timer {
        id: watchdog

        interval: root.timeout
        onTriggered: {
            // abort() may or may not be followed by completed(); the state is
            // set here so a hung stack cannot leave the field disabled.
            // Not counted towards the release valve -- see rule 2.
            pam.abort();
            root.finish(Auth.Errored, qsTr("Authentication timed out"));
        }
    }

    FileView {
        id: configFile

        path: root.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: err => console.warn(`[vela] lock: no PAM stack at ${root.configPath} (${err}); locking is disabled`)
    }
}
