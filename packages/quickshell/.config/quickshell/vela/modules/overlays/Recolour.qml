pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.tokens

// The windows crossing over to a new palette together (`Wallpaper.veil`).
//
// Just before a retint, every window on screen is photographed -- one frozen
// frame each, a `ScreencopyView` of its toplevel, like the overview's
// thumbnails -- and drawn exactly over the window it came from. The retint
// runs underneath: kitty is sent its new palette, the browser hears light or
// dark, and each repaints whenever it gets there, unseen. Then the frames
// fade away on the shell's own palette curve, and what shows through is
// every window already in its new colours. The shell itself is not in the
// frames: it eases its own palette, and its panels are drawn above them.
//
// ABOVE THE WINDOWS, BELOW THE SHELL. The top layer is over every window;
// the settings, the notifications and the drawers while they are open are
// on the overlay layer, over this. Nothing here takes a click or a key: the
// input region is empty, and the frames are only up for a second.
//
// Windows are framed bottom first -- tiled, then floating from the least
// recently focused, then fullscreen, then the special workspace's -- so
// where two overlap the frames overlap the same way. The list is taken once,
// as the frames are: focus moving while they are up must not rebuild one
// with the new colours already in it.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        readonly property string name: win.modelData.name
        readonly property var monitor: Hypr.monitorFor(win.name)

        // The windows being framed, and how many frames are in.
        property var frozen: []
        property int captured: 0
        readonly property int wanted: win.frozen.filter(t => t.wayland).length

        function onScreenNow(): var {
            const ws = win.monitor?.activeWorkspace?.id;
            const special = win.monitor?.lastIpcObject?.specialWorkspace?.name ?? "";
            const layer = t => {
                const g = t.lastIpcObject ?? {};
                if (special !== "" && t.workspace?.name === special)
                    return 3;
                return g.fullscreen ? 2 : g.floating ? 1 : 0;
            };
            return Hypr.clients.filter(t => {
                if (!t.workspace || t.lastIpcObject?.hidden)
                    return false;
                return t.workspace.id === ws || (special !== "" && t.workspace.name === special);
            }).sort((a, b) => layer(a) - layer(b) || Hypr.focusRank(b) - Hypr.focusRank(a));
        }

        function report(): void {
            if (Wallpaper.veil === "capturing")
                Wallpaper.markVeilReady(win.name, win.captured >= win.wanted);
        }

        screen: win.modelData
        visible: Wallpaper.veil !== ""
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "vela-recolour"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Connections {
            target: Wallpaper

            function onVeilChanged(): void {
                if (Wallpaper.veil === "capturing") {
                    fade.stop();
                    frames.opacity = 1;
                    win.captured = 0;
                    win.frozen = win.onScreenNow();
                    Qt.callLater(win.report);
                } else if (Wallpaper.veil === "lifting") {
                    fade.restart();
                } else if (Wallpaper.veil === "") {
                    fade.stop();
                    win.frozen = [];
                    win.captured = 0;
                }
            }
        }

        NumberAnimation {
            id: fade

            target: frames
            property: "opacity"
            to: 0
            duration: Appearance.anim.palette
            easing.type: Easing.InOutQuad
        }

        Item {
            id: frames

            anchors.fill: parent

            Repeater {
                model: win.frozen

                ClippingRectangle {
                    id: frame

                    required property var modelData

                    readonly property var geo: frame.modelData.lastIpcObject ?? null

                    x: (frame.geo?.at?.[0] ?? 0) - (win.monitor?.x ?? 0)
                    y: (frame.geo?.at?.[1] ?? 0) - (win.monitor?.y ?? 0)
                    width: frame.geo?.size?.[0] ?? 0
                    height: frame.geo?.size?.[1] ?? 0
                    // Hyprland's own rounding (general.lua), none when
                    // fullscreen.
                    radius: frame.geo?.fullscreen ? 0 : Appearance.recolour.windowRadius
                    color: "transparent"
                    visible: view.hasContent

                    ScreencopyView {
                        id: view

                        anchors.fill: parent
                        captureSource: frame.modelData.wayland ?? null
                        paintCursor: false
                        // Live only until the first frame lands, then frozen
                        // on it: see WindowThumb for why a single
                        // captureFrame() does not work from cold.
                        live: !view.hasContent

                        onHasContentChanged: if (view.hasContent) {
                            win.captured++;
                            win.report();
                        }
                    }
                }
            }
        }
    }
}
