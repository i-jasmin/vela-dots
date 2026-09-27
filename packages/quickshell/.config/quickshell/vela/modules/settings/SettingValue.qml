import QtQuick
import QtQuick.Layouts
import qs.tokens

// The numeral at the end of a slider row -- "22 px", "84 %", "120 ms".
//
// Right-aligned in a column of its own width so that 8, 84 and 120 do not move
// the track they belong to, and monospace because everything numeric in the
// shell is.
Text {
    font.family: Appearance.font.mono
    font.pixelSize: Appearance.settings.valueSize
    color: Colours.on.surfaceVariant
    horizontalAlignment: Text.AlignRight
    verticalAlignment: Text.AlignVCenter

    Layout.preferredWidth: Appearance.settings.valueWidth
    Layout.alignment: Qt.AlignVCenter
}
