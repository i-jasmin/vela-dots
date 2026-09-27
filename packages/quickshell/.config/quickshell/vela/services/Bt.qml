pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// BlueZ via Quickshell's native backend.
//
// Named Bt, not Bluetooth: Quickshell.Bluetooth exports a `Bluetooth` singleton
// that this file reads from, and a local singleton of the same name would win
// the import race in any file importing both -- every `Bluetooth.devices` there
// would silently resolve to this file instead. Net is short for the same reason.
Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false

    readonly property list<BluetoothDevice> devices: Bluetooth.devices.values
    readonly property list<BluetoothDevice> connected: devices.filter(d => d.connected)
    readonly property list<BluetoothDevice> paired: devices.filter(d => d.paired)

    // What the popout lists: the devices the machine has a relationship with,
    // connected ones first, then the rest of the paired ones by name. Anything
    // merely seen during a scan is left to a picker that asked for a scan.
    readonly property list<BluetoothDevice> known: {
        const all = devices.filter(d => d.paired || d.connected);
        all.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return deviceName(a).localeCompare(deviceName(b));
        });
        return all;
    }

    // Devices seen by the scan the popout runs, not yet paired: what you can
    // pair with. Unnamed ones (a bare address) are left out -- there is no way
    // to tell which of them is the thing in your hand.
    readonly property list<BluetoothDevice> nearby: {
        const all = devices.filter(d => !d.paired && !d.connected && (d.name || d.deviceName) && (d.name || d.deviceName) !== d.address);
        all.sort((a, b) => deviceName(a).localeCompare(deviceName(b)));
        return all;
    }

    readonly property string icon: !available || !enabled ? "bluetooth_disabled" : connected.length > 0 ? "bluetooth_connected" : "bluetooth"

    readonly property string label: !available ? "No adapter" : !enabled ? "Off" : connected.length > 0 ? connected.map(d => deviceName(d)).join(", ") : "On"

    function deviceName(device: BluetoothDevice): string {
        return device?.name || device?.deviceName || device?.address || "Unknown device";
    }

    // BlueZ reports a freedesktop icon name -- audio-headset, input-keyboard,
    // input-mouse. The design draws Material Symbols, so the two vocabularies
    // are mapped here rather than in every row that shows a device.
    function deviceIcon(device: BluetoothDevice): string {
        const name = (device?.icon ?? "").toLowerCase();
        if (name.includes("headset") || name.includes("headphone"))
            return "headphones";
        if (name.includes("keyboard"))
            return "keyboard";
        if (name.includes("mouse") || name.includes("pointing"))
            return "mouse";
        if (name.includes("gaming") || name.includes("joypad"))
            return "sports_esports";
        if (name.includes("phone"))
            return "smartphone";
        if (name.includes("tablet"))
            return "tablet";
        if (name.includes("computer") || name.includes("laptop"))
            return "computer";
        if (name.includes("printer"))
            return "print";
        if (name.includes("camera"))
            return "photo_camera";
        if (name.includes("watch"))
            return "watch";
        if (name.includes("speaker") || name.includes("audio"))
            return "speaker";
        if (name.includes("scanner"))
            return "scanner";
        return "bluetooth";
    }

    // BlueZ battery levels are fractional 0-1, the same convention as UPower
    // and Networking's signal strength -- and the same trap. Rounding here once
    // means no consumer has to know, and none can declare it `int` and get 0.
    function batteryPercent(device: BluetoothDevice): int {
        if (!device?.batteryAvailable)
            return 0;
        const raw = device.battery ?? 0;
        return Math.round(raw > 1 ? raw : raw * 100);
    }

    function hasBattery(device: BluetoothDevice): bool {
        return device?.batteryAvailable ?? false;
    }

    // Second line of a device row -- "Connected · 84%", "Connected", "Paired".
    function detail(device: BluetoothDevice): string {
        if (!device)
            return "";
        const parts = [];
        if (device.connected)
            parts.push("Connected");
        else if (device.pairing)
            parts.push("Pairing…");
        else if (device.paired)
            parts.push("Paired");
        if (device.batteryAvailable)
            parts.push(`${batteryPercent(device)}%`);
        return parts.join(" · ");
    }

    function toggle(): void {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }

    function setEnabled(on: bool): void {
        if (adapter)
            adapter.enabled = on;
    }

    // Set while a picker listing nearby devices is visible. Discovery is a
    // battery and airtime cost, so nothing turns it on speculatively.
    property bool discoverable: false

    function connect(device: BluetoothDevice): void {
        device?.connect();
    }

    function disconnect(device: BluetoothDevice): void {
        device?.disconnect();
    }

    // Trusted as well, so it reconnects by itself next time. BlueZ connects a
    // device once pairing completes only if something asks, so the popout
    // does that when `paired` flips.
    function pair(device: BluetoothDevice): void {
        if (!device)
            return;
        device.trusted = true;
        device.pair();
    }

    function forget(device: BluetoothDevice): void {
        device?.forget();
    }

    function toggleConnection(device: BluetoothDevice): void {
        if (!device)
            return;
        if (device.connected)
            device.disconnect();
        else
            device.connect();
    }

    // BlueZ answers "No discovery started" -- as a warning -- when asked to
    // stop a discovery that was never running, and a plain `Binding` on
    // `discovering` asks exactly that every time it activates, which is every
    // reload. So the write is guarded against what the adapter already
    // reports, and the property is only touched when it actually differs.
    function syncDiscovery(): void {
        const want = root.enabled && root.discoverable;
        if (root.adapter && root.adapter.discovering !== want)
            root.adapter.discovering = want;
    }

    onDiscoverableChanged: root.syncDiscovery()
    onEnabledChanged: root.syncDiscovery()
    onAdapterChanged: root.syncDiscovery()
}
