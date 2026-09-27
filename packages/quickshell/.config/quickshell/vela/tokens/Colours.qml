pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The palette.
//
// matugen writes ~/.local/state/vela/scheme.json on every retint (template:
// ~/.config/vela/templates/shell-scheme.json, run by `vela retint`), and this
// file reads it and assigns the values in place. A new wallpaper therefore
// recolours the running shell directly: nothing inside the repo is rewritten,
// and the shell is not reloaded. The values written out below are only what
// shows before a wallpaper has ever been set.
//
// The "on" roles are nested -- `Colours.on.surface`, not `Colours.onSurface` --
// because QML parses `on` + an uppercase letter as a signal handler whenever the
// base name is a sibling property. See docs/quickshell-notes.md.
QtObject {
    id: root

    // ---- mode -------------------------------------------------------------
    property bool light: false
    // 0 = neutral daylight, 1 = fully warmed (see the Sun service). Not a theme.
    property real warmth: 0

    // The image the current palette was generated from, empty until the first
    // retint.
    property string source: ""

    // Emitted after a new scheme.json has been applied.
    signal retinted

    // ---- dark -------------------------------------------------------------
    readonly property Scheme dark: Scheme {
        primary: "#94cdf7"
        primaryContainer: "#004c6e"
        secondary: "#b7c9d9"
        tertiary: "#cec0e8"
        error: "#ffb4ab"
        surface: "#101417"
        surfaceContainerLow: "#181c20"
        surfaceContainer: "#1c2024"
        surfaceContainerHigh: "#262a2e"
        outline: "#8b9198"
        outlineVariant: "#41474d"
        panelBase: "#181c20"
        surfaceBarAttached: "#141A1D"
        panelBorder: Qt.alpha("#dfe3e8", 0.07)
        hover: Qt.rgba(1, 1, 1, 0.05)
        track: Qt.rgba(1, 1, 1, 0.09)
        muted: "#5D7178"
        scrim: Qt.alpha("#101417", 0.62)
        textOnPrimary: "#00344d"
        textOnPrimaryContainer: "#c9e6ff"
        textOnSurface: "#dfe3e8"
        textOnSurfaceVariant: "#c1c7ce"
    }

    // ---- light ------------------------------------------------------------
    readonly property Scheme lightScheme: Scheme {
        primary: "#256489"
        primaryContainer: "#c9e6ff"
        secondary: "#4f606e"
        tertiary: "#64597c"
        error: "#ba1a1a"
        surface: "#f7f9fe"
        surfaceContainerLow: "#f1f4f9"
        surfaceContainer: "#ebeef3"
        surfaceContainerHigh: "#e5e8ed"
        outline: "#71787e"
        outlineVariant: "#c1c7ce"
        panelBase: "#f1f4f9"
        surfaceBarAttached: "#f1f4f9"
        panelBorder: Qt.alpha("#181c20", 0.08)
        hover: Qt.alpha("#181c20", 0.05)
        track: Qt.rgba(0.090, 0.110, 0.118, 0.10)
        // The design only gives the dark value; light takes its own
        // outlineVariant, which stands in the same relation to its surface.
        muted: "#c1c7ce"
        scrim: Qt.alpha("#181c20", 0.32)
        textOnPrimary: "#ffffff"
        textOnPrimaryContainer: "#001e2f"
        textOnSurface: "#181c20"
        textOnSurfaceVariant: "#41474d"
    }

    // ---- loading the generated scheme ---------------------------------------
    readonly property string schemePath: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/vela/scheme.json`

    readonly property FileView schemeFile: FileView {
        path: root.schemePath
        // Synchronous, so the first frame is already in the right colours.
        blockLoading: true
        watchChanges: true
        // Missing just means no wallpaper has been set yet.
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.applyScheme(text())
    }

    Component.onCompleted: {
        root.applyScheme(schemeFile.text());
        // From here on a change of palette is eased; the one read at startup
        // is not, or every shell start would open on a colour sweep from the
        // defaults above to the wallpaper's.
        Qt.callLater(() => root.settled = true);
    }

    property bool settled: false

    // True while the palette is crossing over to another. Colour Behaviors
    // elsewhere stand aside for it (`enabled: !Colours.crossing`): each would
    // restart its own short fade on every frame of this long one and trail
    // behind everything that follows the palette directly.
    readonly property bool crossing: crossover.running

    readonly property Timer crossover: Timer {
        interval: Appearance.anim.palette
    }

    onRetinted: root.crossover.restart()
    onLightChanged: root.crossover.restart()
    onWarmthChanged: root.crossover.restart()

    function applyScheme(text: string): void {
        if (!text)
            return;
        let doc = null;
        try {
            doc = JSON.parse(text);
        } catch (e) {
            // A half-written file; the next change notification brings the
            // whole one.
            return;
        }
        root.fill(root.dark, doc.dark, true);
        root.fill(root.lightScheme, doc.light, false);
        root.source = doc.image ?? "";
        root.retinted();
    }

    // `p` holds matugen's snake_case role names. The derived roles are composed
    // exactly as the design specifies them for each mode.
    function fill(s: var, p: var, isDark: bool): void {
        if (!p || !p.primary)
            return;
        s.primary = p.primary;
        s.primaryContainer = p.primary_container;
        s.secondary = p.secondary;
        s.tertiary = p.tertiary;
        s.error = p.error;
        s.surface = p.surface;
        s.surfaceContainerLow = p.surface_container_low;
        s.surfaceContainer = p.surface_container;
        s.surfaceContainerHigh = p.surface_container_high;
        s.outline = p.outline;
        s.outlineVariant = p.outline_variant;
        s.panelBase = p.surface_container_low;
        // The dashboard's #141A1D is the design palette's panel base drawn
        // opaque, so a generated palette takes its own panel base the same way.
        s.surfaceBarAttached = p.surface_container_low;
        s.panelBorder = Qt.alpha(p.on_surface, isDark ? 0.07 : 0.08);
        s.hover = isDark ? Qt.rgba(1, 1, 1, 0.05) : Qt.alpha(p.on_surface, 0.05);
        s.track = isDark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0.090, 0.110, 0.118, 0.10);
        s.muted = isDark ? "#5D7178" : p.outline_variant;
        s.scrim = isDark ? Qt.alpha(p.surface, 0.62) : Qt.alpha(p.on_surface, 0.32);
        s.textOnPrimary = p.on_primary;
        s.textOnPrimaryContainer = p.on_primary_container;
        s.textOnSurface = p.on_surface;
        s.textOnSurfaceVariant = p.on_surface_variant;
    }

    readonly property Scheme scheme: light ? lightScheme : dark

    // ---- evening warmth ---------------------------------------------------
    // The same scheme moved toward amber, NOT a light/dark switch. `warmth` is
    // driven by the Sun service over 90 minutes from sunset.
    //
    // `warmth` interpolates toward the fully warmed colour; it does not rotate
    // the hue by a fraction of the way. The difference is the whole ramp.
    // Sweeping the hue from cyan to amber travels through green at full
    // saturation, so a third of the way into the evening the shell flushed
    // vivid green: `primary` reached #71d896 where the design's own ramp
    // (#7FD0E0 -> #A9C6B8 -> #CEBFA0 -> #E8BE8C) shows a muted sage.
    // Interpolating passes through the desaturated middle the design draws.
    // Measured against those four stops and the five warmed roles the design
    // labels, worst channel error falls from 56.5 to 17.5 at the third, and
    // from 51.2 to 18.9 at the two thirds.
    function warm(c: color): color {
        if (root.warmth <= 0)
            return c;
        const target = root.fullyWarm(c);
        if (root.warmth >= 1)
            return target;
        const t = root.warmth;
        return Qt.rgba(c.r + (target.r - c.r) * t, c.g + (target.g - c.g) * t, c.b + (target.b - c.b) * t, c.a);
    }

    // The colour at warmth 1: the same tone at amber, holding the luminance it
    // started with.
    //
    // Rotating hue at a fixed HSL lightness does NOT hold brightness: amber is
    // far more luminous than blue at the same `l`, so the rotation quietly
    // moved every contrast ratio in the shell as the evening came on. Measured
    // on the generated light palette, `primary` as text fell from 6.11:1 to
    // 4.78:1 on `surface` and from 5.24:1 to 4.08:1 on `surfaceContainerHigh`
    // -- through the floor at dusk, on a palette that cleared it at noon; dark
    // mode drifted the other way and took `outline` to 4.42:1 on two of the
    // eight wallpapers measured. So solve for the lightness that restores the
    // luminance it started with. Warmth then changes hue and saturation and
    // nothing a contrast ratio can see, which is what "a hue rotation, not a
    // separate palette" has to mean. Because both ends of the interpolation
    // carry the same luminance, the middle holds it too: measured across the
    // ramp on `primary`, luminance varies by 2.4% end to end.
    //
    // The design's own warmed values do not hold luminance -- they drift from
    // -10.6% to +5.4% across the roles it labels -- so this is a deliberate
    // deviation, taken because the contrast floor is a rule the design states
    // and the drift breaks it.
    //
    // 0.18 is kept for the saturation drop: refitting under interpolation puts
    // the optimum at 0.15, a difference of about one unit in 255.
    function fullyWarm(c: color): color {
        // amber, ~30deg
        const hue = 0.083;
        const sat = Math.max(0, c.hslSaturation * (1 - 0.18));
        return Qt.hsla(hue, sat, root.matchLuminance(hue, sat, root.luminanceOf(c)), c.a);
    }

    // Bisect on HSL lightness until the rotated colour matches `wanted`.
    // Luminance is monotonic in lightness at a fixed hue and saturation, so
    // twelve halvings pin it to better than one part in four thousand -- an
    // order of magnitude finer than the 1/255 the result is quantised to.
    function matchLuminance(hue: real, sat: real, wanted: real): real {
        let lo = 0;
        let hi = 1;
        for (let i = 0; i < 12; ++i) {
            const mid = (lo + hi) / 2;
            if (root.luminanceOf(Qt.hsla(hue, sat, mid, 1)) < wanted)
                lo = mid;
            else
                hi = mid;
        }
        return (lo + hi) / 2;
    }

    // ---- the palette on screen ------------------------------------------------
    //
    // Every role eased towards its target over `anim.palette`, so a new
    // wallpaper's palette, the switch between light and dark, and each step of
    // evening warmth cross over rather than cutting (docs/motion.md). The
    // accessors below read these; nothing else should.
    //
    // A target is computed from the target palette, never from another eased
    // role -- `outline` is checked against the surface it is heading for, not
    // the one on screen mid-change -- so no role chases another. Alphas that a
    // setting moves live (the panel opacity slider) are applied after the
    // easing, so dragging the slider is not delayed.
    readonly property Eased ePrimary: Eased {
        to: root.warm(root.scheme.primary)
        live: root.settled
    }
    readonly property Eased ePrimaryContainer: Eased {
        to: root.warm(root.scheme.primaryContainer)
        live: root.settled
    }
    readonly property Eased eSecondary: Eased {
        to: root.warm(root.scheme.secondary)
        live: root.settled
    }
    readonly property Eased eTertiary: Eased {
        to: root.warm(root.scheme.tertiary)
        live: root.settled
    }
    readonly property Eased eError: Eased {
        to: root.scheme.error
        live: root.settled
    }
    readonly property Eased eSurface: Eased {
        to: root.warm(root.scheme.surface)
        live: root.settled
    }
    readonly property Eased eSurfaceContainerLow: Eased {
        to: root.warm(root.scheme.surfaceContainerLow)
        live: root.settled
    }
    readonly property Eased eSurfaceContainer: Eased {
        to: root.warm(root.scheme.surfaceContainer)
        live: root.settled
    }
    readonly property Eased eSurfaceContainerHigh: Eased {
        to: root.warm(root.scheme.surfaceContainerHigh)
        live: root.settled
    }
    readonly property Eased eOutline: Eased {
        to: root.readable(root.scheme.outline, root.warm(root.scheme.surfaceContainerHigh), root.scheme.textOnSurface)
        live: root.settled
    }
    readonly property Eased eOutlineVariant: Eased {
        to: root.scheme.outlineVariant
        live: root.settled
    }
    readonly property Eased ePanelBase: Eased {
        to: root.warm(root.scheme.panelBase)
        live: root.settled
    }
    readonly property Eased eSurfaceBarAttached: Eased {
        to: root.warm(root.scheme.surfaceBarAttached)
        live: root.settled
    }
    readonly property Eased ePanelBorder: Eased {
        to: root.scheme.panelBorder
        live: root.settled
    }
    readonly property Eased eHover: Eased {
        to: root.scheme.hover
        live: root.settled
    }
    readonly property Eased eTrack: Eased {
        to: root.scheme.track
        live: root.settled
    }
    readonly property Eased eMuted: Eased {
        to: root.warm(root.scheme.muted)
        live: root.settled
    }
    readonly property Eased eScrim: Eased {
        to: root.scheme.scrim
        live: root.settled
    }
    readonly property Eased eTextOnPrimary: Eased {
        to: root.scheme.textOnPrimary
        live: root.settled
    }
    readonly property Eased eTextOnPrimaryContainer: Eased {
        to: root.scheme.textOnPrimaryContainer
        live: root.settled
    }
    readonly property Eased eTextOnSurface: Eased {
        to: root.scheme.textOnSurface
        live: root.settled
    }
    readonly property Eased eTextOnSurfaceVariant: Eased {
        to: root.scheme.textOnSurfaceVariant
        live: root.settled
    }

    // ---- accessors -- always read colours through these --------------------
    readonly property color primary: root.ePrimary.value
    readonly property color primaryContainer: root.ePrimaryContainer.value
    readonly property color secondary: root.eSecondary.value
    readonly property color tertiary: root.eTertiary.value
    // Error never warms: a destructive action must read the same at every hour.
    readonly property color error: root.eError.value
    readonly property color surface: root.eSurface.value
    readonly property color surfaceContainerLow: root.eSurfaceContainerLow.value
    readonly property color surfaceContainer: root.eSurfaceContainer.value
    readonly property color surfaceContainerHigh: root.eSurfaceContainerHigh.value
    // Text never warms either, or contrast drifts out of the 4.5:1 floor.
    //
    // `outline` is the third rung of the readable ramp and the only one that
    // needs guarding. Matugen's outline is neutral-variant tone 50, which
    // Material specifies as a *border* colour and only guarantees at 3:1.
    // Measured over eight wallpapers it lands at 4.24-4.28 against `surface`
    // and 3.64-3.67 against `surfaceContainerHigh` in light mode -- under the
    // floor on every one, and the design's own light value (#6F797B, 4.25)
    // fails identically. Dark mode clears it cold, at 4.54 in the worst case,
    // but full evening warmth takes two of the eight to 4.42. Nothing in this
    // shell draws a border in `outline`: it is text and icons in 151 places
    // and nothing else, so stepping it towards the palette's own text colour
    // until the darkest surface in the ramp clears the floor costs no
    // structure and is the only way a *generated* palette can honour the
    // 4.5:1 floor. A colour that already passes comes back untouched.
    readonly property color outline: root.eOutline.value
    readonly property color outlineVariant: root.eOutlineVariant.value
    // Composed here rather than baked into the scheme, so the Appearance
    // page's panel opacity slider moves it live -- regenerating the palette to
    // change an alpha would be absurd, and the settings window is required to
    // hold no state of its own.
    readonly property color panel: Qt.alpha(root.ePanelBase.value, Appearance.panelOpacity)
    // The one solid surface the bar and an attached drawer share while the
    // dashboard is open: opaque and borderless, so the two read as one shape.
    // The only place the shell lets a surface touch an edge.
    readonly property color surfaceBarAttached: root.eSurfaceBarAttached.value
    readonly property color panelBorder: root.ePanelBorder.value
    readonly property color hover: root.eHover.value
    // The empty half of a meter: slider tracks, the off state of a toggle, the
    // unfilled part of a progress arc. One value, because the design's .07/.09
    // /.10 whites differ by three parts in 255 over any surface in the ramp.
    readonly property color track: root.eTrack.value
    // The fourth meter colour -- deliberately quiet, and never an accent. The
    // waveform's unplayed tail and the dashboard drawer's disk arc use it to
    // sit behind `primary` without competing with it.
    readonly property color muted: root.eMuted.value
    readonly property color scrim: root.eScrim.value
    readonly property color shadow: "#000000"

    readonly property OnRoles on: OnRoles {
        primary: root.eTextOnPrimary.value
        primaryContainer: root.eTextOnPrimaryContainer.value
        surface: root.eTextOnSurface.value
        surfaceVariant: root.eTextOnSurfaceVariant.value
    }

    // Unfocused monitors dim rather than desaturate to grey.
    readonly property real unfocusedOpacity: 0.62

    // ---- contrast ----------------------------------------------------------
    // The design's floor for anything a user reads. A number, so it lives with
    // the other tokens rather than inline in the one function that uses it.
    readonly property real contrastFloor: 4.5

    // sRGB transfer function, undone. `color`'s components are gamma-encoded,
    // and luminance is only meaningful on linear light.
    function toLinear(v: real): real {
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    }

    // WCAG 2.1 relative luminance.
    function luminanceOf(c: color): real {
        return 0.2126 * root.toLinear(c.r) + 0.7152 * root.toLinear(c.g) + 0.0722 * root.toLinear(c.b);
    }

    // WCAG 2.1 contrast ratio, 1 to 21.
    function contrastOf(a: color, b: color): real {
        const x = root.luminanceOf(a);
        const y = root.luminanceOf(b);
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
    }

    // Step `c` towards `towards` in 4% increments until it clears the floor
    // against `bg`. Mixing towards the palette's own text colour keeps the hue,
    // so the result still reads as the same neutral; measured, every light
    // palette tried needs five steps and every dark one needs none. The cap is
    // a guard against a pathological palette, not a working limit.
    function readable(c: color, bg: color, towards: color): color {
        let out = c;
        for (let i = 0; i < 24 && root.contrastOf(out, bg) < root.contrastFloor; ++i)
            out = Qt.rgba(out.r + (towards.r - out.r) * 0.04, out.g + (towards.g - out.g) * 0.04, out.b + (towards.b - out.b) * 0.04, c.a);
        return out;
    }

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // One role of the palette on screen: `value` follows `to`, eased once
    // `live` -- which the root holds off until the startup palette is in.
    component Eased: QtObject {
        property color to
        property bool live: true
        property color value: to

        Behavior on value {
            enabled: live

            ColorAnimation {
                duration: Appearance.anim.palette
                easing.type: Easing.InOutQuad
            }
        }
    }

    // Foreground colours for content sitting on a matching container. Nested
    // because QML reserves `on` + uppercase as a signal handler wherever the
    // base name is a sibling property -- see the note at the top of this file.
    component OnRoles: QtObject {
        property color primary
        property color primaryContainer
        property color surface
        property color surfaceVariant
    }

    component Scheme: QtObject {
        property color primary
        property color primaryContainer
        property color secondary
        property color tertiary
        property color error
        property color surface
        property color surfaceContainerLow
        property color surfaceContainer
        property color surfaceContainerHigh
        property color outline
        property color outlineVariant
        property color panelBase
        property color surfaceBarAttached
        property color panelBorder
        property color hover
        property color track
        property color muted
        property color scrim

        // Spelled out rather than nested, because a scheme is built with
        // property initialisers and QML will not accept `on.surface:` on an
        // object-typed property. The root nests them once, for call sites.
        property color textOnPrimary
        property color textOnPrimaryContainer
        property color textOnSurface
        property color textOnSurfaceVariant
    }
}
