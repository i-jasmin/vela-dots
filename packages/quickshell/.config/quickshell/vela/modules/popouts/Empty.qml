import QtQuick
import QtQuick.Layouts
import qs.tokens

// What a list says when it has nothing in it -- and on a machine with nothing
// paired over Bluetooth, whose battery reports no draw while it sits full on
// mains, that is most of them.
//
// As tall as a list row and aligned with one, so a popout keeps its shape when
// the hardware has nothing to report rather than collapsing to a heading.
Text {
    font.family: Appearance.font.ui
    font.pixelSize: Appearance.size.body
    color: Colours.outline
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    leftPadding: Appearance.space.md
    rightPadding: Appearance.space.md

    Layout.fillWidth: true
    Layout.preferredHeight: Appearance.popout.rowHeight
}
