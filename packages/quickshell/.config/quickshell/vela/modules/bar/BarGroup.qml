pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components as C

// One run of bar items, built from a list of module names out of
// `Config.bar.modules`. The bar has three of these -- leading, centre, trailing
// -- and this is the only file that knows what a name means, so adding a module
// is one `case` and one `Component` rather than an edit in four places.
//
// A module may publish two optional properties, both read here:
//
//   present     false to take itself off the bar entirely. The Loader carries
//               it rather than the module, because a Layout gives an invisible
//               child no cell but still gives a zero-sized visible one its
//               spacing -- which is how a hidden item leaves a gap behind.
//               A divider has no say of its own: it shows only while there is
//               something on both sides of it to divide -- anywhere between it
//               and the next divider, not only next door, or a rule before the
//               tray went whenever the privacy dots beside it were hidden,
//               which is nearly always.
//   leadMargin / trailMargin
//               extra space before and after it, along the bar. A horizontal
//               bar's status run is inset 8px from the chips either side and
//               keeps an 11px internal rhythm the group's own 6px gap cannot
//               express.
//   shrinks     true if the module may be given less room than it asked for.
//               Only the window title says yes: it is the one item with no
//               natural length. The Loader carries it because the Loader is
//               what the layout sees -- `Layout.minimumWidth` set on the module
//               inside is read by nothing, which is why a capped run still
//               overflowed.
//
// A module that comes or goes -- the status run folding behind its arrow,
// the media chip as a player appears -- opens and closes on `Morph` rather
// than jumping: its length along the bar, its gap and its opacity all follow
// one eased `reveal`. The gap is the reason the run's spacing is laid out
// by the slots and not by the layout: a layout keeps the gap around an item
// until the item is hidden outright, and every hidden item then took its gap
// with it in one frame at the end of the fold.
BarFlow {
    id: root

    required property BarState bar
    required property var modules

    vertical: root.bar.vertical
    // `gap` is still the run's spacing; the slots apply it (see above).
    rowSpacing: 0
    columnSpacing: 0

    // Whether any slot before `index` is meant to be on the bar: the gap
    // before a slot belongs to it only when something comes before it.
    function precededByShown(index: int): bool {
        for (let i = index - 1; i >= 0; i--) {
            const slot = slots.itemAt(i);
            if (slot !== null && slot.wanted)
                return true;
        }
        return false;
    }

    // Whether anything is on the bar from `index` onwards in direction `step`
    // before the next divider. Reads `slots.count` so a divider's binding
    // re-runs as the Loaders after it are created.
    function anyShown(index: int, step: int): bool {
        const count = slots.count;
        for (let i = index; i >= 0 && i < count; i += step) {
            const slot = slots.itemAt(i);
            if (slot === null)
                continue;
            if (slot.modelData === "divider")
                return false;
            if (slot.item?.present ?? true)
                return true;
        }
        return false;
    }

    function componentFor(name: string): Component {
        switch (name) {
        case "expander":
            return expanderComponent;
        case "bell":
            return bellComponent;
        case "launcher":
            return launcherComponent;
        case "workspaces":
            return workspacesComponent;
        case "divider":
            return dividerComponent;
        case "activeWindow":
            return activeWindowComponent;
        case "media":
            return mediaComponent;
        case "resources":
            return resourcesComponent;
        case "tray":
            return trayComponent;
        case "privacy":
            return privacyComponent;
        case "ai":
            return aiComponent;
        case "battery":
            return batteryComponent;
        case "clock":
            return clockComponent;
        case "power":
            return powerComponent;
        default:
            console.warn(`[vela] unknown bar module: ${name}`);
            return null;
        }
    }

    Repeater {
        id: slots

        model: root.modules

        Loader {
            id: slot

            required property string modelData
            required property int index

            // Meant to be on the bar: where `reveal` is heading.
            readonly property bool wanted: slot.modelData === "divider" ? root.anyShown(slot.index - 1, -1) && root.anyShown(slot.index + 1, 1) : (slot.item?.present ?? true)

            // How far out it is, 0 to 1. Settled once the bar has been laid
            // out, so a bar that has just started draws what is there.
            property real reveal: slot.wanted ? 1 : 0
            property bool settled: false

            Behavior on reveal {
                enabled: slot.settled

                C.Morph {}
            }

            Component.onCompleted: Qt.callLater(() => slot.settled = true)

            // The run's gap before it, when anything comes before it, and
            // the module's own margins.
            readonly property real lead: (root.precededByShown(slot.index) ? root.gap : 0) + (slot.item?.leadMargin ?? 0)
            readonly property real trail: slot.item?.trailMargin ?? 0
            readonly property bool moving: slot.reveal < 1

            Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            Layout.leftMargin: root.vertical ? 0 : slot.lead * slot.reveal
            Layout.rightMargin: root.vertical ? 0 : slot.trail * slot.reveal
            Layout.topMargin: root.vertical ? slot.lead * slot.reveal : 0
            Layout.bottomMargin: root.vertical ? slot.trail * slot.reveal : 0

            // Along the bar only; across it the module keeps its size, so it
            // closes like a drawer rather than shrinking to a point.
            Layout.preferredWidth: !root.vertical && slot.moving ? slot.implicitWidth * slot.reveal : -1
            Layout.preferredHeight: root.vertical && slot.moving ? slot.implicitHeight * slot.reveal : -1
            Layout.fillWidth: !root.vertical && (slot.item?.shrinks ?? false)
            Layout.minimumWidth: (slot.item?.shrinks ?? false) || (!root.vertical && slot.moving) ? 0 : -1
            Layout.minimumHeight: root.vertical && slot.moving ? 0 : -1

            visible: slot.reveal > 0
            opacity: slot.reveal
            clip: slot.moving
            sourceComponent: root.componentFor(slot.modelData)
        }
    }

    Component {
        id: bellComponent

        Bell {
            bar: root.bar
        }
    }

    Component {
        id: expanderComponent

        BarExpander {
            bar: root.bar
        }
    }

    Component {
        id: launcherComponent

        LauncherButton {
            bar: root.bar
        }
    }

    Component {
        id: workspacesComponent

        Workspaces {
            bar: root.bar
        }
    }

    Component {
        id: dividerComponent

        BarDivider {
            bar: root.bar
        }
    }

    Component {
        id: activeWindowComponent

        ActiveWindow {
            bar: root.bar
        }
    }

    Component {
        id: mediaComponent

        Media {
            bar: root.bar
        }
    }

    Component {
        id: resourcesComponent

        Resources {
            bar: root.bar
        }
    }

    Component {
        id: trayComponent

        Tray {
            bar: root.bar
        }
    }

    Component {
        id: privacyComponent

        PrivacyDots {
            bar: root.bar
        }
    }

    Component {
        id: aiComponent

        AiStatus {
            bar: root.bar
        }
    }

    Component {
        id: batteryComponent

        Battery {
            bar: root.bar
        }
    }

    Component {
        id: clockComponent

        Clock {
            bar: root.bar
        }
    }

    Component {
        id: powerComponent

        PowerButton {
            bar: root.bar
        }
    }
}
