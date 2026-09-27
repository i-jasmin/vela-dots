pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// MPRIS players, with one designated "active" player so widgets do not each
// have to pick, plus the audio tap the dashboard's waveform is drawn from.
//
// Named Players, not Mpris: Quickshell.Services.Mpris exports an `Mpris`
// singleton that this file reads from, and a local singleton of that name would
// shadow it in any file importing both. Net and Bt are short for the same
// reason.
//
// Preference goes to whatever is actually playing, and the choice sticks until
// that player stops or disappears -- otherwise the bar flips between a browser
// tab and a music player every few seconds.
Singleton {
    id: root

    readonly property list<MprisPlayer> all: Mpris.players.values
    readonly property list<MprisPlayer> controllable: all.filter(p => p.canControl)

    property MprisPlayer active: null

    readonly property bool hasActive: active !== null
    readonly property bool playing: active?.isPlaying ?? false
    readonly property string title: active?.trackTitle ?? ""
    readonly property string artist: active?.trackArtist ?? ""
    readonly property string album: active?.trackAlbum ?? ""
    readonly property string artUrl: active?.trackArtUrl ?? ""
    readonly property string identity: active?.identity ?? ""

    readonly property bool canGoNext: active?.canGoNext ?? false
    readonly property bool canGoPrevious: active?.canGoPrevious ?? false
    readonly property bool canSeek: (active?.canSeek ?? false) && lengthKnown

    // MPRIS never pushes position: a player reports it when asked and on seek,
    // so a progress indicator bound straight to it sits still. Both references
    // solve it the same way -- poke positionChanged on a timer -- and doing it
    // once here means every consumer gets a live position instead of each
    // growing its own timer.
    readonly property real position: active?.position ?? 0
    readonly property real length: active?.length ?? 0
    readonly property bool lengthKnown: (active?.lengthSupported ?? false) && length > 0
    readonly property real progress: lengthKnown ? Math.max(0, Math.min(1, position / length)) : 0

    // Shuffle and repeat, where the player supports them. `looping` is any
    // repeat at all; `cycleLoop` steps none -> playlist -> track -> none.
    readonly property bool canShuffle: (active?.shuffleSupported ?? false) && (active?.canControl ?? false)
    readonly property bool shuffling: active?.shuffle ?? false
    readonly property bool canLoop: (active?.loopSupported ?? false) && (active?.canControl ?? false)
    readonly property bool looping: (active?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
    readonly property bool loopingTrack: (active?.loopState ?? MprisLoopState.None) === MprisLoopState.Track

    function toggleShuffle(): void {
        if (root.canShuffle)
            root.active.shuffle = !root.active.shuffle;
    }

    function cycleLoop(): void {
        if (!root.canLoop)
            return;
        const s = root.active.loopState;
        root.active.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
    }

    function seek(fraction: real): void {
        if (canSeek)
            active.position = Math.max(0, Math.min(1, fraction)) * length;
    }

    // mm:ss, or h:mm:ss once it needs to be.
    function formatTime(seconds: real): string {
        if (!isFinite(seconds) || seconds < 0)
            return "--:--";
        const total = Math.floor(seconds);
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        const pad = n => n < 10 ? `0${n}` : `${n}`;
        return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
    }

    Timer {
        running: root.playing
        interval: 500
        repeat: true
        onTriggered: root.active?.positionChanged()
    }

    function playPause(): void {
        if (active?.canTogglePlaying)
            active.togglePlaying();
    }

    function next(): void {
        if (canGoNext)
            active.next();
    }

    function previous(): void {
        if (canGoPrevious)
            active.previous();
    }

    // A player the user picked by hand (the dashboard's Media tab). Kept for as
    // long as it exists: the automatic choice below re-runs every second, and
    // without this a paused player picked from the list was replaced by the
    // playing one a second later.
    property var chosen: null

    function choose(player: var): void {
        root.chosen = player;
        root.active = player;
    }

    function pick(): void {
        if (root.chosen && controllable.includes(root.chosen)) {
            root.active = root.chosen;
            return;
        }
        root.chosen = null;
        // Keep the current choice while it is still playing and still exists.
        if (root.active && controllable.includes(root.active) && root.active.isPlaying)
            return;
        root.active = controllable.find(p => p.isPlaying) ?? controllable[0] ?? null;
    }

    onControllableChanged: pick()

    Connections {
        target: Mpris.players

        function onValuesChanged(): void {
            root.pick();
        }
    }

    // isPlaying is per-player, so re-pick on a timer rather than wiring a
    // Connections to every player in a changing list.
    Timer {
        running: root.all.length > 0
        interval: 1000
        repeat: true
        onTriggered: root.pick()
    }

    // --- The audio tap ------------------------------------------------------
    //
    // MPRIS carries no audio, so a waveform has to come from somewhere else.
    // Two sources exist on a stock machine and both are real measurements --
    // nothing here is synthesised from the track position:
    //
    //   cava              a frequency spectrum of the output mix, one value
    //                     per bar, which is what the dashboard draws.
    //                     Optional package.
    //   PwNodePeakMonitor PipeWire's own peak meter on the default sink: one
    //                     amplitude per tick, always available. It drives
    //                     `level` (the lock screen's audio-reactive arc) and,
    //                     when cava is absent, a scrolling amplitude history
    //                     that stands in for the spectrum.
    //
    // Both are metering, not decoding, so neither can profile a whole track:
    // the bars are what is audible now, and consumers colour them by `progress`
    // rather than reading a per-track profile that does not exist.

    // How many bars the spectrum is asked for. Changing it rewrites cava's
    // config and restarts it, so consumers agree on one number rather than
    // each asking for its own.
    property int waveformBars: 24

    // Both taps cost CPU, so they run only while something is drawing them.
    // A surface calls hold on the way up and release on the way down.
    property int waveformHolds: 0
    readonly property bool tapping: waveformHolds > 0

    function holdWaveform(): void {
        waveformHolds += 1;
    }

    function releaseWaveform(): void {
        waveformHolds = Math.max(0, waveformHolds - 1);
    }

    // Instantaneous output amplitude, 0-1. Real, and zero when nothing plays.
    readonly property real level: peak.enabled ? Math.max(0, Math.min(1, peak.peak)) : 0

    // waveformBars values in 0-1. Empty until the tap has produced a frame, so
    // a consumer can tell "silent" from "no data" and draw an idle state.
    property var waveform: []

    readonly property bool cavaAvailable: cavaProc.available
    readonly property string waveformSource: !tapping ? "idle" : cavaAvailable ? "cava" : "peak"

    // Audio already holds the default sink in its own PwObjectTracker, which is
    // what makes the node readable here; a second tracker would be redundant.
    PwNodePeakMonitor {
        id: peak

        node: Audio.sink
        enabled: root.tapping && Audio.sink !== null
    }

    // The fallback spectrum: a scrolling window of the peak meter. Genuine
    // amplitude over time -- the oldest sample on the left, the newest on the
    // right -- rather than a spectrum, which is the honest limit of what
    // PipeWire's meter can say.
    Timer {
        running: root.tapping && !root.cavaAvailable
        interval: 50
        repeat: true

        onTriggered: {
            const bars = [...root.waveform];
            while (bars.length < root.waveformBars)
                bars.unshift(0);
            bars.push(root.level);
            root.waveform = bars.slice(bars.length - root.waveformBars);
        }
    }

    onTappingChanged: {
        if (!tapping)
            waveform = [];
    }

    // cava writes its own config file and has no command line for these, so one
    // is generated next to the rest of vela's cache. Rewritten whenever the bar
    // count changes; cava reads it only as it starts, so a running one is
    // restarted once the new file is on disk.
    FileView {
        id: cavaConfig

        path: `${Quickshell.env("HOME")}/.cache/vela/cava.conf`
        atomicWrites: true
        // The first launch on a new machine has no file to read; the write
        // below creates it, parent directories and all.
        printErrors: false

        Component.onCompleted: write()

        onSaved: {
            if (cavaProc.running) {
                cavaProc.restarting = true;
                cavaProc.exec(cavaProc.command);
            }
        }

        function write(): void {
            setText(`# Generated by vela -- edits are overwritten.
[general]
mode = normal
framerate = 60
autosens = 1
lower_cutoff_freq = 50
higher_cutoff_freq = 10000
bars = ${root.waveformBars}

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
channels = mono
mono_option = average

[smoothing]
noise_reduction = 35
`);
        }
    }

    Connections {
        target: root

        function onWaveformBarsChanged(): void {
            cavaConfig.write();
        }
    }

    Process {
        id: cavaProc

        // Cleared to false the first time cava fails to start, so the fallback
        // takes over instead of the shell retrying a missing binary forever.
        property bool available: true
        // Set while a new config ends the running cava, whose exit is then
        // not a failure.
        property bool restarting: false

        // Quickshell does not kill child processes on signal and does not run
        // QML teardown, so a bare `cava` would outlive the shell and reparent
        // to init -- one orphan per restart, all of them decoding audio.
        // setpriv asks the kernel to signal the child when its parent dies,
        // which is the only mechanism that also survives the shell being
        // SIGKILLed: a wrapper script that ties the child to a stdin pipe is
        // itself killed before its trap can run. Measured both ways.
        //
        // If setpriv is missing the process exits immediately and the waveform
        // falls back to the PipeWire peak meter, which is the same degradation
        // as cava itself being missing.
        command: ["setpriv", "--pdeathsig", "TERM", "--", "cava", "-p", cavaConfig.path]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: data => {
                const bars = data.split(";").filter(v => v !== "").map(v => Math.max(0, Math.min(1, parseInt(v) / 1000)));
                if (bars.length > 0)
                    root.waveform = bars;
            }
        }

        onExited: code => {
            if (cavaProc.restarting) {
                cavaProc.restarting = false;
                return;
            }
            // 127 is "command not found" from the wrapper; anything non-zero
            // while we still wanted it running means cava will not work here.
            if (code !== 0 && root.tapping) {
                cavaProc.available = false;
                root.waveform = [];
                console.warn(`[vela] cava unavailable (exit ${code}); waveform falls back to the PipeWire peak meter`);
            }
        }

        // Last, so stdinEnabled and the parser are both in place before the
        // child exists -- see the note in Clipboard's watcher.
        running: root.tapping && available
    }
}
