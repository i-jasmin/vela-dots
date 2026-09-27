import QtQuick
import qs.tokens

// "FOCUS", "NOW PLAYING", "SYSTEM HEALTH" -- the label that heads every card on
// the dashboard. Eleven pixels, upper case, a tenth of an em of tracking, and
// the last readable neutral in the ramp.
//
// Shared, because the bar's popouts, clipboard history and the Appearance page
// head their sections the same way and the second surface to want one should
// import this rather than write its own.
Text {
    font.family: Appearance.font.ui
    font.pixelSize: Appearance.size.caption
    font.capitalization: Font.AllUppercase
    // `captionTracking` is in em, which is what the design states it in; Qt
    // wants pixels.
    font.letterSpacing: Appearance.size.caption * Appearance.captionTracking
    color: Colours.outline
    elide: Text.ElideRight
}
