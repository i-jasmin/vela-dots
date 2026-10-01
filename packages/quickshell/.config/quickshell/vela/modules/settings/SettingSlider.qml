import QtQuick
import QtQuick.Layouts
import qs.components
import qs.tokens

// A slider on a settings page: the round handle, the rest of the row, and a
// wheel that waits to be asked.
//
// The pages scroll, and a slider that took every turn of the wheel over it
// changed whatever setting the pointer crossed on the way down the page.
// Click it or tab to it first; from then the wheel moves it, and until then
// the wheel scrolls the page.
Slider {
    handleWidth: Appearance.settings.sliderHandle
    handleHeight: Appearance.settings.sliderHandle
    wheelNeedsFocus: true

    Layout.fillWidth: true
    Layout.alignment: Qt.AlignVCenter
}
