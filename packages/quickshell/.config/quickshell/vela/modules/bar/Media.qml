import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.tokens

// Playing media -- the third and last thing the design lets carry colour, and
// the only one of the three that is not a focus state.
//
// A vertical bar has room for the glyph alone; a horizontal one draws it in
// a chip with the track beside it. The glyph goes `primary` while something is
// actually playing and drops back to the neutral ramp when it is paused --
// paused media is not playing media, and the rule is about the sound, not about
// the player existing.
//
// Nothing at all when there is no player: an empty chip saying nothing is worse
// than the gap it would fill.
//
// A click opens the dashboard on its Media tab, where the player is; a
// right-click plays or pauses, the way right-clicking the speaker mutes it.
Item {
    id: root

    required property BarState bar

    // Folded away with the rest of the status run (BarExpander).
    readonly property bool present: Players.hasActive && !root.bar.collapsed
    readonly property string label: Players.artist ? `${Players.artist} — ${Players.title}` : Players.title
    readonly property color glyphColour: Players.playing ? root.bar.accent(Colours.primary) : Colours.on.surfaceVariant

    implicitWidth: root.bar.vertical ? toggle.implicitWidth : chip.implicitWidth
    implicitHeight: root.bar.vertical ? toggle.implicitHeight : chip.implicitHeight

    BarButton {
        id: toggle

        visible: root.bar.vertical
        anchors.centerIn: parent
        icon: "graphic_eq"
        filled: true
        iconColour: root.glyphColour

        onClicked: root.bar.dashboardOn("media")
        onSecondaryClicked: Players.playPause()
    }

    BarChip {
        id: chip

        visible: !root.bar.vertical
        anchors.verticalCenter: parent.verticalCenter
        padLead: Appearance.bar.chipPadLead
        padTrail: Appearance.bar.chipPadTrail
        interactive: true

        onClicked: root.bar.dashboardOn("media")
        onSecondaryClicked: Players.playPause()

        Icon {
            Layout.alignment: Qt.AlignVCenter
            text: "graphic_eq"
            size: Appearance.size.iconSm
            color: root.glyphColour
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: Appearance.bar.mediaMaxWidth
            text: root.label
            elide: Text.ElideRight
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.label
            color: Colours.on.surfaceVariant
        }
    }
}
