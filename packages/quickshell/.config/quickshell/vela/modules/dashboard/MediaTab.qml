pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.tokens
import qs.services
import qs.components

// Media: what is playing, and the controls for it.
//
// The cover spins inside a ring of 56 bars fed by the audio tap (cava, or
// PipeWire's peak meter where cava is missing), and both stop with playback.
// Top layout: disc beside the controls. Side layout: disc above them.
//
// No "up next": MPRIS carries no queue that Quickshell exposes, and a list
// that could only ever be empty is not worth its space.
Item {
    id: root

    required property bool side
    // The drawer is open. The tap runs only while this tab is both shown and
    // loaded, because it costs a process.
    required property bool live

    readonly property bool playing: Players.playing
    readonly property bool spinning: root.playing && !Appearance.reduceMotion

    onLiveChanged: root.live ? Players.holdWaveform() : Players.releaseWaveform()
    Component.onCompleted: if (root.live)
        Players.holdWaveform()
    Component.onDestruction: if (root.live)
        Players.releaseWaveform()

    // ---- the disc ------------------------------------------------------------
    component Disc: Item {
        id: disc

        implicitWidth: Appearance.dashboard.discBox
        implicitHeight: Appearance.dashboard.discBox

        // The spectrum mirrored round the circle, so low frequencies meet at
        // the top and there is no seam where the highest bar meets the lowest.
        readonly property var levels: Players.waveform
        function level(i: int): real {
            const n = disc.levels.length;
            if (n === 0)
                return Appearance.dashboard.barMin;
            const half = Appearance.dashboard.bars / 2;
            const j = i < half ? i : Appearance.dashboard.bars - 1 - i;
            const v = disc.levels[Math.min(n - 1, Math.floor(j / half * n))] ?? 0;
            return Math.max(Appearance.dashboard.barMin, Math.min(1, v));
        }

        Repeater {
            model: Appearance.dashboard.bars

            Item {
                id: spoke

                required property int index

                x: disc.width / 2
                y: disc.height / 2
                rotation: spoke.index * 360 / Appearance.dashboard.bars

                Rectangle {
                    // Stands on the circle and grows outward.
                    x: -width / 2
                    y: -Appearance.dashboard.barRadius - height
                    width: Appearance.dashboard.barWidth
                    // A paused track keeps its last frame rather than falling.
                    property real target: disc.level(spoke.index)
                    height: Appearance.dashboard.barHeight * (root.playing ? target : Math.max(Appearance.dashboard.barMin, target))
                    radius: Appearance.dashboard.historyRadius
                    color: Colours.primary
                    opacity: spoke.index % 2 ? Appearance.dashboard.barOpacity : Appearance.dashboard.barOpacityDim

                    Behavior on height {
                        enabled: !Appearance.reduceMotion
                        NumberAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }
            }
        }

        ClippingRectangle {
            id: cover

            anchors.centerIn: parent
            width: Appearance.dashboard.cover
            height: Appearance.dashboard.cover
            radius: width / 2
            color: Colours.surfaceContainerHigh

            // Advanced frame by frame rather than animated from 0 to 360, so
            // pausing leaves the disc where it stopped and resuming carries on
            // from there.
            FrameAnimation {
                running: root.live && root.spinning
                onTriggered: cover.rotation = (cover.rotation + frameTime * 360000 / Appearance.dashboard.spinPeriod) % 360
            }

            Image {
                anchors.fill: parent
                source: Players.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: Appearance.dashboard.cover * 2
                sourceSize.height: Appearance.dashboard.cover * 2
                visible: status === Image.Ready
            }

            Icon {
                anchors.centerIn: parent
                visible: !Players.artUrl
                text: "album"
                size: Appearance.size.iconXl
                color: Colours.outline
            }

            // Grooves: faint rings every few pixels, like the pressing.
            Repeater {
                model: Math.floor(Appearance.dashboard.cover / 2 / Appearance.dashboard.grooveEvery)

                Rectangle {
                    required property int index

                    anchors.centerIn: parent
                    width: (index + 1) * Appearance.dashboard.grooveEvery * 2
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: Appearance.widget.hairline
                    border.color: Colours.alpha(Colours.shadow, Appearance.dashboard.grooveAlpha)
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: Appearance.dashboard.spindle + Appearance.dashboard.spindleRing * 2
                height: width
                radius: width / 2
                color: Colours.alpha(Colours.surfaceBarAttached, Appearance.dashboard.spindleRingAlpha)

                Rectangle {
                    anchors.centerIn: parent
                    width: Appearance.dashboard.spindle
                    height: width
                    radius: width / 2
                    color: Colours.surfaceBarAttached
                }
            }
        }
    }

    // ---- meta, scrub, controls -----------------------------------------------
    component Meta: ColumnLayout {
        spacing: Appearance.dashboard.metaGap

        SectionLabel {
            text: Players.hasActive ? qsTr("Now playing · %1").arg(Players.identity) : qsTr("Now playing")
            font.pixelSize: Appearance.dashboard.sectionLabel
            Layout.fillWidth: true
        }

        Text {
            text: Players.hasActive && Players.title ? Players.title : qsTr("Nothing playing")
            font.family: Appearance.font.ui
            font.pixelSize: root.side ? Appearance.dashboard.trackTitleSide : Appearance.dashboard.trackTitleTop
            color: Colours.on.surface
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.topMargin: Appearance.dashboard.metaGap
        }

        Text {
            visible: text !== ""
            text: [Players.artist, Players.album].filter(s => s).join(" — ")
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.dashboard.trackArtist
            color: Colours.on.surfaceVariant
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    component Scrub: ColumnLayout {
        spacing: Appearance.dashboard.scrubGap
        opacity: Players.lengthKnown ? 1 : Appearance.dashboard.disabledOpacity

        Item {
            id: bar

            implicitHeight: Appearance.dashboard.scrubKnob
            Layout.fillWidth: true

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Appearance.dashboard.scrub
                radius: height / 2
                color: Colours.track

                Rectangle {
                    width: parent.width * Players.progress
                    height: parent.height
                    radius: height / 2
                    color: Colours.primary
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: bar.width * Players.progress - width / 2
                width: Appearance.dashboard.scrubKnob
                height: width
                radius: width / 2
                color: Colours.primary
                visible: Players.lengthKnown
            }

            MouseArea {
                anchors.fill: parent
                enabled: Players.canSeek
                cursorShape: Players.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: event => Players.seek(event.x / width)
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: Players.lengthKnown ? Players.formatTime(Players.position) : "--:--"
                font.family: Appearance.font.mono
                font.pixelSize: Appearance.dashboard.eventLabel
                color: Colours.outline
                Layout.fillWidth: true
            }

            Text {
                text: Players.lengthKnown ? Players.formatTime(Players.length) : "--:--"
                font.family: Appearance.font.mono
                font.pixelSize: Appearance.dashboard.eventLabel
                color: Colours.outline
            }
        }
    }

    component ControlIcon: Icon {
        id: control

        property bool active: true
        signal clicked

        opacity: control.active ? 1 : Appearance.dashboard.disabledOpacity

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Appearance.dashboard.hitSlop
            enabled: control.active
            cursorShape: Qt.PointingHandCursor
            onClicked: control.clicked()
        }
    }

    component Controls: RowLayout {
        spacing: Appearance.dashboard.controlsGap

        ControlIcon {
            text: "shuffle"
            size: Appearance.dashboard.controlSmall
            color: Players.shuffling ? Colours.primary : Colours.outline
            active: Players.canShuffle
            onClicked: Players.toggleShuffle()
        }

        ControlIcon {
            text: "skip_previous"
            size: Appearance.dashboard.controlIcon
            color: Colours.on.surfaceVariant
            active: Players.canGoPrevious
            onClicked: Players.previous()
        }

        Rectangle {
            implicitWidth: Appearance.dashboard.playSize
            implicitHeight: Appearance.dashboard.playSize
            radius: Appearance.dashboard.playRadius
            color: Colours.primary
            opacity: Players.hasActive ? 1 : Appearance.dashboard.disabledOpacity

            Icon {
                anchors.centerIn: parent
                text: root.playing ? "pause" : "play_arrow"
                size: Appearance.dashboard.controlIcon
                color: Colours.on.primary
            }

            MouseArea {
                anchors.fill: parent
                enabled: Players.hasActive
                cursorShape: Qt.PointingHandCursor
                onClicked: Players.playPause()
            }
        }

        ControlIcon {
            text: "skip_next"
            size: Appearance.dashboard.controlIcon
            color: Colours.on.surfaceVariant
            active: Players.canGoNext
            onClicked: Players.next()
        }

        ControlIcon {
            text: Players.loopingTrack ? "repeat_one" : "repeat"
            size: Appearance.dashboard.controlSmall
            color: Players.looping ? Colours.primary : Colours.outline
            active: Players.canLoop
            onClicked: Players.cycleLoop()
        }
    }

    component Device: RowLayout {
        spacing: Appearance.dashboard.deviceGap
        visible: Audio.sink !== null

        Icon {
            text: Audio.deviceIcon(Audio.sink)
            size: Appearance.dashboard.deviceIcon
            color: Colours.outline
        }

        Text {
            text: Audio.deviceName(Audio.sink)
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.dashboard.toggleNote
            color: Colours.outline
            elide: Text.ElideRight
            Layout.maximumWidth: Appearance.dashboard.deviceMax
        }
    }

    // ---- top -----------------------------------------------------------------
    Component {
        id: topLayout

        RowLayout {
            spacing: Appearance.dashboard.gapMedia

            Disc {
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                spacing: Appearance.dashboard.gapColumn
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                Meta {
                    Layout.fillWidth: true
                }

                Scrub {
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true

                    Controls {}

                    Item {
                        Layout.fillWidth: true
                    }

                    Device {}
                }
            }
        }
    }

    // ---- side ----------------------------------------------------------------
    Component {
        id: sideLayout

        ColumnLayout {
            spacing: Appearance.dashboard.gapColumn

            Disc {
                Layout.alignment: Qt.AlignHCenter
            }

            Meta {
                Layout.fillWidth: true
            }

            Scrub {
                Layout.fillWidth: true
            }

            Controls {
                Layout.alignment: Qt.AlignHCenter
            }

            Device {
                Layout.alignment: Qt.AlignHCenter
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    Loader {
        anchors.fill: parent
        anchors.leftMargin: root.side ? Appearance.dashboard.padSide : Appearance.dashboard.padMediaLead
        anchors.rightMargin: root.side ? Appearance.dashboard.padSide : Appearance.dashboard.padMedia
        sourceComponent: root.side ? sideLayout : topLayout
    }
}
