import QtQuick
import qs.tokens

// The animation for a surface changing size or place: the dashboard's open and
// tab morph, as one thing to put in a Behavior.
//
//     Behavior on height {
//         Morph {}
//     }
//
// Takes the emphasized curve and the morph duration from `Appearance.anim`,
// so under reduceMotion it is instant -- the new size simply applies.
NumberAnimation {
    duration: Appearance.anim.morph
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Appearance.anim.emphasized
}
