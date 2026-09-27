import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.config
import qs.services
import qs.components

// The lock screen, assembled. One surface per output; `WlSessionLock` builds
// it, so everything here is created after the compositor has already locked --
// which is why nothing in this file may fail. A component that throws on load
// would leave the session locked with a blank screen on it.
Item {
    id: root

    property Auth auth: null
    property bool releasing: false

    // Both taps in `Players` cost CPU, so they are reference counted. The lock
    // holds one only while it is up and something is actually playing, and lets
    // go the instant either stops being true -- including on destruction, which
    // is the path that matters here: the surface is torn down when the session
    // is released, and a tap left held would leave cava decoding audio for the
    // rest of the session.
    readonly property bool wantsTap: root.visible && Players.playing && (Config.lock.showMedia || Config.lock.audioReactiveArc)
    property bool holding: false

    // Ten of the 24 bars the spectrum meters, evenly spread, because ten is
    // what the design draws and 24 at this width would be a solid block.
    readonly property var levels: {
        const src = Players.waveform ?? [];
        const want = Appearance.lock.levelsBars;
        if (src.length < want)
            return [];

        const out = [];
        for (let i = 0; i < want; i++)
            out.push(src[Math.round(i * (src.length - 1) / (want - 1))] ?? 0);
        return out;
    }

    onWantsTapChanged: {
        if (root.wantsTap === root.holding)
            return;
        root.holding = root.wantsTap;
        if (root.holding)
            Players.holdWaveform();
        else
            Players.releaseWaveform();
    }

    Component.onCompleted: {
        if (root.wantsTap) {
            root.holding = true;
            Players.holdWaveform();
        }
        field.focusField();
    }

    Component.onDestruction: if (root.holding)
        Players.releaseWaveform()

    focus: true

    // The whole surface leaves together once the password is accepted. Opacity
    // only, and the session is released by a timer in Lock.qml that does not
    // wait for this to finish -- see the note there.
    opacity: root.releasing ? 0 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Appearance.anim.exitEasing
        }
    }

    LockBackdrop {
        anchors.fill: parent
        // Negative means "not tracking anything", which is not the same as a
        // level of zero -- silence is a real reading.
        level: Config.lock.audioReactiveArc && root.holding ? Players.level : -1
        turning: Config.lock.audioReactiveArc && root.holding && !Appearance.reduceMotion
    }

    // The centre stack is centred, EXCEPT on a screen too short to hold it and
    // the bottom stack at the design's offsets -- 960x540 is a real case, and
    // it is what a 1920x1080 panel at scale 2 reports. There it moves up until
    // it clears the entry block rather than being drawn through it. Placed with
    // x/y rather than an anchor because the position is conditional.
    readonly property real clockTop: Math.min(root.height / 2 - clock.height / 2, entry.y - Appearance.space.lg - clock.height)
    // How far off centre that pushed it, so the stats travel with the clock
    // instead of staying behind on the centre line.
    readonly property real centreShift: root.clockTop - (root.height / 2 - clock.height / 2)

    LockClock {
        id: clock

        x: (root.width - width) / 2
        y: root.clockTop
        stateText: root.auth?.busy ? qsTr("Checking") : qsTr("Locked")
    }

    LockStats {
        x: (root.width - width) / 2
        y: root.height / 2 + Appearance.lock.statsOffset + root.centreShift
        // Below a certain height there is no room for them at all. Tested
        // against the screen rather than against this row's own height, which
        // would be a binding on the thing the binding decides -- a loop.
        visible: Config.lock.showStats.length > 0 && root.height >= Appearance.lock.statsMinHeight
    }

    ColumnLayout {
        id: entry

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Appearance.lock.bottomMargin
        spacing: Appearance.lock.bottomGap

        LockIdentity {
            Layout.alignment: Qt.AlignHCenter
        }

        PasswordField {
            id: field

            auth: root.auth

            Layout.alignment: Qt.AlignHCenter
        }

        // One slot, two things to say: the fingerprint hint when PAM has a
        // reader to offer, and whatever PAM said when it refused an attempt.
        // Held at a fixed height so the field does not walk up and down the
        // screen as the message comes and goes.
        RowLayout {
            spacing: Appearance.lock.hintGap

            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Appearance.size.iconLabel

            Icon {
                text: "fingerprint"
                size: Appearance.size.iconLabel
                color: Colours.outline
                visible: hint.text !== "" && !root.auth?.failed
            }

            Text {
                id: hint

                text: {
                    if (root.auth?.message)
                        return root.auth.message;
                    if (Config.lock.fingerprint && root.auth?.fingerprintPrompted)
                        return qsTr("or touch the reader");
                    return "";
                }
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.label
                color: root.auth?.failed ? Colours.error : Colours.outline

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    LockMedia {
        x: Appearance.lock.cornerMargin
        y: parent.height - height - Appearance.lock.cornerMargin
        visible: Config.lock.showMedia && Players.hasActive
    }

    // The live spectrum. Drawn only while the tap is actually held, so it is
    // never a still picture of a waveform that is not moving.
    Sparkline {
        x: parent.width - width - Appearance.lock.cornerMargin
        y: parent.height - height - Appearance.lock.cornerMargin
        implicitWidth: Appearance.lock.levelsBars * Appearance.lock.levelsBarWidth + (Appearance.lock.levelsBars - 1) * Appearance.lock.levelsGap
        implicitHeight: Appearance.lock.levelsHeight
        visible: Config.lock.showMedia && root.holding && root.levels.length > 0
        opacity: Appearance.lock.levelsOpacity

        values: root.levels
        maxValue: 1
        barSpacing: Appearance.lock.levelsGap
        fill: Colours.muted
        highlight: Colours.primary
        highlightAbove: Appearance.lock.levelsHighlight
    }

    LockNetwork {
        x: parent.width - width - Appearance.lock.cornerMargin
        y: Appearance.lock.cornerMargin
    }
}
