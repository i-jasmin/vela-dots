pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.tokens
import qs.components
import qs.modules.attached
import qs.modules.bar

// The popout shell. One window, one drawer, five contents, and the rule their
// design exists to state:
//
//     A popout is a control for the bar item you clicked.
//     The dashboard is information you go and look at.
//
// So there are four of them and there will not be a fifth: Output, Network,
// Bluetooth, Power. Calendar, weather, media and system stats are the
// dashboard's and appear nowhere else. Three more contents ride the same
// anchor machinery without being controls of that kind: the workspace window
// list, the bar's own popout; the notification centre off the bell -- the
// history, which is the notifications' control in the sense that matters,
// since it is where you act on one you missed; and, off the privacy capsule,
// who has the microphone, camera or screen, with the microphone's mute.
//
// ONE OPEN, SHELL-WIDE. `BarPopouts` is a singleton because the design's rule
// is that popouts never stack: one is open, shell-wide, or none is. Every
// monitor's shell window (modules/shell/Shell.qml) holds one of these, and
// only the one on `BarPopouts.screenName` opens -- so asking for a popout on
// the other monitor retracts this one as that one grows.
//
// ATTACHED TO ITS BAR ITEM. A popout hangs off the bar the way the dashboard
// does -- an `AttachedDrawer` centred on the item that opened it, flush with the
// bar's inner face, joined to it by two fillets, the bar solid while it is out.
// Asking for another popout while one is open does not close one and open the
// other: the drawer slides along the bar to the new item and takes the new
// content's size, and the contents cross over on the way, the new one arriving
// from the side the drawer is travelling towards.
//
// IN THE BAR'S OWN WINDOW. The window covers the screen and the drawer is
// placed inside it: a layer-shell surface clips at its own edges, so a window
// sized to the drawer would scissor away its shadow, and a surface that covers
// the screen is what makes click-away dismissal possible at all. The bar is in
// the same window, so `BarPopouts.anchor` -- the bar item's place on the
// screen -- is its place here too.
Item {
    id: root

    // The monitor whose shell window this is in, and the BarState of its
    // bar, whose colour the drawer takes.
    required property string host
    required property BarState bar

    readonly property bool shown: BarPopouts.current !== "" && BarPopouts.screenName === root.host
    // Held through the exit, then dropped: unloading the content is what
    // releases the Wi-Fi scan and the Bluetooth discovery the contents asked
    // for while they were on screen.
    readonly property bool alive: drawer.live
    readonly property bool live: drawer.live

    // --- frozen at open -----------------------------------------------------
    //
    // `BarPopouts.close()` clears `current` and `payload` and nothing else, so
    // binding straight to the singleton would empty the drawer at the instant
    // the exit begins -- the popout would vanish rather than retract. These are
    // copies, taken while a popout opens and left alone while it closes.
    property string name: ""
    property var subject: undefined
    property rect anchor: Qt.rect(0, 0, 0, 0)

    // The middle of the bar item, along the bar.
    readonly property real anchorCentre: Config.bar.vertical ? root.anchor.y + root.anchor.height / 2 : root.anchor.x + root.anchor.width / 2

    function sync(): void {
        // A close leaves every copy standing, which is the whole point of
        // them -- and so does a popout opening on another monitor, which is
        // this one closing. Asked of the singleton rather than of `shown`,
        // which may not have heard the change yet.
        if (BarPopouts.current === "" || BarPopouts.screenName !== root.host)
            return;
        const was = root.anchorCentre;
        root.name = BarPopouts.current;
        root.subject = BarPopouts.payload;
        root.anchor = BarPopouts.anchor;
        // Crossing to another bar item: the new content comes in from the
        // side the drawer is heading for, and what it replaces leaves the
        // other way. Judged here rather than when the name changes, because
        // `open()` moves the anchor first and the name last.
        if (drawer.out && root.anchorCentre !== was)
            fade.direction = root.anchorCentre < was ? -1 : 1;
    }

    Connections {
        target: BarPopouts

        // `anchor` and `screenName` move without `current` changing when the
        // same popout is asked for from the other monitor, so all of them are
        // watched rather than just the name.
        function onCurrentChanged(): void {
            root.sync();
        }

        function onAnchorChanged(): void {
            root.sync();
        }

        function onScreenNameChanged(): void {
            root.sync();
        }

        function onPayloadChanged(): void {
            root.sync();
        }

        // The bar item this is anchored to has just moved to a different edge
        // of the screen. Following it would mean animating a popout across the
        // display; putting it away is what the user would do next anyway.
        function onPositionChanged(): void {
            BarPopouts.close();
        }
    }

    visible: root.alive

    onShownChanged: {
        if (!root.shown)
            return;
        keys.forceActiveFocus();
        // Arriving with the drawer rather than after it: the content rises
        // the way the drawer grows, like the dashboard's.
        fade.vertical = !Config.bar.vertical;
        fade.direction = Config.bar.position === "right" || !Config.bar.vertical ? 1 : -1;
        fade.enter();
        // Swaps from here on run along the bar.
        fade.vertical = Config.bar.vertical;
    }

    function contentFor(name: string): Component {
        switch (name) {
        case "output":
            return outputContent;
        case "network":
            return networkContent;
        case "bluetooth":
            return bluetoothContent;
        case "power":
            return powerContent;
        case "workspaces":
            return windowsContent;
        case "notifications":
            return centreContent;
        case "privacy":
            return inUseContent;
        }
        return null;
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        // Reached only by what the focused control did not want, so left and
        // right still move a segmented rail and a slider still takes its own
        // arrow keys.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                BarPopouts.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                keys.step(true);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                keys.step(false);
                event.accepted = true;
            }
        }

        // To the next control from the one that has the keyboard. The window
        // holds the bar and the other drawers too, and the focus chain runs
        // through all of them, so anything outside this popout -- a drawer
        // still retracting as this one opens -- is walked past.
        function step(forward: bool): void {
            const from = keys.Window.activeFocusItem ?? keys;
            let next = from.nextItemInFocusChain(forward);
            for (let i = 0; i < 64 && next && !keys.holds(next); i++)
                next = next.nextItemInFocusChain(forward);
            if (next && keys.holds(next))
                next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
        }

        function holds(item: Item): bool {
            for (let p = item; p; p = p.parent)
                if (p === keys)
                    return true;
            return false;
        }

        AttachedDrawer {
            id: drawer

            // Each content declares the shape it wants around it: the four
            // controls are 292 wide at radius 20 with 14 of padding, the
            // workspace window list is 246 at 18 with 8.
            readonly property int padding: fade.item?.contentPadding ?? Appearance.popout.padding

            anchors.fill: parent
            key: "popout"
            screenName: root.host
            bar: root.bar
            open: root.shown
            along: root.anchorCentre
            radius: fade.item?.contentRadius ?? Appearance.radius.popout
            contentWidth: fade.item?.popoutWidth ?? Appearance.popout.width
            contentHeight: fade.implicitHeight + drawer.padding * 2

            Crossfade {
                id: fade

                anchors.fill: parent
                anchors.margins: drawer.padding
                // A page on its way out stays centred on the bar item it
                // belonged to and against the bar, whatever the new one's
                // size.
                alignment: Config.bar.position === "top" ? Qt.AlignHCenter | Qt.AlignTop : Config.bar.position === "bottom" ? Qt.AlignHCenter | Qt.AlignBottom : Config.bar.position === "left" ? Qt.AlignLeft | Qt.AlignVCenter : Qt.AlignRight | Qt.AlignVCenter
                // Unloaded once the popout has finished leaving, which is what
                // releases `Net.scanning` and `Bt.discoverable`.
                //
                // While shown, by the popout asked for rather than the frozen
                // copy: on a reopen the drawer comes alive a moment before
                // `sync` has run, and the copy still named the last popout --
                // which was created for that moment, and did what it does on
                // opening. The notification centre marked everything seen.
                component: root.alive ? root.contentFor(root.shown ? BarPopouts.current : root.name) : null

                onItemChanged: if (root.shown)
                    keys.forceActiveFocus()
            }
        }
    }

    // `qs.services` is deliberately not imported in this file. It exports a
    // `Power` singleton, which would shadow `Power.qml` next door -- the same
    // import race that made the services `Net` and `Bt` rather than `Network`
    // and `Bluetooth`. The contents import it themselves, and `Power.qml`
    // qualifies its import for exactly this reason.
    Component {
        id: outputContent

        Output {}
    }

    Component {
        id: networkContent

        Network {}
    }

    Component {
        id: bluetoothContent

        Bluetooth {}
    }

    Component {
        id: powerContent

        Power {}
    }

    Component {
        id: windowsContent

        Windows {
            workspace: root.subject
        }
    }

    Component {
        id: centreContent

        NotificationCentre {}
    }

    Component {
        id: inUseContent

        InUse {}
    }
}
