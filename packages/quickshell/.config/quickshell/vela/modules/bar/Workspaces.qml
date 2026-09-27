pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.tokens

// The workspace rail -- the one part of the bar with real behaviour, and the
// part the design calls out: "workspace pill stretches on focus".
//
// The active pill does not just recolour. It STRETCHES: 24px to 38px down a
// vertical bar, 6px of padding to 13px along a horizontal one. That is the
// whole point of the rail -- you find where you are with your peripheral
// vision, from the shape, before the colour has registered.
//
// Six states, five of them drawn in the vertical bar's design:
//
//   active      `primaryContainer` behind `on.primaryContainer`, stretched
//   occupied    `Colours.hover` behind `on.surfaceVariant` -- it has windows,
//               you are not on it. The fill is the half of that state this
//               file used to drop: in both bars the design draws workspace 3 on
//               `rgba(255,255,255,.05)`, the same resting fill the app tile
//               and the media tile carry two items further down the same rail,
//               so it is the occupied state and not a hover demonstration.
//   hovered     `surfaceContainerHigh` -- a step above `hover`, so pointing at
//               an occupied pill still reads as a change
//   empty       `outline` -- it exists in the run, it is unused
//   unused tail `outlineVariant` -- the last pill, the one you have not
//               reached yet. The only place in the shell that colour is
//               allowed, and it is allowed because nothing here is text you
//               read; it is a slot you count.
//
// Clicking an inactive pill focuses that workspace. Clicking the active one
// opens its window list -- which is where the window title lives when the bar
// is a column and has no room for it.
Item {
    id: root

    required property BarState bar

    readonly property int active: Hypr.activeWorkspaceOn(root.bar.screenName)

    // The design shows five: `count` of them always, and past that every
    // number up to the highest workspace in use. The same list the overview
    // draws its cards from, so a workspace made there -- or with super + 6 --
    // is a pill here at once.
    readonly property var ids: Hypr.workspaceIds

    // A horizontal bar pads the rail away from the launcher and the divider
    // either side of it; a vertical one does not, because the rail is already
    // inset by the width of the bar.
    readonly property int pad: root.bar.vertical ? 0 : Appearance.space.xs

    implicitWidth: flow.implicitWidth + (root.bar.vertical ? 0 : root.pad * 2)
    implicitHeight: flow.implicitHeight + (root.bar.vertical ? root.pad * 2 : 0)

    BarFlow {
        id: flow

        anchors.centerIn: parent
        vertical: root.bar.vertical
        gap: Appearance.space.xs

        Repeater {
            model: root.ids

            Rectangle {
                id: pill

                required property int index
                required property int modelData

                readonly property bool isActive: pill.modelData === root.active
                readonly property bool occupied: Hypr.countOn(pill.modelData) > 0
                readonly property bool tail: pill.index === root.ids.length - 1 && !pill.occupied && !pill.isActive

                readonly property int pad: pill.isActive ? Appearance.bar.wsPadActiveH : Appearance.bar.wsPadH

                Layout.alignment: root.bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter

                // The horizontal pill's 22px floor is a MINIMUM ON THE LABEL, not
                // on the pill: the design sizes it content-box, so its 6px
                // padding adds to the floor rather than eating into it, and an
                // idle pill measures 34 across. Reading it the other way made
                // every pill 12px narrow and the rail pitch 26 against the
                // design's 38.
                //
                // The floor is on the PILL, and every pill gets it. It used to
                // apply to idle pills only, on the reasoning that the active
                // one should be free to stretch for a two-digit workspace. It
                // does still stretch -- but a single digit made the active pill
                // 32 against an idle 34, measured on the running bar, so every
                // workspace switch grew one pill by 2px and shrank another, and
                // the whole run after it stepped sideways. A pill changing
                // width is the state change; a pill *moving* is not.
                implicitWidth: root.bar.vertical ? Appearance.bar.wsPillCross : Math.max(Appearance.bar.wsCrossH + Appearance.bar.wsPadH * 2, label.implicitWidth + pill.pad * 2)
                implicitHeight: root.bar.vertical ? (pill.isActive ? Appearance.bar.wsPillActive : Appearance.bar.wsPill) : Appearance.bar.wsCrossH

                radius: Appearance.bar.pillRadius(pill.implicitWidth, pill.implicitHeight)

                color: pill.isActive ? root.bar.accent(Colours.primaryContainer) : mouse.containsMouse ? (pill.occupied ? Colours.surfaceContainerHigh : Colours.hover) : pill.occupied ? Colours.hover : "transparent"

                // The stretch is the state change, not decoration around it --
                // so it is animated, and it halves rather than disappearing
                // under reduceMotion.
                Behavior on implicitWidth {
                    enabled: Config.bar.workspaces.stretchActive

                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Appearance.anim.enterEasing
                    }
                }

                Behavior on implicitHeight {
                    enabled: Config.bar.workspaces.stretchActive

                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Appearance.anim.enterEasing
                    }
                }

                Behavior on color {
                    enabled: !Colours.crossing

                    ColorAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Appearance.anim.enterEasing
                    }
                }

                Text {
                    id: label

                    anchors.centerIn: parent
                    text: pill.modelData
                    // Rubik, not the mono face, although this is a numeral: the
                    // design sets the whole rail in the bar's UI font because
                    // a workspace number is a name you point at, not a quantity
                    // you read off. The horizontal and vertical bars both draw
                    // it this way.
                    font.family: Appearance.font.ui
                    font.pixelSize: Appearance.size.label
                    font.weight: pill.isActive ? Font.Medium : Font.Normal
                    color: pill.isActive ? root.bar.accent(Colours.on.primaryContainer) : pill.occupied ? Colours.on.surfaceVariant : pill.tail ? Colours.outlineVariant : Colours.outline

                    Behavior on color {
                        enabled: !Colours.crossing

                        ColorAnimation {
                            duration: Appearance.anim.fast
                            easing.type: Appearance.anim.enterEasing
                        }
                    }
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Clicking where you already are is the only click with
                    // nothing else to do, so that is the one that opens the
                    // window list. Clicking anywhere else takes you there.
                    onClicked: {
                        if (pill.isActive)
                            root.bar.popout("workspaces", pill, pill.modelData);
                        else
                            Hypr.focusWorkspace(pill.modelData);
                    }
                }
            }
        }
    }

    // The keybind path to the same window list a click on the active pill
    // gives, anchored on the rail rather than on one pill so it lands in the
    // same place either way.
    Connections {
        target: BarPopouts

        function onRequested(name: string): void {
            if (name === "workspaces" && root.bar.forKeys)
                root.bar.popout(name, root, root.active);
        }
    }

    // Not in the design, and invisible until used: the rail is the one place
    // on the bar where a scroll has an obvious meaning.
    //
    // One step per wheel notch (120 units of angleDelta). A touchpad sends a
    // stream of small deltas, and stepping on every one of them raced through
    // every workspace on a single two-finger swipe.
    WheelHandler {
        property real pending: 0

        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            pending += event.angleDelta.y;
            if (Math.abs(pending) < 120)
                return;
            const up = pending > 0;
            pending = 0;
            const at = root.ids.indexOf(root.active);
            if (at < 0)
                return;
            const next = at + (up ? -1 : 1);
            if (next >= 0 && next < root.ids.length)
                Hypr.focusWorkspace(root.ids[next]);
        }
    }
}
