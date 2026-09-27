import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.services

// The middle of the lock: a tracked-out state word, a 154px monospace time and
// the date under it. The one place in the shell where type is the whole design,
// so the three tracking corrections below matter more than they look.
ColumnLayout {
    id: root

    // "LOCKED" / "CHECKING" -- the only thing in the centre stack that moves.
    // Not called `state`: every Item already has one.
    property string stateText: ""

    spacing: Appearance.lock.centreGap

    Text {
        text: root.stateText.toUpperCase()
        font.family: Appearance.font.ui
        font.pixelSize: Appearance.lock.stateSize
        font.letterSpacing: Appearance.lock.stateSize * Appearance.lock.stateTracking
        // Qt adds letter spacing after the last glyph as well, so a tracked-out
        // word sits half a space left of centre until the same amount is put
        // back on its leading edge.
        leftPadding: font.letterSpacing
        // The state of the session is what the screen is for -- one of the few
        // things the design lets carry colour.
        color: Colours.primary

        Layout.alignment: Qt.AlignHCenter
    }

    Text {
        text: Time.time
        font.family: Appearance.font.mono
        font.pixelSize: Appearance.size.display
        font.weight: Font.ExtraLight
        font.letterSpacing: Appearance.size.display * Appearance.lock.clockTracking
        // Negative tracking, so the correction goes the other way.
        leftPadding: -font.letterSpacing
        color: Colours.on.surface
        // The design sets `line-height: 1` on the clock. Qt's own line box for
        // a 154px face is a third taller than that, and the extra would push
        // the date -- and with it the whole centre stack's idea of its own
        // height -- 30px down the screen. Digits carry no descender, so a line
        // box the height of the type is exactly right here and nowhere else.
        verticalAlignment: Text.AlignVCenter

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: Appearance.size.display
    }

    Text {
        text: Time.date
        font.family: Appearance.font.ui
        font.pixelSize: Appearance.lock.dateSize
        font.weight: Font.Light
        color: Colours.on.surfaceVariant

        Layout.alignment: Qt.AlignHCenter
    }
}
