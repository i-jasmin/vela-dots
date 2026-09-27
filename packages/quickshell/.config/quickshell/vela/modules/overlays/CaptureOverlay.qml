import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.tokens
import qs.config
import qs.services
import qs.components

// Capture, on `super + shift + S`. One keybind starts a region select and the
// verb comes afterwards, which is the whole idea: the user does not have to
// decide between screenshot, recording and OCR before they have decided what
// they are pointing at.
//
// NAMED `CaptureOverlay`, for the reason `ClipboardPanel` is not `Clipboard`: a
// `Capture.qml` here would shadow the `Capture` singleton in `services/`.
//
// WHAT THIS FILE DOES NOT DO. Every verb on the toolbar is a process: `grim`
// for the frame, `wl-copy` to put it on the clipboard, `wf-recorder` for video
// and GIF, `tesseract` for OCR. A module does not start processes, so `run()`
// hands the verb to `services/Capture.qml`, which has exactly the six entry
// points the toolbar names. Everything *else* on the screen -- the region, the
// handles, the live size badge, the keyboard, the window-under-cursor pick --
// is done here, because none of it needs a shell.
//
// The design gives this screen no motion at all: it is instant, both ways. A
// dim that fades in is a dim that is in the way of the thing being captured.
PanelWindow {
    id: root

    readonly property bool shown: ShellState.capture

    // The region, in this window's coordinates. Four reals rather than a `rect`
    // because every edit is to one side of it and clamping reads better this
    // way.
    property real selLeft: 0
    property real selTop: 0
    property real selWidth: 0
    property real selHeight: 0

    // THE WINDOW'S OWN width/height ARE NOT THE SCREEN. A Quickshell
    // PanelWindow reports the size it was asked for, not the size the
    // compositor gave its anchored surface -- measured: 32x100 while the
    // surface covered a 941x1016 output, which clamped a whole-window region
    // down to 11x79. The content item is the only honest source of the area.
    readonly property real areaWidth: keys.width
    readonly property real areaHeight: keys.height

    readonly property real selRight: root.selLeft + root.selWidth
    readonly property real selBottom: root.selTop + root.selHeight

    // Owned by the Capture service: nothing in this file ever sets it.
    readonly property bool recording: Capture.recording
    readonly property int recordedSeconds: Capture.elapsed

    // Choosing a region, as opposed to showing one that is being recorded.
    //
    // While recording, the overlay has to get out of the way: it used to stay
    // up with the keyboard grabbed and screen-wide mouse areas, so the desktop
    // being recorded could not be used, and esc -- the obvious way out -- hid
    // the only stop button while wf-recorder kept going. Now only the frame
    // (drawn outside the region, so it is not in the video) and the stop chip
    // remain, the chip is the only thing that takes input, and the capture key
    // pressed again stops the recording.
    readonly property bool selecting: root.shown && !root.recording

    readonly property string sizeText: `${Math.round(root.selWidth)} × ${Math.round(root.selHeight)}`

    readonly property string recordedText: {
        const m = Math.floor(root.recordedSeconds / 60);
        const s = root.recordedSeconds % 60;
        return `REC ${m < 10 ? "0" : ""}${m}:${s < 10 ? "0" : ""}${s}`;
    }

    screen: {
        const screens = Quickshell.screens;
        if (screens.length === 0)
            return null;
        return screens.find(s => s.name === Hypr.focusedMonitorName) ?? screens[0];
    }

    visible: root.shown || root.recording
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    mask: root.recording ? recordingMask : null

    readonly property Region recordingMask: Region {
        item: recordingChip
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vela-capture"
    WlrLayershell.keyboardFocus: root.selecting ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function setSelection(l: real, t: real, w: real, h: real): void {
        const maxW = root.areaWidth;
        const maxH = root.areaHeight;
        root.selLeft = Math.max(0, Math.min(maxW, l));
        root.selTop = Math.max(0, Math.min(maxH, t));
        root.selWidth = Math.max(0, Math.min(maxW - root.selLeft, w));
        root.selHeight = Math.max(0, Math.min(maxH - root.selTop, h));
    }

    function selectAll(): void {
        root.setSelection(0, 0, root.areaWidth, root.areaHeight);
    }

    // A Hyprland client's geometry is in global logical pixels and this window
    // is one monitor, so the monitor's origin comes off first. Without that a
    // pick on the second screen selects a region off the left of the first.
    function localRectOf(client: var): var {
        const o = client?.lastIpcObject;
        if (!o || !o.at || !o.size)
            return null;
        const mon = Hypr.monitorFor(root.screen?.name ?? "");
        const ox = mon?.x ?? 0;
        const oy = mon?.y ?? 0;
        return {
            "x": o.at[0] - ox,
            "y": o.at[1] - oy,
            "w": o.size[0],
            "h": o.size[1]
        };
    }

    // Only a window this monitor is showing: on its workspace, or on a
    // special workspace open over it, and not a group's hidden tab. By
    // monitor alone, windows on the workspaces out of sight qualified too,
    // and with the pointer over one window the pick could be another that
    // filled the screen on a workspace nobody was looking at.
    function onScreen(client: var): bool {
        const mon = Hypr.monitorFor(root.screen?.name ?? "");
        if (!mon || (client.monitor?.name ?? "") !== mon.name || client.lastIpcObject?.hidden)
            return false;
        const ws = client.workspace?.id;
        return ws !== undefined && (ws === mon.activeWorkspace?.id || ws === mon.lastIpcObject?.specialWorkspace?.id);
    }

    function selectWindowAt(px: real, py: real): void {
        // Topmost first: Hyprland's focus history puts the window most recently
        // on top at the front, which is the one the cursor is over when two
        // overlap.
        const candidates = Hypr.clients.filter(c => root.onScreen(c)).sort((a, b) => (a.lastIpcObject?.focusHistoryID ?? 99) - (b.lastIpcObject?.focusHistoryID ?? 99));
        for (const client of candidates) {
            const r = root.localRectOf(client);
            if (r && px >= r.x && px <= r.x + r.w && py >= r.y && py <= r.y + r.h) {
                root.setSelection(r.x, r.y, r.w, r.h);
                return;
            }
        }
    }

    // Opening with the focused window already selected is what makes "drag to
    // adjust" the right hint: there is always something to adjust. Falling back
    // to a centred region rather than to nothing, so the toolbar is reachable
    // on a bare workspace.
    function resetSelection(): void {
        const r = root.localRectOf(Hypr.activeToplevel);
        if (r && r.w > 0 && r.h > 0)
            root.setSelection(r.x, r.y, r.w, r.h);
        else
            root.setSelection(root.areaWidth * 0.18, root.areaHeight * 0.2, root.areaWidth * 0.64, root.areaHeight * 0.55);
        root.opened = root.selectionKey();
    }

    // Window geometry is only as fresh as Hyprland's last full answer, so the
    // open asks for a new one, and a selection nobody has touched yet follows
    // the focused window when it lands -- or it opened round the window's
    // size of some minutes ago.
    property string opened: ""

    function selectionKey(): string {
        return `${root.selLeft},${root.selTop},${root.selWidth},${root.selHeight}`;
    }

    Connections {
        target: Hypr.activeToplevel
        enabled: root.shown && root.opened !== "" && root.opened === root.selectionKey()

        function onLastIpcObjectChanged(): void {
            root.resetSelection();
        }
    }

    // THE SIX ASKS. Each of these is one line once `Capture` exists:
    //
    //   copy()      grim -g "<region>" - | wl-copy
    //   save()      grim -g "<region>" <Config.capture.saveDir>/<stamp>.png
    //   annotate()  save, then hand the file to an editor
    //   record()    wf-recorder -g "<region>" -f <Config.capture.recordDir>/…
    //   gif()       the same, --codec gif
    //   ocr()       grim -g "<region>" - | tesseract - - -l <ocrLanguage> | wl-copy
    //
    // Until then this says so out loud rather than pretending the button worked.
    function run(verb: string): void {
        // Window-local coordinates and the monitor's name: `Capture` adds the
        // monitor origin itself, because `grim -g` works in the compositor's
        // global space and passing these through unchanged captures the wrong
        // part of the wrong screen on a second monitor.
        Capture.run(verb, root.selLeft, root.selTop, root.selWidth, root.selHeight, root.screen?.name ?? "");

        // Recording keeps the frame and the chip, drawn while `recording`;
        // the surface itself is done either way.
        ShellState.close("capture");
    }

    // A layer-shell window has no size until the compositor has configured its
    // surface, and `onShownChanged` fires before that -- measured: the first
    // reset ran against a 32x100 window and clamped a 773x958 region down to
    // 11x79. So the open arms the reset and the first frame that has a real
    // size performs it. Both dimensions are checked, because they arrive in two
    // separate change notifications and the first one lands with the other
    // still at its default.
    property bool pendingReset: false

    function tryReset(): void {
        if (!root.pendingReset || root.areaWidth <= 1 || root.areaHeight <= 1)
            return;
        root.pendingReset = false;
        root.resetSelection();
    }

    onAreaWidthChanged: root.tryReset()
    onAreaHeightChanged: root.tryReset()

    onShownChanged: {
        if (!root.shown) {
            root.pendingReset = false;
            return;
        }
        // The capture key during a recording stops it. Deferred: closing the
        // surface from inside the handler for its own opening is a binding
        // loop on `shown`, and Qt drops the close.
        if (root.recording) {
            Qt.callLater(() => {
                Capture.stop();
                ShellState.close("capture");
            });
            return;
        }
        root.opened = "";
        Hypr.refresh();
        root.pendingReset = true;
        root.tryReset();
        keys.forceActiveFocus();
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                ShellState.close("capture");
                break;
            case Qt.Key_Space:
                root.selectAll();
                break;
            case Qt.Key_W:
                root.selectWindowAt(picker.mouseX, picker.mouseY);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.run(Config.capture.defaultAction);
                break;
            default:
                return;
            }
            event.accepted = true;
        }

        // ---- the dim ----------------------------------------------------
        //
        // Four rectangles around the region rather than one with a hole in it:
        // QML has no inverse clip, and the selection has to show the live
        // desktop underneath at full brightness or the user cannot see what they
        // are about to capture.
        Repeater {
            model: 4

            Rectangle {
                required property int index

                visible: root.selecting
                color: Colours.scrim

                x: index === 2 ? 0 : index === 3 ? root.selRight : 0
                y: index === 0 ? 0 : index === 1 ? root.selBottom : root.selTop
                width: index < 2 ? root.areaWidth : index === 2 ? root.selLeft : root.areaWidth - root.selRight
                height: index === 0 ? root.selTop : index === 1 ? root.areaHeight - root.selBottom : root.selHeight
            }
        }

        // Drag anywhere on the dim to start a fresh region; the handles and the
        // region itself sit above this and take their presses first.
        MouseArea {
            id: picker

            anchors.fill: parent
            enabled: root.selecting
            hoverEnabled: true
            cursorShape: Qt.CrossCursor

            property real anchorX: 0
            property real anchorY: 0

            onPressed: mouse => {
                picker.anchorX = mouse.x;
                picker.anchorY = mouse.y;
                root.setSelection(mouse.x, mouse.y, 0, 0);
            }

            onPositionChanged: mouse => {
                if (!picker.pressed)
                    return;
                root.setSelection(Math.min(picker.anchorX, mouse.x), Math.min(picker.anchorY, mouse.y), Math.abs(mouse.x - picker.anchorX), Math.abs(mouse.y - picker.anchorY));
            }

            // A click rather than a drag is a mis-hit, not an instruction to
            // capture nothing.
            onReleased: {
                if (root.selWidth < Appearance.overlays.capture.minimum || root.selHeight < Appearance.overlays.capture.minimum)
                    root.resetSelection();
            }
        }

        // ---- the region --------------------------------------------------
        Item {
            id: frame

            x: root.selLeft
            y: root.selTop
            width: root.selWidth
            height: root.selHeight

            // The design's `0 0 40px rgba(primary,.2)` bloom. NOT a shadow: a
            // shadow fills its own shape as well as spreading beyond it, so it
            // would wash 20% cyan over the very thing being captured, and QML
            // has no way to punch the middle back out.
            //
            // Five nested rings instead, each reaching a fifth further out than
            // the last and each drawn at a fifth of the alpha. They stack, so
            // the band next to the edge carries all five and the outermost
            // carries one -- a falloff, in five steps, from .18 to .04. Static:
            // nothing in this shell pulses.
            Repeater {
                model: 5

                Rectangle {
                    required property int index

                    readonly property int reach: Math.round(Appearance.overlays.capture.glow / 5) * (index + 1)

                    anchors.fill: parent
                    anchors.margins: -reach
                    radius: Appearance.overlays.capture.radius + reach
                    color: "transparent"
                    // The border is drawn inside the rectangle, and the
                    // rectangle is grown by exactly the border's width, so the
                    // band lands outside the region and never over it.
                    border.width: reach
                    border.color: Colours.alpha(Colours.primary, Appearance.overlays.capture.glowAlpha / 5)
                }
            }

            // Inside the region, so it would be in the video: shown only
            // while choosing. The bloom above stays outside it.
            Rectangle {
                visible: root.selecting
                anchors.fill: parent
                color: "transparent"
                radius: Appearance.overlays.capture.radius
                border.width: Appearance.overlays.capture.border
                border.color: Colours.primary
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.selecting
                cursorShape: Qt.SizeAllCursor

                property real grabX: 0
                property real grabY: 0

                onPressed: mouse => {
                    grabX = mouse.x;
                    grabY = mouse.y;
                }

                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    root.setSelection(root.selLeft + mouse.x - grabX, root.selTop + mouse.y - grabY, root.selWidth, root.selHeight);
                }
            }
        }

        // ---- the four handles ---------------------------------------------
        Repeater {
            model: 4

            Rectangle {
                id: handle

                required property int index

                // 0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right.
                //
                // `atRight`, not `right`: an Item already has `right` (and
                // `left`, `top`, `bottom`, `baseline`) as a FINAL anchor line,
                // and shadowing one is a hard load error -- "Cannot override
                // FINAL property". Measured.
                readonly property bool atRight: index === 1 || index === 3
                readonly property bool atBottom: index >= 2

                visible: root.selecting
                width: Appearance.overlays.capture.handle
                height: Appearance.overlays.capture.handle
                radius: width / 2
                color: Colours.primary

                x: (handle.atRight ? root.selRight : root.selLeft) - width / 2
                y: (handle.atBottom ? root.selBottom : root.selTop) - height / 2

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Appearance.space.xs
                    cursorShape: handle.atRight === handle.atBottom ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor

                    onPositionChanged: mouse => {
                        if (!pressed)
                            return;
                        const p = mapToItem(keys, mouse.x, mouse.y);
                        const l = handle.atRight ? root.selLeft : p.x;
                        const t = handle.atBottom ? root.selTop : p.y;
                        const r = handle.atRight ? p.x : root.selRight;
                        const b = handle.atBottom ? p.y : root.selBottom;
                        root.setSelection(Math.min(l, r), Math.min(t, b), Math.abs(r - l), Math.abs(b - t));
                    }
                }
            }
        }

        // ---- the live size badge -------------------------------------------
        Rectangle {
            id: badge

            visible: root.selecting

            // Beside the region's top-right corner, and flipped inside when
            // there is no room for it out there.
            readonly property bool outside: root.selRight + Appearance.overlays.capture.badgeGap + width < root.areaWidth

            x: badge.outside ? root.selRight + Appearance.overlays.capture.badgeGap : Math.max(0, root.selRight - width - Appearance.overlays.capture.badgeGap)
            y: root.selTop

            implicitWidth: sizeLabel.implicitWidth + Appearance.overlays.capture.badgePadding * 2
            implicitHeight: Appearance.overlays.capture.badgeHeight
            radius: Appearance.radius.small
            color: Colours.primaryContainer

            Text {
                id: sizeLabel

                anchors.centerIn: parent
                text: root.sizeText
                font.family: Appearance.font.mono
                font.pixelSize: Appearance.size.label
                color: Colours.on.primaryContainer
            }
        }

        // ---- the toolbar ----------------------------------------------------
        Panel {
            id: toolbar

            visible: root.selecting
            level: "drawer"
            radius: Appearance.overlays.capture.toolbarRadius
            padding: Appearance.overlays.capture.toolbarPadding
            shadowY: Appearance.shadow.panelY
            shadowBlur: Appearance.shadow.panelBlur
            shadowAlpha: Appearance.shadow.drawerAlpha

            implicitWidth: verbs.implicitWidth + toolbar.padding * 2
            implicitHeight: verbs.implicitHeight + toolbar.padding * 2

            // Centred on the region and floating below it, and pushed back above
            // it when the region reaches the bottom of the screen.
            x: Math.round(Math.max(0, Math.min(root.areaWidth - width, root.selLeft + (root.selWidth - width) / 2)))
            // Below the region, which is where the design puts it; above it
            // when the region reaches the bottom of the screen; and inside it,
            // hard against its lower edge, when the region is the whole screen
            // and there is no outside left. The hint line rides underneath, so
            // its height is part of the sum.
            y: {
                const needed = height + hint.implicitHeight + Appearance.space.sm;
                const below = root.selBottom + Appearance.overlays.capture.toolbarOffset;
                if (below + needed <= root.areaHeight)
                    return Math.round(below);
                const above = root.selTop - Appearance.overlays.capture.toolbarOffset - needed;
                if (above >= 0)
                    return Math.round(above);
                return Math.round(Math.max(0, Math.min(root.areaHeight, root.selBottom) - needed - Appearance.overlays.capture.toolbarOffset));
            }

            RowLayout {
                id: verbs

                anchors.centerIn: parent
                spacing: Appearance.overlays.capture.toolbarGap

                // The screen's one affirmative verb. Everything else is neutral,
                // including Record -- an error tint on it would read as "this is
                // going wrong" rather than "this is the destructive one".
                Pill {
                    text: qsTr("Copy")
                    icon: "content_copy"
                    tone: "filled"
                    pillHeight: Appearance.overlays.capture.buttonHeight
                    radius: Appearance.overlays.capture.buttonRadius
                    hPadding: Appearance.overlays.capture.buttonPaddingFilled
                    spacing: Appearance.overlays.capture.buttonGap
                    fontSize: Appearance.size.body
                    iconSize: Appearance.overlays.iconToolbar

                    onClicked: root.run("copy")
                }

                Repeater {
                    model: [
                        {
                            "verb": "save",
                            "label": qsTr("Save"),
                            "icon": "save"
                        },
                        {
                            "verb": "annotate",
                            "label": qsTr("Annotate"),
                            "icon": "draw"
                        }
                    ]

                    Pill {
                        required property var modelData

                        text: modelData.label
                        icon: modelData.icon
                        tone: "plain"
                        foreground: Colours.on.surfaceVariant
                        pillHeight: Appearance.overlays.capture.buttonHeight
                        radius: Appearance.overlays.capture.buttonRadius
                        hPadding: Appearance.overlays.capture.buttonPadding
                        spacing: Appearance.overlays.capture.buttonGap
                        fontSize: Appearance.size.body
                        iconSize: Appearance.overlays.iconToolbar

                        onClicked: root.run(modelData.verb)
                    }
                }

                // Stills to the left of it, moving pictures and text to the
                // right: the divider is the whole grouping.
                Rectangle {
                    implicitWidth: 1
                    implicitHeight: Appearance.overlays.capture.dividerHeight
                    color: Colours.panelBorder

                    Layout.leftMargin: Appearance.overlays.capture.dividerMargin
                    Layout.rightMargin: Appearance.overlays.capture.dividerMargin
                    Layout.alignment: Qt.AlignVCenter
                }

                Repeater {
                    model: [
                        {
                            "verb": "record",
                            "label": qsTr("Record"),
                            "icon": "radio_button_checked"
                        },
                        {
                            "verb": "gif",
                            "label": qsTr("GIF"),
                            "icon": "gif_box"
                        },
                        {
                            "verb": "ocr",
                            "label": qsTr("OCR"),
                            "icon": "text_fields"
                        }
                    ]

                    Pill {
                        required property var modelData

                        text: modelData.label
                        icon: modelData.icon
                        tone: "plain"
                        foreground: Colours.on.surfaceVariant
                        pillHeight: Appearance.overlays.capture.buttonHeight
                        radius: Appearance.overlays.capture.buttonRadius
                        hPadding: Appearance.overlays.capture.buttonPadding
                        spacing: Appearance.overlays.capture.buttonGap
                        fontSize: Appearance.size.body
                        iconSize: Appearance.overlays.iconToolbar

                        onClicked: root.run(modelData.verb)
                    }
                }
            }
        }

        // Keybinds are literals, so the whole line is monospace.
        Text {
            id: hint

            visible: root.selecting
            x: Math.round(toolbar.x + (toolbar.width - width) / 2)
            y: Math.round(toolbar.y + toolbar.height + Appearance.space.xs)

            text: qsTr("drag to adjust · space for full screen · w for window under cursor · esc cancels")
            font.family: Appearance.font.mono
            font.pixelSize: Appearance.size.caption
            color: Colours.outline
        }

        // ---- the recording chip ---------------------------------------------
        Rectangle {
            id: recordingChip

            visible: root.recording

            x: root.areaWidth - width - Appearance.space.overlayMargin
            y: Appearance.space.overlayMargin

            implicitWidth: chip.implicitWidth + Appearance.overlays.capture.chipPadding * 2
            implicitHeight: Appearance.overlays.capture.chipHeight
            radius: Appearance.overlays.capture.chipRadius
            color: Colours.alpha(Colours.error, 0.12)
            border.width: 1
            border.color: Colours.alpha(Colours.error, 0.22)

            RowLayout {
                id: chip

                anchors.centerIn: parent
                spacing: Appearance.overlays.capture.chipGap

                Rectangle {
                    implicitWidth: Appearance.overlays.capture.chipDot
                    implicitHeight: Appearance.overlays.capture.chipDot
                    radius: width / 2
                    color: Colours.error
                }

                Text {
                    text: root.recordedText
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.size.body
                    color: Colours.error
                }

                Rectangle {
                    implicitWidth: 1
                    implicitHeight: Appearance.overlays.capture.chipDivider
                    color: Colours.alpha(Colours.error, 0.3)
                }

                Icon {
                    text: "stop_circle"
                    size: Appearance.size.iconRow
                    color: Colours.error

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Capture.stop()
                    }
                }
            }
        }
    }
}
