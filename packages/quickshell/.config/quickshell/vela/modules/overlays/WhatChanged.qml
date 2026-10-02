import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.tokens
import qs.config
import qs.services
import qs.components

// What changed. The reboot banner first, then the two cards: the handful of
// packages that need the user to do something, and the rest as a monospace
// version diff.
//
// WHAT THE DESIGN ASSUMES AND THE SYSTEM DOES NOT HAVE, twice over:
//
// 1. A TRANSACTION RECORD. The design is headed "14 packages upgraded · 412 MB"
//    and is described as the screen shown *after* an update. Nothing here
//    records an upgrade: `Updates` asks dnf5 what is pending and dnf5's
//    check-update reports no download size. Reading the pending list and
//    labelling it "upgraded" would be a straight lie, so the header counts what
//    is waiting and dates it from the last check. Rendering the true
//    post-upgrade view needs `dnf5 history` behind a new field on `Updates`.
//
// 2. A SNAPSHOT. The design ends on the pre-upgrade snapshot, with a button to
//    roll back to it. vela takes none, so there is no footer: one that only
//    ever said there was no snapshot told nobody anything.
//
// The banner is real: `rebootRequired` compares the running kernel against the
// newest one on disk, which is genuinely post-upgrade evidence.
PanelWindow {
    id: root

    readonly property bool shown: ShellState.whatChanged

    readonly property string headline: {
        if (!Updates.available)
            return qsTr("No package tool answered");
        if (!Updates.everChecked)
            return qsTr("Not checked yet");
        if (Updates.failed)
            return qsTr("Couldn't check for updates");
        if (Updates.count === 0)
            return qsTr("Everything is up to date");
        return qsTr("%1 packages to upgrade").arg(Updates.count);
    }

    // What dnf could not do on the last check, and what to do about it: the
    // error that stopped it, a repository whose signing key this user has
    // not accepted yet, or ones that did not answer. A key is the one that
    // needs you -- dnf asks to import it in a terminal, once, and nothing
    // here can answer that -- so it comes before the ones that will likely
    // answer next time.
    readonly property var notice: {
        if (Updates.failed)
            return {
                title: qsTr("dnf could not check"),
                body: Updates.failed
            };
        if (Updates.keys.length > 0)
            return {
                title: qsTr("A repository's key needs accepting"),
                body: qsTr("Run dnf5 check-update in a terminal once and answer y. Left out until then: %1").arg(Updates.keys.join(", "))
            };
        if (Updates.unreachable.length > 0)
            return {
                title: qsTr("Not every repository answered"),
                body: qsTr("Left out this time: %1").arg(Updates.unreachable.join(", "))
            };
        return null;
    }

    // A time and a count are literals, so the whole strip is monospace.
    readonly property string meta: {
        if (!Updates.everChecked)
            return "";
        const when = qsTr("checked %1").arg(Qt.formatDateTime(Updates.lastChecked, "HH:mm"));
        const security = Updates.securityCount > 0 ? qsTr("%1 security").arg(Updates.securityCount) : "";
        const third = Updates.sourceNote;
        return [when, security, third].filter(s => s).join(" · ");
    }

    // The three actions `Updates.actionFor` can answer with, each with the
    // glyph and the tint the design gives it.
    function glyphFor(action: string): string {
        if (action === "Needs reboot")
            return "memory";
        if (action.startsWith("Restart the compositor"))
            return "desktop_windows";
        return "terminal";
    }

    function tintFor(action: string): color {
        if (action === "Needs reboot")
            return Colours.primary;
        if (action.startsWith("Restart the compositor"))
            return Colours.tertiary;
        return Colours.secondary;
    }

    // ONE KERNEL BUMP IS TEN PACKAGES. The design draws three tidy rows;
    // a real dnf5 kernel update answers with kernel, kernel-core, kernel-devel,
    // kernel-modules and six more, every one of them "Needs reboot" and every
    // one of them the same version pair. Ten identical rows is not "worth
    // knowing", it is a wall, so rows that share an action and a version pair
    // collapse to one -- named after the shortest of them, which is the
    // package somebody would recognise -- and the rest are counted.
    readonly property var notableGroups: {
        const groups = [];
        const seen = {};
        for (const u of Updates.notable) {
            const key = `${u.action}|${u.oldVersion}|${u.newVersion}`;
            if (seen[key] === undefined) {
                seen[key] = groups.length;
                groups.push({
                    "name": u.name,
                    "action": u.action,
                    "oldVersion": u.oldVersion,
                    "newVersion": u.newVersion,
                    "extra": 0
                });
                continue;
            }
            const g = groups[seen[key]];
            g.extra += 1;
            if (u.name.length < g.name.length)
                g.name = u.name;
        }
        return groups;
    }

    property bool routineExpanded: false

    // Expanded still has a ceiling: the panel sizes to its contents and a
    // hundred-package upgrade would run off the bottom of the screen.
    readonly property var routineShown: Updates.routine.slice(0, root.routineExpanded ? Appearance.overlays.changes.routineMax : Appearance.overlays.changes.routineShown)

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
    WlrLayershell.namespace: "vela-what-changed"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (!root.shown)
            return;
        // A dnf5 refresh is a ~41 second round trip; opening a panel is not a
        // reason to start one. Whatever the hourly check last found is what is
        // drawn, and the header dates it.
        root.routineExpanded = false;
        keys.forceActiveFocus();
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key !== Qt.Key_Escape)
                return;
            ShellState.close("whatChanged");
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
                    ShellState.close("whatChanged");
            }
        }

        Panel {
            id: panel

            level: "drawer"
            padding: Appearance.space.drawerPadding

            width: Math.min(Appearance.overlays.changes.width, parent.width - root.insetLeft - root.insetRight - Appearance.space.overlayMargin * 2)
            implicitHeight: column.implicitHeight + panel.padding * 2

            x: Math.round(root.insetLeft + (parent.width - root.insetLeft - root.insetRight - width) / 2)

            readonly property int restY: Math.round(root.insetTop + (parent.height - root.insetTop - root.insetBottom) * Appearance.overlays.topChanges)
            y: panel.restY + entrance.offset
            opacity: entrance.opacity

            Reveal {
                id: entrance

                shown: root.shown
            }

            ColumnLayout {
                id: column

                anchors.fill: parent
                spacing: Appearance.overlays.changes.blockGap

                // ---- header -------------------------------------------------
                RowLayout {
                    spacing: Appearance.overlays.changes.bannerGap

                    Layout.fillWidth: true

                    Icon {
                        text: "history"
                        size: Appearance.size.iconLg
                        color: Colours.primary

                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: root.headline
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.heading
                        color: Colours.on.surface
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: root.meta
                        font.family: Appearance.font.mono
                        font.pixelSize: Appearance.size.label
                        color: Colours.outline

                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Having read what is coming: run it, in a terminal, where
                    // dnf asks before it changes anything.
                    Pill {
                        visible: Updates.count > 0 && Updates.canUpgrade
                        text: qsTr("Update")
                        icon: "download"
                        tone: "accent"
                        pillHeight: Appearance.overlays.changes.buttonHeight
                        hPadding: Appearance.overlays.changes.buttonPadding
                        fontSize: Appearance.size.body

                        Layout.alignment: Qt.AlignVCenter

                        onClicked: {
                            Updates.upgrade();
                            ShellState.close("whatChanged");
                        }
                    }
                }

                // ---- the reboot banner ---------------------------------------
                Rectangle {
                    visible: Updates.rebootRequired
                    radius: Appearance.radius.cardLg
                    // Error-tinted, and error never warms: a machine asking to
                    // be restarted reads the same at every hour.
                    color: Colours.alpha(Colours.error, 0.09)
                    border.width: 1
                    border.color: Colours.alpha(Colours.error, 0.2)

                    Layout.fillWidth: true
                    Layout.preferredHeight: banner.implicitHeight + Appearance.overlays.changes.bannerPadV * 2

                    RowLayout {
                        id: banner

                        anchors.fill: parent
                        anchors.leftMargin: Appearance.overlays.changes.bannerPadH
                        anchors.rightMargin: Appearance.overlays.changes.bannerPadH
                        spacing: Appearance.overlays.changes.bannerGap

                        Icon {
                            text: "restart_alt"
                            size: Appearance.overlays.iconBanner
                            color: Colours.error

                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            spacing: 0

                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: qsTr("Reboot recommended")
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.size.body
                                color: Colours.error

                                Layout.fillWidth: true
                            }

                            Text {
                                text: qsTr("Running kernel %1 · installed %2").arg(Updates.runningKernel).arg(Updates.newestKernel)
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.size.label
                                color: Colours.on.surfaceVariant
                                elide: Text.ElideRight

                                Layout.fillWidth: true
                            }
                        }

                        // This opens the power menu rather than rebooting, as
                        // the design's button does. A module does not start
                        // processes, and a reboot is the power menu's job
                        // anyway -- that menu already owns it, with the
                        // confirmation a reboot deserves.
                        Pill {
                            text: qsTr("Reboot")
                            tone: "danger"
                            pillHeight: Appearance.overlays.changes.buttonHeight
                            hPadding: Appearance.overlays.changes.buttonPadding
                            fontSize: Appearance.size.body

                            Layout.alignment: Qt.AlignVCenter

                            onClicked: ShellState.open("power")
                        }

                        Pill {
                            text: qsTr("Later")
                            pillHeight: Appearance.overlays.changes.buttonHeight
                            hPadding: Appearance.overlays.changes.buttonPadding
                            fontSize: Appearance.size.body

                            Layout.alignment: Qt.AlignVCenter

                            onClicked: ShellState.close("whatChanged")
                        }
                    }
                }

                // ---- what the check could not do --------------------------------
                Rectangle {
                    visible: root.notice !== null
                    radius: Appearance.radius.cardLg
                    color: Colours.alpha(Colours.tertiary, 0.09)
                    border.width: 1
                    border.color: Colours.alpha(Colours.tertiary, 0.2)

                    Layout.fillWidth: true
                    Layout.preferredHeight: notice.implicitHeight + Appearance.overlays.changes.bannerPadV * 2

                    RowLayout {
                        id: notice

                        anchors.fill: parent
                        anchors.leftMargin: Appearance.overlays.changes.bannerPadH
                        anchors.rightMargin: Appearance.overlays.changes.bannerPadH
                        spacing: Appearance.overlays.changes.bannerGap

                        Icon {
                            text: "sync_problem"
                            size: Appearance.overlays.iconBanner
                            color: Colours.tertiary

                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            spacing: 0

                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: root.notice?.title ?? ""
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.size.body
                                color: Colours.tertiary

                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.notice?.body ?? ""
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.size.label
                                color: Colours.on.surfaceVariant
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight

                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                // ---- the two cards --------------------------------------------
                // None when dnf could not check: "nothing waiting" would be a
                // guess.
                RowLayout {
                    visible: !Updates.failed
                    spacing: Appearance.overlays.changes.cardGap

                    Layout.fillWidth: true

                    Card {
                        radius: Appearance.radius.cardLg
                        implicitHeight: notable.implicitHeight + padding * 2

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true

                        ColumnLayout {
                            id: notable

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: Appearance.overlays.changes.noteGap

                            SectionLabel {
                                text: qsTr("Worth knowing")

                                Layout.fillWidth: true
                            }

                            Repeater {
                                model: root.notableGroups

                                RowLayout {
                                    id: note

                                    required property var modelData
                                    required property int index

                                    spacing: Appearance.overlays.changes.noteGap
                                    opacity: noteArrival.opacity
                                    transform: Translate {
                                        y: noteArrival.offset
                                    }

                                    Layout.fillWidth: true

                                    Stagger {
                                        id: noteArrival

                                        index: note.index
                                        active: entrance.entering
                                    }

                                    // Tinted as designed, although three tinted
                                    // glyphs is a fourth use of colour beyond
                                    // the three the invariants reserve it for.
                                    Icon {
                                        text: root.glyphFor(modelData.action)
                                        size: Appearance.size.iconRow
                                        color: root.tintFor(modelData.action)

                                        Layout.alignment: Qt.AlignTop
                                    }

                                    ColumnLayout {
                                        spacing: 0

                                        Layout.fillWidth: true

                                        Text {
                                            text: `${modelData.name} ${modelData.oldVersion} → ${modelData.newVersion}`
                                            font.family: Appearance.font.mono
                                            font.pixelSize: Appearance.size.body
                                            color: Colours.on.surface
                                            elide: Text.ElideRight

                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: modelData.extra > 0 ? qsTr("%1 · and %2 more from the same bump").arg(modelData.action).arg(modelData.extra) : modelData.action
                                            font.family: Appearance.font.ui
                                            font.pixelSize: Appearance.size.caption
                                            color: Colours.outline
                                            elide: Text.ElideRight

                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: root.notableGroups.length === 0
                                text: Updates.count === 0 ? qsTr("Nothing waiting") : qsTr("Nothing here needs anything from you")
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.size.label
                                color: Colours.outline
                                wrapMode: Text.Wrap

                                Layout.fillWidth: true
                            }
                        }
                    }

                    Card {
                        radius: Appearance.radius.cardLg
                        implicitHeight: routine.implicitHeight + padding * 2

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true

                        ColumnLayout {
                            id: routine

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: Appearance.overlays.changes.rowGap

                            SectionLabel {
                                text: Updates.routine.length > Appearance.overlays.changes.routineShown ? qsTr("Routine · %1 more").arg(Updates.routine.length - Appearance.overlays.changes.routineShown) : qsTr("Routine")

                                Layout.fillWidth: true
                                Layout.bottomMargin: Appearance.overlays.changes.rowGap / 2
                            }

                            Repeater {
                                model: root.routineShown

                                RowLayout {
                                    id: routine

                                    required property var modelData
                                    required property int index

                                    spacing: Appearance.space.sm
                                    opacity: routineArrival.opacity
                                    transform: Translate {
                                        y: routineArrival.offset
                                    }

                                    Layout.fillWidth: true

                                    // After the notable notes, in order.
                                    Stagger {
                                        id: routineArrival

                                        index: root.notableGroups.length + routine.index
                                        active: entrance.entering
                                    }

                                    // A package name and a version diff are both
                                    // literals, so the whole list is monospace.
                                    Text {
                                        text: modelData.name
                                        font.family: Appearance.font.mono
                                        font.pixelSize: Appearance.size.label
                                        color: Colours.on.surfaceVariant
                                        elide: Text.ElideRight

                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: `${modelData.oldVersion} → ${modelData.newVersion}`
                                        font.family: Appearance.font.mono
                                        font.pixelSize: Appearance.size.label
                                        color: Colours.outline
                                    }
                                }
                            }

                            Text {
                                visible: Updates.routine.length === 0
                                text: qsTr("Nothing routine")
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.size.label
                                color: Colours.outline

                                Layout.fillWidth: true
                            }

                            Text {
                                visible: Updates.routine.length > Appearance.overlays.changes.routineShown
                                text: root.routineExpanded ? qsTr("Show fewer") : qsTr("Show all %1").arg(Math.min(Updates.routine.length, Appearance.overlays.changes.routineMax))
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.size.label
                                color: Colours.primary

                                Layout.fillWidth: true
                                Layout.topMargin: Appearance.space.xs / 2

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.routineExpanded = !root.routineExpanded
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
