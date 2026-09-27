pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import qs.services
import qs.tokens
import qs.components

// One cell of the workspace overview's grid: a workspace, at 376x232, with its
// windows drawn where they actually are.
//
// Occupied and empty are the same component. An empty workspace is not a
// different kind of card, it is this card with nothing on it -- a dashed
// outline and a plus -- and forking it would make a second copy of the one
// thing, which the shell never keeps.
//
// THE MINIATURE IS GEOMETRIC, not decorative. The design draws its window
// frames by hand at sizes that suit the picture; a real overview has to be
// navigable, which means a window is where it is. The card holds a scale model
// of the monitor, letterboxed into the space under the label, and every window
// sits at its own position and size inside it. The windows themselves are drawn
// by the overview, in one layer over all the cards (see `WindowThumb`); the
// card only lends them that model.
Item {
    id: root

    required property int wsId
    // Carries the ring: the keyboard selection, which starts on the focused
    // workspace.
    required property bool ringed
    // Is actually the focused workspace -- what the "N . focused" label says.
    required property bool current
    // An empty workspace past the next one: fades rather than taking a fourth
    // fill, which is how the design separates 5 from 6.
    required property bool distant
    // Not a workspace yet: the card after the last one, which makes it. The
    // same empty card, captioned for what a click on it does.
    property bool fresh: false

    signal activated
    signal entered

    // Whether anything is on it, for the empty state. `windowCounts` is read,
    // not `Hypr.windowsOn`: moving a window between workspaces changes no
    // toplevel in the list, so a binding over the list alone never re-runs
    // (the trap `Hypr.recount` documents) and a card emptied by a drag kept
    // looking occupied.
    readonly property bool empty: (Hypr.windowCounts[root.wsId] ?? 0) === 0

    // The monitor this workspace lives on, in layout coordinates -- Hyprland
    // reports a monitor's mode in device pixels and a window's geometry in
    // logical ones, so the mode has to be divided by the scale before the two
    // can be compared.
    readonly property var monitor: (Hypr.workspaces.find(w => w.id === root.wsId)?.monitor) ?? Hypr.focusedMonitor
    readonly property real monScale: root.monitor?.scale > 0 ? root.monitor.scale : 1
    readonly property real monWidth: (root.monitor?.width ?? 0) / root.monScale
    readonly property real monHeight: (root.monitor?.height ?? 0) / root.monScale
    readonly property real monX: root.monitor?.x ?? 0
    readonly property real monY: root.monitor?.y ?? 0

    // The space the miniature is allowed: clear of the label, inset from the
    // other three edges.
    readonly property int fieldX: Appearance.overview.thumbInset
    readonly property int fieldY: Appearance.overview.thumbTop
    readonly property int fieldWidth: root.width - Appearance.overview.thumbInset * 2
    readonly property int fieldHeight: root.height - Appearance.overview.thumbTop - Appearance.overview.thumbInset

    // Letterboxed, so the model keeps the monitor's aspect whatever the card's
    // is. Zero while `Hypr` is still empty, which is what keeps the first frame
    // from drawing every window on top of itself at the origin.
    readonly property real fit: root.monWidth > 0 && root.monHeight > 0 ? Math.min(root.fieldWidth / root.monWidth, root.fieldHeight / root.monHeight) : 0
    readonly property real originX: root.fieldX + (root.fieldWidth - root.monWidth * root.fit) / 2
    readonly property real originY: root.fieldY + (root.fieldHeight - root.monHeight * root.fit) / 2

    implicitWidth: Appearance.overview.cardWidth
    implicitHeight: Appearance.overview.cardHeight
    width: implicitWidth
    height: implicitHeight

    // Never the card you are standing on or the one the keyboard is on: those
    // are the two the eye is looking for. Eased on its own, apart from the
    // overview's staggered entrance, which sets `arrival`.
    property real dimming: root.empty && root.distant && !root.ringed && !root.current ? Appearance.overview.distantOpacity : 1
    // The staggered entrance, which the windows drawn over this card follow.
    property real arrival: 1
    property real enterOffset: 0

    opacity: root.dimming * root.arrival
    transform: Translate {
        y: root.enterOffset
    }

    Behavior on dimming {
        NumberAnimation {
            duration: Appearance.anim.fast
            easing.type: Appearance.anim.enterEasing
        }
    }

    // The ring. A solid 6px band at 9%, not a shadow: the design's
    // `box-shadow: 0 0 0 6px` does not blur, so neither does this.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -Appearance.overview.halo
        radius: Appearance.radius.cardLg + Appearance.overview.halo
        color: Colours.alpha(Colours.primary, Appearance.overview.haloAlpha)
        // Faded rather than switched, so it moves between cards with the
        // selection -- the Behavior below used to wait on an opacity nothing
        // ever changed.
        opacity: root.ringed ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Appearance.anim.enterEasing
            }
        }
    }

    Card {
        id: surface

        anchors.fill: parent
        radius: Appearance.radius.cardLg
        padding: Appearance.overview.cardPadding

        color: Colours.alpha(Colours.panel, root.empty ? Appearance.overview.emptyAlpha : root.ringed ? Appearance.overview.focusedAlpha : Appearance.overview.cardAlpha)
        // The dashed outline of an empty card is drawn by the Shape below, so
        // the rectangle's own border only exists when there is something on the
        // workspace.
        border.width: root.empty ? 0 : root.ringed ? Appearance.overview.focusBorder : 1
        border.color: root.ringed ? Colours.primary : Colours.panelBorder

        Behavior on color {
            enabled: !Colours.crossing

            ColorAnimation {
                duration: Appearance.anim.fast
                easing.type: Appearance.anim.enterEasing
            }
        }
    }

    // The empty state's dashed outline. `Rectangle` has no dash, and a row of
    // little rectangles would not follow a corner, so this is the one place in
    // the module that needs a Shape.
    Shape {
        anchors.fill: parent
        visible: root.empty
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false

        ShapePath {
            id: dash

            // An empty card keeps its dashes when it is the selected one: the
            // dash says "nothing here", the colour and the weight say "this is
            // the one". Losing either would lose half the state.
            strokeColor: root.ringed ? Colours.primary : Colours.alpha(Colours.on.surface, Appearance.overview.emptyBorderAlpha)
            strokeWidth: root.ringed ? Appearance.overview.focusBorder : 1
            fillColor: "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: [Appearance.overview.dash, Appearance.overview.dash]

            PathRectangle {
                // Half the stroke in, so a one-pixel rule lands on the card's
                // edge rather than straddling it.
                x: dash.strokeWidth / 2
                y: dash.strokeWidth / 2
                width: root.width - dash.strokeWidth
                height: root.height - dash.strokeWidth
                radius: Appearance.radius.cardLg
            }
        }
    }

    // The empty state's plus and caption.
    Column {
        anchors.centerIn: parent
        spacing: Appearance.overview.emptyGap
        visible: root.empty

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "add"
            size: Appearance.overview.emptyIcon
            color: Colours.outlineVariant
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.fresh ? qsTr("New workspace") : qsTr("Workspace %1").arg(root.wsId)
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.overview.emptyLabelSize
            color: Colours.outline
        }
    }

    // ---- the label --------------------------------------------------------
    //
    // A workspace number is a literal, so it is mono -- and the focused card
    // says so in words rather than only in colour, because colour alone is not
    // a label.
    Text {
        x: Appearance.overview.labelLeft
        y: Appearance.overview.labelTop
        text: root.current ? qsTr("%1 · focused").arg(root.wsId) : `${root.wsId}`
        font.family: Appearance.font.mono
        font.pixelSize: Appearance.overview.labelSize
        font.weight: root.current ? Font.Medium : Font.Normal
        color: root.current ? Colours.primary : Colours.outline
        // An empty card carries no number -- its caption says which workspace
        // it is. The exception is the one you are standing on, which has to say
        // so even when there is nothing on it.
        visible: !root.empty || root.current
    }

    // A HoverHandler rather than the MouseArea's own hover: it reports the
    // cursor without taking it, so moving over a window thumbnail still counts
    // as being over this card.
    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                root.entered();
        }
    }

    // Under the thumbnails deliberately: a click on a window goes to that
    // window, a click anywhere else on the card goes to the workspace.
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
