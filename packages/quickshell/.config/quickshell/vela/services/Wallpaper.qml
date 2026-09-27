pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.config
import qs.tokens

// The wallpaper folder, and the retint that re-themes from it.
//
// Applying runs `vela retint`, the same command the CLI uses, so there is one
// matugen config (~/.config/vela/matugen.toml) and one retint for the whole
// desktop: the shell's palette (scheme.json, which `Colours` watches), Hyprland,
// hyprlock, kitty, fuzzel and GTK all follow the same wallpaper. A bare
// `matugen` is never run, because it would read ~/.config/matugen, which may
// belong to a different rice.
//
// The wallpaper state lives in ~/.local/state/vela/wallpaper.json rather than
// in Quickshell's per-shell state directory, so `vela wallpaper` can record a
// choice while the shell is not running and the shell picks it up on start.
//
// Which image matugen reads matters too. Quantising a 7680x2160 JPEG takes
// about 310 ms on one machine, which blows the design's 200 ms budget on the
// extraction alone. A 480px copy takes 20 ms and lands within four units of
// 255 on one channel of one role -- invisible -- so a small copy is the source
// when there is one. The whole picture, though, not the cards' 480x300 crop:
// that leaves out half of an ultrawide wallpaper, and the palette came out
// different from the one `vela wallpaper` makes from the file itself.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string directory: {
        const d = Config.launcher.wallpaperDir ?? "";
        return d.startsWith("~") ? home + d.slice(1) : d;
    }

    // matugen is a separate package from everything else here; without it the
    // switcher still browses and sets wallpapers, it just cannot re-theme.
    property bool themerAvailable: false
    property bool scanning: false
    property string error: ""

    // [{ path, name, width, height, resolution, thumbnail, palette }],
    // name-ascending.
    property var wallpapers: []
    readonly property int count: wallpapers.length

    property string current: ""
    // The switcher binds `super + shift + W` to this.
    property string previous: ""
    // "Set for this monitor" -- { "DP-1": "/path" }. The palette is global;
    // only the image is per-monitor.
    property var perMonitor: ({})

    // The dashboard's caption, "coast-fog.jpg · matugen rebuild 180 ms", and
    // the switcher's "bar, panels and lock re-theme in ~180 ms": the whole
    // retint, from the request to every template having been written.
    property int lastRebuildMs: 0
    property bool applying: false

    // --- preview ----------------------------------------------------------
    //
    // The switcher shows the palette an image *would* generate, six swatches
    // with their hex, without applying it. `--dry-run` writes no template and
    // `--json hex` puts the whole scheme on stdout.
    property string previewPath: ""
    property bool previewing: false
    property var previewDark: ({})
    property var previewLight: ({})
    // The mode the switcher is previewing, which may not be the one in use
    // yet: its Light / Dark / Auto choice applies with the wallpaper. Empty
    // follows the config. Auto is whatever the sun says now.
    property string previewMode: ""
    readonly property bool previewLightMode: {
        const m = root.previewMode || Config.appearance.mode;
        if (m === "auto")
            return Sun.available ? Sun.day : Colours.light;
        return m === "light";
    }
    // The six roles the switcher swatches, in its order.
    readonly property var previewPalette: {
        const p = previewLightMode ? previewLight : previewDark;
        return {
            primary: p.primary ?? "",
            primaryContainer: p.primary_container ?? "",
            secondary: p.secondary ?? "",
            tertiary: p.tertiary ?? "",
            surface: p.surface ?? "",
            surfaceContainer: p.surface_container ?? ""
        };
    }
    readonly property string schemeLabel: `${Config.appearance.scheme} · ${previewLightMode ? "light" : "dark"}`

    readonly property string cacheDir: `${Quickshell.cacheDir}/wallpapers`
    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"}/vela`
    readonly property string statePath: `${stateDir}/wallpaper.json`
    // Where the state lived before it moved beside the CLI's; read once, so an
    // upgrade keeps the wallpaper that was set.
    readonly property string legacyStatePath: `${Quickshell.stateDir}/wallpaper.json`
    readonly property string matugenConfig: `${Quickshell.env("XDG_CONFIG_HOME") || home + "/.config"}/vela/matugen.toml`

    // The mode the other apps were last retinted in. The shell's own palette
    // carries both modes and flips on its own; kitty, GTK and Hyprland only get
    // the one they were generated in, so a light/dark switch re-runs the retint.
    property string lastMode: ""
    readonly property string mode: Colours.light ? "light" : "dark"
    property bool stateLoaded: false
    property real startedAt: 0

    function entryFor(path: string): var {
        return wallpapers.find(w => w.path === path) ?? null;
    }

    function currentFor(monitor: string): string {
        return perMonitor[monitor] ?? current;
    }

    // See the header: the small full-frame copy is fifteen times faster to
    // quantise and generates the same palette. Never the cropped thumbnail.
    function themingSource(path: string): string {
        const e = entryFor(path);
        return e && e.palette ? e.palette : path;
    }

    function refresh(): void {
        if (scanning || !directory)
            return;
        const files = [];
        for (let i = 0; i < folder.count; i++)
            files.push(`${folder.get(i, "filePath")}`);
        if (files.length === 0) {
            wallpapers = [];
            return;
        }
        scanning = true;
        probe.command = ["sh", "-c", probeScript, "vela", cacheDir].concat(files);
        probe.running = true;
    }

    // The switcher's two buttons. "Apply" sets the wallpaper everywhere and
    // re-themes from it; "Set for this monitor" changes one screen's image and
    // leaves the palette alone, because there is one palette and it follows the
    // wallpaper the user chose for the shell rather than the last screen they
    // happened to be pointing at.
    function apply(path: string, monitor: string): void {
        if (!path)
            return;
        if (monitor) {
            const next = Object.assign({}, perMonitor);
            next[monitor] = path;
            perMonitor = next;
            saveState();
            return;
        }
        if (current && current !== path)
            previous = current;
        current = path;
        // A wallpaper chosen for the shell replaces every per-monitor override.
        // Without this, applying one on a single-monitor machine sets `current`
        // and changes nothing on screen, because `currentFor()` prefers the
        // override that is still sitting there -- which is exactly how this
        // read as "the wallpaper will not change".
        if (Object.keys(perMonitor).length > 0)
            perMonitor = ({});
        saveState();
        retint(path);
    }

    // Regenerate every palette from `path` in the current mode. The image
    // itself does not change.
    function retint(path: string): void {
        if (!path || !themerAvailable || !Config.appearance.generateFromWallpaper)
            return;
        root.requestedMode = root.mode;
        if (themer.running || root.veil === "capturing") {
            // One at a time; the latest request wins once this one is done.
            pendingRetint = path;
            return;
        }
        // The windows are photographed first, so they can cross over to the
        // new colours together (see the veil, below); the retint itself waits
        // for the frames.
        if (root.veil === "" || root.veil === "lifting") {
            root.veilPath = path;
            root.veilReady = ({});
            veilLift.stop();
            veilSettle.stop();
            // Where each window is now: its position comes from a full
            // query, and the frames are drawn where it says.
            Hypr.refreshWindows();
            root.veil = "";
            root.veil = "capturing";
            veilCapture.restart();
            veilGuard.restart();
            return;
        }
        root.runRetint(path);
    }

    function runRetint(path: string): void {
        // A retint begun while the frames wait to fade keeps them up until
        // it too is done.
        veilSettle.stop();
        applying = true;
        error = "";
        startedAt = Date.now();
        themer.retintMode = root.mode;
        // The scheme is passed rather than left to the script to read back
        // from shell.json: a scheme picked in settings is written there as
        // this starts, and the write can land after the read.
        themer.command = ["sh", "-c", 'PATH="$HOME/.local/bin:$PATH" exec vela retint "$@"', "vela", themingSource(path), root.mode, Config.appearance.scheme];
        themer.running = true;
    }

    property string pendingRetint: ""
    // The mode the latest retint was asked for: a light/dark switch made
    // together with a new wallpaper (the switcher's Apply) is already being
    // retinted in, and needs no second retint of its own.
    property string requestedMode: ""

    function revert(): void {
        if (previous)
            apply(previous, "");
    }

    function preview(path: string): void {
        if (!path || !themerAvailable || previewing)
            return;
        previewPath = path;
        previewing = true;
        previewProc.command = ["matugen", "--config", matugenConfig, "--dry-run", "--json", "hex", "-q", "--source-color-index", "0", "-t", Config.appearance.scheme, "image", themingSource(path)];
        previewProc.running = true;
    }

    function saveState(): void {
        state.setText(JSON.stringify({
            current: root.current,
            previous: root.previous,
            perMonitor: root.perMonitor,
            mode: root.lastMode,
            lastRebuildMs: root.lastRebuildMs
        }));
    }

    // Dimensions and a 480px thumbnail for every image, in one subprocess
    // rather than two per file. The cache filename carries the source mtime and
    // the source dimensions, so an unchanged folder costs one `stat` per image
    // and no decoding at all, and a re-saved wallpaper invalidates itself.
    //
    // Two files come out of one decode: the 480x300 card, cropped, and the
    // whole picture within 480x480, which is what the palette is read from.
    // The key is a checksum of the full path: the file's name with anything
    // unusual turned into `_` made `a b.jpg` and `a_b.jpg` one entry.
    readonly property string probeScript: `
set -u
cache=$1
shift
mkdir -p "$cache"
keep=$cache/.keep
: > "$keep"
for f in "$@"; do
  [ -f "$f" ] || continue
  key=$(printf '%s' "$f" | cksum | tr ' ' '_')
  m=$(stat -c %Y "$f" 2>/dev/null) || continue
  t=
  for c in "$cache/$key-$m-"*.jpg; do
    if [ -f "$c" ]; then t=$c; break; fi
  done
  if [ -z "$t" ]; then
    d=$(magick identify -format '%w %h' "$f[0]" 2>/dev/null) || d=
    [ -n "$d" ] || d='0 0'
    w=$(echo "$d" | cut -d' ' -f1)
    h=$(echo "$d" | cut -d' ' -f2)
    t=$cache/$key-$m-$w-$h.jpg
    magick "$f[0]" \\( +clone -thumbnail 480x480 -write "\${t%.jpg}.png" +delete \\) -thumbnail 480x300^ -gravity center -extent 480x300 -quality 82 "$t" 2>/dev/null || t=
  fi
  p=
  if [ -n "$t" ]; then
    p=\${t%.jpg}.png
    [ -f "$p" ] || magick "$f[0]" -thumbnail 480x480 "$p" 2>/dev/null || p=
    echo "$t" >> "$keep"
    [ -z "$p" ] || echo "$p" >> "$keep"
  fi
  printf '%s\\t%s\\t%s\\n' "$t" "$f" "$p"
done
for c in "$cache"/*.jpg "$cache"/*.png; do
  [ -f "$c" ] || continue
  grep -qxF "$c" "$keep" || rm -f "$c"
done
rm -f "$keep"
`

    FolderListModel {
        id: folder

        folder: root.directory ? `file://${root.directory}` : ""
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp", "*.JPG", "*.JPEG", "*.PNG"]

        // The model repopulates a file at a time, so rescanning on every
        // countChanged would launch a subprocess per image on startup.
        onCountChanged: settle.restart()
        onStatusChanged: if (status === FolderListModel.Ready)
            settle.restart()
    }

    Timer {
        id: settle

        interval: 150
        onTriggered: root.refresh()
    }

    Process {
        id: probe

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (!lines[i].trim())
                        continue;
                    const parts = lines[i].split("\t");
                    const thumb = parts[0] ?? "";
                    const path = parts[1] ?? "";
                    const palette = parts[2] ?? "";
                    if (!path)
                        continue;
                    // key-<mtime>-<width>-<height>.jpg
                    const m = thumb.match(/-(\d+)-(\d+)-(\d+)\.jpg$/);
                    const w = m ? parseInt(m[2]) : 0;
                    const h = m ? parseInt(m[3]) : 0;
                    out.push({
                        path: path,
                        name: path.slice(path.lastIndexOf("/") + 1),
                        width: w,
                        height: h,
                        // The switcher's caption under the centre card.
                        resolution: w > 0 ? `${w} × ${h}` : "",
                        // Never empty: a card with no image is worse than a
                        // card that decodes the original slowly.
                        thumbnail: thumb || path,
                        // What the palette is read from; empty means the
                        // original.
                        palette: palette
                    });
                }
                root.wallpapers = out;
            }
        }

        stderr: StdioCollector {
            id: probeErr
        }

        onExited: code => {
            root.scanning = false;
            if (code !== 0)
                root.error = probeErr.text.trim().split("\n")[0] || `wallpaper scan exited with ${code}`;
        }
    }

    Process {
        id: themer

        property string retintMode: ""

        stderr: StdioCollector {
            id: themerErr
        }

        onExited: code => {
            root.applying = false;
            if (code === 0) {
                // The dashboard's "matugen rebuild 180 ms": the whole retint,
                // every template written, by the time the palette file has
                // landed.
                root.lastRebuildMs = Math.round(Date.now() - root.startedAt);
                root.lastMode = themer.retintMode;
            } else {
                // matugen prints "Error:", then the cause as "0: <message>",
                // then two lines of backtrace advice. The cause is the line
                // worth showing.
                const lines = themerErr.text.split("\n").map(l => l.replace(/\x1b\[[0-9;]*m/g, "").trim()).filter(l => l && !/^Error:?$/.test(l) && !/RUST_BACKTRACE|Backtrace omitted/.test(l));
                root.error = (lines[0] ?? "").replace(/^\d+:\s*/, "") || `vela retint exited with ${code}`;
                root.requestedMode = "";
                console.warn(`[vela] retint failed: ${root.error}`);
            }
            root.saveState();
            if (root.pendingRetint) {
                const next = root.pendingRetint;
                root.pendingRetint = "";
                root.retint(next);
            } else if (root.veil === "holding") {
                veilSettle.restart();
            }
        }
    }

    // ---- the veil -------------------------------------------------------
    //
    // Apps repaint in one jump when their colours change -- kitty when it is
    // sent the new palette, a browser when it hears light or dark, anything
    // GTK -- each whenever it hears, so a retint was windows snapping over
    // to the new palette one by one while the shell eased into it. So first
    // the windows on screen are photographed, one frozen frame each, drawn
    // over the window it came from (modules/overlays/Recolour.qml); the
    // retint runs underneath; and once it is done and the apps have
    // repainted, the frames fade away on the shell's own palette curve.
    // Every window crosses over to its new colours at once, with the shell.
    //
    //   ""           nothing up
    //   "capturing"  the frames are being taken; the retint waits for them
    //   "holding"    the frames are up, the retint is running underneath
    //   "lifting"    the frames are fading away
    property string veil: ""
    property string veilPath: ""
    // Screen name -> whether its frames are all in.
    property var veilReady: ({})

    function markVeilReady(screen: string, ready: bool): void {
        const next = Object.assign({}, root.veilReady);
        next[screen] = ready;
        root.veilReady = next;
        if (root.veil === "capturing" && Quickshell.screens.every(s => root.veilReady[s.name] === true))
            root.veilCaptured();
    }

    function veilCaptured(): void {
        veilCapture.stop();
        if (root.veil !== "capturing")
            return;
        root.veil = "holding";
        root.runRetint(root.veilPath);
    }

    // A frame that never comes -- a window the compositor will not hand over
    // -- does not hold the retint up: that window just changes the old way.
    Timer {
        id: veilCapture

        interval: 250
        onTriggered: root.veilCaptured()
    }

    // After the retint, a moment for the apps it told to repaint: a browser
    // takes a frame or two after hearing light or dark.
    Timer {
        id: veilSettle

        interval: 150
        onTriggered: {
            root.veil = "lifting";
            veilLift.restart();
        }
    }

    Timer {
        id: veilLift

        interval: Appearance.anim.palette + 50
        onTriggered: if (root.veil === "lifting")
            root.veil = ""
    }

    // Whatever happens, the frames do not stay up.
    Timer {
        id: veilGuard

        interval: 10000
        onTriggered: if (root.veil !== "") {
            root.veil = "lifting";
            veilLift.restart();
        }
    }

    // A light/dark switch -- the settings window, the dashboard's Theme tile,
    // sunset under "auto" -- recolours the shell by itself, but everything
    // else was generated in one mode and needs regenerating in the other.
    // Held back only while the shell is starting, so the flurry of changes
    // then settles first; after that at once. A second and a half on every
    // switch was the rest of the desktop changing well after the shell.
    onModeChanged: modeSettle.restart()
    onStateLoadedChanged: {
        modeSettle.restart();
        started.restart();
    }

    property bool settled: false

    Timer {
        id: started

        interval: 4000
        onTriggered: root.settled = true
    }

    Timer {
        id: modeSettle

        interval: root.settled ? 50 : 1500
        onTriggered: {
            if (root.stateLoaded && root.current && root.mode !== (root.requestedMode || root.lastMode))
                root.retint(root.current);
        }
    }

    Process {
        id: previewProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const doc = JSON.parse(text);
                    const dark = {};
                    const light = {};
                    const colours = doc.colors ?? {};
                    // matugen 4 nests each value as { "color": "#..." }; older
                    // releases gave the string directly.
                    const hex = v => typeof v === "string" ? v : (v?.color ?? "");
                    for (const role in colours) {
                        dark[role] = hex(colours[role].dark);
                        light[role] = hex(colours[role].light);
                    }
                    root.previewDark = dark;
                    root.previewLight = light;
                } catch (e) {
                    root.previewDark = {};
                    root.previewLight = {};
                }
            }
        }

        stderr: StdioCollector {}

        onExited: root.previewing = false
    }

    // --- state ------------------------------------------------------------
    FileView {
        id: state

        path: root.statePath
        printErrors: false
        atomicWrites: true
        // `vela wallpaper` writes this file too.
        watchChanges: true

        onFileChanged: reload()
        onLoaded: root.readState(text())
        onLoadFailed: legacyState.path = root.legacyStatePath
        onSaveFailed: mkdir.running = true
    }

    FileView {
        id: legacyState

        printErrors: false

        onLoaded: {
            root.readState(text());
            root.saveState();
        }
        onLoadFailed: root.stateLoaded = true
    }

    function readState(text: string): void {
        let s = null;
        try {
            s = JSON.parse(text);
        } catch (e) {
            root.stateLoaded = true;
            return;
        }
        root.current = s.current ?? "";
        root.previous = s.previous ?? "";
        root.perMonitor = s.perMonitor ?? ({});
        root.lastMode = s.mode ?? root.lastMode;
        root.lastRebuildMs = s.lastRebuildMs ?? root.lastRebuildMs;
        root.stateLoaded = true;
    }

    Process {
        id: mkdir

        command: ["mkdir", "-p", root.stateDir, root.cacheDir]
    }

    Process {
        id: haveMatugen

        running: true
        command: ["sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; command -v matugen >/dev/null && command -v vela >/dev/null']
        onExited: code => root.themerAvailable = code === 0
    }

    Component.onCompleted: mkdir.running = true
}
