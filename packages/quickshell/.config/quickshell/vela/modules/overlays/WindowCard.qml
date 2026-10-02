import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import qs.tokens
import qs.services
import qs.components

// One window in the window picker's grid: a 168px live thumbnail over a footer
// that names the application, the title and the workspace it is sitting on.
//
// THE THUMBNAIL IS THE REAL WINDOW. `ScreencopyView` captures a `Toplevel`, and
// every `HyprlandToplevel` carries one on `.wayland`, so this needs no extra
// Hyprland IPC work, which it was expected to. A window the
// compositor will not hand over (it has no wayland handle yet, or the capture
// has produced no frame) falls back to the application's glyph rather than to a
// grey box pretending to be a screenshot.
//
// The capture is only live while the picker is open: twelve live captures are
// twelve compositor-side copies a frame, and the picker is on screen for about
// a second at a time.
Item {
    id: root

    required property var client
    property bool selected: false
    property bool capturing: false
    // The picker's filter string, highlighted inside the title.
    property string query: ""

    readonly property string appClass: Hypr.classOf(root.client)
    readonly property string windowTitle: root.client?.title ?? ""
    readonly property int workspaceId: root.client?.workspace?.id ?? 0

    // "foot · workspace 2", but "workspace 3" when the title already opens with
    // the application's name and repeating it would say nothing.
    readonly property string source: {
        const ws = qsTr("workspace %1").arg(root.workspaceId);
        const cls = root.appClass;
        if (!cls || root.windowTitle.toLowerCase().startsWith(cls.toLowerCase()))
            return ws;
        return `${cls} · ${ws}`;
    }

    function htmlEscape(s: string): string {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // The match is lifted out of the title in `primary`, which is the one thing
    // on this card allowed to carry colour besides the selection itself.
    readonly property string richTitle: {
        const t = root.windowTitle;
        const q = root.query.trim();
        if (!q)
            return root.htmlEscape(t);
        const i = t.toLowerCase().indexOf(q.toLowerCase());
        if (i < 0)
            return root.htmlEscape(t);
        return `${root.htmlEscape(t.slice(0, i))}<font color="${Colours.primary}">${root.htmlEscape(t.slice(i, i + q.length))}</font>${root.htmlEscape(t.slice(i + q.length))}`;
    }

    signal clicked
    signal activated

    implicitHeight: Appearance.overlays.picker.thumbnail + footer.implicitHeight

    // The halo, outside the card and therefore outside its clip. A ring rather
    // than a glow: the design's `0 0 0 6px` has no blur in it.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -Appearance.overlays.halo
        radius: Appearance.radius.tile + Appearance.overlays.halo
        color: "transparent"
        border.width: Appearance.overlays.halo
        border.color: Colours.alpha(Colours.primary, Appearance.overlays.haloAlpha)
        // Fades between cards as the selection moves, rather than jumping.
        opacity: root.selected ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Appearance.anim.enterEasing
            }
        }
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: Appearance.radius.tile
        color: Colours.surface
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: thumb

                color: Colours.alpha(Colours.surface, 0.9)
                topLeftRadius: card.radius
                topRightRadius: card.radius
                clip: true

                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.overlays.picker.thumbnail

                ScreencopyView {
                    id: capture

                    // Covers the tile and is anchored top-left, which is how the
                    // design crops: the top of a window is where its identity
                    // is -- the tab strip, the first lines of the file.
                    readonly property real scaleFactor: capture.sourceSize.width > 0 && capture.sourceSize.height > 0 ? Math.max(thumb.width / capture.sourceSize.width, thumb.height / capture.sourceSize.height) : 1

                    captureSource: root.capturing ? root.client?.wayland ?? null : null
                    live: root.capturing
                    visible: capture.hasContent

                    width: capture.sourceSize.width * capture.scaleFactor
                    height: capture.sourceSize.height * capture.scaleFactor
                }

                AppIcon {
                    anchors.centerIn: parent
                    visible: !capture.hasContent
                    source: AppIcons.forClient(root.client)
                    glyph: Hypr.iconOf(root.client)
                    size: Appearance.overlays.picker.placeholder
                    imageSize: Appearance.overlays.picker.placeholder * 2
                    color: Colours.outline
                }
            }

            Rectangle {
                id: footer

                color: root.selected ? Colours.primaryContainer : Colours.alpha(Colours.primaryContainer, 0)

                Behavior on color {
                    enabled: !Colours.crossing

                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                Layout.fillWidth: true
                Layout.preferredHeight: strip.implicitHeight + Appearance.overlays.picker.footerPadV * 2

                implicitHeight: strip.implicitHeight + Appearance.overlays.picker.footerPadV * 2

                RowLayout {
                    id: strip

                    anchors.fill: parent
                    anchors.leftMargin: Appearance.overlays.picker.footerPadH
                    anchors.rightMargin: Appearance.overlays.picker.footerPadH
                    spacing: Appearance.overlays.picker.footerGap

                    AppIcon {
                        source: AppIcons.forClient(root.client)
                        glyph: Hypr.iconOf(root.client)
                        size: Appearance.size.iconRow
                        imageSize: Appearance.size.iconRow + Appearance.size.appIconGrow
                        color: root.selected ? Colours.on.primaryContainer : Colours.outline

                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        spacing: 0

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: root.richTitle
                            textFormat: Text.StyledText
                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.size.body
                            color: Colours.on.surface
                            elide: Text.ElideRight

                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.source
                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.size.micro
                            color: root.selected ? Colours.on.primaryContainer : Colours.outline
                            elide: Text.ElideRight

                            Layout.fillWidth: true
                        }
                    }

                    // The design puts a red dot here for a window that is
                    // recording. Nothing on a typical system can tell the shell
                    // that a window is recording, so the same dot carries the
                    // one thing Hyprland does report about a window wanting
                    // attention: urgency.
                    Rectangle {
                        visible: root.client?.urgent ?? false
                        implicitWidth: Appearance.overlays.picker.dot
                        implicitHeight: Appearance.overlays.picker.dot
                        radius: width / 2
                        color: Colours.error

                        Layout.alignment: Qt.AlignVCenter
                    }

                    Rectangle {
                        visible: root.selected
                        implicitWidth: enterKey.implicitWidth + Appearance.overlays.picker.keycapPadH * 2
                        implicitHeight: enterKey.implicitHeight + Appearance.overlays.picker.keycapPadV * 2
                        radius: Appearance.overlays.picker.keycapRadius
                        color: Colours.alpha(Colours.on.primaryContainer, 0.12)

                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: enterKey

                            anchors.centerIn: parent
                            text: "↵"
                            font.family: Appearance.font.mono
                            font.pixelSize: Appearance.size.micro
                            color: Colours.on.primaryContainer
                        }
                    }
                }
            }
        }
    }

    // Drawn last so it sits over the thumbnail: a Rectangle paints its own
    // border before its children, and a live capture would otherwise cover the
    // 2px selection edge entirely.
    Rectangle {
        anchors.fill: parent
        radius: Appearance.radius.tile
        color: "transparent"
        border.width: root.selected ? Appearance.overlays.selectedBorder : 1
        border.color: root.selected ? Colours.primary : Colours.panelBorder

        Behavior on border.color {
            enabled: !Colours.crossing

            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onDoubleClicked: root.activated()
    }
}
