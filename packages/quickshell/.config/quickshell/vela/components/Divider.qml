import QtQuick
import QtQuick.Layouts
import qs.tokens

// The hairline between a list and the control under it -- the design draws one
// in the Output, Network and Power popouts, always the panel's own border
// colour and always one physical pixel.
//
// It is a file rather than three copies of a two-line Rectangle. It is not in
// `components/` because no other surface has asked for one yet; the moment a
// second does, this belongs there beside `SectionLabel`.
Rectangle {
    implicitHeight: Appearance.widget.hairline
    color: Colours.panelBorder

    Layout.fillWidth: true
}
