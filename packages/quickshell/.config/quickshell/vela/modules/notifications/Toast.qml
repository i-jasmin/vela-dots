pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.tokens
import qs.services
import qs.components

// One card in the popup stack -- and one card is one *application*, not one
// notification. Four messages from the same chat are one card that says four,
// rather than four cards that shove everything else off the screen. The
// delegate is keyed by the application's name, so a card already on screen
// keeps its delegate -- and its half-finished animation -- when the next
// message from that app lands.
//
// The design draws the urgent case: an error-tinted border, an error-tinted
// glyph tile, the word "Urgent" before the app's name, and the notification's
// own actions laid out under the text. An ordinary toast is the same card with
// the neutral panel border, and it is the only difference -- colour here means
// urgency and nothing else.
//
// THE CARD OWNS ITS OWN DISMISSAL. The countdown, the hover freeze, the swipe
// and the exit all live here, and `Notifs` is only told the popup has gone once
// the exit has finished; releasing earlier would free the entry underneath a
// card that is still being drawn.
//
// A swipe (components/SwipeArea.qml: dragged, or swept with two fingers on
// the touchpad) puts the card away and leaves the notifications in the
// centre; middle-click and Dismiss drop them. One that says more than three
// lines, or carries a picture worth seeing, has a chevron that opens the card
// out to all of it.
Item {
    id: root

    // The delegate key: the application name this card speaks for.
    required property string app

    // The design sets the cards eleven pixels apart. It is carried inside the
    // card's own height rather than as layout spacing, so a card that collapses
    // to nothing takes its gap with it instead of leaving a hole in the stack.
    property int gap: 11
    // 36px, radius 12, as designed. A step larger than the 34px tile the digest
    // header carries, because a toast is the louder of the two.
    readonly property int actionGap: Appearance.notifications.actionGap
    readonly property real borderTint: Appearance.notifications.urgentBorderTint
    readonly property real tileTint: Appearance.notifications.urgentTileTint

    // Everything this app currently has in the popup stack, newest first.
    // `entries` still includes the ones already animating away -- that is what
    // keeps the card drawable through its own exit -- while `live` is what the
    // card actually counts and reads.
    readonly property var entries: Notifs.popupGroups[root.app] ?? []
    readonly property var live: root.entries.filter(e => !e.closing)
    // Typed rather than `var`: QML compares object properties by identity and
    // only signals a real change, so another application's notification
    // arriving does not retick this card's countdown.
    readonly property QtObject head: root.live[0] ?? root.entries[0] ?? null
    readonly property int count: root.live.length
    readonly property var actions: root.head?.buttons ?? []

    // One critical notification makes the whole card critical. Burying a disk
    // failure inside a calm grey card because four chat messages arrived after
    // it would defeat the point of having urgency at all.
    readonly property bool urgent: root.live.some(e => e.critical)

    // Flipped after construction so the entrance has something to run from; a
    // Behavior does nothing about the value a property is born with.
    property bool appeared: false
    readonly property bool shown: root.appeared && root.count > 0

    // Opened out to all it says. Closed again when the app says something
    // new.
    property bool expanded: false
    readonly property bool pictured: (root.head?.image ?? "") !== "" && picture.status === Image.Ready
    // Wider than tall: a screenshot or a photo, drawn across the card when
    // opened out. Anything squarer is a face or an icon, and stays a
    // thumbnail.
    readonly property bool wide: root.pictured && picture.implicitWidth > picture.implicitHeight * 1.3
    readonly property bool expandable: root.expanded || summaryText.truncated || bodyText.truncated || root.wide

    // Nothing may count down while the user is reading or holding the card
    // -- this copy of it, or its twin on another monitor (`Notifs.pause`).
    readonly property bool frozen: hover.hovered || swipe.swiping
    readonly property bool held: (Notifs.paused[root.app] ?? 0) > 0

    onFrozenChanged: Notifs.pause(root.app, root.frozen)
    Component.onDestruction: if (root.frozen)
        Notifs.pause(root.app, false)
    onHeldChanged: root.retime()

    // The app replaced what this card says: the time to read it starts again.
    Connections {
        target: Notifs

        function onRefreshed(entry: var): void {
            if (root.live.includes(entry))
                root.retime();
        }
    }

    // 0 gone, 1 arrived. One property drives the height, the rise and the fade
    // together, which is what keeps them in step without three Behaviors that
    // could drift apart.
    property real reveal: root.shown ? 1 : 0

    // The card's height, eased: a toast whose app says something longer or
    // shorter grows or shrinks to it rather than jumping, and the stack below
    // moves with it. Not while it is arriving -- `reveal` has that.
    property real cardHeight: card.implicitHeight

    Behavior on cardHeight {
        enabled: root.reveal === 1

        Morph {}
    }

    Layout.fillWidth: true
    Layout.preferredHeight: Math.round((root.cardHeight + root.gap) * root.reveal)

    Component.onCompleted: root.appeared = true

    onShownChanged: root.retime()
    onHeadChanged: {
        root.expanded = false;
        root.retime();
    }

    // A closed entry is not freed until nothing is drawing it. While the card
    // is up that means the ones the cap or a single dismissal retired; once the
    // card has faded out it means all of them, and letting the last one go is
    // what destroys this delegate.
    onEntriesChanged: if (root.shown)
        Qt.callLater(root.reap)
    onRevealChanged: if (root.reveal === 0 && !root.shown)
        Qt.callLater(root.reap)

    // Restarts the countdown from full: the card has just changed under the
    // user's eyes, so the time they get to read it starts again. QML's Timer
    // has no pause, so a hover stops it outright and unhovering gives the full
    // interval back -- which is the generous way round.
    function retime(): void {
        countdown.stop();
        if (root.shown && !root.urgent && !root.persistent && !root.held)
            countdown.start();
    }

    // What the sending application asked for, in milliseconds: 0 is "leave it
    // up until it is dealt with" (a download in progress, a call), -1 is "the
    // server decides", which is `notifications.timeout`.
    readonly property int requested: root.head?.expireTimeout ?? -1
    readonly property bool persistent: root.requested === 0

    function reap(): void {
        for (const entry of root.entries)
            if (entry.closing)
                Notifs.popupClosed(entry);
    }

    // The freedesktop "default" action is the whole card, not a button.
    function activate(): void {
        const entry = root.head;
        if (entry?.defaultAction) {
            entry.defaultAction.invoke();
            // A resident notification asked to survive its own action.
            if (!entry.resident)
                Notifs.dismiss(entry);
        }
        Notifs.closePopupGroup(root.app);
    }

    function invoke(action: var): void {
        const entry = root.head;
        action.invoke();
        if (entry && !entry.resident)
            Notifs.dismiss(entry);
        Notifs.closePopupGroup(root.app);
    }

    // Arrives on the expressive curve, the stack opening round it; leaves
    // quickly, the stack closing up behind it. Under reduceMotion the morph
    // is gone and what is left is a short fade.
    //
    // Which way it is going is read from the value it is heading for, not
    // from `shown`: `reveal` and these bindings all follow `shown`, and in no
    // fixed order, so a toast going away would often leave on the arrival's
    // curve and duration. The Behavior sets `targetValue` before it starts.
    Behavior on reveal {
        id: revealing

        NumberAnimation {
            duration: revealing.targetValue > 0 ? Math.max(Appearance.anim.morph, Appearance.anim.fast) : Appearance.anim.depart
            easing.type: Easing.BezierSpline
            easing.bezierCurve: revealing.targetValue > 0 ? Appearance.anim.emphasized : Appearance.anim.leave
        }
    }

    HoverHandler {
        id: hover
    }

    Timer {
        id: countdown

        // A critical notification never expires on its own -- it is dismissed
        // by the user or by the application that sent it.
        interval: Math.max(1000, root.requested > 0 ? root.requested : Notifs.timeout)
        onTriggered: Notifs.closePopupGroup(root.app)
    }

    // Declared before the card so every pill on it gets first refusal on a
    // click. Thrown, the card is put away and its notifications stay in the
    // centre; under reduced motion it is put away where it stands, and the
    // fade carries it.
    SwipeArea {
        id: swipe

        anchors.fill: parent
        // How far a card has to be thrown before letting go puts it away
        // rather than snapping it back.
        threshold: width * Notifs.swipeThreshold
        onThrown: Notifs.closePopupGroup(root.app)
        onTapped: mouse => {
            if (mouse.button === Qt.MiddleButton)
                Notifs.dismissGroup(root.app);
            else
                root.activate();
        }
    }

    Panel {
        id: card

        level: "popout"
        padding: Appearance.popout.padding
        // The one thing that separates an urgent card from an ordinary one.
        borderColour: root.urgent ? Colours.alpha(Colours.error, root.borderTint) : Colours.panelBorder

        width: root.width
        implicitHeight: body.implicitHeight + card.padding * 2
        height: root.cardHeight
        clip: root.cardHeight !== card.implicitHeight

        // The rise in the design's motion: the card starts below where it
        // belongs and comes up to it. `anim.riseBy` is already zero when
        // motion is reduced, which leaves the fade alone.
        x: swipe.offset
        y: Math.round((1 - root.reveal) * Appearance.anim.riseBy)
        // Two fades multiplied rather than two Behaviors fighting: the arrival
        // and the throw are different gestures that both dim the same card.
        opacity: root.reveal * swipe.fade

        RowLayout {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Appearance.space.md

            Rectangle {
                implicitWidth: Appearance.notifications.toastTile
                implicitHeight: Appearance.notifications.toastTile
                radius: Appearance.bar.tileRadius(Appearance.notifications.toastTile)
                // No square behind an app's own icon, which has a shape of its own.
                color: toastIcon.showsImage ? "transparent" : root.urgent ? Colours.alpha(Colours.error, root.tileTint) : Colours.hover

                Layout.alignment: Qt.AlignTop

                AppIcon {
                    id: toastIcon

                    anchors.centerIn: parent
                    // Urgency has its own glyph; everything else is drawn as
                    // whatever the application is -- its own icon, when an icon
                    // theme is chosen.
                    source: root.urgent ? "" : AppIcons.forClass(root.app)
                    glyph: root.urgent ? "priority_high" : Hypr.symbolFor(root.app)
                    size: Appearance.size.iconMd
                    imageSize: Appearance.notifications.toastTile
                    color: root.urgent ? Colours.error : Colours.on.surfaceVariant
                }
            }

            ColumnLayout {
                spacing: Appearance.space.xs

                Layout.fillWidth: true

                RowLayout {
                    spacing: Appearance.space.sm

                    Layout.fillWidth: true

                    AppLine {
                        label: root.urgent ? qsTr("Urgent · %1").arg(root.app) : root.app
                        labelColour: root.urgent ? Colours.error : Colours.on.surface
                        note: root.count > 1 ? qsTr("%1 messages").arg(root.count) : ""
                        stamp: root.head ? Notifs.ago(root.head.time) : ""

                        Layout.fillWidth: true
                    }

                    // Open it out, or back.
                    Icon {
                        visible: root.expandable
                        text: "expand_more"
                        size: Appearance.notifications.chevron
                        color: chevronMouse.containsMouse ? Colours.on.surface : Colours.outline
                        rotation: root.expanded ? 180 : 0

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
                            onClicked: root.expanded = !root.expanded
                        }
                    }
                }

                Text {
                    id: summaryText

                    text: root.head?.summary ?? ""
                    visible: text !== ""
                    font.family: Appearance.font.ui
                    font.pixelSize: Appearance.size.label
                    color: Colours.on.surfaceVariant
                    wrapMode: Text.Wrap
                    // Read off a probe, as the body's is: its own `lineCount`
                    // moves with the leading, and the two chased each other.
                    lineHeight: summaryProbe.lineCount > 1 ? Appearance.notifications.bodyLineHeight : 1
                    maximumLineCount: root.expanded ? Appearance.notifications.expandedLines : 2
                    elide: Text.ElideRight

                    Layout.fillWidth: true

                    Text {
                        id: summaryProbe

                        visible: false
                        width: summaryText.width
                        text: summaryText.text
                        font: summaryText.font
                        wrapMode: summaryText.wrapMode
                    }
                }

                RowLayout {
                    visible: bodyText.text !== "" || thumb.visible
                    spacing: Appearance.space.sm

                    Layout.fillWidth: true

                    Text {
                        id: bodyText

                        // The server advertises body markup, so an application may
                        // send the freedesktop subset of HTML here.
                        text: root.head?.body ?? ""
                        visible: text !== ""
                        textFormat: Text.StyledText
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.label
                        color: Colours.outline
                        wrapMode: Text.Wrap
                        // Looser leading once the body wraps. Whether it wraps is
                        // read off the probe below, not off this text's own
                        // `lineCount`: that moved with the leading it chose, and
                        // the two chased each other (a binding loop, every time a
                        // longer message replaced a short one).
                        lineHeight: bodyProbe.lineCount > 1 ? Appearance.notifications.bodyLineHeight : 1
                        maximumLineCount: root.expanded ? Appearance.notifications.expandedLines : 3
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop

                        // The same text at the same width, never drawn and never
                        // led, so its line count answers only to the wrapping.
                        Text {
                            id: bodyProbe

                            visible: false
                            width: bodyText.width
                            text: bodyText.text
                            textFormat: bodyText.textFormat
                            font: bodyText.font
                            wrapMode: bodyText.wrapMode
                        }
                    }

                    ClippingRectangle {
                        id: thumb

                        visible: root.pictured && !(root.expanded && root.wide)
                        implicitWidth: Appearance.notifications.thumb
                        implicitHeight: Appearance.notifications.thumb
                        radius: Appearance.notifications.thumbRadius
                        color: Colours.hover

                        Layout.alignment: Qt.AlignTop

                        Image {
                            anchors.fill: parent
                            source: thumb.visible ? root.head.image : ""
                            sourceSize.width: Appearance.notifications.thumb * 2
                            sourceSize.height: Appearance.notifications.thumb * 2
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                }

                // The picture, large, once opened out. Always loaded, because
                // its shape decides whether it is a picture or a face.
                ClippingRectangle {
                    visible: root.expanded && root.wide
                    implicitHeight: Math.min(Appearance.notifications.pictureMax, root.wide ? width * picture.implicitHeight / picture.implicitWidth : 0)
                    radius: Appearance.notifications.thumbRadius
                    color: Colours.hover

                    Layout.fillWidth: true

                    Image {
                        id: picture

                        anchors.fill: parent
                        source: root.head?.image ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                RowLayout {
                    // An urgent card never expires on its own, so it always
                    // carries a way out. An ordinary one shows the row only
                    // when the notification actually offered something.
                    visible: root.urgent || root.actions.length > 0
                    spacing: Appearance.space.sm

                    Layout.fillWidth: true
                    Layout.topMargin: root.actionGap

                    Repeater {
                        model: root.actions

                        Pill {
                            required property var modelData

                            text: modelData.text
                            tone: root.urgent ? "danger" : "subtle"
                            fontSize: Appearance.size.label
                            onClicked: root.invoke(modelData)
                        }
                    }

                    Pill {
                        text: qsTr("Dismiss")
                        fontSize: Appearance.size.label
                        onClicked: Notifs.dismissGroup(root.app)
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
