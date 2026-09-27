pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.tokens
import qs.services as Svc

// The wallpaper, drawn by the shell on the background layer.
//
// The design never gives this a screen, because a wallpaper is not a panel --
// but the wallpaper switcher is a switcher for something, and without this
// there is nothing for it to switch. A new wallpaper is the biggest change the
// shell ever makes, so it gets the longest transition in it (docs/motion.md).
//
// Two Image layers. The outgoing one stays put and the incoming one is revealed
// over it, so nothing ever shows the clear colour mid-change. Exactly two is
// the whole budget: a layer per change would pile up decoded screen-sized
// textures for as long as the reveals overlapped. A reveal draws the incoming
// picture through a soft-edged mask on the GPU (see `Layer`), the way swww's
// transitions do, and a fade is a plain cross-fade.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        // Which layer currently holds the visible wallpaper.
        property bool second: false
        readonly property string source: Svc.Wallpaper.currentFor(win.modelData.name)

        readonly property Layer showing: win.second ? second : first
        readonly property Layer incoming: win.second ? first : second

        // `reduceMotion` turns the reveal into a plain cross-fade and halves it.
        // The flag's rule is opacity only, and a circle expanding across the
        // whole screen is the largest moving thing in the shell -- the one place
        // most worth honouring it, not the one place to make an exception for.
        readonly property string mode: Appearance.reduceMotion ? (Config.background.transition === "none" ? "none" : "fade") : Config.background.transition
        readonly property int duration: {
            const ms = Math.max(0, Config.background.transitionMs);
            return Appearance.reduceMotion ? Math.round(ms / 2) : ms;
        }

        // Where a grow starts. The pointer is asked for at the moment of the
        // change rather than tracked, and its global position is brought back
        // into this screen's own coordinates.
        property real originX: win.width / 2
        property real originY: win.height / 2

        // The furthest corner from the origin, so the circle always finishes by
        // covering the screen rather than leaving a lit rim in one corner.
        readonly property real reach: {
            const dx = Math.max(win.originX, win.width - win.originX);
            const dy = Math.max(win.originY, win.height - win.originY);
            return Math.ceil(Math.sqrt(dx * dx + dy * dy)) * 2;
        }

        screen: modelData
        color: Colours.surface

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "vela-background"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore

        // Nothing here is interactive, and a background that swallowed clicks
        // would break drag-select and right-click on the desktop.
        mask: Region {}

        function placeOrigin(): void {
            if (win.mode !== "grow" || Config.background.transitionOrigin !== "cursor") {
                win.originX = win.width / 2;
                win.originY = win.height / 2;
                return;
            }
            const m = Svc.Hypr.monitorFor(win.modelData.name);
            const c = Svc.Hypr.cursor;
            // A pointer on another monitor would put the origin off-screen, so
            // anything outside this one falls back to its centre.
            const lx = c.x - (m?.x ?? 0);
            const ly = c.y - (m?.y ?? 0);
            const inside = lx >= 0 && ly >= 0 && lx <= win.width && ly <= win.height;
            win.originX = inside ? lx : win.width / 2;
            win.originY = inside ? ly : win.height / 2;
        }

        onSourceChanged: win.present()
        // A monitor plugged in later is created with `source` already set, and
        // QML sends no change signal for an initial value.
        Component.onCompleted: win.present()

        function present(): void {
            if (!win.source)
                return;
            const url = `file://${win.source}`;
            if (String(win.showing.source) === url && win.showing.reveal >= 1)
                return;
            Svc.Hypr.refreshCursor();
            // Going back to the previous wallpaper (super + shift + W) asks the
            // spare layer for the image it already holds. Assigning the same
            // source is a no-op -- no status change, so the reveal would never
            // start and the screen would stay on the newer picture.
            if (String(win.incoming.source) === url && win.incoming.ready) {
                win.incoming.begin();
                return;
            }
            win.incoming.source = url;
        }

        Layer {
            id: first
        }

        Layer {
            id: second
        }
    }

    component Layer: Item {
        id: pane

        // 0 hidden, 1 fully revealed. The shape of the reveal is the
        // transition; this is just how far through it is.
        property real reveal: 0
        property alias source: image.source
        readonly property bool ready: image.status === Image.Ready
        readonly property bool visibleLayer: pane.reveal > 0
        // Mid-reveal. Only then is the picture drawn through the mask; at rest
        // it is a plain image, with no effect and no mask texture behind it.
        readonly property bool revealing: pane.reveal > 0 && pane.reveal < 1

        anchors.fill: parent
        visible: pane.visibleLayer
        // The layer being revealed has to be on top of the one it replaces.
        z: pane.revealing ? 1 : 0

        function begin(): void {
            win.placeOrigin();
            pane.reveal = 0;
            if (win.duration <= 0 || win.mode === "none") {
                pane.reveal = 1;
                win.second = pane === second;
                return;
            }
            grow.restart();
        }

        NumberAnimation {
            id: grow

            target: pane
            property: "reveal"
            from: 0
            to: 1
            duration: win.duration
            // The one curve that suits a reveal: quick to commit, slow to
            // settle, so the eye follows the edge rather than the middle.
            easing.type: Easing.OutCubic
            onFinished: {
                win.second = pane === second;
                // The layer left behind is now the one underneath, and is
                // shown whole so it can be revealed over in its turn.
                win.showing.reveal = 1;
                win.incoming.reveal = 0;
            }
        }

        Image {
            id: image

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            // Decode at the screen's size, not the file's: these run to
            // 7680px, and the full texture is a hundred megabytes of VRAM for
            // a 1920px panel.
            sourceSize.width: win.width
            sourceSize.height: win.height
            // Drawn by the effect below while the reveal runs, and by itself
            // otherwise -- and a fade needs neither mask nor effect at all.
            visible: !pane.revealing || win.mode === "fade"
            opacity: win.mode === "fade" && pane.revealing ? pane.reveal : 1

            onStatusChanged: {
                // Begin only once the image can actually be drawn, so a slow
                // decode never reveals an empty circle.
                if (image.status === Image.Ready && pane.reveal === 0)
                    pane.begin();
            }
        }

        // Grow and wipe show the picture through a mask the size of the
        // screen, softened at its edge.
        //
        // Not a clip. This used to be a ClippingRectangle whose circle grew to
        // several times the screen to reach the far corner, and a clip that
        // large is drawn through a texture the size of the window: the circle
        // came out cut off by a straight edge, and in the frame it settled the
        // whole new wallpaper showed as a rectangle in the top left corner.
        // Here nothing is ever bigger than the screen -- the circle is a
        // gradient painted inside a screen-sized item.
        //
        // Built for each reveal and dropped after it. The effect binds to its
        // mask's texture once, when it is made -- measured: a mask whose layer
        // is switched on afterwards leaves the effect drawing nothing at all --
        // and a mask kept alive between changes would hold a screen-sized
        // texture for nothing.
        Loader {
            anchors.fill: parent
            active: pane.revealing && win.mode !== "fade"

            sourceComponent: Item {
                MultiEffect {
                    anchors.fill: parent
                    source: image
                    maskEnabled: true
                    maskSource: mask
                    // The mask's own soft edge, passed through as it is:
                    // MultiEffect ramps across [min·(1+spread) − spread,
                    // min·(1+spread)], so 0.5 and 1 give 0 to 1. Measured: 0
                    // and 1 ramp across -1 to 0, which shows the whole picture
                    // at once.
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }

                Item {
                    id: mask

                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    // Grow: a disc from the origin, feathered over its last
                    // `feather` pixels, painted as one screen-sized rectangle.
                    Shape {
                        anchors.fill: parent
                        visible: win.mode === "grow"
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            id: disc

                            readonly property real radius: Math.max(1, win.reach / 2 * pane.reveal)

                            strokeWidth: -1
                            startX: 0
                            startY: 0

                            fillGradient: RadialGradient {
                                centerX: win.originX
                                centerY: win.originY
                                centerRadius: disc.radius
                                focalX: win.originX
                                focalY: win.originY

                                GradientStop {
                                    position: 0
                                    color: "white"
                                }

                                GradientStop {
                                    position: Math.max(0, 1 - Appearance.wallpaper.feather / disc.radius)
                                    color: "white"
                                }

                                GradientStop {
                                    position: 1
                                    color: "transparent"
                                }
                            }

                            PathLine {
                                x: mask.width
                                y: 0
                            }

                            PathLine {
                                x: mask.width
                                y: mask.height
                            }

                            PathLine {
                                x: 0
                                y: mask.height
                            }

                            PathLine {
                                x: 0
                                y: 0
                            }
                        }
                    }

                    // Wipe: left to right, with the same soft leading edge.
                    Rectangle {
                        id: band

                        visible: win.mode === "wipe"
                        width: (mask.width + Appearance.wallpaper.feather) * pane.reveal
                        height: mask.height

                        gradient: Gradient {
                            orientation: Gradient.Horizontal

                            GradientStop {
                                position: 0
                                color: "white"
                            }

                            GradientStop {
                                position: Math.max(0, 1 - Appearance.wallpaper.feather / Math.max(1, band.width))
                                color: "white"
                            }

                            GradientStop {
                                position: 1
                                color: "transparent"
                            }
                        }
                    }
                }
            }
        }
    }
}
