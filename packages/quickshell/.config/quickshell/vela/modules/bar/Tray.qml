pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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
// An app's menu opens as a popout like the three after it, drawn by the shell
// in its own colours rather than by the app (modules/popouts/TrayMenu.qml).
Item {
    id: root

    required property BarState bar

    // A horizontal bar insets the whole status run from the chips before it.
    readonly property int leadMargin: root.bar.vertical ? 0 : Appearance.bar.chipPadLead

    // Folded away with the rest of the status run (BarExpander).
    readonly property bool present: !root.bar.collapsed

    readonly property real glyphSize: root.bar.vertical ? Appearance.size.iconRow : Appearance.size.iconLabel
    readonly property int gap: root.bar.vertical ? Appearance.bar.trayGapV : Appearance.bar.trayGapH

    implicitWidth: flow.implicitWidth
    implicitHeight: flow.implicitHeight

    BarFlow {
        id: flow

        anchors.centerIn: parent
        vertical: root.bar.vertical
        gap: root.gap

        Repeater {
            model: SysTray.items

            Item {
                id: entry

                required property SystemTrayItem modelData

                readonly property string source: AppIcons.usable(entry.modelData.icon) ? entry.modelData.icon : ""

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
                            item.hasMenu ? root.bar.popout("tray", entry, item) : item.activate();
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
