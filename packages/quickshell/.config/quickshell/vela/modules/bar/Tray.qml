pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.components
import qs.services
import qs.tokens

// The status run: any tray icons, then bluetooth, output and network -- three
// of the bar's four control popouts, each opened from the glyph that shows its
// state. The fourth, Power, hangs off the battery next door, and the bell
// after this is a module of its own (Bell.qml).
//
// Bare glyphs rather than buttons, 13px apart on a vertical bar and 11px on a
// horizontal one, exactly as the design draws them. With no tile to light up,
// hover moves the glyph one step up the neutral ramp instead -- see
// BarButton's `tile: false`.
//
// Both bars lead the run with `expand_circle_down`. It used to reveal
// only the StatusNotifierItem tray, and so only existed while an app had put
// something in it; it is `BarExpander` now, leading the whole trailing run,
// and folds all of this away -- as one module, so it closes with the rest of
// the run (BarGroup's `reveal`) rather than emptying from the inside.
//
// SERVICE REQUEST: this is the one place in the bar that reads a system source
// directly instead of asking a service, because there is no `services/Tray.qml`
// to ask -- none has been written yet. The three helpers below
// (`usable`, resolving an item's icon, the activate/menu routing) are service
// work sitting in a UI file, and should move the moment that singleton exists.
Item {
    id: root

    required property BarState bar

    // A horizontal bar insets the whole status run from the chips before it.
    readonly property int leadMargin: root.bar.vertical ? 0 : Appearance.bar.chipPadLead

    readonly property var items: SystemTray.items.values.filter(i => i.status !== Status.Passive)

    // Folded away with the rest of the status run (BarExpander).
    readonly property bool present: !root.bar.collapsed

    readonly property real glyphSize: root.bar.vertical ? Appearance.size.iconRow : Appearance.size.iconLabel
    readonly property int gap: root.bar.vertical ? Appearance.bar.trayGapV : Appearance.bar.trayGapH

    // Quickshell answers `image://icon/<name>` even for a name the theme does
    // not have, with a placeholder that reports itself as loaded -- so a tray
    // icon has to be checked against the theme before it is handed to an Image
    // or the bar grows a magenta square.
    //
    // An icon that ships its own directory (`?path=`, which is how Electron
    // apps and anything installed outside the icon theme send one) is resolved
    // by Quickshell's provider from that directory, so it is passed through:
    // checking its bare name against the theme turned Discord, Slack or
    // VS Code into the placeholder glyph.
    function usable(source: string): bool {
        if (!source)
            return false;
        const prefix = "image://icon/";
        const at = source.indexOf(prefix);
        if (at === -1 || source.includes("?path="))
            return true;
        const name = source.slice(at + prefix.length).split("?")[0];
        return name.length > 0 && Quickshell.iconPath(name, true) !== "";
    }

    implicitWidth: flow.implicitWidth
    implicitHeight: flow.implicitHeight

    BarFlow {
        id: flow

        anchors.centerIn: parent
        vertical: root.bar.vertical
        gap: root.gap

        Repeater {
            model: root.items

            Item {
                id: entry

                required property SystemTrayItem modelData

                readonly property string source: root.usable(entry.modelData.icon) ? entry.modelData.icon : ""

                Layout.alignment: root.bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
                implicitWidth: root.glyphSize
                implicitHeight: root.glyphSize

                IconImage {
                    anchors.fill: parent
                    source: entry.source
                    asynchronous: true
                    visible: entry.source !== ""
                }

                // An unresolvable icon still needs a target, and one glyph is
                // better than a checkerboard.
                Icon {
                    anchors.centerIn: parent
                    visible: entry.source === ""
                    text: "extension"
                    size: root.glyphSize
                }

                // The item's own menu, as a platform menu next to the icon on
                // the side away from the screen edge.
                function openMenu(): void {
                    const bar = root.bar;
                    const x = bar.vertical ? (bar.position === "left" ? entry.width : 0) : 0;
                    const y = bar.vertical ? 0 : (bar.position === "top" ? entry.height : 0);
                    const p = entry.mapToItem(null, x, y);
                    entry.modelData.display(entry.QsWindow.window, p.x, p.y);
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: event => {
                        const item = entry.modelData;
                        if (event.button === Qt.MiddleButton)
                            item.secondaryActivate();
                        else if (event.button === Qt.RightButton || item.onlyMenu)
                            // Menu-only items (most applets) answer nothing to
                            // Activate, so a left click has to open the menu too.
                            item.hasMenu ? entry.openMenu() : item.activate();
                        else
                            item.activate();
                    }
                }
            }
        }

        BarButton {
            id: bluetooth

            Layout.alignment: root.bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            icon: Bt.icon
            tile: false
            size: root.glyphSize
            iconSize: root.glyphSize
            visible: Bt.available
            showing: root.bar.showing("bluetooth")

            onClicked: root.bar.popout("bluetooth", bluetooth, undefined)
        }

        BarButton {
            id: output

            Layout.alignment: root.bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            icon: Audio.icon
            tile: false
            size: root.glyphSize
            iconSize: root.glyphSize
            showing: root.bar.showing("output")

            onClicked: root.bar.popout("output", output, undefined)
            onSecondaryClicked: Audio.toggleMute()
            onScrolled: delta => Audio.changeVolume(delta > 0 ? 0.02 : -0.02)
        }

        BarButton {
            id: network

            Layout.alignment: root.bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            icon: Net.icon
            tile: false
            size: root.glyphSize
            iconSize: root.glyphSize
            showing: root.bar.showing("network")

            onClicked: root.bar.popout("network", network, undefined)
        }
    }

    // The popout keybind lands here for the three this run owns, so a shortcut
    // opens it on the same anchor a click would.
    Connections {
        target: BarPopouts

        function onRequested(name: string): void {
            if (!root.bar.forKeys)
                return;
            if (name === "bluetooth")
                root.bar.popout(name, bluetooth, undefined);
            else if (name === "output")
                root.bar.popout(name, output, undefined);
            else if (name === "network")
                root.bar.popout(name, network, undefined);
        }
    }
}
