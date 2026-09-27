import QtQuick
import qs.tokens

// The last item on the bar. Opens the power menu.
//
// Not to be confused with the Power popout, which is the battery's
// -- percentage, profiles, draw. This one ends the session. Two different
// things wearing the same word, and the bar is where they sit next to each
// other, so: this button drives `ShellState.power`; the battery drives
// `BarPopouts.current === "power"`.
BarButton {
    id: root

    required property BarState bar

    size: root.bar.vertical ? Appearance.bar.iconButton : Appearance.bar.iconButtonH
    iconSize: root.bar.vertical ? Appearance.size.iconMd : Appearance.size.iconRow
    icon: "power_settings_new"
    showing: root.bar.holds("power")

    onClicked: root.bar.toggle("power")
}
