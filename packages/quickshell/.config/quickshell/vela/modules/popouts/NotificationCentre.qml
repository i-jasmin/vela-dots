pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.tokens
import qs.services
import qs.components
import qs.modules.bar

// The notification centre, off the bell at the end of the tray.
//
// `Notifs` has always kept the last fifty notifications, and until this there
// was nowhere to read them: a toast missed was a toast gone. This is that
// history, one group per application in the order they last spoke, each
// showing its newest few until it is opened out. A row does what the toast
// would have done -- its default action, and then it is dismissed unless the
// app asked for it to stay -- and × drops it without acting.
//
// Like a phone's: one that says more than fits has a chevron that opens it
// out to all of it, with its picture drawn large; and each can be swiped
// away -- dragged sideways, or swept with two fingers on the touchpad --
// with the list closing up behind it.
//
// Opening the centre is what "read" means: whatever arrived since it was last
// open is marked new here, and from then on the bell loses its dot and the
// lock screen stops counting it.
//
// The header carries the two switches that decide what reaches you at all: do
// not disturb, and -- while a focus session is holding notifications back --
// the digest, with a way to see it now.
PopoutContent {
    id: root

    // What was new when the centre opened: marked, and then seen.
    property date newSince: new Date(0)
    // Applications opened out past their newest few, by name.
    property var opened: ({})
    // Notifications opened out to all they say.
    property var expanded: []
    // Notifications folding away, dismissed once they have.
    property var leaving: []
    // Clear all, once everything has folded away.
    property bool clearing: false

    popoutWidth: Appearance.popout.centreWidth
    // The heading is drawn below, with Clear all beside it.
    heading: ""

    Component.onCompleted: {
        root.newSince = Notifs.seenAt;
        Notifs.markSeen();
        // Every card on screen is in the list below; showing both is showing
        // the same thing twice.
        for (const app of Notifs.popupApps)
            Notifs.closePopupGroup(app);
    }

    function activate(entry: var): void {
        if (entry.defaultAction)
            entry.defaultAction.invoke();
        if (!entry.resident)
            Notifs.dismiss(entry);
        BarPopouts.close();
    }

    function invoke(entry: var, action: var): void {
        action.invoke();
        if (!entry.resident)
            root.leave([entry]);
    }

    function toggle(entry: var): void {
        root.expanded = root.expanded.includes(entry) ? root.expanded.filter(e => e !== entry) : root.expanded.concat([entry]);
    }

    // Folds them away, then dismisses them: a list that closes up behind what
    // went, rather than jumping. Kept here rather than on the rows, so a row
    // rebuilt halfway (another notification arriving) still goes.
    function leave(entries: var): void {
        const fresh = entries.filter(e => !root.leaving.includes(e));
        if (fresh.length === 0)
            return;
        root.leaving = root.leaving.concat(fresh);
        folded.restart();
    }

    Timer {
        id: folded

        interval: Appearance.anim.depart
        onTriggered: {
            const gone = root.leaving;
            for (const e of gone)
                Notifs.dismiss(e);
            // Clear all also lets go of what focus is holding back.
            if (root.clearing)
                Notifs.clear();
            root.clearing = false;
            root.leaving = root.leaving.filter(e => !gone.includes(e));
            root.expanded = root.expanded.filter(e => !gone.includes(e));
        }
    }

    // ---- header --------------------------------------------------------------
    RowLayout {
        spacing: Appearance.popout.headerGap

        Layout.fillWidth: true

        Icon {
            text: Notifs.doNotDisturb ? "notifications_off" : "notifications"
            size: Appearance.size.iconMd
            color: Colours.primary
        }

        Text {
            text: qsTr("Notifications")
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.body
            color: Colours.on.surface
        }

        Text {
            visible: Notifs.list.length > 0
            text: `${Notifs.list.length}`
            font.family: Appearance.font.mono
            font.pixelSize: Appearance.size.caption
            color: Colours.outline
        }

        Item {
            Layout.fillWidth: true
        }

        Pill {
            visible: Notifs.list.length > 0
            text: qsTr("Clear all")
            tone: "plain"
            pillHeight: Appearance.widget.pillHeight
            onClicked: {
                root.clearing = true;
                root.leave(Notifs.list);
            }
        }
    }

    // ---- what reaches you ------------------------------------------------------
    Row {
        icon: Notifs.doNotDisturb ? "do_not_disturb_on" : "do_not_disturb_off"
        title: qsTr("Do not disturb")
        subtitle: Notifs.doNotDisturb ? (Config.notifications.urgentBypassesFocus ? qsTr("Only urgent ones pop up; everything lands here") : qsTr("Nothing pops up; everything still lands here")) : qsTr("Cards pop up as they arrive")
        trailing: Component {
            Toggle {
                readonly property bool wanted: Notifs.doNotDisturb

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => Notifs.doNotDisturb = on
            }
        }
        onClicked: Notifs.doNotDisturb = !Notifs.doNotDisturb

        Layout.fillWidth: true
    }

    Row {
        visible: Notifs.holding
        icon: "timer"
        title: Notifs.heldCount === 1 ? qsTr("Focus is holding 1") : qsTr("Focus is holding %1").arg(Notifs.heldCount)
        subtitle: qsTr("Next digest %1, or when the session ends").arg(Notifs.nextDigestLabel)
        interactive: Notifs.heldCount > 0
        trailing: Component {
            Pill {
                text: qsTr("Show now")
                tone: "subtle"
                interactive: Notifs.heldCount > 0
                onClicked: {
                    Notifs.releaseDigest();
                    BarPopouts.close();
                }
            }
        }

        Layout.fillWidth: true
    }

    Divider {}

    // ---- the history -----------------------------------------------------------
    Empty {
        visible: Notifs.list.length === 0
        text: qsTr("Nothing yet")
    }

    Flickable {
        id: history

        visible: Notifs.list.length > 0
        contentWidth: width
        contentHeight: groups.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(groups.implicitHeight, Appearance.popout.centreListMax)

        ColumnLayout {
            id: groups

            width: history.width
            spacing: 0

            // Keyed by application name, and each group's rows by the
            // notification itself: ScriptModel keeps the delegates that are
            // still there when the list changes, so a row being swiped, or
            // opened out, is not rebuilt under the pointer when something
            // else arrives.
            Repeater {
                model: ScriptModel {
                    values: Notifs.apps
                }

                Item {
                    id: group

                    required property string modelData
                    required property int index

                    readonly property var entries: Notifs.groups[group.modelData] ?? []
                    readonly property bool open: root.opened[group.modelData] === true
                    readonly property var shown: group.open ? group.entries : group.entries.slice(0, Appearance.popout.centreShown)
                    readonly property bool urgent: group.entries.some(e => e.critical)
                    // All of it on its way out: the heading folds away too.
                    readonly property bool going: group.entries.length > 0 && group.entries.every(e => root.leaving.includes(e))
                    // The gap above it is carried inside its height, so it
                    // folds away with it.
                    readonly property int gap: group.index > 0 ? Appearance.popout.centreGroupGap : 0
                    property real fold: group.going ? 0 : 1

                    implicitHeight: Math.round((group.gap + inner.implicitHeight) * group.fold)
                    clip: group.fold < 1
                    opacity: arrival.opacity * group.fold

                    Layout.fillWidth: true
                    Layout.preferredHeight: group.implicitHeight

                    Behavior on fold {
                        NumberAnimation {
                            duration: Appearance.anim.depart
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.anim.leave
                        }
                    }

                    // The groups arrive one after another as the centre opens.
                    Stagger {
                        id: arrival

                        index: group.index
                    }

                    ColumnLayout {
                        id: inner

                        y: group.gap
                        width: group.width
                        spacing: 0
                        transform: Translate {
                            y: arrival.offset
                        }

                        // The app: its glyph, its name, how many, and × for
                        // all of it.
                        RowLayout {
                            spacing: Appearance.space.sm

                            Layout.fillWidth: true

                            Rectangle {
                                implicitWidth: Appearance.popout.centreTile
                                implicitHeight: Appearance.popout.centreTile
                                radius: Appearance.bar.tileRadius(Appearance.popout.centreTile)
                                color: groupIcon.showsImage ? "transparent" : group.urgent ? Colours.alpha(Colours.error, Appearance.notifications.urgentTileTint) : Colours.hover

                                AppIcon {
                                    id: groupIcon

                                    anchors.centerIn: parent
                                    source: group.urgent ? "" : AppIcons.forClass(group.modelData)
                                    glyph: group.urgent ? "priority_high" : Apps.symbolForClass(group.modelData)
                                    size: Appearance.size.iconSm
                                    imageSize: Appearance.popout.centreTile
                                    color: group.urgent ? Colours.error : Colours.on.surfaceVariant
                                }
                            }

                            Text {
                                text: group.modelData
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.size.label
                                color: group.urgent ? Colours.error : Colours.on.surface
                                elide: Text.ElideRight

                                Layout.fillWidth: true
                            }

                            Text {
                                visible: group.entries.length > 1
                                text: `${group.entries.length}`
                                font.family: Appearance.font.mono
                                font.pixelSize: Appearance.size.caption
                                color: Colours.outline
                            }

                            Pill {
                                icon: "close"
                                tone: "plain"
                                pillHeight: Appearance.popout.centreTile
                                onClicked: root.leave(group.entries)
                            }
                        }

                        Repeater {
                            model: ScriptModel {
                                values: group.shown
                            }

                            Entry {}
                        }

                        // The rest of this app's history, on request.
                        Pill {
                            visible: group.entries.length > Appearance.popout.centreShown
                            text: group.open ? qsTr("Show fewer") : qsTr("%1 more").arg(group.entries.length - Appearance.popout.centreShown)
                            icon: group.open ? "expand_less" : "expand_more"
                            tone: "plain"
                            pillHeight: Appearance.settings.segmentHeight
                            fontSize: Appearance.size.caption
                            onClicked: {
                                const next = Object.assign({}, root.opened);
                                next[group.modelData] = !group.open;
                                root.opened = next;
                            }

                            Layout.topMargin: Appearance.popout.centreEntryGap
                        }
                    }
                }
            }
        }
    }

    // ---- one notification ------------------------------------------------------
    //
    // Collapsed, its summary on a line and its body on two, with any picture
    // as a thumbnail beside them; opened out, all of it, and a picture wider
    // than it is tall (a screenshot, a photo -- the point of the
    // notification) drawn across the card. A squarer one is a face or an
    // icon, and stays a thumbnail.
    //
    // Clicking it does what the app asked (its default action). One that
    // asked for nothing opens out instead, if there is more to it; the
    // chevron always does. Middle-click, ×, or a swipe put it away.
    component Entry: Item {
        id: entry

        required property var modelData

        readonly property bool fresh: entry.modelData.time > root.newSince
        readonly property bool expanded: root.expanded.includes(entry.modelData)
        readonly property bool going: root.leaving.includes(entry.modelData)
        readonly property bool pictured: entry.modelData.image !== "" && picture.status === Image.Ready
        readonly property bool wide: entry.pictured && picture.implicitWidth > picture.implicitHeight * 1.3
        readonly property bool expandable: entry.expanded || summaryText.truncated || bodyText.truncated || entry.wide

        // The card's height, eased as it opens out and closes; and a fold
        // that takes it, and the gap above it, down to nothing as it goes.
        property real cardHeight: card.implicitHeight
        property real fold: entry.going ? 0 : 1

        implicitHeight: Math.round((Appearance.popout.centreEntryGap + entry.cardHeight) * entry.fold)
        clip: true

        Layout.fillWidth: true
        Layout.preferredHeight: entry.implicitHeight

        Behavior on cardHeight {
            enabled: !entry.going

            Morph {}
        }

        Behavior on fold {
            NumberAnimation {
                duration: Appearance.anim.depart
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.leave
            }
        }

        SwipeArea {
            id: swipe

            anchors.fill: parent
            anchors.topMargin: Appearance.popout.centreEntryGap
            threshold: width * Notifs.swipeThreshold
            swipeEnabled: !entry.going
            onThrown: root.leave([entry.modelData])
            onTapped: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    root.leave([entry.modelData]);
                else if (entry.modelData.defaultAction || !entry.expandable)
                    root.activate(entry.modelData);
                else
                    root.toggle(entry.modelData);
            }
        }

        Rectangle {
            id: card

            x: swipe.offset
            y: Appearance.popout.centreEntryGap
            width: entry.width
            implicitHeight: entryBody.implicitHeight + Appearance.notifications.rowPadV * 2
            height: entry.cardHeight
            clip: entry.cardHeight !== card.implicitHeight
            radius: Appearance.radius.card
            color: swipe.containsMouse || swipe.swiping ? Colours.track : Colours.hover
            opacity: swipe.fade * entry.fold

            Behavior on color {
                enabled: !Colours.crossing

                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }

            ColumnLayout {
                id: entryBody

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: Appearance.notifications.rowPadH
                anchors.rightMargin: Appearance.space.xs
                anchors.topMargin: Appearance.notifications.rowPadV
                spacing: Appearance.space.xs

                RowLayout {
                    spacing: Appearance.space.sm

                    Layout.fillWidth: true

                    // Arrived since the centre was last open.
                    Rectangle {
                        visible: entry.fresh
                        implicitWidth: Appearance.bar.dot
                        implicitHeight: Appearance.bar.dot
                        radius: width / 2
                        color: Colours.primary

                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        id: summaryText

                        text: entry.modelData.summary || entry.modelData.appName || qsTr("Notification")
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.label
                        color: Colours.on.surface
                        wrapMode: Text.Wrap
                        maximumLineCount: entry.expanded ? Appearance.notifications.expandedLines : 1
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                    }

                    Text {
                        text: Notifs.ago(entry.modelData.time)
                        font.family: Appearance.font.mono
                        font.pixelSize: Appearance.size.caption
                        color: Colours.outline
                    }

                    // Open it out, or back.
                    Icon {
                        id: chevron

                        visible: entry.expandable
                        text: "expand_more"
                        size: Appearance.notifications.chevron
                        color: chevronMouse.containsMouse ? Colours.on.surface : Colours.outline
                        rotation: entry.expanded ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation {
                                duration: Appearance.anim.normal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.anim.emphasized
                            }
                        }

                        MouseArea {
                            id: chevronMouse

                            anchors.fill: parent
                            anchors.margins: -Appearance.space.xs
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggle(entry.modelData)
                        }
                    }

                    Pill {
                        icon: "close"
                        tone: "plain"
                        pillHeight: Appearance.settings.chipButton
                        onClicked: root.leave([entry.modelData])
                    }
                }

                RowLayout {
                    visible: bodyText.text !== "" || thumb.visible
                    spacing: Appearance.space.sm

                    Layout.fillWidth: true
                    Layout.rightMargin: Appearance.space.sm

                    Text {
                        id: bodyText

                        text: entry.modelData.body
                        textFormat: Text.StyledText
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.caption
                        color: Colours.outline
                        wrapMode: Text.Wrap
                        // Opened out, all of it: the list scrolls.
                        maximumLineCount: entry.expanded ? 1000 : Appearance.popout.centreBodyLines
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                    }

                    ClippingRectangle {
                        id: thumb

                        visible: entry.pictured && !(entry.expanded && entry.wide)
                        implicitWidth: Appearance.notifications.thumb
                        implicitHeight: Appearance.notifications.thumb
                        radius: Appearance.notifications.thumbRadius
                        color: Colours.hover

                        Layout.alignment: Qt.AlignTop

                        Image {
                            anchors.fill: parent
                            source: thumb.visible ? entry.modelData.image : ""
                            sourceSize.width: Appearance.notifications.thumb * 2
                            sourceSize.height: Appearance.notifications.thumb * 2
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                }

                // The picture, large, once opened out. Always loaded (hidden
                // until then), because its shape is what decides whether it is
                // a picture or a face.
                ClippingRectangle {
                    visible: entry.expanded && entry.wide
                    implicitHeight: Math.min(Appearance.notifications.pictureMax, entry.wide ? width * picture.implicitHeight / picture.implicitWidth : 0)
                    radius: Appearance.notifications.thumbRadius
                    color: Colours.hover

                    Layout.fillWidth: true
                    Layout.rightMargin: Appearance.space.sm

                    Image {
                        id: picture

                        anchors.fill: parent
                        source: entry.modelData.image
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                // The app's own buttons, as the toast offered them.
                Flow {
                    visible: entry.modelData.buttons.length > 0
                    spacing: Appearance.space.xs

                    Layout.fillWidth: true

                    Repeater {
                        model: entry.modelData.buttons

                        Pill {
                            required property var modelData

                            text: modelData.text
                            tone: "subtle"
                            pillHeight: Appearance.settings.segmentHeight
                            fontSize: Appearance.size.caption
                            onClicked: root.invoke(entry.modelData, modelData)
                        }
                    }
                }
            }
        }
    }
}
