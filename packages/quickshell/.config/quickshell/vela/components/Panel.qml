import QtQuick
import QtQuick.Effects
import qs.tokens

// The floating surface every other surface sits on: the bar, the four popouts,
// the launcher, the dashboard drawer. One component, four elevations -- set
// `level` and the radius, the fill opacity and the shadow all follow.
//
//     Panel {
//         level: "popout"
//         implicitWidth: 292
//         implicitHeight: column.implicitHeight + padding * 2
//
//         ColumnLayout {
//             id: column
//             anchors.fill: parent      // `parent` is the padded content area
//             spacing: Appearance.space.md
//         }
//     }
//
// A Panel does not size itself. Binding its implicit size to the layout's, as
// above, is two lines and cannot loop; deriving it from `childrenRect` here
// would, the moment a child anchored to the panel it is measuring.
//
// TWO THINGS THE WINDOW HAS TO PROVIDE, because a panel cannot do them from
// inside its own item tree:
//
// 1. SHADOW GUTTER. A layer-shell surface clips at its own edges, so the shadow
//    falls outside the window and is scissored away. The window must be
//    `shadowGutter` px larger than the panel on every side -- or cover the
//    screen, as most do -- with the panel inset into it and nothing drawn in
//    the margin:
//
//        PanelWindow {
//            margins { left: 10; top: 10 }     // the design's 10px bar margin
//            Panel { anchors.fill: parent; anchors.margins: shadowGutter }
//        }
//
//    For an anchored bar, only the gutter on the free edges is reachable.
//
// 2. BACKDROP BLUR. The design asks for a 28px blur of whatever is *behind*
//    the panel. QML cannot see behind its own window -- `MultiEffect` only
//    blurs items inside this scene graph -- so the compositor has to do it.
//    Give the window a namespace and let Hyprland blur it:
//
//        WlrLayershell.namespace: "vela-popout"
//        -- hypr/conf/rules.lua
//        hl.layer_rule({ match = { namespace = "^(vela-.*)$" }, blur = true })
//        hl.layer_rule({ match = { namespace = "^(vela-.*)$" }, ignore_alpha = 0.4 })
//
//    `Appearance.backdropBlur` (28) is the radius that rule should carry. The
//    panel is legible without it -- the fill is 82-93% opaque by design -- so a
//    compositor that does not blur degrades to flat, not to unreadable.
Item {
    id: root

    // "bar" | "popout" | "panel" | "drawer" -- the design's four elevations.
    property string level: "panel"

    default property alias content: body.data
    readonly property alias contentItem: body

    property int padding: Appearance.space.panelPadding
    property int radius: root.level === "bar" ? Appearance.radius.barV : root.level === "popout" ? Appearance.radius.popout : root.level === "drawer" ? Appearance.radius.drawer : Appearance.radius.panel

    // Each corner on its own, for a panel against the edge of the screen --
    // the attached bar, square where it meets its edge -- and each side's
    // hairline, which such a panel leaves off along the screen's own edges,
    // where it would sit on the monitor's outermost pixels. The shadow keeps
    // `radius`; the bar, the one panel that squares corners, casts none.
    property real topLeftRadius: root.radius
    property real topRightRadius: root.radius
    property real bottomLeftRadius: root.radius
    property real bottomRightRadius: root.radius
    property bool hairlineLeft: true
    property bool hairlineTop: true
    property bool hairlineRight: true
    property bool hairlineBottom: true

    // Added to the user's panel opacity rather than replacing it, so the
    // settings slider still moves every surface together: .82 bar, .92 popout,
    // .90 launcher, .93 drawer at the default.
    property real opacityBoost: root.level === "bar" ? 0 : root.level === "popout" ? 0.10 : root.level === "drawer" ? 0.11 : 0.08
    property color colour: Colours.alpha(Colours.panel, Math.min(1, Appearance.panelOpacity + root.opacityBoost))
    property color borderColour: Colours.panelBorder

    // The bar carries no shadow in the design; it sits on the wallpaper, not
    // over another surface.
    property int shadowY: root.level === "bar" ? 0 : root.level === "drawer" ? Appearance.shadow.drawerY : Appearance.shadow.panelY
    property int shadowBlur: root.level === "bar" ? 0 : root.level === "drawer" ? Appearance.shadow.drawerBlur : Appearance.shadow.panelBlur
    property real shadowAlpha: root.level === "drawer" ? Appearance.shadow.drawerAlpha : Appearance.shadow.alpha

    // How much transparent room the shadow needs outside the panel: the whole
    // blur, plus the downward offset. Measured, against the "half the blur"
    // this used to allow: `RectangularShadow` fades out across the full
    // `blur` beyond its rectangle -- a drawer's reaches 150px below the panel,
    // 110 either side and 70 above -- and the box below, sized to half of
    // that, cut it off while it was still an eighth of the way dark. That
    // showed as a hard edge round every floating panel's shadow.
    readonly property int shadowGutter: root.shadowBlur === 0 ? 0 : Math.ceil(root.shadowBlur + root.shadowY)

    // The shadow is masked out of the panel's own footprint.
    //
    // `RectangularShadow` fills the whole rounded rect, interior included, and
    // the fill in front of it is 82-93% opaque by design -- so the shadow read
    // through it as a grey cast, densest at the centre where the blur has not
    // fallen off. Measured on a light-mode popout: body #F2F5F6 against the
    // design's #FAFDFE, 8 units, lightening to #F5F9FA at the edges. Dark
    // mode hides it at 2 units, which is why it survived this long.
    //
    // A shadow belongs outside the shape casting it, so the panel's own
    // rounded rect is used as an inverted mask. The mask has to be built in a
    // box grown by `shadowGutter`, because that is the only region the blur
    // reaches and a layer clips to its item.
    Item {
        id: shadowBox

        anchors.fill: parent
        anchors.margins: -root.shadowGutter
        visible: root.shadowBlur > 0

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: shadowMask
        }

        RectangularShadow {
            x: root.shadowGutter
            y: root.shadowGutter
            width: surface.width
            height: surface.height
            radius: surface.radius
            blur: root.shadowBlur
            offset: Qt.vector2d(0, root.shadowY)
            color: Colours.alpha(Colours.shadow, root.shadowAlpha)
            // The panel's geometry rarely changes; cache the shadow rather than
            // re-rasterising a 110px blur every frame the drawer animates.
            cached: true
        }
    }

    ShaderEffectSource {
        id: shadowMask

        anchors.fill: shadowBox
        hideSource: true
        visible: false
        sourceItem: Item {
            width: shadowBox.width
            height: shadowBox.height

            Rectangle {
                x: root.shadowGutter
                y: root.shadowGutter
                width: surface.width
                height: surface.height
                radius: surface.radius
                topLeftRadius: surface.topLeftRadius
                topRightRadius: surface.topRightRadius
                bottomLeftRadius: surface.bottomLeftRadius
                bottomRightRadius: surface.bottomRightRadius
                color: "white"
            }
        }
    }

    // The panel itself: fill, hairline and content.
    //
    // Drawn as one picture while the panel is part-way faded. Qt applies an
    // item's opacity to each thing inside it separately, so a panel fading in
    // showed its layers through one another -- cards as pale boxes over the
    // fill, the settings nav's corner cover as a dark stripe -- for the first
    // frames of every open, which read as a flicker. A layer fades the whole
    // panel as it will look. Only while it is fading: at rest it costs
    // nothing, and text is drawn straight to the window as everywhere else.
    // The shadow is outside this, with its own layer, and fades with it.
    Item {
        id: face

        anchors.fill: parent
        layer.enabled: root.opacity > 0 && root.opacity < 1
        // Smooth, for the surfaces that come forward from a smaller scale
        // while they fade (`Reveal.scaleFrom`).
        layer.smooth: true

        Rectangle {
            id: surface

            anchors.fill: parent
            radius: root.radius
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomLeftRadius: root.bottomLeftRadius
            bottomRightRadius: root.bottomRightRadius
            color: root.colour
        }

        // The hairline, drawn over the fill rather than as the fill's own
        // border. A Rectangle draws its border as a ring and does not paint
        // its colour under it, so a border fainter than the fill is a
        // see-through ring: with the shadow masked out under the panel, the
        // wallpaper showed there untouched, as a light line between every
        // panel and its shadow. Over the fill, the ring is the fill with the
        // hairline on it.
        //
        // A side without one is cut off rather than left undrawn, since a
        // Rectangle's border is one ring: the ring is drawn whole and a
        // hairline's width is clipped from that side, which keeps the corners
        // where the ring turns into the sides that stay.
        Item {
            id: hairlineClip

            readonly property real cut: Appearance.widget.hairline

            anchors.fill: parent
            anchors.leftMargin: root.hairlineLeft ? 0 : hairlineClip.cut
            anchors.topMargin: root.hairlineTop ? 0 : hairlineClip.cut
            anchors.rightMargin: root.hairlineRight ? 0 : hairlineClip.cut
            anchors.bottomMargin: root.hairlineBottom ? 0 : hairlineClip.cut
            clip: !(root.hairlineLeft && root.hairlineTop && root.hairlineRight && root.hairlineBottom)

            Rectangle {
                x: -hairlineClip.anchors.leftMargin
                y: -hairlineClip.anchors.topMargin
                width: root.width
                height: root.height
                radius: root.radius
                topLeftRadius: root.topLeftRadius
                topRightRadius: root.topRightRadius
                bottomLeftRadius: root.bottomLeftRadius
                bottomRightRadius: root.bottomRightRadius
                color: "transparent"
                border.width: Appearance.widget.hairline
                border.color: root.borderColour
            }
        }

        Item {
            id: body

            anchors.fill: parent
            anchors.margins: root.padding
        }
    }
}
