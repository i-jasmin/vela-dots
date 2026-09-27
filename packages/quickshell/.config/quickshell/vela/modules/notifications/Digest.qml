pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.services
import qs.components

// The notification digest, and the rule it exists to state: while focus is
// held, everything that is not urgent stops popping one card at a time and
// collects into *one* card -- "7 while you were focused", the window it covers,
// and a row per application with a count. Two buttons under it, and a footer
// line promising when the next one lands.
//
// The card holds no state of its own. `Notifs` decides what is held, when the
// batch is ready and what happens to it; this draws that and calls back.
Item {
    id: root

    // `digestDue` is the service saying the batch is ready -- the interval
    // elapsed, or focus ended. An empty batch has nothing to say.
    readonly property bool showing: Notifs.digestDue && Notifs.heldCount > 0

    property bool expanded: true

    // The design's gaps, which are the module's own rather than the token set's:
    // 11 between the card and the footer line, 14 between the card's three
    // blocks, 9 between the rows, 11/13 of padding inside a row, and a 34px
    // header tile at radius 11.
    property int gap: 11
    readonly property int footerInset: Appearance.space.xs

    property real reveal: root.showing ? 1 : 0

    Layout.fillWidth: true
    Layout.preferredHeight: Math.round((column.implicitHeight + root.gap) * root.reveal)

    // The detail line under an application's name. The design draws it as the
    // newest thing that app said plus a count of the rest -- "Mara, and 2
    // others" -- so it is built from the *distinct* summaries rather than from
    // the number of notifications: four messages from three people is three
    // names, and saying "and 3 others" of them would be a lie.
    function detailOf(entries: var): string {
        const seen = [];
        for (const entry of entries) {
            const line = (entry.summary || entry.body || "").trim();
            if (line && !seen.includes(line))
                seen.push(line);
        }
        if (seen.length === 0)
            return "";
        if (seen.length === 1)
            return seen[0];
        if (seen.length === 2)
            return qsTr("%1, and 1 other").arg(seen[0]);
        return qsTr("%1, and %2 others").arg(seen[0]).arg(seen.length - 1);
    }

    // The same arrival and exit as a toast's, and read the same way: from
    // where `reveal` is heading, which the Behavior knows before it starts,
    // rather than from `showing`, which may not have reached these bindings
    // yet.
    Behavior on reveal {
        id: revealing

        NumberAnimation {
            duration: revealing.targetValue > 0 ? Math.max(Appearance.anim.morph, Appearance.anim.fast) : Appearance.anim.depart
            easing.type: Easing.BezierSpline
            easing.bezierCurve: revealing.targetValue > 0 ? Appearance.anim.emphasized : Appearance.anim.leave
        }
    }

    // 0 folded, 1 open: the list's share of its own height, eased, so the
    // chevron folds the card rather than cutting it.
    property real openness: root.expanded ? 1 : 0

    Behavior on openness {
        Morph {}
    }

    ColumnLayout {
        id: column

        width: root.width
        height: implicitHeight
        spacing: root.gap

        y: Math.round((1 - root.reveal) * Appearance.anim.riseBy)
        opacity: root.reveal

        Panel {
            id: card

            level: "panel"
            padding: Appearance.space.panelPadding
            implicitHeight: inner.implicitHeight + card.padding * 2

            Layout.fillWidth: true

            ColumnLayout {
                id: inner

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Appearance.notifications.blockGap

                RowLayout {
                    spacing: root.gap

                    Layout.fillWidth: true

                    Rectangle {
                        implicitWidth: Appearance.notifications.digestTile
                        implicitHeight: Appearance.notifications.digestTile
                        radius: Appearance.bar.tileRadius(Appearance.notifications.digestTile)
                        color: Colours.primaryContainer

                        Icon {
                            anchors.centerIn: parent
                            text: "inbox"
                            size: Appearance.size.iconMd
                            color: Colours.on.primaryContainer
                        }
                    }

                    ColumnLayout {
                        spacing: 0

                        Layout.fillWidth: true

                        Text {
                            text: qsTr("%1 while you were focused").arg(Notifs.heldCount)
                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.size.body
                            color: Colours.on.surface
                            elide: Text.ElideRight

                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: 0

                            Layout.fillWidth: true

                            Text {
                                // A time range is a literal, so it is set in
                                // mono even though the clause after it is
                                // prose. The two are separate items for that
                                // reason and for no other.
                                text: Notifs.heldRange
                                font.family: Appearance.font.mono
                                font.pixelSize: Appearance.size.caption
                                color: Colours.outline
                            }

                            Text {
                                text: Notifs.heldUrgent ? qsTr("· %1 urgent").arg(Notifs.held.filter(e => e.critical).length) : qsTr("· nothing urgent")
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.size.caption
                                color: Colours.outline
                                leftPadding: Appearance.space.xs
                                elide: Text.ElideRight

                                Layout.fillWidth: true
                            }
                        }
                    }

                    Pill {
                        icon: root.expanded ? "expand_less" : "expand_more"
                        tone: "plain"
                        iconSize: Appearance.size.iconMd
                        onClicked: root.expanded = !root.expanded
                    }
                }

                ColumnLayout {
                    id: rows

                    spacing: Appearance.notifications.rowGap
                    visible: root.openness > 0
                    opacity: root.openness
                    // Laid out at full height and cut to its share of it, so
                    // the rows do not reflow as the card folds; the gap above
                    // folds with it.
                    clip: root.openness < 1

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(rows.implicitHeight * root.openness)
                    Layout.topMargin: -Math.round(inner.spacing * (1 - root.openness))

                    Repeater {
                        model: Notifs.heldApps

                        Rectangle {
                            id: entry

                            required property string modelData

                            readonly property var group: Notifs.heldGroups[entry.modelData] ?? []
                            readonly property QtObject newest: entry.group[0] ?? null
                            readonly property bool urgent: entry.group.some(e => e.critical)
                            // The design's "Open" chip: somewhere for the row to
                            // go. The freedesktop default action if the app
                            // sent one, otherwise the first button it offered
                            // -- to the user they mean the same thing, which is
                            // "take me to it".
                            readonly property var action: entry.newest ? (entry.newest.defaultAction ?? entry.newest.buttons[0] ?? null) : null

                            implicitHeight: line.implicitHeight + Appearance.notifications.rowPadV * 2
                            radius: Appearance.radius.card
                            color: Colours.hover

                            Layout.fillWidth: true

                            RowLayout {
                                id: line

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.leftMargin: Appearance.notifications.rowPadH
                                anchors.rightMargin: Appearance.notifications.rowPadH
                                anchors.topMargin: Appearance.notifications.rowPadV
                                spacing: root.gap

                                Icon {
                                    text: entry.urgent ? "priority_high" : Hypr.symbolFor(entry.modelData)
                                    size: Appearance.size.iconMd
                                    // Neutral, except for the two things that
                                    // are not: something urgent got held, or
                                    // the row still has somewhere to go.
                                    color: entry.urgent ? Colours.error : entry.action ? Colours.tertiary : Colours.outline

                                    Layout.alignment: Qt.AlignTop
                                }

                                ColumnLayout {
                                    spacing: 0

                                    Layout.fillWidth: true

                                    AppLine {
                                        label: entry.modelData
                                        note: entry.group.length === 1 ? qsTr("1 message") : qsTr("%1 messages").arg(entry.group.length)

                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: root.detailOf(entry.group)
                                        visible: text !== ""
                                        font.family: Appearance.font.ui
                                        font.pixelSize: Appearance.size.label
                                        color: Colours.outline
                                        wrapMode: Text.Wrap
                                        lineHeight: lineCount > 1 ? Appearance.notifications.bodyLineHeight : 1
                                        maximumLineCount: 2
                                        elide: Text.ElideRight

                                        Layout.fillWidth: true
                                    }
                                }

                                Pill {
                                    text: qsTr("Open")
                                    visible: entry.action !== null
                                    pillHeight: 24
                                    fontSize: Appearance.size.caption

                                    Layout.alignment: Qt.AlignTop

                                    onClicked: {
                                        const batch = entry.group;
                                        entry.action.invoke();
                                        // Going to the application deals with
                                        // everything it said, not just the
                                        // last of it. The entries stay in the
                                        // history; only the digest lets go.
                                        for (const held of batch)
                                            Notifs.unhold(held);
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    spacing: Appearance.space.sm

                    Layout.fillWidth: true

                    Pill {
                        // The affirmative action while focus has already ended
                        // and there is nothing left to stay in.
                        text: qsTr("Mark all read")
                        tone: Notifs.holding ? "subtle" : "accent"
                        pillHeight: 32
                        fontSize: Appearance.size.label
                        onClicked: Notifs.markAllRead()

                        Layout.fillWidth: true
                    }

                    Pill {
                        // The design draws "Stay in focus", which is only an
                        // offer while focus is still on. Once it has ended the
                        // same button becomes the way to throw the batch away.
                        text: Notifs.holding ? qsTr("Stay in focus") : qsTr("Dismiss all")
                        tone: Notifs.holding ? "accent" : "subtle"
                        pillHeight: 32
                        fontSize: Appearance.size.label
                        onClicked: {
                            if (Notifs.holding)
                                Notifs.stayInFocus();
                            else
                                Notifs.dismissDigest();
                        }

                        Layout.fillWidth: true
                    }
                }
            }
        }

        // The promise the design's last line makes. Spaced by explicit margins
        // rather than by the layout's spacing, because the time in the middle
        // of the sentence is a literal and has to be set in mono -- which means
        // three items where the design has one string, and word gaps that the
        // layout would otherwise put in the wrong places.
        RowLayout {
            spacing: 0

            Layout.fillWidth: true
            Layout.leftMargin: root.footerInset
            Layout.rightMargin: root.footerInset

            Icon {
                text: "schedule"
                size: Appearance.size.iconSm
                color: Colours.outline
            }

            Text {
                text: qsTr("Next digest at")
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.caption
                color: Colours.outline

                Layout.leftMargin: root.gap
            }

            Text {
                text: Notifs.nextDigestLabel
                font.family: Appearance.font.mono
                font.pixelSize: Appearance.size.caption
                color: Colours.outline

                Layout.leftMargin: Appearance.space.xs
            }

            Text {
                text: qsTr(", or when focus ends")
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.caption
                color: Colours.outline
                elide: Text.ElideRight

                Layout.fillWidth: true
            }
        }
    }
}
