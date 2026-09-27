import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.tokens

// The bar's panel and the three runs of items on it.
//
// The vertical and horizontal bars are the same list in the same order with
// the flow turned: launcher, workspaces, rule, window -- slack -- media,
// resources, tray, battery, clock, power. Two things move when it turns:
//
//   * the clock leaves the centre. A column has no centre to speak of, so the
//     clock stacks into the trailing run, second from the end, above the power
//     button.
//   * the rules appear. A vertical bar separates status from indicators from
//     time with a 20px rule; a horizontal one has the width to let adjacency do
//     that work and draws none.
//
// Everything else about the rotation is `BarFlow`'s problem, not this file's.
Panel {
    id: root

    required property BarState bar

    level: "bar"
    radius: root.bar.radius
    // While a drawer hangs off this bar the two share one opaque surface, and
    // the bar goes over to it by `bar.solid` -- quickly as the drawer opens,
    // and eased back once it has gone. Quickly rather than at once: a
    // translucent bar over a bright wallpaper going opaque in one frame read
    // as a blink.
    colour: root.bar.fill
    // The hairline goes the instant anything is attached -- even faint, it is
    // a lighter row along the face a drawer hangs from -- and eases back with
    // the fill once the last drawer has gone.
    borderColour: root.bar.attached ? "transparent" : Colours.alpha(Colours.panelBorder, Colours.panelBorder.a * (1 - root.bar.solid))
    // The runs carry their own padding, which is not symmetric: 9px along a
    // vertical bar and nothing across it, 8px along a horizontal one.
    padding: 0

    readonly property int padAlong: root.bar.vertical ? Appearance.bar.padAlongV : Appearance.bar.padAlongH

    // A vertical bar rules off the trailing run before the tray and before the
    // clock. Nowhere else, and never on a horizontal bar.
    readonly property list<string> verticalRules: ["tray", "clock"]

    readonly property var leadingModules: Config.bar.modules.left
    readonly property var centreModules: root.bar.vertical ? [] : Config.bar.modules.centre

    readonly property var trailingModules: {
        const right = [...Config.bar.modules.right];
        // The arrow that folds the run away leads it, unless shell.json has
        // put it somewhere else: everything after it up to the clock is what
        // it hides.
        if (!right.includes("expander"))
            right.unshift("expander");
        // The bell was the tray's last glyph and is its own module now (it
        // folds by its own rule), so it goes where it always was: after the
        // tray, or before the last item if there is no tray.
        if (!right.includes("bell")) {
            const tray = right.indexOf("tray");
            right.splice(tray >= 0 ? tray + 1 : Math.max(0, right.length - 1), 0, "bell");
        }
        if (!root.bar.vertical)
            return right;

        // The centre run has nowhere to go, so it lands just inside the end of
        // the trailing one -- the design puts the clock above the power button
        // and nothing between them.
        const at = Math.max(0, right.length - 1);
        const merged = [...right.slice(0, at), ...Config.bar.modules.centre, ...right.slice(at)];

        const out = [];
        for (const name of merged) {
            if (root.verticalRules.includes(name) && out.length > 0 && out[out.length - 1] !== "divider")
                out.push("divider");
            out.push(name);
        }
        return out;
    }

    // How much room the leading run has before it reaches the centred clock:
    // from where the run starts to the clock's left edge, less one gap. The
    // title is the only thing in the run that can give, and `ActiveWindow`
    // lets it.
    readonly property int leadingRoom: {
        if (root.bar.vertical || !centre.visible)
            return -1;
        const centreLeft = (root.width - centre.implicitWidth) / 2;
        return Math.max(0, Math.round(centreLeft - root.padAlong - Appearance.bar.gapCentreH));
    }

    BarFlow {
        id: flow

        anchors.fill: parent
        anchors.topMargin: root.bar.vertical ? root.padAlong : 0
        anchors.bottomMargin: anchors.topMargin
        anchors.leftMargin: root.bar.vertical ? 0 : root.padAlong
        anchors.rightMargin: anchors.leftMargin

        vertical: root.bar.vertical
        // A vertical bar has one rhythm throughout; a horizontal one lets each
        // run set its own, so the outer flow contributes nothing.
        gap: root.bar.vertical ? Appearance.bar.gapV : 0

        BarGroup {
            Layout.alignment: root.bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            // Stops the leading run reaching the clock. The centre group is
            // placed on the bar's own centre (see the note below), so nothing
            // pushes back when the leading run grows -- and on a 960-logical
            // output the window title ran straight through the time. -1 is
            // "no maximum", which is what a vertical bar wants.
            Layout.maximumWidth: root.bar.vertical ? -1 : root.leadingRoom
            // A layout fills by default, and the explicit maximum above
            // replaces the one its children would give it. So with no window
            // title in it -- an empty workspace -- the run still stretched out
            // to the clock, and with nothing inside to take the slack, every
            // cell widened and the workspace pills drifted off the launcher.
            // It takes its natural width; the cap only ever shortens it.
            Layout.fillWidth: false
            bar: root.bar
            modules: root.leadingModules
            gap: root.bar.vertical ? Appearance.bar.gapV : Appearance.bar.gapLeadH
        }

        Item {
            Layout.fillWidth: !root.bar.vertical
            Layout.fillHeight: root.bar.vertical
        }

        BarGroup {
            Layout.alignment: root.bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            bar: root.bar
            modules: root.trailingModules
            gap: root.bar.vertical ? Appearance.bar.gapV : Appearance.bar.gapTrailH
        }
    }

    // Centred on the bar, not on what the other two runs leave over.
    //
    // The design uses `space-between` here, which parks the clock wherever the
    // left and right groups happen to end. That makes the time step sideways
    // every time the focused window's title changes length, which is the one
    // thing a clock must not do. The design's own prose asks for "Centre: date
    // and time side by side", and that is what this is.
    BarGroup {
        id: centre

        anchors.centerIn: parent
        visible: root.centreModules.length > 0
        bar: root.bar
        modules: root.centreModules
        gap: Appearance.bar.gapCentreH
    }
}
