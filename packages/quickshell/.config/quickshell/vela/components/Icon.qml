import QtQuick
import qs.tokens

// A single Material Symbols Rounded glyph. `text` is the ligature name --
// "wifi", "battery_5_bar", "graphic_eq".
//
// Weight 300 and unfilled, everywhere. The design never fills a glyph, and a
// filled one would read as a second accent next to the one colour the screen
// is allowed. Both are variable-font axes, so holding them constant costs
// nothing and a module cannot drift by picking a different weight.
Text {
    id: root

    // 0 unfilled, 1 filled. Animatable, which is how a glyph shows selection
    // without a second icon -- but the shell itself stays at 0.
    property real fill: Appearance.font.iconFill
    property int weight: Appearance.font.iconWeight
    property int grade: Appearance.font.iconGrade

    // Set `size`, not `font.pixelSize`. Both the pixel size and the optical-size
    // axis read this one property, because deriving opsz from `font.pixelSize`
    // closes a loop: assigning `font.variableAxes` mutates `font`, which
    // notifies `pixelSize`, which re-evaluates the axes. It is silent while an
    // icon's size never changes and fires the moment one does -- which a
    // rotatable bar does on every live position change.
    property real size: Appearance.size.iconMd

    font.family: Appearance.font.icon
    font.pixelSize: root.size
    font.variableAxes: ({
            FILL: root.fill.toFixed(2),
            wght: root.weight,
            GRAD: root.grade,
            opsz: root.size
        })
    color: Colours.on.surfaceVariant
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter

    Behavior on color {
        enabled: !Colours.crossing

        ColorAnimation {
            duration: Appearance.anim.fast
            easing.type: Appearance.anim.enterEasing
        }
    }
}
