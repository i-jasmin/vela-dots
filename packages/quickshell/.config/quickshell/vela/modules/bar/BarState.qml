import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.tokens

// One of these per monitor. Everything a bar item needs to know that is not a
// token and not a service: which way the bar runs, whether this monitor holds
// focus, and how to hand its own geometry to the popout layer.
//
// It is passed down rather than read from a singleton so that a hover on this
// screen's clock cannot move the other screen's popout -- the mistake that
// makes a two-monitor shell feel haunted.
QtObject {
    id: root

    // The ShellScreen this bar is drawn on.
    property var screen: null
    readonly property string screenName: root.screen?.name ?? ""

    readonly property string position: Config.bar.position
    readonly property bool vertical: Config.bar.vertical

    // The status run folded away behind its arrow (BarExpander). One state
    // for every monitor's bar.
    readonly property bool collapsed: ShellState.barCollapsed

    // Floating, the bar keeps `bar.margin` from the screen's edges; attached,
    // it sits against its own edge along the whole of it (Settings, Bar).
    readonly property bool flush: !Config.bar.floating
    readonly property int margin: root.flush ? 0 : Config.bar.margin
    // From the config, not the token: `bar.thicknessVertical` and
    // `bar.thicknessHorizontal` are settings, and reading the token instead
    // meant a user who changed either moved every overlay's inset and left the
    // bar where it was. The tokens are the defaults those keys start from.
    readonly property int thickness: Config.bar.thickness
    readonly property int radius: root.vertical ? Appearance.radius.barV : Appearance.radius.barH

    // --- per-monitor focus ---------------------------------------------------
    //
    // Defaults to focused. Hyprland answers nothing for the first second or so,
    // and a bar that starts dimmed on every monitor and brightens a
    // beat later reads as a bug rather than as focus.
    readonly property bool focused: {
        if (!Config.bar.perMonitor.enabled)
            return true;
        if (Hypr.monitors.length <= 1)
            return true;
        if (Hypr.focusedMonitorName === "")
            return true;
        return Hypr.focusedMonitorName === root.screenName;
    }

    readonly property real dim: root.focused ? 1 : Config.bar.perMonitor.dimUnfocused

    // This bar is the one a keybind means (`bar popout network`): the bar on
    // the focused monitor, and only that one. `focused` will not do -- it is
    // true on every monitor while per-monitor dimming is off or Hyprland has
    // not answered, and each bar then opened the popout over the last.
    readonly property bool forKeys: ShellState.focusedScreen === root.screenName

    // --- attached surfaces ---------------------------------------------------
    //
    // `dashboardOpen` is the clock's pill: on the moment the drawer is asked
    // for. `attached` is the bar's surface: solid while anything hangs off it
    // on this monitor -- the dashboard, a popout, the launcher, the power
    // menu -- including its retreat, so a drawer never hangs off a
    // translucent bar.
    readonly property bool dashboardOpen: root.holds("dashboard")
    readonly property bool attached: ShellState.attachedScreens.includes(root.screenName)

    // How far the bar has gone over to the attached surface: 0 is its own
    // translucent fill, 1 is `surfaceBarAttached`. It eases in over
    // `anim.fast` the moment anything hangs off the bar, and back out over
    // `colourFade` once the last drawer has gone. The drawers mix their fill
    // by this same number (AttachedDrawer), and they are drawn in the bar's
    // window, so the bar and a drawer are one colour in every frame.
    //
    // Started by hand rather than by a Behavior. The Behaviors this replaces
    // took their duration from a binding on the same `attached` that set them
    // off, and which of the two the engine re-evaluated first was not fixed.
    // After the first open it was usually the stale one: the bar took the
    // slow fade in, and its border -- a ring the fill is not drawn under --
    // stayed for 300 ms as a see-through line along the bar's face, under
    // the drawer.
    property real solid: 0
    readonly property color loose: Colours.alpha(Colours.panel, Appearance.panelOpacity)
    readonly property color fill: root.mix(root.loose, Colours.surfaceBarAttached, root.solid)

    readonly property NumberAnimation fade: NumberAnimation {
        target: root
        property: "solid"
    }

    onAttachedChanged: {
        root.fade.stop();
        root.fade.to = root.attached ? 1 : 0;
        root.fade.duration = root.attached ? Appearance.anim.fast : Appearance.dashboard.colourFade;
        root.fade.start();
    }

    // Mixed with the colour weighted by its alpha, so that what reaches the
    // screen moves in a straight line from one to the other. Mixed channel
    // by channel instead, the way to the border's faint light went through a
    // brighter, half-opaque grey: the outline flared on the way back.
    function mix(a: color, b: color, t: real): color {
        const alpha = a.a + (b.a - a.a) * t;
        if (alpha <= 0)
            return Qt.rgba(0, 0, 0, 0);
        const channel = (x, y) => (x * a.a + (y * b.a - x * a.a) * t) / alpha;
        return Qt.rgba(channel(a.r, b.r), channel(a.g, b.g), channel(a.b, b.b), alpha);
    }

    // True while `surface` -- the dashboard, the launcher, the power menu --
    // is open off this bar, for the button that opened it.
    function holds(surface: string): bool {
        return ShellState[surface] && ShellState.drawerScreen === root.screenName;
    }

    // What that button does: opens it here, or puts it away.
    function toggle(surface: string): void {
        ShellState.toggleOn(surface, root.screenName);
    }

    // The dashboard on one tab, for an item that stands for it: opens it
    // here on `tab`, changes to `tab`, or puts it away if it is already
    // showing `tab` here.
    function dashboardOn(tab: string): void {
        ShellState.toggleDashboardOn(tab, root.screenName);
    }

    // The calendar -- the dashboard's Home with the month out -- here, or
    // put away if that is what is showing here.
    function calendar(): void {
        ShellState.toggleCalendarOn(root.screenName);
    }

    // The unfocused bar keeps its accent legible but stops it competing: same
    // hue, same lightness, roughly half the chroma. The dim above does the
    // rest, so this only has to take the edge off.
    function accent(c: color): color {
        if (root.focused)
            return c;
        return Qt.hsla(c.hslHue, c.hslSaturation * 0.4, c.hslLightness, c.a);
    }

    // --- popouts ------------------------------------------------------------
    //
    // A bar item calls `popout("network", this)` and is done. The bar shares
    // its window with the popout, and the window covers the screen from its
    // origin, so the item's place in the window is its place on the screen.

    function rectOf(item: Item): rect {
        const p = item.mapToItem(null, 0, 0);
        return Qt.rect(p.x, p.y, item.width, item.height);
    }

    function popout(name: string, item: Item, detail: var): void {
        BarPopouts.toggle(name, root.screenName, root.rectOf(item), detail);
    }

    // True while this monitor is the one showing `name`, so the item that
    // opened it can hold its pressed look.
    function showing(name: string): bool {
        return BarPopouts.isOpen(name, root.screenName);
    }
}
