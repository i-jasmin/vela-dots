pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.tokens
import qs.config
import qs.services
// `BarFlow` is the one thing in the shell that knows which way a bar runs, and
// a miniature of the bar has to know the same thing. Imported rather than
// re-derived, so there is one copy -- it belongs in components/, and has not
// moved there yet.
import qs.modules.bar

// The wallpaper switcher's right panel: the bar, wearing the palette the
// selected image would generate.
//
// A SCHEMATIC, NOT A SCALE MODEL, and deliberately. The bar is 58px on a
// 1360px screen; inside a 204px preview that is under one pixel, so the
// design draws it as blocks at its own proportions and so does this. What is
// live about it is everything that is not a size: which edge the bar is on,
// how many workspace pills there are and which one is focused -- read from
// `Config.bar` and `Hypr`, the same two sources the real bar reads -- and the
// six colours, which come from matugen's dry run rather than from the running
// theme. Nothing under modules/bar/ was edited to get this.
//
// The blocks shrink to fit along the rail. That is not a liberty: the design's
// own rail is a CSS flex box whose children all carry the default
// `flex-shrink: 1`, so what it draws is already its authored sizes squashed
// into whatever the panel left. `fit` is that squash, done explicitly.
ClippingRectangle {
    id: root

    // The six roles from `Wallpaper.previewPalette`, hex or empty. Empty falls
    // back to the running scheme, so the panel is never blank.
    readonly property var preview: Wallpaper.previewPalette
    readonly property color accent: root.preview.primary ? root.preview.primary : Colours.primary
    readonly property color accentContainer: root.preview.primaryContainer ? root.preview.primaryContainer : Colours.primaryContainer
    readonly property color second: root.preview.secondary ? root.preview.secondary : Colours.secondary
    readonly property color base: root.preview.surface ? root.preview.surface : Colours.surface

    readonly property string position: Config.bar.position
    readonly property bool vertical: Config.bar.vertical

    // The two ends of the backdrop: the design's `linear-gradient(140deg,
    // #1B3328, #0E1714)` is the generated surface lifted halfway towards the
    // accent container at one end and dropped a step at the other, which is
    // what makes the miniature read as the wallpaper rather than as a panel.
    readonly property color gradientLead: Qt.tint(root.base, Colours.alpha(root.accentContainer, 0.5))
    readonly property color gradientTrail: Qt.darker(root.base, 1.3)
    // 140 degrees in the design's terms is 40 off a plain vertical gradient.
    readonly property real gradientAngle: 40 * Math.PI / 180

    // ---- the rail's contents, squashed to fit ----------------------------
    readonly property int pillCount: Math.max(1, Config.bar.workspaces.count)
    readonly property int activeWorkspace: Math.min(Math.max(Hypr.focusedWorkspaceId, 1), root.pillCount)

    readonly property int railLength: Math.max(0, (root.vertical ? root.height : root.width) - Appearance.wallpaper.miniMargin * 2)
    // tile + pills + two trailing strokes, with a gap between every pair and
    // one either side of the spacer.
    readonly property int needed: Appearance.wallpaper.miniPadding * 2 + Appearance.wallpaper.miniTile + (root.pillCount - 1) * Appearance.wallpaper.miniPill + Appearance.wallpaper.miniPillActive + Appearance.wallpaper.miniItem * 2 + (root.pillCount + 3) * Appearance.wallpaper.miniGap
    readonly property real fit: root.railLength > 0 && root.needed > root.railLength ? root.railLength / root.needed : 1

    function scaled(v: int): int {
        return Math.max(2, Math.floor(v * root.fit));
    }

    // ---- the window mock-up beside the rail ------------------------------
    readonly property int lead: Appearance.wallpaper.miniMargin + Appearance.wallpaper.miniThickness + Appearance.wallpaper.miniLead
    readonly property int alongStart: Appearance.wallpaper.miniMargin + Appearance.wallpaper.miniPadding
    readonly property int freeX: root.vertical ? (root.position === "left" ? root.lead : Appearance.wallpaper.miniGutter) : root.alongStart
    readonly property int freeRight: root.vertical ? (root.position === "right" ? root.lead : Appearance.wallpaper.miniGutter) : Appearance.wallpaper.miniGutter
    readonly property int freeY: root.vertical ? root.alongStart : (root.position === "top" ? root.lead : Appearance.wallpaper.miniGutter)
    readonly property int freeBottom: root.vertical ? Appearance.wallpaper.miniGutter : (root.position === "bottom" ? root.lead : Appearance.wallpaper.miniGutter)

    radius: Appearance.wallpaper.previewRadius
    color: root.gradientTrail

    // A 140-degree gradient, which `Gradient` does not have: a vertical one on
    // a rotated rectangle, sized so its full range crosses the visible box --
    // a square of the diagonal would put both stops off-screen and the
    // backdrop would come out flat.
    Rectangle {
        anchors.centerIn: parent
        width: Math.ceil(parent.height * Math.sin(root.gradientAngle) + parent.width * Math.cos(root.gradientAngle))
        height: Math.ceil(parent.height * Math.cos(root.gradientAngle) + parent.width * Math.sin(root.gradientAngle))
        rotation: -40

        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.gradientLead
            }

            GradientStop {
                position: 1
                color: root.gradientTrail
            }
        }
    }

    // ---- the window the bar sits over ------------------------------------
    Rectangle {
        x: root.freeX
        y: root.freeY
        width: Math.max(0, Math.min(Appearance.wallpaper.miniTitleWidth, root.width - root.freeX - root.freeRight))
        height: Appearance.wallpaper.miniTitleHeight
        radius: Appearance.wallpaper.miniTitleRadius
        color: Colours.alpha(root.accent, 0.5)
    }

    Rectangle {
        x: root.freeX
        y: root.freeY + Appearance.wallpaper.miniTitleHeight + Appearance.wallpaper.miniContentGap
        width: Math.max(0, root.width - root.freeX - root.freeRight)
        height: Math.max(0, root.height - root.freeBottom - y)
        radius: Appearance.wallpaper.miniContentRadius
        color: Colours.alpha(root.base, 0.7)
        border.width: 1
        border.color: Colours.alpha(root.second, 0.08)
    }

    // ---- the rail --------------------------------------------------------
    Rectangle {
        id: rail

        // Placed rather than anchored: an anchor whose binding
        // resolves to `undefined` is not reliably cleared, and `Config` serves
        // its defaults for the first frames, so a position-dependent anchor
        // would leave the rail pinned to the wrong edge.
        x: root.vertical ? (root.position === "left" ? Appearance.wallpaper.miniMargin : root.width - Appearance.wallpaper.miniMargin - Appearance.wallpaper.miniThickness) : Appearance.wallpaper.miniMargin
        y: root.vertical ? Appearance.wallpaper.miniMargin : (root.position === "top" ? Appearance.wallpaper.miniMargin : root.height - Appearance.wallpaper.miniMargin - Appearance.wallpaper.miniThickness)
        width: root.vertical ? Appearance.wallpaper.miniThickness : Math.max(0, root.width - Appearance.wallpaper.miniMargin * 2)
        height: root.vertical ? Math.max(0, root.height - Appearance.wallpaper.miniMargin * 2) : Appearance.wallpaper.miniThickness
        radius: Appearance.radius.small
        color: Colours.alpha(root.base, 0.85)
        border.width: 1
        border.color: Colours.alpha(root.second, 0.1)

        BarFlow {
            anchors.fill: parent
            anchors.topMargin: root.vertical ? root.scaled(Appearance.wallpaper.miniPadding) : 0
            anchors.bottomMargin: anchors.topMargin
            anchors.leftMargin: root.vertical ? 0 : root.scaled(Appearance.wallpaper.miniPadding)
            anchors.rightMargin: anchors.leftMargin

            vertical: root.vertical
            gap: root.scaled(Appearance.wallpaper.miniGap)

            // The launcher tile -- a step larger than everything else on the
            // rail, as it is on the real bar.
            Rectangle {
                implicitWidth: root.vertical ? Appearance.wallpaper.miniTile : root.scaled(Appearance.wallpaper.miniTile)
                implicitHeight: root.vertical ? root.scaled(Appearance.wallpaper.miniTile) : Appearance.wallpaper.miniTile
                radius: Appearance.wallpaper.miniTileRadius
                color: Colours.alpha(root.accent, 0.25)

                Layout.alignment: Qt.AlignCenter
            }

            Repeater {
                model: root.pillCount

                Rectangle {
                    id: pill

                    required property int index

                    readonly property bool active: pill.index + 1 === root.activeWorkspace
                    readonly property int along: root.scaled(pill.active ? Appearance.wallpaper.miniPillActive : Appearance.wallpaper.miniPill)

                    implicitWidth: root.vertical ? Appearance.wallpaper.miniPillCross : pill.along
                    implicitHeight: root.vertical ? pill.along : Appearance.wallpaper.miniPillCross
                    radius: Appearance.wallpaper.miniPillRadius
                    // The active workspace is one of the three things in this
                    // shell allowed to carry colour, here and on the real bar.
                    color: pill.active ? root.accentContainer : Colours.hover

                    Layout.alignment: Qt.AlignCenter
                }
            }

            Item {
                Layout.fillHeight: root.vertical
                Layout.fillWidth: !root.vertical
            }

            // The trailing run -- tray, battery, clock, power -- as the two
            // strokes the design draws for it.
            Repeater {
                model: 2

                Rectangle {
                    implicitWidth: root.vertical ? Appearance.wallpaper.miniPillCross : root.scaled(Appearance.wallpaper.miniItem)
                    implicitHeight: root.vertical ? root.scaled(Appearance.wallpaper.miniItem) : Appearance.wallpaper.miniPillCross
                    radius: Appearance.wallpaper.miniItemRadius
                    color: Colours.alpha(root.second, 0.4)

                    Layout.alignment: Qt.AlignCenter
                }
            }
        }
    }
}
