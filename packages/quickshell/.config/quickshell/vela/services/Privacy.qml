pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Who is listening, watching or looking at the screen right now.
//
// PipeWire knows, as links. An application recording the microphone is an
// input stream linked to an audio source; one showing the camera is a video
// stream linked to a camera; one sharing the screen is a video stream linked to
// the screen-cast node the portal made. A link is only counted while it is
// active -- carrying data, not merely set up -- which is the difference between
// a call that is on and a call app that is open.
//
// What is not counted: anything reading a sink's monitor, which is how cava and
// the shell's own peak meter hear the music. That is recording what you are
// already hearing, not you.
//
// THE CAMERA HAS A SECOND WAY IN. Most browsers still open /dev/video* directly
// rather than through PipeWire, so a video call in one would show nothing. For
// that, `fuser` is asked every few seconds who holds a video device -- only on
// a machine that has one, and slowly while nothing does. PipeWire's own daemons
// are left out of that answer: when they hold the device it is for a PipeWire
// client, which the links already name.
Singleton {
    id: root

    // The links that could mean one of the three: a microphone into a
    // stream, or anything out of a video source. Told apart by node type,
    // which PipeWire gives every node up front, so this needs nothing bound.
    readonly property var candidates: Pipewire.linkGroups.values.filter(g => (root.isMicDevice(g.source) && root.isStream(g.target)) || root.isVideoSource(g.source))
    // Carrying something now. A link's state reads Unlinked until the link
    // is bound, which the tracker below does for every candidate.
    readonly property var live: root.candidates.filter(g => g.state === PwLinkState.Active)

    // The applications, by name, deduplicated.
    readonly property var mic: root.names(root.live.filter(g => root.isMicDevice(g.source) && root.isStream(g.target)).map(g => g.target))
    readonly property var camera: root.merge(root.names(root.live.filter(g => root.isVideoSource(g.source) && root.isCamera(g.source)).map(g => g.target)), root.v4l2)
    readonly property var screen: root.names(root.live.filter(g => root.isVideoSource(g.source) && !root.isCamera(g.source)).map(g => g.target))

    readonly property bool any: root.mic.length > 0 || root.camera.length > 0 || root.screen.length > 0

    // Holders of a /dev/video* device, from the poll below.
    property var v4l2: []
    property bool hasCamera: false

    // Binding is what fills in a link's state and a node's properties, so the
    // candidate links are tracked, and both ends of each.
    PwObjectTracker {
        objects: {
            const out = [];
            for (const g of root.candidates) {
                out.push(g);
                if (g.source)
                    out.push(g.source);
                if (g.target)
                    out.push(g.target);
            }
            return out;
        }
    }

    // The same trick `Audio.track` explains: reading `ready` first makes a
    // binding re-run when the tracker fills the properties in.
    function props(node: PwNode): var {
        void node?.ready;
        return node?.properties ?? {};
    }

    function isStream(node: PwNode): bool {
        return !!node && (node.type & PwNodeType.Stream) !== 0;
    }

    // A microphone: an audio source that is a device, not somebody's stream.
    function isMicDevice(node: PwNode): bool {
        return !!node && (node.type & PwNodeType.AudioSource) === PwNodeType.AudioSource && !root.isStream(node);
    }

    function isVideoSource(node: PwNode): bool {
        return !!node && (node.type & PwNodeType.VideoSource) === PwNodeType.VideoSource && !root.isStream(node);
    }

    // A camera is a device PipeWire found (`device.api` v4l2 or libcamera);
    // any other video source is somebody's screen cast -- the portal's
    // "xdph-streaming-0" has no device behind it.
    function isCamera(node: PwNode): bool {
        const p = root.props(node);
        return !!p["device.api"] || /^(v4l2|libcamera)/.test(node?.name ?? "");
    }

    function nameOf(node: PwNode): string {
        const p = root.props(node);
        return p["application.name"] || p["application.process.binary"] || node?.description || node?.name || qsTr("Something");
    }

    function names(nodes: var): var {
        return root.merge(nodes.map(n => root.nameOf(n)), []);
    }

    function merge(a: var, b: var): var {
        const out = [];
        for (const n of [...a, ...b])
            if (n && !out.some(o => o.toLowerCase() === n.toLowerCase()))
                out.push(n);
        return out;
    }

    // ---- /dev/video* ---------------------------------------------------------

    Timer {
        interval: root.hasCamera ? 3000 : 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: poll.running = true
    }

    Process {
        id: poll

        // "none" when there is no video device at all, otherwise one command
        // name per holder. fuser prints the PIDs on stdout and everything else
        // on stderr.
        command: ["sh", "-c", "set -- /dev/video*; [ -e \"$1\" ] || { echo none; exit 0; }; for p in $(fuser \"$@\" 2>/dev/null); do cat \"/proc/$p/comm\" 2>/dev/null; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(l => l.trim()).filter(l => l);
                root.hasCamera = !lines.includes("none");
                const held = lines.filter(l => l !== "none" && !/^(pipewire|wireplumber)$/.test(l));
                // Only replaced when it changes, so the lists above do not
                // re-run every three seconds for nothing.
                if (held.join("\n") !== root.v4l2.join("\n"))
                    root.v4l2 = held;
            }
        }
    }
}
