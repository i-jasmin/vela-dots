pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.tokens
import qs.services
import qs.components

// Focus: the session timer, and the two things it changes elsewhere.
//
// All state lives in services/Focus.qml -- a session keeps counting with the
// drawer shut -- and the two toggles are what the rest of the shell reads:
// "Hold notifications" (Notifs) and "Countdown in the bar" (the bar clock).
// Top layout: the ring beside the controls. Side layout: stacked.
Item {
    id: root

    required property bool side

    readonly property var chips: Focus.presets.map(m => qsTr("%1 min").arg(m))

    component Dial: Ring {
        diameter: Appearance.dashboard.focusRing
        thickness: Appearance.dashboard.focusStroke
        value: Focus.left
        fill: Colours.primary
        capStyle: ShapePath.RoundCap
        // One second per tick, linear, so the arc never pauses between them.
        valueDuration: Appearance.reduceMotion ? 0 : Appearance.dashboard.focusTick
        valueCurve: Appearance.dashboard.linear

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Appearance.dashboard.metaGap

            Text {
                text: Focus.clock
                font.family: Appearance.font.mono
                font.pixelSize: Appearance.dashboard.focusTime
                font.weight: Font.ExtraLight
                font.letterSpacing: Appearance.dashboard.focusTime * Appearance.dashboard.focusTracking
                color: Colours.on.surface
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: Focus.stateLabel
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.dashboard.focusState
                color: Colours.outline
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    component Session: RowLayout {
        spacing: Appearance.dashboard.sessionGap

        Text {
            text: qsTr("Session %1 of %2").arg(Focus.session).arg(Focus.sessionCount)
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.dashboard.sessionLabel
            color: Colours.on.surface
        }

        RowLayout {
            spacing: Appearance.dashboard.dotGap
            Layout.alignment: Qt.AlignVCenter

            Repeater {
                model: Focus.sessionCount

                Rectangle {
                    required property int index

                    readonly property int n: index + 1

                    implicitWidth: n === Focus.session ? Appearance.dashboard.dotCurrent : Appearance.dashboard.dot
                    implicitHeight: Appearance.dashboard.dot
                    radius: height / 2
                    color: n < Focus.session ? Colours.primary : n === Focus.session ? Colours.primaryContainer : Colours.track

                    Behavior on implicitWidth {
                        NumberAnimation {
                            duration: Appearance.dashboard.dotMove
                        }
                    }

                    Behavior on color {
                        enabled: !Colours.crossing

                        ColorAnimation {
                            duration: Appearance.dashboard.dotMove
                        }
                    }
                }
            }
        }
    }

    component Lengths: Segmented {
        sliding: true
        model: root.chips
        currentIndex: Math.max(0, Focus.presets.indexOf(Focus.minutes))
        segmentHeight: Appearance.dashboard.chipHeight
        inset: Appearance.dashboard.chipInset
        railRadius: Appearance.dashboard.chipRailRadius
        hPadding: Appearance.dashboard.chipPad
        fontSize: Appearance.dashboard.chipLabel
        slideDuration: Appearance.dashboard.chipMove
        onSelected: index => Focus.choose(Focus.presets[index])
    }

    component Buttons: RowLayout {
        id: buttons

        property bool stretch: false

        spacing: Appearance.dashboard.gap

        Pill {
            text: Focus.running ? qsTr("Pause") : qsTr("Start")
            icon: Focus.running ? "pause" : "play_arrow"
            tone: "filled"
            pillHeight: Appearance.dashboard.buttonHeight
            hPadding: Appearance.dashboard.buttonPad
            fontSize: Appearance.dashboard.buttonLabel
            iconSize: Appearance.dashboard.buttonIcon
            Layout.fillWidth: buttons.stretch
            onClicked: Focus.toggle()
        }

        Pill {
            text: qsTr("Reset")
            icon: "restart_alt"
            tone: "subtle"
            pillHeight: Appearance.dashboard.buttonHeight
            hPadding: Appearance.dashboard.buttonPad
            fontSize: Appearance.dashboard.buttonLabel
            iconSize: Appearance.dashboard.buttonIcon
            onClicked: Focus.reset()
        }
    }

    component Option: RowLayout {
        id: sw

        property string title
        property string note
        property bool checked
        signal toggled(bool on)

        spacing: Appearance.dashboard.sessionGap

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            Text {
                text: sw.title
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.dashboard.toggleTitle
                color: Colours.on.surface
            }

            Text {
                text: sw.note
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.dashboard.toggleNote
                color: Colours.outline
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Toggle {
            checked: sw.checked
            trackWidth: Appearance.dashboard.toggleWidth
            trackHeight: Appearance.dashboard.toggleHeight
            onToggled: on => sw.toggled(on)
        }
    }

    component Switches: ColumnLayout {
        id: switches

        property bool brief: false

        spacing: Appearance.dashboard.toggleGap

        Option {
            title: qsTr("Hold notifications")
            note: switches.brief ? qsTr("One digest when the session ends") : qsTr("Delivered as one digest when the session ends")
            checked: Focus.holdNotifications
            onToggled: on => Focus.setHoldNotifications(on)
            Layout.fillWidth: true
        }

        Option {
            title: qsTr("Countdown in the bar")
            note: switches.brief ? qsTr("Replaces the clock while focusing") : qsTr("Replaces the clock while a session runs")
            checked: Focus.countdownInBar
            onToggled: on => Focus.setCountdownInBar(on)
            Layout.fillWidth: true
        }
    }

    // ---- top -----------------------------------------------------------------
    Component {
        id: topLayout

        RowLayout {
            spacing: Appearance.dashboard.gapFocus

            Dial {
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                spacing: Appearance.dashboard.gapColumn
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    Layout.fillWidth: true

                    Session {}

                    Item {
                        Layout.fillWidth: true
                    }

                    Lengths {}
                }

                Buttons {}

                Switches {
                    Layout.fillWidth: true
                    Layout.topMargin: Appearance.dashboard.subGap
                }
            }
        }
    }

    // ---- side ----------------------------------------------------------------
    Component {
        id: sideLayout

        ColumnLayout {
            spacing: Appearance.dashboard.gapColumn

            Dial {
                Layout.alignment: Qt.AlignHCenter
            }

            Session {
                Layout.alignment: Qt.AlignHCenter
            }

            Lengths {
                equalWidths: true
                Layout.fillWidth: true
            }

            Buttons {
                stretch: true
                Layout.fillWidth: true
            }

            Switches {
                brief: true
                Layout.fillWidth: true
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    Loader {
        anchors.fill: parent
        anchors.leftMargin: root.side ? Appearance.dashboard.padSide : Appearance.dashboard.padFocusLead
        anchors.rightMargin: root.side ? Appearance.dashboard.padSide : Appearance.dashboard.padMedia
        sourceComponent: root.side ? sideLayout : topLayout
    }
}
