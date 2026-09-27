pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.services as Svc
import qs.components

// The bar's fourth control popout: the battery. Charge, the three power
// profiles as a segmented rail, and three rows of the things you would only
// look up when the number surprised you.
//
// THE IMPORT IS QUALIFIED because `qs.services` exports a `Power` singleton and
// this file is called Power.qml. Left unqualified, the name in this file would
// resolve to one of the two depending on import order, silently -- the same
// race that made the services `Net` and `Bt` rather than `Network` and
// `Bluetooth`. The architecture names this file, so the import bends instead.
//
// TWO OF THE THREE ROWS CANNOT BE REAL ON EVERY MACHINE, and they say so
// rather than inventing a number:
//
//   Draw          on a laptop whose firmware stops reporting a rate once the
//                 pack sits full on mains -- sysfs `power_now` fails with
//                 ENODEV rather than returning zero -- `Power.measuring` is
//                 false and the row reads "--". Printing "0.0 W" would be a
//                 measurement that was never taken.
//   Charge limit  on a chassis with no `charge_control_end_threshold`. There
//                 is no ACPI standard behind a charge ceiling and the laptops
//                 that offer one do it through their own platform driver, so
//                 the row reads "Not supported". An 80% that nothing is
//                 enforcing would be worse than an absent row.
//
// Health is real: a percentage and the cycle count, computed from the two
// figures the kernel does report.
//
// The bar's power *button* is a different thing entirely -- it opens the
// session menu. This is the battery.
PopoutContent {
    id: root

    // "Draw", "Health", "Charge limit". One repeater rather than three copies
    // of the same two-text row, and the order the design puts them in.
    readonly property var details: [
        {
            label: qsTr("Draw"),
            value: Svc.Power.drawText
        },
        {
            label: qsTr("Health"),
            value: Svc.Power.healthText
        },
        {
            label: qsTr("Charge limit"),
            value: Svc.Power.chargeLimitText
        }
    ]

    icon: Svc.Power.icon
    heading: qsTr("Power")

    RowLayout {
        spacing: Appearance.popout.chargeGap
        visible: Svc.Power.available

        Layout.fillWidth: true

        Text {
            text: qsTr("%1%").arg(Svc.Power.percent)
            // A percentage, so the mono face, like every figure -- the design
            // leaves this one figure in the UI font, which is the one place in
            // the popouts the two disagree. A charge that changes while you
            // watch it should not re-space itself.
            font.family: Appearance.font.mono
            font.pixelSize: Appearance.popout.chargeSize
            font.weight: Font.Light
            color: Svc.Power.critical ? Colours.error : Colours.on.surface

            Layout.alignment: Qt.AlignBaseline
        }

        Text {
            // Empty until UPower has gathered enough samples, which is normal
            // for the first minute of a session and is why this is not a
            // sentence with a hole in it.
            text: Svc.Power.remainingText
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.label
            color: Colours.outline
            elide: Text.ElideRight

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBaseline
        }
    }

    Empty {
        text: qsTr("No battery")
        visible: !Svc.Power.available
    }

    // The gauge on some laptops' controllers really does freeze while the pack
    // keeps draining, and everything that trusts the percentage -- UPower's own
    // critical action included -- then agrees on a number that is wrong. The
    // popout is where a dying battery says so.
    Text {
        text: qsTr("Charge reading has stopped moving")
        visible: Svc.Power.gaugeStuck
        font.family: Appearance.font.ui
        font.pixelSize: Appearance.size.label
        color: Colours.error
        elide: Text.ElideRight

        Layout.fillWidth: true
    }

    Segmented {
        id: profiles

        // Not a fixed three: not every machine offers `performance`, and a
        // segment the daemon would refuse is a dead third of the control. The
        // service asks the bus what is really on offer.
        model: Svc.Power.profiles.map(p => Svc.Power.shortLabel(p))
        currentIndex: Math.max(0, Svc.Power.profiles.indexOf(Svc.Power.profile))
        equalWidths: true
        visible: Svc.Power.profilesAvailable
        segmentRadius: Appearance.radius.chip
        railRadius: Appearance.radius.card
        onSelected: index => Svc.Power.setProfile(Svc.Power.profiles[index])

        Layout.fillWidth: true

        // The daemon is the authority, not the rail: a profile changed from
        // anywhere else moves it back, and a plain binding would have been
        // destroyed by the first click.
        Binding {
            target: profiles
            property: "currentIndex"
            value: Math.max(0, Svc.Power.profiles.indexOf(Svc.Power.profile))
        }
    }

    Empty {
        text: qsTr("No power profile daemon")
        visible: !Svc.Power.profilesAvailable && Svc.Power.probes > 0
    }

    Divider {}

    Repeater {
        model: root.details

        RowLayout {
            id: detail

            required property var modelData

            spacing: Appearance.space.md

            Layout.fillWidth: true

            Text {
                text: detail.modelData.label
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.label
                color: Colours.outline

                Layout.fillWidth: true
            }

            Text {
                // Watts, percentages, cycle counts: monospace, always.
                text: detail.modelData.value
                font.family: Appearance.font.mono
                font.pixelSize: Appearance.size.label
                color: Colours.on.surfaceVariant
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
