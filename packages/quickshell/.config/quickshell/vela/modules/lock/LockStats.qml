import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.config
import qs.services
import qs.components

// The four ambient stats under the lock screen's clock: weather, events, unread
// and battery, in the order `Config.lock.showStats` gives them.
//
// NOTHING HERE IS INVENTED. The design draws "2 today / First at 16:00", but
// where khal is not installed and no `.ics` exists anywhere, the events column
// says so instead of showing a number it does not have. Same for weather before
// its first fetch, and the battery column is not drawn at all on a machine
// without one.
RowLayout {
    id: root

    readonly property var stats: {
        const out = [];

        for (const key of Config.lock.showStats) {
            if (key === "weather")
                out.push({
                    icon: Weather.icon,
                    tint: Colours.secondary,
                    value: Weather.available ? `${Math.round(Weather.temp)}°` : "—",
                    label: Weather.available ? Weather.description : Weather.error || qsTr("No forecast yet")
                });
            else if (key === "events")
                out.push(root.eventsStat());
            else if (key === "unread")
                out.push(root.unreadStat());
            else if (key === "battery" && Power.available)
                out.push(root.batteryStat());
        }

        return out;
    }

    function eventsStat(): var {
        if (!Calendar.available)
            return {
                icon: "event",
                tint: Colours.primary,
                value: "—",
                label: Calendar.reason || qsTr("No calendar")
            };

        const today = Calendar.todayEvents;
        const next = Calendar.nextEvent;

        return {
            icon: "event",
            tint: Colours.primary,
            value: qsTr("%1 today").arg(today.length),
            label: next ? qsTr("First at %1").arg(Qt.formatDateTime(next.start, "hh:mm")) : qsTr("Nothing scheduled")
        };
    }

    function unreadStat(): var {
        // What arrived since the notification centre was last opened.
        const fresh = Notifs.list.filter(e => e.time > Notifs.seenAt);
        const total = fresh.length;
        const urgent = fresh.filter(e => e.critical).length;

        return {
            icon: "inbox",
            tint: Colours.tertiary,
            value: qsTr("%1 unread").arg(total),
            label: urgent > 0 ? qsTr("%1 urgent").arg(urgent) : total > 0 ? qsTr("Nothing urgent") : qsTr("Nothing waiting")
        };
    }

    function batteryStat(): var {
        const state = Power.full ? qsTr("Full") : Power.charging ? qsTr("Charging") : qsTr("Unplugged");
        // `remainingText` ends in "remaining" / "until full", which the state
        // word already says here; only the span itself is wanted.
        const left = Power.secondsRemaining > 0 ? Time.span(Power.secondsRemaining * 1000) : "";

        return {
            icon: Power.icon,
            tint: Colours.secondary,
            value: `${Power.percent}%`,
            label: left ? `${state} · ${left}` : state
        };
    }

    spacing: 0

    Repeater {
        model: root.stats

        Item {
            id: stat

            required property int index
            required property var modelData

            implicitWidth: Appearance.lock.statWidth
            implicitHeight: column.implicitHeight

            Layout.alignment: Qt.AlignVCenter

            // A hairline between columns, not around them. Drawn on the inside
            // edge rather than between two siblings, so one fixed column width
            // covers every count of stats the config can ask for.
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Appearance.lock.dividerHeight
                color: Colours.alpha(Colours.on.surface, 0.1)
                visible: stat.index > 0
            }

            ColumnLayout {
                id: column

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.lock.statGap

                Icon {
                    text: stat.modelData.icon
                    size: Appearance.lock.statIcon
                    color: stat.modelData.tint

                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    // A count, a temperature or a percentage: monospace, like
                    // every figure in the shell, even where the design sets it
                    // in Rubik.
                    text: stat.modelData.value
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.lock.statValue
                    font.weight: Font.Light
                    color: Colours.on.surface

                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: stat.modelData.label
                    font.family: Appearance.font.ui
                    font.pixelSize: Appearance.size.label
                    // `outline` rather than the design's #7E8A8E, which is
                    // below the 4.5:1 contrast floor for readable text.
                    color: Colours.outline
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
