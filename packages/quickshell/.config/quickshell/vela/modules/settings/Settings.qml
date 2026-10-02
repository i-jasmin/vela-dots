pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.tokens
import qs.components

// The settings window. 1020x706, a 242px nav whose current page is a
// full-height pill, and a content pane of section labels and cards.
//
// IT WRITES shell.json AND HOLDS NO STATE OF ITS OWN. There is no pending copy
// of a setting anywhere in this module: every control reads `Config` and writes
// `Config`, the shell is already bound to `Config`, and `Persist` puts the
// adapter back on disk behind them. Editing shell.json by hand while the window
// is open moves the controls, because there is only ever one answer to what a
// setting is.
//
// THE WINDOW IS FULL SCREEN AND THE PANEL IS INSET INTO IT: a layer-shell
// surface clips at its own edges, so the `0 30px 80px` shadow needs
// transparent gutter to fall into, and the panel is centred on the space the
// bar leaves. Nothing is drawn in the margin.
//
// AND IT IS NOT MODAL. Only the panel takes input (`mask`); everywhere else the
// pointer goes to whatever is underneath. It used to take the whole screen,
// with a click beside the panel closing it and the keyboard held exclusively,
// which put everything else out of reach for as long as it was open: an
// autohiding bar could not be revealed (the cursor never reached its strip at
// the edge), the bar and the dock could not be clicked, and a file it opened --
// the calendar's, an editor on a config -- could not be typed into until it
// closed. Now it is put away with esc, the close button or super + I, and the
// keyboard is on demand: it has it when it opens, and gives it up to a window
// that is clicked or, with focus following the mouse, pointed at. It takes it
// back exclusively only while a keybind is being recorded (BindEditor.capturing),
// where every key has to reach it.
PanelWindow {
    id: root

    readonly property bool shown: ShellState.settings

    // The nav, in the design's order, with General added at the top: the
    // settings that belong to no one surface (location, units, folders) had
    // nowhere else to go. `About` is last but sits below the spacer, so it is
    // indexed with the rest and drawn apart from them.
    readonly property var pages: [
        {
            key: "general",
            label: qsTr("General"),
            icon: "tune"
        },
        {
            key: "appearance",
            label: qsTr("Appearance"),
            icon: "palette"
        },
        {
            key: "bar",
            label: qsTr("Bar"),
            icon: "view_quilt"
        },
        {
            key: "notifications",
            label: qsTr("Notifications"),
            icon: "notifications"
        },
        {
            key: "calendars",
            label: qsTr("Calendars"),
            icon: "calendar_month"
        },
        {
            key: "launcher",
            label: qsTr("Launcher"),
            icon: "search"
        },
        {
            key: "lock",
            label: qsTr("Lock screen"),
            icon: "lock"
        },
        {
            key: "keybinds",
            label: qsTr("Keybinds"),
            icon: "keyboard"
        },
        {
            key: "modules",
            label: qsTr("Modules"),
            icon: "extension"
        },
        {
            key: "ai",
            label: qsTr("AI tools"),
            icon: "terminal"
        },
        {
            key: "about",
            label: qsTr("About"),
            icon: "info"
        }
    ]

    // The last page is drawn below the spacer, the rest above it.
    readonly property int aboutIndex: root.pages.length - 1

    property int page: 0

    readonly property var pageDef: root.pages[Math.min(root.page, root.aboutIndex)]

    // The design centres the window on the space the bar leaves, not on the
    // screen: its 204px left edge is 34 past centre, which is half of the 58px
    // rail plus its 10px margin. One expression covers all four bar positions,
    // and a position change moves the window live.
    readonly property int insetLeft: Config.bar.position === "left" ? Config.bar.footprint : 0
    readonly property int insetRight: Config.bar.position === "right" ? Config.bar.footprint : 0
    readonly property int insetTop: Config.bar.position === "top" ? Config.bar.footprint : 0
    readonly property int insetBottom: Config.bar.position === "bottom" ? Config.bar.footprint : 0

    function showPage(i: int): void {
        const next = Math.max(0, Math.min(root.aboutIndex, i));
        // The pane crosses over the way the nav runs: a page further down
        // comes up from below, one further up comes down from above.
        pane.direction = next < root.page ? -1 : 1;
        root.page = next;
        const item = root.page === root.aboutIndex ? aboutItem : navItems.itemAt(root.page);
        if (item)
            item.forceActiveFocus();
    }

    // Follows the focused monitor. `Hypr` is empty for the first second or two
    // of a session, so this falls through to the first screen rather than to
    // null, which would put the window wherever the compositor felt like.
    screen: {
        const screens = Quickshell.screens;
        if (screens.length === 0)
            return null;
        return screens.find(s => s.name === Hypr.focusedMonitorName) ?? screens[0];
    }

    // Held open through the exit animation, then dropped: a hidden layer
    // surface still costs the compositor a buffer.
    visible: root.shown || win.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vela-settings"
    // On demand: the compositor hands it the keyboard as it opens, so esc
    // works without a click first, but a window can take it back. Exclusive
    // only while a keybind is being recorded.
    WlrLayershell.keyboardFocus: !root.shown ? WlrKeyboardFocus.None : BindEditor.capturing !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    // Only the panel answers the pointer: see the header.
    mask: Region {
        item: win
    }

    // Recording a keybind ends with the window, however it was put away.
    onVisibleChanged: {
        if (!root.visible)
            BindEditor.cancelCapture();
    }

    // Opened on a page by name (the cheatsheet's "Edit in settings"), or on
    // whichever page was showing last.
    onShownChanged: {
        if (!root.shown)
            return;
        const wanted = root.pages.findIndex(p => p.key === ShellState.settingsPage);
        ShellState.settingsPage = "";
        root.showPage(wanted >= 0 ? wanted : root.page);
    }

    // A FocusScope, so a clicked control that goes away (a dock tile dragged
    // into a new place) hands focus back here and esc keeps working.
    FocusScope {
        id: keys

        anchors.fill: parent
        focus: true

        // Reached only by what the focused control did not want, so arrows
        // still walk the nav and a segmented rail still takes its own.
        Keys.onEscapePressed: event => {
            ShellState.close("settings");
            event.accepted = true;
        }

        Panel {
            id: win

            // What a page's dropdown lifts its list onto (Dropdown.qml), out
            // of the page's clipping.
            objectName: "settingsPanel"

            // An application window, not a shell surface: opaque, so the panel
            // opacity slider is seen moving the bar behind it rather than the
            // window it is being dragged in.
            level: "panel"
            padding: 0
            radius: Appearance.radius.popout
            colour: Colours.surface
            shadowY: Appearance.settings.shadowY
            shadowBlur: Appearance.settings.shadowBlur
            shadowAlpha: Appearance.settings.shadowAlpha

            // Capped by the output. 1020x706 is the design's window, but on a
            // display smaller than the design it overflowed and the first
            // invariant -- nothing touches an edge -- went with it.
            width: Math.min(Appearance.settings.windowWidth, parent.width - root.insetLeft - root.insetRight - Appearance.space.overlayMargin * 2)
            height: Math.min(Appearance.settings.windowHeight, parent.height - root.insetTop - root.insetBottom - Appearance.space.overlayMargin * 2)
            x: Math.round((parent.width - win.width + root.insetLeft - root.insetRight) / 2)
            // Placed with x/y rather than anchors: both depend on config, and
            // an anchor whose binding resolves to undefined is not reliably
            // cleared. The window rises into place (`Reveal`), and
            // `reduceMotion` drops the translation outright and leaves the
            // fade.
            y: Math.round((parent.height - win.height + root.insetTop - root.insetBottom) / 2) + entrance.offset
            opacity: entrance.opacity

            Reveal {
                id: entrance

                shown: root.shown
            }

            Rectangle {
                id: nav

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Appearance.settings.navWidth
                color: Colours.surfaceContainerLow
                radius: win.radius

                // The window rounds its corners and the nav fills its left
                // edge, so the nav is rounded on the left and squared on the
                // right by a cover rather than by clipping the whole window to
                // a mask.
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.radius
                    color: parent.color
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Colours.panelBorder
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: Appearance.settings.navPadV
                    anchors.bottomMargin: Appearance.settings.navPadV
                    anchors.leftMargin: Appearance.settings.navPadH
                    anchors.rightMargin: Appearance.settings.navPadH
                    spacing: Appearance.settings.navGap

                    RowLayout {
                        spacing: Appearance.space.sm

                        Layout.fillWidth: true
                        Layout.leftMargin: Appearance.settings.navTitlePadH
                        Layout.topMargin: Appearance.settings.navTitleTop
                        Layout.bottomMargin: Appearance.settings.navTitleBottom

                        Text {
                            text: qsTr("Shell settings")
                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.size.subheading
                            color: Colours.on.surface

                            Layout.fillWidth: true
                        }

                        // A click beside the window no longer closes it (see
                        // the header), so it says how it does.
                        Pill {
                            icon: "close"
                            tone: "plain"
                            pillHeight: Appearance.settings.closeSize
                            iconSize: Appearance.settings.closeIcon

                            Layout.preferredWidth: Appearance.settings.closeSize

                            onClicked: ShellState.close("settings")
                        }
                    }

                    Repeater {
                        id: navItems

                        model: root.pages.slice(0, root.aboutIndex)

                        NavItem {
                            required property int index
                            required property var modelData

                            icon: modelData.icon
                            title: modelData.label
                            selected: root.page === index

                            onClicked: root.showPage(index)
                            onMove: by => root.showPage(index + by)
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    NavItem {
                        id: aboutItem

                        icon: root.pages[root.aboutIndex].icon
                        title: root.pages[root.aboutIndex].label
                        selected: root.page === root.aboutIndex

                        onClicked: root.showPage(root.aboutIndex)
                        onMove: by => root.showPage(root.aboutIndex + by)
                    }
                }
            }

            Crossfade {
                id: pane

                anchors.left: nav.right
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: Appearance.settings.panePadV
                anchors.bottomMargin: Appearance.settings.panePadV
                anchors.leftMargin: Appearance.settings.panePadH
                anchors.rightMargin: Appearance.settings.panePadH
                clip: true

                component: {
                    switch (root.pageDef.key) {
                    case "general":
                        return general;
                    case "appearance":
                        return appearance;
                    case "bar":
                        return bar;
                    case "notifications":
                        return notifications;
                    case "calendars":
                        return calendars;
                    case "launcher":
                        return launcher;
                    case "lock":
                        return lock;
                    case "keybinds":
                        return keybinds;
                    case "modules":
                        return modules;
                    case "ai":
                        return ai;
                    default:
                        return about;
                    }
                }
            }
        }
    }

    Component {
        id: appearance

        AppearancePane {}
    }

    Component {
        id: bar

        BarPane {}
    }

    Component {
        id: keybinds

        KeybindsPane {}
    }

    Component {
        id: ai

        AiPane {}
    }

    Component {
        id: about

        AboutPane {}
    }

    Component {
        id: general

        GeneralPane {}
    }

    Component {
        id: notifications

        NotificationsPane {}
    }

    Component {
        id: calendars

        CalendarsPane {}
    }

    Component {
        id: launcher

        LauncherPane {}
    }

    Component {
        id: lock

        LockPane {}
    }

    Component {
        id: modules

        ModulesPane {}
    }
}
