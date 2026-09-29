import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.tokens
import qs.config
import qs.services
import qs.components

// Sessions: named window layouts, saved and brought back.
//
// All of it lives in services/Sessions.qml: saving (with each terminal's
// working directory), restoring (reopening apps onto their workspaces), and
// the last session brought back at login. This file draws it.
//
// One layout is active at a time -- the one last saved, updated or restored,
// while the apps on screen are still its apps. The active card offers Update;
// every other card offers Restore.
PanelWindow {
    id: root

    readonly property bool shown: ShellState.sessions

    screen: {
        const screens = Quickshell.screens;
        if (screens.length === 0)
            return null;
        return screens.find(s => s.name === Hypr.focusedMonitorName) ?? screens[0];
    }

    readonly property int insetLeft: Config.bar.position === "left" ? Config.bar.footprint : 0
    readonly property int insetRight: Config.bar.position === "right" ? Config.bar.footprint : 0
    readonly property int insetTop: Config.bar.position === "top" ? Config.bar.footprint : 0
    readonly property int insetBottom: Config.bar.position === "bottom" ? Config.bar.footprint : 0

    visible: root.shown || panel.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vela-sessions"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (!root.shown)
            return;
        // Geometry and pids are only as fresh as the last full query, and a
        // window resized since then would be saved at its old size.
        Hypr.refresh();
        keys.forceActiveFocus();
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key !== Qt.Key_Escape)
                return;
            ShellState.close("sessions");
            event.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            color: Colours.scrim
            opacity: panel.opacity
        }

        MouseArea {
            anchors.fill: parent

            onClicked: event => {
                const p = mapToItem(panel, event.x, event.y);
                if (p.x < 0 || p.y < 0 || p.x > panel.width || p.y > panel.height)
                    ShellState.close("sessions");
            }
        }

        Panel {
            id: panel

            level: "drawer"
            padding: Appearance.space.drawerPadding

            width: Math.min(Appearance.overlays.sessions.width, parent.width - root.insetLeft - root.insetRight - Appearance.space.overlayMargin * 2)
            implicitHeight: column.implicitHeight + panel.padding * 2

            x: Math.round(root.insetLeft + (parent.width - root.insetLeft - root.insetRight - width) / 2)

            readonly property int restY: Math.round(root.insetTop + (parent.height - root.insetTop - root.insetBottom) * Appearance.overlays.topSessions)
            y: panel.restY + entrance.offset
            opacity: entrance.opacity

            Reveal {
                id: entrance

                shown: root.shown
            }

            ColumnLayout {
                id: column

                anchors.fill: parent
                spacing: Appearance.overlays.blockGap

                // ---- header -------------------------------------------------
                RowLayout {
                    spacing: Appearance.overlays.headerGap

                    Layout.fillWidth: true

                    Icon {
                        text: "bookmarks"
                        size: Appearance.size.iconLg
                        color: Colours.primary

                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: qsTr("Sessions")
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.heading
                        color: Colours.on.surface

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // The screen's one affirmative verb, and the only thing on
                    // it that is filled.
                    Pill {
                        text: qsTr("Save current")
                        icon: "add"
                        tone: "filled"
                        enabled: Hypr.clients.length > 0
                        pillHeight: Appearance.overlays.sessions.chipHeight
                        radius: Appearance.overlays.sessions.chipRadius
                        hPadding: Appearance.overlays.sessions.savePadding
                        fontSize: Appearance.size.body
                        iconSize: Appearance.size.iconLabel

                        Layout.alignment: Qt.AlignVCenter

                        onClicked: Sessions.save(null)
                    }

                    // A keybind is a literal.
                    Text {
                        visible: text !== ""
                        text: BindEditor.label("sessions.save", Config.keybinds.sessionSave)
                        font.family: Appearance.font.mono
                        font.pixelSize: Appearance.size.caption
                        color: Colours.outline

                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                // ---- the saved layouts ----------------------------------------
                //
                // A card is always one column of three wide. Stretched to fill
                // the row, a lone layout became a card the width of the panel.
                // A row of fewer than three is centred.
                GridLayout {
                    id: grid

                    readonly property real cardWidth: Math.floor((grid.parent.width - Appearance.overlays.cardGap * (Appearance.overlays.columns - 1)) / Appearance.overlays.columns)

                    columns: Math.max(1, Math.min(Appearance.overlays.columns, Sessions.sessions.length))
                    columnSpacing: Appearance.overlays.cardGap
                    rowSpacing: Appearance.overlays.cardGap
                    visible: Sessions.sessions.length > 0

                    Layout.alignment: Qt.AlignHCenter

                    Repeater {
                        model: Sessions.sessions

                        SessionCard {
                            id: card

                            required property var modelData
                            required property int index

                            session: modelData
                            active: Sessions.isActive(modelData)
                            canRestore: !Sessions.busy
                            restoring: Sessions.restoring === modelData.name
                            opacity: arrival.opacity
                            transform: Translate {
                                y: arrival.offset
                            }

                            Layout.preferredWidth: grid.cardWidth
                            Layout.preferredHeight: implicitHeight

                            Stagger {
                                id: arrival

                                index: card.index
                                active: entrance.entering
                            }

                            onUpdateRequested: Sessions.update(index)
                            onRestoreRequested: {
                                Sessions.restore(index);
                                ShellState.close("sessions");
                            }
                            onRenamed: name => Sessions.rename(index, name)
                            onForgotten: Sessions.forget(index)
                        }
                    }
                }

                ColumnLayout {
                    visible: Sessions.sessions.length === 0
                    spacing: Appearance.space.xs

                    Layout.fillWidth: true
                    Layout.topMargin: Appearance.space.xl
                    Layout.bottomMargin: Appearance.space.xl

                    Text {
                        text: qsTr("No layouts saved yet")
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.body
                        color: Colours.on.surface
                        horizontalAlignment: Text.AlignHCenter

                        Layout.fillWidth: true
                    }

                    Text {
                        text: qsTr("Arrange the windows you want, then save the arrangement a name")
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.label
                        color: Colours.outline
                        horizontalAlignment: Text.AlignHCenter

                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    implicitHeight: 1
                    color: Colours.panelBorder

                    Layout.fillWidth: true
                }

                // ---- footer ----------------------------------------------------
                RowLayout {
                    spacing: Appearance.overlays.headerGap

                    Layout.fillWidth: true

                    ColumnLayout {
                        spacing: Appearance.space.xs

                        Layout.fillWidth: true

                        Text {
                            text: qsTr("Restoring reopens apps, not just frames")
                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.size.body
                            color: Colours.on.surface

                            Layout.fillWidth: true
                        }

                        Text {
                            text: Config.sessions.captureWorkingDirectory ? qsTr("Each window records its class, workspace, tiling position and working directory. Terminals come back in the folder you left them in.") : qsTr("Each window records its class, workspace and tiling position. Working directories are not recorded (sessions.captureWorkingDirectory is off).")
                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.size.label
                            color: Colours.outline
                            wrapMode: Text.Wrap

                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        implicitWidth: loginRow.implicitWidth + Appearance.overlays.sessions.chipPadding * 2
                        implicitHeight: Appearance.overlays.sessions.chipHeight
                        radius: Appearance.overlays.sessions.chipRadius
                        color: Colours.hover

                        Layout.alignment: Qt.AlignVCenter

                        RowLayout {
                            id: loginRow

                            anchors.centerIn: parent
                            spacing: Appearance.overlays.sessions.chipGap

                            Icon {
                                text: "restore"
                                size: Appearance.size.iconLabel
                                color: Colours.outline
                            }

                            Text {
                                text: qsTr("Restore last session on login")
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.size.label
                                color: Colours.on.surfaceVariant
                            }

                            // Brings back the layout as it last stood, the first
                            // time the shell starts under a new Hyprland.
                            Toggle {
                                checked: Config.sessions.restoreOnLogin
                                trackWidth: Appearance.overlays.sessions.toggleWidth
                                trackHeight: Appearance.overlays.sessions.toggleHeight

                                onToggled: on => {
                                    Config.sessions.restoreOnLogin = on;
                                    Config.save();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
