pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// NetworkManager state via Quickshell's native backend.
//
// Named Net, not Network, because Quickshell.Networking already exports a
// `Network` type that this file uses. A local singleton of the same name wins
// the import race in any file that imports both, silently, and every read of
// `Network` there would return this singleton instead of the AP type. The same
// applies to Bt, for the same reason.
//
// Everything here is empty for the first second or two after launch, so
// consumers must bind rather than read once.
Singleton {
    id: root

    readonly property list<NetworkDevice> devices: Networking.devices.values
    readonly property NetworkDevice wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property NetworkDevice wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null

    readonly property bool wifiAvailable: wifiDevice !== null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiBlocked: !Networking.wifiHardwareEnabled
    readonly property bool wiredConnected: wiredDevice?.connected ?? false

    readonly property Network activeWifi: wifiDevice?.networks?.values?.find(n => n.connected) ?? null
    readonly property string ssid: activeWifi?.name ?? ""

    // Every access point the device can currently see, strongest first, with
    // the connected one pinned to the top -- the order the popout lists them
    // in. NetworkManager only reports the connected AP until a scan is asked
    // for, which is what `scanning` below is for.
    readonly property list<Network> networks: {
        const all = [...(wifiDevice?.networks?.values ?? [])];
        all.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return signalOf(b) - signalOf(a);
        });
        return all;
    }

    // Quickshell reports signalStrength as a fraction, 0-1 -- the same
    // convention as UPower's percentage, and the same trap. Declaring this
    // `int` truncated 0.91 to 0, so the bar showed the weakest icon on a full
    // strength connection. Normalised rather than just multiplied, so a future
    // Quickshell that switches to 0-100 does not silently break it again.
    readonly property real signalRaw: signalOf(activeWifi)
    readonly property int signal: Math.round(signalRaw > 1 ? signalRaw : signalRaw * 100)

    // `Unknown` means NetworkManager's connectivity check is switched off or
    // has not run -- the default on installs without
    // NetworkManager-config-connectivity-fedora. Read as offline, a working
    // connection showed the "no internet" icon forever.
    readonly property bool online: Networking.connectivity === NetworkConnectivity.Full || (Networking.connectivity === NetworkConnectivity.Unknown && connected)
    readonly property bool connected: wiredConnected || activeWifi !== null

    // Negotiated rate of the live link, as NetworkManager prints it ("1170
    // Mb/s"). Not exposed natively -- WifiNetwork has no linkSpeed, only
    // WiredDevice does -- so it comes from nmcli, and is "" when nmcli is
    // absent or nothing is connected.
    property string linkSpeed: ""

    readonly property string icon: {
        if (wiredConnected)
            return "lan";
        if (!wifiEnabled)
            return "wifi_off";
        if (!activeWifi)
            return "signal_wifi_bad";
        if (!online)
            return "signal_wifi_statusbar_not_connected";
        return signalIcon(activeWifi);
    }

    readonly property string label: wiredConnected ? "Wired" : activeWifi ? ssid : wifiEnabled ? "Disconnected" : "Wi-Fi off"

    // Set while a UI listing networks is visible. Without it NetworkManager
    // only reports the currently connected AP, so a picker would show one row.
    property bool scanning: false

    function signalOf(network: Network): real {
        const raw = (network as WifiNetwork)?.signalStrength ?? 0;
        return raw > 1 ? raw / 100 : raw;
    }

    function signalPercent(network: Network): int {
        return Math.round(signalOf(network) * 100);
    }

    // The three ligatures the design uses, plus an empty state. Material
    // Symbols spells the full-strength one `wifi`, not `wifi_4_bar`.
    function signalIcon(network: Network): string {
        const pct = signalPercent(network);
        if (pct >= 66)
            return "wifi";
        if (pct >= 33)
            return "wifi_2_bar";
        if (pct > 0)
            return "wifi_1_bar";
        return "signal_wifi_0_bar";
    }

    // "WPA3", "WPA2", "Open"... Quickshell already prints these the way a user
    // would recognise them, so there is no table here to drift out of date.
    function securityLabel(network: Network): string {
        const security = (network as WifiNetwork)?.security;
        if (security === undefined || security === null || security === WifiSecurityType.Unknown)
            return "";
        return WifiSecurityType.toString(security);
    }

    // The second line of a network row: what the connection is, or what it
    // would be -- "Connected · WPA3 · 866 Mb/s", "Open", "Saved".
    function detail(network: Network): string {
        if (!network)
            return "";
        if (network.connected)
            return ["Connected", securityLabel(network), root.linkSpeed].filter(p => p).join(" · ");
        if (network.known)
            return "Saved";
        return securityLabel(network) || "Open";
    }

    function connect(network: Network): void {
        network?.connect();
    }

    // A secured network NetworkManager has no saved profile for. `connect()`
    // on one of these only fails with NoSecrets -- nothing in the session
    // answers NetworkManager's password request -- so the popout asks itself.
    // Enterprise (EAP) networks need more than a password and are left to
    // NetworkManager.
    function needsPassword(network: Network): bool {
        const security = (network as WifiNetwork)?.security;
        return !!network && !network.known && [WifiSecurityType.Sae, WifiSecurityType.Wpa2Psk, WifiSecurityType.WpaPsk, WifiSecurityType.StaticWep].includes(security);
    }

    function connectWithPsk(network: Network, psk: string): void {
        (network as WifiNetwork)?.connectWithPsk(psk);
    }

    function disconnect(network: Network): void {
        network?.disconnect();
    }

    function forget(network: Network): void {
        network?.forget();
    }

    function toggleWifi(): void {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // --- Airplane mode ------------------------------------------------------
    //
    // Every radio off, expressed through the two backends that already own
    // them rather than through rfkill: NetworkManager and BlueZ both refuse to
    // be second-guessed, and going via rfkill would leave their state stale.
    readonly property bool airplane: !Networking.wifiEnabled && (!Bt.available || !Bt.enabled)

    function setAirplane(on: bool): void {
        Networking.wifiEnabled = !on;
        if (Bt.available)
            Bt.adapter.enabled = !on;
    }

    function toggleAirplane(): void {
        setAirplane(!airplane);
    }

    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.scanning
        when: root.wifiDevice !== null
    }

    // ACTIVE rather than SSID as the key: nmcli escapes a colon inside an SSID
    // as `\:`, and parsing that back out of a colon-separated line is a bug
    // waiting to happen for one string nobody reads.
    Process {
        id: rateProc

        command: ["nmcli", "-t", "-f", "ACTIVE,RATE", "device", "wifi", "list", "--rescan", "no"]

        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.split("\n").find(l => l.startsWith("yes:"));
                root.linkSpeed = line ? line.slice(4).trim().replace("Mbit/s", "Mb/s") : "";
            }
        }

        onExited: code => {
            if (code !== 0)
                root.linkSpeed = "";
        }
    }

    Timer {
        running: root.activeWifi !== null
        interval: 10000
        repeat: true
        triggeredOnStart: true
        onTriggered: rateProc.running = true
    }
}
