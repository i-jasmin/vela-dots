pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// PipeWire. Sinks, sources and per-application streams.
//
// PwObjectTracker is mandatory: a node's `audio` group stays null until
// something binds the node, so volume and mute read as 0/false for every node
// that is not in the tracker below. Every node this file hands out is therefore
// tracked, not just the default sink.
//
// The bar's Output popout is the consumer: a device list with the active one
// marked, a master slider, and one slider per playing application.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool ready: sink?.audio !== null && sink?.audio !== undefined
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property int percent: Math.round(volume * 100)

    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    // Rebuilt from Pipewire.nodes rather than bound to a filter expression:
    // UntypedObjectModel notifies through valuesChanged, and a `.values.filter`
    // binding does retick on it, but the lists are also needed at startup when
    // the model may already be full and never change again.
    property list<PwNode> sinks: []
    property list<PwNode> sources: []
    // Applications playing audio. Recording streams are deliberately excluded:
    // the popout's per-app section is an output mixer.
    property list<PwNode> streams: []

    readonly property string icon: {
        if (muted || volume <= 0)
            return "volume_off";
        if (volume < 0.34)
            return "volume_mute";
        if (volume < 0.67)
            return "volume_down";
        return "volume_up";
    }

    function setVolume(v: real): void {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function changeVolume(delta: real): void {
        setVolume(volume + delta);
    }

    function toggleMute(): void {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleMicMute(): void {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    // --- Devices -----------------------------------------------------------

    function setSink(node: PwNode): void {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function setSource(node: PwNode): void {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    function isDefaultSink(node: PwNode): bool {
        return !!node && node === root.sink;
    }

    // Human name for a device row. `description` is the friendly string
    // WirePlumber builds ("... Speaker"); `nickname` is usually the same minus
    // the card, and `name` is the raw alsa id, which is a last resort.
    function deviceName(node: PwNode): string {
        return node?.description || node?.nickname || node?.name || "Unknown device";
    }

    // `properties` is empty until a PwObjectTracker binds the node, and it is
    // not a notifying property -- a binding built on it alone would keep the
    // value it had at first evaluation. Reading `ready` first makes the binding
    // depend on something that *does* notify, so it re-evaluates the moment the
    // tracker fills the node in. Every helper below that touches `properties`
    // calls this first, for that reason and no other.
    function track(node: PwNode): var {
        // The read is the whole point; the value is deliberately discarded.
        void node?.ready;
        return node?.properties ?? {};
    }

    // The Output popout uses three device icons: headphones, speaker, cast.
    function deviceIcon(node: PwNode): string {
        if (!node)
            return "speaker";
        const props = track(node);
        const form = (props["device.form-factor"] ?? "").toLowerCase();
        if (form === "headset" || form === "headphone" || form === "headphones")
            return "headphones";
        if (form === "hands-free" || form === "speaker")
            return "speaker";
        if (form === "microphone")
            return "mic";
        if (form === "tv")
            return "cast";

        const haystack = `${node.name} ${node.description}`.toLowerCase();
        if (haystack.includes("hdmi") || haystack.includes("displayport"))
            return "cast";
        if (props["device.api"] === "bluez5" || haystack.includes("bluez"))
            return "headphones";
        return node.isSink ? "speaker" : "mic";
    }

    // The second line of an active device row -- "AAC · 84% battery" in the
    // design. Only a Bluetooth device has anything to say here; a built-in
    // card returns "" and the row draws one line.
    function deviceDetail(node: PwNode): string {
        if (!node)
            return "";
        const props = track(node);
        const parts = [];

        const codec = props["api.bluez5.codec"] ?? props["bluez5.codec"] ?? "";
        if (codec)
            parts.push(codec.toUpperCase());

        // Cross-referenced by MAC: PipeWire knows the codec, BlueZ knows the
        // battery, and only the address ties the two views of one headset.
        const address = (props["api.bluez5.address"] ?? "").toLowerCase();
        if (address) {
            const device = Bt.devices.find(d => (d.address ?? "").toLowerCase() === address);
            if (device && device.batteryAvailable)
                parts.push(`${Bt.batteryPercent(device)}% battery`);
        }

        return parts.join(" · ");
    }

    // --- Per-application streams -------------------------------------------

    function streamName(node: PwNode): string {
        const props = track(node);
        return props["application.name"] || props["media.name"] || node?.description || node?.name || "Unknown";
    }

    // The desktop icon name the application advertises, for consumers that
    // would rather draw the real application icon than a Material glyph.
    function streamIconName(node: PwNode): string {
        const props = track(node);
        return props["application.icon-name"] || props["application.process.binary"] || "";
    }

    // Material Symbols ligature for a stream row. The design shows graphic_eq
    // for a music player and public for a browser, so the table sorts
    // applications into those broad shapes rather than naming every program.
    function streamIcon(node: PwNode): string {
        const name = `${streamName(node)} ${streamIconName(node)}`.toLowerCase();
        if (/firefox|chrom|chrome|brave|vivaldi|epiphany|librewolf|zen|webkit/.test(name))
            return "public";
        if (/spotify|mpv|vlc|rhythmbox|audacious|amberol|clementine|strawberry|tidal|deezer/.test(name))
            return "graphic_eq";
        if (/mpd|music|player/.test(name))
            return "music_note";
        if (/discord|telegram|signal|element|zoom|teams|slack|webrtc/.test(name))
            return "call";
        if (/kitty|foot|alacritty|wezterm|terminal|konsole/.test(name))
            return "terminal";
        if (/steam|lutris|wine|game|proton/.test(name))
            return "sports_esports";
        if (/obs|kdenlive|shotcut|movie|video/.test(name))
            return "movie";
        return "graphic_eq";
    }

    function streamVolume(node: PwNode): real {
        return node?.audio?.volume ?? 0;
    }

    function streamPercent(node: PwNode): int {
        return Math.round(streamVolume(node) * 100);
    }

    function setStreamVolume(node: PwNode, v: real): void {
        if (node?.audio)
            node.audio.volume = Math.max(0, Math.min(1, v));
    }

    function streamMuted(node: PwNode): bool {
        return node?.audio?.muted ?? false;
    }

    function toggleStreamMute(node: PwNode): void {
        if (node?.audio)
            node.audio.muted = !node.audio.muted;
    }

    // Sorting is done on `type`, a bitmask, rather than on media.class: the
    // properties map is empty until a node is tracked, and the tracker below is
    // built from these very lists, so reading properties here would never
    // classify anything. `type` is populated the moment the node appears.
    //
    //   Audio|Stream|Sink   an application playing  (AudioOutStream)
    //   Audio|Stream|Source an application recording
    //   Audio|Sink          an output device
    //   Audio|Source        an input device
    function refresh(): void {
        const newSinks = [];
        const newSources = [];
        const newStreams = [];

        for (const node of Pipewire.nodes.values) {
            const type = node.type;
            if (!(type & PwNodeType.Audio))
                continue;

            if (type & PwNodeType.Stream) {
                if (type & PwNodeType.Sink)
                    newStreams.push(node);
                continue;
            }
            // Not `else if`: a duplex device (Audio/Duplex, an interface that
            // both plays and records) is both, and belongs in both lists.
            if (type & PwNodeType.Sink)
                newSinks.push(node);
            if (type & PwNodeType.Source)
                newSources.push(node);
        }

        // Default first, the way `Net.networks` puts the connected AP first and
        // `Bt.known` the connected device. The popouts draw the device lists
        // identically, so the ordering rule belongs here rather than being
        // re-sorted by each popout.
        const defaultFirst = fallback => (a, b) => {
                const da = a === fallback, db = b === fallback;
                if (da !== db)
                    return da ? -1 : 1;
                return (root.deviceName(a) ?? "").localeCompare(root.deviceName(b) ?? "");
            };
        newSinks.sort(defaultFirst(Pipewire.defaultAudioSink));
        newSources.sort(defaultFirst(Pipewire.defaultAudioSource));

        root.sinks = newSinks;
        root.sources = newSources;
        root.streams = newStreams;
    }

    // Pipewire.nodes may already be populated by the time this lazily-created
    // singleton exists, in which case valuesChanged never fires again.
    Component.onCompleted: refresh()

    Connections {
        target: Pipewire.nodes

        function onValuesChanged(): void {
            root.refresh();
        }
    }

    // Picking another device changes no node, only which one is the default,
    // and the lists are ordered by that.
    Connections {
        target: Pipewire

        function onDefaultAudioSinkChanged(): void {
            root.refresh();
        }

        function onDefaultAudioSourceChanged(): void {
            root.refresh();
        }
    }

    PwObjectTracker {
        objects: [root.sink, root.source, ...root.sinks, ...root.sources, ...root.streams].filter(n => n)
    }
}
