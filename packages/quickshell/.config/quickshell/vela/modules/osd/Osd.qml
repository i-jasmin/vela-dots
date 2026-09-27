pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.tokens
import qs.components
import qs.services as Svc

// Volume and brightness feedback.
//
// The design gives this no screen of its own -- its light-mode screen only
// lists it among the surfaces a light palette has to cover -- so it is built
// from the same parts as everything else and says nothing the bar does not
// already say. It exists because a volume key that changes the volume and shows
// nothing reads as a key that did not work.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        // What is being shown, and whether to show it. The first value of a
        // session is not a change, so the gate below swallows it -- otherwise
        // the shell announces the volume to nobody every time it starts.
        property string kind: ""
        property bool armed: false

        // One OSD, on the monitor you are using: a key press is not news on
        // every screen at once. Before Hyprland has named a focused monitor,
        // every screen counts as it.
        readonly property bool here: Svc.Hypr.focusedMonitorName === "" || win.modelData.name === Svc.Hypr.focusedMonitorName

        readonly property real value: win.kind === "brightness" ? Svc.Brightness.percent / 100 : Svc.Audio.volume
        readonly property bool muted: win.kind === "volume" && Svc.Audio.muted
        readonly property string icon: {
            if (win.kind === "brightness")
                return "light_mode";
            if (win.muted)
                return "volume_off";
            return Svc.Audio.volume > 0.5 ? "volume_up" : Svc.Audio.volume > 0 ? "volume_down" : "volume_mute";
        }

        function show(what: string): void {
            if (!win.armed || !win.here)
                return;
            win.kind = what;
            linger.restart();
        }

        screen: modelData
        // Held through its exit: the pill sinks and fades out rather than
        // vanishing the instant the timer runs out.
        visible: linger.running || entrance.opacity > 0
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "vela-osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.bottom: true
        exclusionMode: ExclusionMode.Ignore
        // Gutter for the shadow, which a layer surface would otherwise clip.
        implicitWidth: panel.implicitWidth + Appearance.shadow.gutter * 2
        implicitHeight: panel.implicitHeight + Appearance.shadow.gutter * 2
        // Above the bar when the bar is along the bottom: the window ignores
        // exclusive zones, so it would otherwise sit on top of it.
        margins.bottom: Appearance.space.overlayMargin - Appearance.shadow.gutter + (Config.bar.position === "bottom" ? Config.bar.footprint : 0)

        mask: Region {
            item: panel
        }

        // Ignore the values that arrive while the services are still filling in.
        Timer {
            interval: Appearance.osd.armDelay
            running: true
            onTriggered: win.armed = true
        }

        Timer {
            id: linger

            interval: Appearance.osd.linger
        }

        Reveal {
            id: entrance

            shown: linger.running
        }

        Connections {
            function onVolumeChanged(): void {
                win.show("volume");
            }

            function onMutedChanged(): void {
                win.show("volume");
            }

            target: Svc.Audio
        }

        Connections {
            function onPercentChanged(): void {
                win.show("brightness");
            }

            target: Svc.Brightness
        }

        Panel {
            id: panel

            level: "popout"
            // The row below sets its own inset. The panel's padding on top of
            // it left the row less than no height inside a 56px pill, and it
            // collapsed: no bar, no number, the glyph in the corner.
            padding: 0
            anchors.centerIn: parent
            anchors.verticalCenterOffset: entrance.offset
            implicitWidth: Appearance.osd.width
            implicitHeight: Appearance.osd.height
            opacity: entrance.opacity

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Appearance.space.lg
                anchors.rightMargin: Appearance.space.lg
                spacing: Appearance.space.md

                Icon {
                    text: win.icon
                    size: Appearance.size.iconLg
                    color: win.muted ? Colours.outline : Colours.primary
                }

                Rectangle {
                    Layout.fillWidth: true

                    implicitHeight: Appearance.osd.track
                    radius: height / 2
                    color: Colours.track

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, win.value))
                        height: parent.height
                        radius: parent.radius
                        color: win.muted ? Colours.outline : Colours.primary

                        Behavior on width {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                                easing.type: Appearance.anim.enterEasing
                            }
                        }
                    }
                }

                Text {
                    text: `${Math.round(win.value * 100)}`
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.size.label
                    color: Colours.on.surfaceVariant

                    Layout.minimumWidth: Appearance.osd.valueWidth
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
