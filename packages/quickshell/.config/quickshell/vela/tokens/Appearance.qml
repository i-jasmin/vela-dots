pragma Singleton
import QtQuick

// Every metric in the shell. No module defines its own.
QtObject {
    id: root

    property real radiusScale: 1.0      // settings: corner radius slider
    property real panelOpacity: 0.82    // settings: panel opacity slider
    property bool reduceMotion: false   // settings: motion, reduced
    property bool motionOff: false      // settings: motion, off
    property real motionSpeed: 1        // settings: motion speed

    // A duration as the settings have it: the design's, divided by the speed
    // chosen, and none at all with motion off. Every duration below goes
    // through this, and nothing in the shell sets a duration of its own, so
    // the one slider speeds up or slows down all of it.
    function scaled(ms: int): int {
        return root.motionOff ? 0 : Math.round(ms / Math.max(0.25, root.motionSpeed));
    }

    // ---- shape ------------------------------------------------------------
    readonly property QtObject radius: QtObject {
        readonly property int panel: Math.round(22 * root.radiusScale)
        readonly property int drawer: Math.round(26 * root.radiusScale)
        readonly property int popout: Math.round(20 * root.radiusScale)
        readonly property int dock: Math.round(24 * root.radiusScale)
        // 20px cards, a step up from the Appearance page's 18px ones, for cards
        // that sit inside a larger-radius surface.
        readonly property int cardXl: Math.round(20 * root.radiusScale)
        readonly property int cardLg: Math.round(18 * root.radiusScale)
        readonly property int card: Math.round(15 * root.radiusScale)
        readonly property int tile: Math.round(16 * root.radiusScale)
        readonly property int chip: Math.round(12 * root.radiusScale)
        readonly property int small: Math.round(9 * root.radiusScale)
        // Smaller than any control: the colour swatch beside a hex value.
        readonly property int xs: Math.round(6 * root.radiusScale)
        readonly property int barV: Math.round(20 * root.radiusScale)
        readonly property int barH: Math.round(16 * root.radiusScale)
        // The launcher's 24 was borrowing `dock`, which made it read as if it
        // had taken the dock's corner; `row` (13) had no token at all.
        readonly property int launcher: Math.round(24 * root.radiusScale)
        readonly property int row: Math.round(13 * root.radiusScale)
        readonly property int full: 9999
    }

    // ---- spacing ----------------------------------------------------------
    readonly property QtObject space: QtObject {
        readonly property int xs: 4
        readonly property int sm: 8
        readonly property int md: 12
        readonly property int lg: 16
        readonly property int xl: 20
        readonly property int barMargin: 10
        readonly property int overlayMargin: 26
        readonly property int panelPadding: 16
        readonly property int drawerPadding: 20
    }

    // ---- bar --------------------------------------------------------------
    readonly property QtObject bar: QtObject {
        readonly property int thicknessVertical: 58
        readonly property int thicknessHorizontal: 40
        readonly property int wsPill: 24          // idle length
        readonly property int wsPillActive: 38    // active stretches, not recolours only
        readonly property int wsPillCross: 30
        readonly property int iconButton: 34
        readonly property int revealDelay: 120    // ms, settings-controlled

        // ---- folded in from the bar module -------------------------------
        // The values measured off the design's vertical and horizontal bar that
        // this file did not carry. Six of them are type sizes, which the house
        // rule allows here only.

        // ---- vertical ---------------------------------------------------------

        // `padding: 9px 0` on the rail: along the bar only, nothing across it.
        readonly property int padAlongV: 9
        // The rail's one gap. Every item on it is 11px from its neighbour.
        readonly property int gapV: 11
        // The launcher's tile is a step larger than every other icon button.
        readonly property int launcherTile: 36
        // Icon over number, in the cpu, ram and battery stacks.
        readonly property int statGap: 3
        readonly property real statSize: 9.5
        readonly property real dateSize: 9
        readonly property real clockSize: 15
        // The tray glyphs are bare, so they carry their own breathing room.
        readonly property int trayGapV: 13

        // ---- horizontal -------------------------------------------------------

        readonly property int padAlongH: 8
        readonly property int launcherTileH: 28
        readonly property real glyphH: 19
        // Every square button on the horizontal bar, and every chip's height.
        readonly property int iconButtonH: 26
        // Workspace pills grow wider, not taller: a fixed 22px cross measure and a
        // padding that steps from 6 to 13 when the pill is the active one.
        readonly property int wsCrossH: 22
        readonly property int wsPadH: 6
        readonly property int wsPadActiveH: 13
        readonly property real titleSize: 12
        readonly property real timeSize: 13
        // The design tracks the inline clock a fraction wide so 14:32 does not
        // read as one word.
        readonly property real timeTracking: 0.02
        // The three groups do not share a gap: the left group is airier than the
        // right, which is carrying five items in the same run.
        readonly property int gapLeadH: 8
        readonly property int gapCentreH: 10
        readonly property int gapTrailH: 6
        readonly property int trayGapH: 11
        // The window title sits half an em from its app glyph...
        readonly property int titleGap: 7
        // ...and the two halves of the cpu/ram chip sit a whole one apart.
        readonly property int statGapH: 9
        readonly property int chipPadLead: 8
        readonly property int chipPadTrail: 10
        readonly property int chipGap: 8

        // ---- shared ------------------------------------------------------------

        // The media chip elides rather than pushing the clock off centre.
        readonly property int mediaMaxWidth: 140
        // Not in the design, which draws a six-word title and stops there. A
        // real title runs to any length, and the clock is centred on the screen
        // rather than on what is left of it, so the title has to be capped or it
        // walks underneath.
        readonly property int titleMaxWidth: 220

        // The strip of window left live at the screen edge while the bar is hidden,
        // so the cursor can reach it. Two pixels rather than one: a scaled output
        // rounds a one-pixel input region away.
        readonly property int revealStrip: 2
        // How long an autohiding bar waits, once the pointer has left it,
        // before it goes: long enough to forgive slipping off it and back.
        readonly property int hideDelay: 300
        // A popout asked for by keybind while its item is folded away waits
        // this long after the run opens, so it anchors where the item settles.
        readonly property int unfoldSettle: 50

        // The dot a glyph wears while something waits behind it: unread
        // notifications on the bell.
        readonly property int dot: 7

        // The privacy capsule: the one bar item that takes a colour of its own
        // without being selected, because "the microphone is on" has to be
        // seen from across the room. A wash of `tertiary` behind glyphs in it,
        // one step stronger under the cursor.
        readonly property real privacyTint: 0.18
        readonly property real privacyTintHover: 0.28
        readonly property int privacyPad: 6

        // ---- radii -------------------------------------------------------------
        //
        // The design rounds a bar tile to a third of its side and stops at the
        // chip radius: 12 on the 36px launcher, 11 on the 34px app tile, 9 on the
        // horizontal bar's 26px buttons, 8 on a 24px workspace pill, 7 on a 22px
        // one. One rule reproduces all five, and -- unlike five literals -- it
        // keeps following the settings screen's corner-radius slider.

        function tileRadius(side: int): int {
            return Math.round(side / 3 * root.radiusScale);
        }

        // A pill is rounded on its short measure and never past `radius.small`,
        // which is what stops the active pill turning into a lozenge as it
        // stretches from 24 to 38.
        function pillRadius(w: int, h: int): int {
            return Math.min(root.radius.small, Math.round(Math.min(w, h) / 3 * root.radiusScale));
        }
    }

    // ---- popouts ----------------------------------------------------------
    // Folded in from the popouts module: the values measured off the design's
    // control popouts that this file did not carry.
    readonly property QtObject popout: QtObject {

        // ---- the four control popouts ------------------------------------------

        // 292px, fixed. The device rows, the master slider and the three-way
        // segmented rail are all designed against it.
        readonly property int width: 292
        // The popout pads tighter than a panel does (root.space.panelPadding
        // is 16): 14 all round, with 12 between its children.
        readonly property int padding: 14
        // A heading's glyph sits 10 from its word -- wider than a pill's 6, tighter
        // than a list row's 12.
        readonly property int headerGap: 10
        // A list row, and therefore also the height an empty state holds so the
        // popout does not change shape when a list has nothing in it.
        readonly property int rowHeight: 40

        // Output: the master volume's numeral is right-aligned in its own column so
        // that 7, 62 and 100 do not move the slider; a per-app row names the
        // application in the same way.
        readonly property int valueWidth: 24
        readonly property int streamLabelWidth: 46
        // A per-app slider is a pixel thinner than the master and carries no
        // handle -- the design draws the fill alone.
        readonly property int streamTrack: 5

        // Network: the design's smaller toggle. The knob's 3px gutter is the same
        // at both sizes, so only the track differs from the settings window's.
        readonly property int toggleWidth: 40
        readonly property int toggleHeight: 22
        // A real scan answers with far more access points than the three the
        // design draws, and a popout that runs off the bottom of the screen is
        // not a popout. The strongest few, connected first, then "8 more" to
        // open the rest out (PopoutList) -- which scroll past about eight rows.
        readonly property int listShown: 6
        readonly property int listMax: 8 * rowHeight + 7 * root.space.md

        // Power: the charge figure is the one large number in the module.
        readonly property real chargeSize: 30
        readonly property int chargeGap: 9

        // ---- the workspace window list ----------------------------------------
        //
        // Same machinery, different shape: narrower, squarer, and its rows sit
        // almost on top of each other because they are one list rather than a
        // stack of sections.
        readonly property int windowsWidth: 246
        readonly property int windowsRowHeight: 38
        readonly property int windowsSpacing: 1

        // ---- a tray app's menu ------------------------------------------------
        //
        // One list too, so the window list's rows, at a control popout's width
        // for the labels apps write. A long one scrolls past twelve rows.
        readonly property int menuMax: 12 * windowsRowHeight + 11 * windowsSpacing

        // ---- the notification centre, off the bell --------------------------
        //
        // Wider than a control popout, because a notification is a sentence
        // rather than a label. The history scrolls past `centreListMax`, and
        // each app shows its newest few until it is opened out.
        readonly property int centreWidth: 360
        readonly property int centreListMax: 440
        readonly property int centreShown: 3
        readonly property int centreBodyLines: 2
        readonly property int centreEntryGap: 6
        readonly property int centreGroupGap: 12
        readonly property int centreTile: 30
    }

    // ---- notifications ----------------------------------------------------
    readonly property QtObject notifications: QtObject {
        readonly property int width: 376
        readonly property int cardGap: 11
        readonly property int toastTile: 36
        readonly property int digestTile: 34
        readonly property int rowGap: 9
        readonly property int rowPadV: 11
        readonly property int rowPadH: 13
        readonly property int blockGap: 14
        readonly property real bodyLineHeight: 1.45
        // The design's `margin-top: 6` above a toast's action row.
        readonly property int actionGap: 6
        // The design's urgent card: `rgba(255,180,171,.24)` border over a `.14`
        // tile, both struck from `error`.
        readonly property real urgentBorderTint: 0.24
        readonly property real urgentTileTint: 0.14

        // Swiping one away (components/SwipeArea.qml). How far it moves
        // before it counts as a swipe rather than an unsteady click; how fast
        // a flick throws it however short (pixels a millisecond, over the
        // last `flingWindow` ms); and how long a touchpad sweep can pause
        // before it counts as let go.
        readonly property int swipeSlop: 6
        readonly property real flingSpeed: 0.6
        readonly property int flingWindow: 100
        readonly property int sweepIdle: 180

        // A notification opened out: its summary wraps to this many lines at
        // most (the body to all of it, the centre scrolls), and a picture is
        // drawn this tall at most.
        readonly property int expandedLines: 24
        readonly property int pictureMax: 180
        readonly property int thumb: 36
        readonly property int thumbRadius: 8
        // The chevron that opens one out.
        readonly property int chevron: 18
    }

    // ---- recolour -----------------------------------------------------------
    // The frames a retint crossfades windows through (overlays/Recolour.qml).
    readonly property QtObject recolour: QtObject {
        // Hyprland's window rounding (hypr/conf/general.lua), so a frame has
        // the corners of the window it covers.
        readonly property int windowRadius: 12
    }

    // ---- osd --------------------------------------------------------------
    // The volume and brightness pill at the foot of the screen.
    readonly property QtObject osd: QtObject {
        readonly property int width: 224
        readonly property int height: 56
        readonly property int track: 6
        // The numeral's column, so 7, 62 and 100 do not move the bar.
        readonly property int valueWidth: 24
        // How long it stays after the last change, and how long after startup
        // before a change counts -- the services fill in their first values
        // then, and announcing those would be announcing nothing.
        readonly property int linger: 1600
        readonly property int armDelay: 1200
    }

    // ---- attached surfaces --------------------------------------------------
    //
    // Everything that hangs off the bar the way the dashboard does -- the
    // dashboard, the popouts, the launcher, the power menu -- through
    // `modules/attached/AttachedDrawer.qml`. Each keeps its own width and
    // corner; these are what they share.
    readonly property QtObject attached: QtObject {
        // `0 34px 60px -30px rgba(0,0,0,.75)`, cast away from the bar and cut
        // off at its face, so it darkens what is under the drawer and never
        // the bar it hangs from.
        readonly property int shadowOffset: 34
        readonly property int shadowBlur: 60
        readonly property int shadowSpread: -30
        readonly property real shadowAlpha: 0.75
        // The content fading with its drawer as it opens and closes.
        readonly property int fade: root.reduceMotion ? root.anim.fast : root.scaled(300)
        // How far the drawer paints over the bar's face at the join, so the
        // seam between the two windows is never the bar's own edge.
        readonly property int bridge: 2
    }

    // ---- dashboard ----------------------------------------------------------
    //
    // The dashboard: a drawer attached to the bar's inner edge. "Top" values
    // serve a horizontal bar (top or bottom), "side" ones a vertical bar (left
    // or right); the side layout reflows rather than squashing the top one, so
    // the two sets differ in more than width.
    readonly property QtObject dashboard: QtObject {
        // Across the bar: fixed. Along it: the tab strip plus the tab.
        readonly property int widthTop: 780
        readonly property int widthSide: 420
        readonly property int stripHeight: 58
        // Far corners, and the concave fillets where the drawer meets the bar.
        // One value, so the curve runs on without a step.
        readonly property int radius: Math.round(28 * root.radiusScale)
        readonly property int fillet: root.dashboard.radius

        // Content height per tab, excluding the strip.
        readonly property var heightsTop: ({
                home: 262,
                media: 318,
                system: 262,
                focus: 262
            })
        readonly property var heightsSide: ({
                home: 552,
                media: 612,
                system: 420,
                focus: 448
            })

        // The shadow every attached surface casts (`attached` below).
        readonly property int shadowOffset: root.attached.shadowOffset
        readonly property int shadowBlur: root.attached.shadowBlur
        readonly property int shadowSpread: root.attached.shadowSpread
        readonly property real shadowAlpha: root.attached.shadowAlpha

        // Motion. Open and close resize the drawer along its growth axis, a
        // tab switch morphs it across, and both use the design's
        // cubic-bezier(.3,.9,.2,1). Under reduceMotion nothing travels or
        // morphs; content still fades, briefly.
        //
        // The design's morph, curves and content entrance became the
        // shell's expressive register (`anim`, docs/motion.md), and the
        // drawer takes them from there. What is left here is the dashboard's
        // own: the tab pill, the page fade on close, and how far a tab's
        // content travels in each orientation.
        readonly property var curve: root.anim.emphasized
        readonly property int pill: root.scaled(root.reduceMotion ? 0 : 450)
        readonly property int fade: root.attached.fade
        readonly property int rise: root.anim.riseBy
        readonly property int slide: root.anim.shiftBy
        readonly property int colourFade: root.scaled(300)

        // Tab strip.
        readonly property int tabWidthTop: 116
        readonly property int tabWidthSide: 88
        readonly property int tabHeight: 34
        readonly property int tabInset: 4
        readonly property int tabRailRadius: 21
        readonly property real tabIconTop: 17
        readonly property real tabIconSide: 16
        readonly property real tabLabelTop: 12.5
        readonly property real tabLabelSide: 12

        // Page insets and rhythm.
        readonly property int padTop: 24
        readonly property int padSide: 20
        readonly property int padMedia: 30
        readonly property int padMediaLead: 26
        readonly property int padFocusLead: 34
        readonly property int gap: 8
        readonly property int gapHome: 16
        readonly property int gapHomeSide: 14
        readonly property int gapMedia: 30
        readonly property int gapFocus: 36
        readonly property int gapColumn: 16
        readonly property int cardRadius: Math.round(18 * root.radiusScale)
        readonly property int cardPadV: 13
        readonly property int cardPadH: 15
        readonly property real sectionLabel: 11

        // Home.
        readonly property real greeting: 12
        readonly property real clockTop: 64
        readonly property real clockSide: 56
        readonly property real clockTracking: -0.04
        readonly property real secondsTop: 15
        readonly property real secondsSide: 14
        readonly property int secondsWidth: 22
        readonly property real dateLine: 13
        readonly property real weatherIconTop: 38
        readonly property real weatherIconSide: 32
        readonly property real tempTop: 30
        readonly property real tempSide: 26
        readonly property real weatherNote: 11.5
        readonly property int weatherRule: 48
        readonly property int weatherGap: 22
        readonly property int hourGap: 14
        readonly property real hourLabel: 10
        readonly property real hourIcon: 17
        readonly property real hourValue: 11
        readonly property int timelinePadV: 14
        readonly property int timelinePadH: 18
        readonly property int timelinePadBottom: 10
        readonly property int timelineStart: 8
        readonly property int timelineEnd: 22
        // Today's rolling window: this many whole hours before now's hour,
        // this many in all -- three back and eight or nine ahead.
        readonly property int timelineBefore: 3
        readonly property int timelineSpan: 12
        readonly property int trackHeight: 30
        readonly property int trackLine: 2
        readonly property int eventHeight: 24
        readonly property int eventRadius: Math.round(8 * root.radiusScale)
        readonly property int eventMin: 8
        readonly property int eventPad: 7
        readonly property real eventLabel: 10.5
        // An event block narrower than this share of the day draws no label.
        readonly property real eventLabelMin: 0.034
        readonly property int nowLine: 2
        readonly property int nowOverhang: 2
        readonly property int nextDot: 6
        readonly property int hourRow: 14
        readonly property int agendaRow: 30
        readonly property int agendaRowRadius: Math.round(10 * root.radiusScale)
        readonly property int agendaTime: 38
        readonly property int agendaDotCol: 10
        readonly property int agendaDot: 8
        readonly property int agendaNowDot: 10
        readonly property int agendaSpine: 64
        readonly property int agendaPad: 10
        readonly property real agendaTitle: 12.5

        // Media.
        readonly property int discBox: 256
        readonly property int cover: 176
        readonly property int spindle: 24
        readonly property int spindleRing: 4
        readonly property int grooveEvery: 4
        readonly property int bars: 56
        readonly property int barRadius: 104
        readonly property int barWidth: 3
        readonly property int barHeight: 22
        readonly property real barMin: 0.16
        readonly property int spinPeriod: 14000
        readonly property real trackTitleTop: 24
        readonly property real trackTitleSide: 22
        readonly property real trackArtist: 13
        readonly property int scrub: 4
        readonly property int scrubKnob: 12
        readonly property int controlsGap: 20
        readonly property real controlSmall: 19
        readonly property real controlIcon: 26
        readonly property int playSize: 52
        readonly property int playRadius: Math.round(18 * root.radiusScale)

        // System.
        readonly property int ringTop: 96
        readonly property int ringSide: 84
        readonly property int ringStrokeTop: 7
        readonly property int ringStrokeSide: 6
        readonly property real ringValueTop: 20
        readonly property real ringValueSide: 17
        readonly property real ringUnitTop: 11
        readonly property real ringUnitSide: 10
        readonly property real ringLabelTop: 13
        readonly property real ringLabelSide: 12
        readonly property int ringValueMs: root.scaled(root.reduceMotion ? 0 : 900)
        readonly property int ringGap: 14
        readonly property int ringPad: 12
        // The AI tools' cards under the rest (`AiCards.qml`): a header, then
        // one small ring per plan window, as many to a row as fit. Every
        // size is fixed so the drawer can work out the cards' height before
        // they exist -- `aiCardHeight` is the one formula both use.
        readonly property int aiRing: 58
        readonly property int aiStroke: 6
        readonly property real aiValue: 15
        readonly property real aiUnit: 9
        readonly property int aiMeter: 160
        // Three or more windows to a half card: the label under the ring
        // instead of beside it, so they still fit on one row.
        readonly property int aiStackWidth: 96
        readonly property int aiStackHeight: 96
        readonly property int aiMeterGap: 10
        readonly property int aiColumnGap: 12
        readonly property int aiRowGap: 10
        readonly property int aiHeader: 36
        readonly property int aiHeaderGap: 12
        readonly property int aiBadge: 30
        readonly property int aiBadgeRadius: Math.round(9 * root.radiusScale)
        readonly property real aiName: 14
        // The updates line under the rest of the System tab (`SystemTab.qml`),
        // there once the update check has answered.
        readonly property int updatesHeight: 44
        function aiColumns(cardWidth: real, stacked: bool): int {
            const inner = cardWidth - 2 * root.dashboard.cardPadH;
            const meter = stacked ? root.dashboard.aiStackWidth : root.dashboard.aiMeter;
            return Math.max(1, Math.floor((inner + root.dashboard.aiColumnGap) / (meter + root.dashboard.aiColumnGap)));
        }
        function aiCardHeight(rows: int, stacked: bool): int {
            const n = Math.max(1, rows);
            const row = stacked ? root.dashboard.aiStackHeight : root.dashboard.aiRing;
            return 2 * root.dashboard.cardPadV + root.dashboard.aiHeader + root.dashboard.aiHeaderGap + n * row + (n - 1) * root.dashboard.aiRowGap;
        }
        // Whether the cards stack their labels: when a card has more windows
        // than fit beside their rings on one row.
        function aiStacked(tools: var, cardWidth: real): bool {
            const beside = root.dashboard.aiColumns(cardWidth, false);
            return tools.some(t => t.windows.length > beside);
        }
        function aiRows(tool: var, cardWidth: real, stacked: bool): int {
            const n = tool.windows.length;
            return n === 0 ? 1 : Math.ceil(n / root.dashboard.aiColumns(cardWidth, stacked));
        }
        readonly property int historyHeight: 58
        readonly property int historyGap: 2
        readonly property int historyRadius: 2
        readonly property real historyFloor: 0.04
        readonly property real historyOldest: 0.25
        readonly property real historyNewest: 0.8
        readonly property real historyShare: 1.7
        readonly property int procNameTop: 74
        readonly property int procNameSide: 84
        readonly property int procValue: 30
        readonly property int procBar: 4
        // A process bar is full at this share of the machine, or at the
        // busiest one if that is more.
        readonly property real procFull: 40

        // Focus.
        readonly property int focusRing: 188
        readonly property int focusStroke: 6
        readonly property real focusTime: 40
        readonly property real focusState: 11.5
        readonly property real sessionLabel: 14
        readonly property int dot: 8
        readonly property int dotCurrent: 22
        readonly property int dotGap: 5
        readonly property int chipHeight: 28
        readonly property int chipPad: 13
        readonly property int chipInset: 3
        readonly property int chipRailRadius: 18
        readonly property int buttonHeight: 38
        readonly property int buttonPad: 18
        readonly property real buttonLabel: 12.5
        readonly property real buttonIcon: 18
        readonly property int toggleWidth: 42
        readonly property int toggleHeight: 24
        readonly property real toggleTitle: 12.5
        readonly property real toggleNote: 11
        readonly property int toggleGap: 12

        // Shared rhythm inside the tabs.
        readonly property int pageTopGap: 2
        readonly property int stackGap: 6
        readonly property int metaGap: 4
        readonly property int subGap: 2
        readonly property int cardGap: 10
        readonly property real smallText: 12
        readonly property real disabledOpacity: 0.38
        // Extra reach around a bare glyph that acts as a button.
        readonly property int hitSlop: 6
        readonly property var linear: [0, 0, 1, 1, 1, 1]

        // Home, continued.
        readonly property int clockGap: 10
        readonly property int homeRowGap: 24
        readonly property int weatherIconGap: 12
        readonly property int tempNoteGap: 5
        readonly property int weatherNoteMax: 220
        readonly property int dayNoteMax: 360
        readonly property real ruleAlpha: 0.08
        readonly property real elapsedAlpha: 0.35
        // Upcoming events are tinted by calendar: primary for work, tertiary
        // for personal (Calendar's per-source role).
        readonly property real eventTint: 0.1
        readonly property int nowMove: root.scaled(root.reduceMotion ? 0 : 1000)
        readonly property int weatherCardPadV: 14
        readonly property int weatherCardPadH: 16
        readonly property int weatherCardGap: 14
        readonly property int agendaPadTop: 12
        readonly property int agendaPadBottom: 10
        readonly property int agendaPadH: 8
        readonly property int agendaGap: 6
        readonly property int agendaRowGap: 2
        readonly property int agendaCols: 12
        readonly property int agendaSpineInset: 10
        readonly property int agendaSpineWidth: 2
        readonly property real spineAlpha: 0.06

        // Home's month (MonthFold), folded out under the day. The card's
        // height in each layout is fixed, so the drawer knows what it grows
        // by before anything is laid out; a month always draws six weeks.
        readonly property int foldTop: 246
        readonly property int foldSide: 300
        // Below the month on a top drawer: the card gap again, where the day
        // card alone sits close to the drawer's edge.
        readonly property int foldTail: 10
        readonly property int foldPadV: 14
        readonly property int foldPadH: 18
        readonly property int foldPadHSide: 16
        readonly property int foldGap: 18
        readonly property int foldStack: 8
        readonly property int foldMonthWidth: 252
        readonly property int foldHeaderGap: 6
        readonly property real foldMonth: 13
        readonly property int foldPill: 26
        readonly property real foldChevron: 18
        readonly property int foldCell: 22
        readonly property int foldCellSide: 26
        readonly property int foldCellRadius: Math.round(8 * root.radiusScale)
        readonly property real foldDay: 11
        readonly property real foldWeekday: 9.5
        readonly property int foldSyncGap: 7
        readonly property real foldSyncIcon: 14
        readonly property real foldCaption: 10.5
        readonly property int foldChipGap: 6
        // Calendars named in the month's legend before the rest are counted.
        readonly property int foldChipsTop: 3
        readonly property int foldChipsSide: 3
        readonly property int foldRow: 28
        readonly property int foldRowGap: 2
        readonly property int foldSpineInset: 6
        // The event form (EventForm) that takes the day list's place.
        readonly property int formGap: 8
        readonly property int formField: 30
        readonly property int formRadius: Math.round(9 * root.radiusScale)
        readonly property int formPad: 10
        readonly property real formText: 12.5
        readonly property int formTime: 64
        // How far a clickable event's hover reaches past its row, and the
        // glyph on one that cannot be changed here.
        readonly property int formRowBleed: 6
        readonly property real formLock: 13
        // The arrow on the day card that folds it out, and its turn.
        readonly property real foldArrow: 18
        readonly property int foldTurn: root.reduceMotion ? 0 : root.anim.normal

        // Media, continued.
        readonly property real barOpacity: 0.85
        readonly property real barOpacityDim: 0.6
        readonly property real grooveAlpha: 0.07
        readonly property real spindleRingAlpha: 0.5
        readonly property int scrubGap: 7
        readonly property int deviceGap: 7
        readonly property real deviceIcon: 16
        readonly property int deviceMax: 180

        // System, continued.
        readonly property int ringPadSide: 6
        readonly property int unitGap: 1
        readonly property real procName: 12
        readonly property int historyMove: root.scaled(root.reduceMotion ? 0 : 600)
        readonly property int procMove: root.scaled(root.reduceMotion ? 0 : 800)

        // Focus, continued.
        readonly property int focusTick: 1000
        readonly property real focusTracking: -0.03
        readonly property int sessionGap: 14
        readonly property int dotMove: root.scaled(root.reduceMotion ? 0 : 400)
        readonly property real chipLabel: 11.5
        readonly property int chipMove: root.scaled(root.reduceMotion ? 0 : 250)

        // Bar clock: the pill it wears while the drawer is open.
        readonly property int clockPillPad: 12
        readonly property int clockPillHeight: 28
        readonly property int clockPillPadV: 6
        readonly property int clockPillRadius: Math.round(10 * root.radiusScale)
    }

    // ---- launcher ---------------------------------------------------------
    readonly property QtObject launcher: QtObject {
        // 580 is the design's *content* box -- its panel is a content-box div, so
        // the 8px padding falls outside the authored width. Reading 580 as the
        // outer width costs every row 16px.
        readonly property int contentWidth: 580
        readonly property int searchHeight: 54
        readonly property int searchPadding: 15
        readonly property int searchGap: 13
        readonly property int dividerInset: 6
        readonly property int listInset: 6
        readonly property int listTop: 8
        readonly property int listBottom: 6
        readonly property int rowGap: 2
        readonly property int rowHeight: 48
        readonly property int tile: 30
        readonly property int tileGap: 13
        readonly property int footerInset: 12
        readonly property int footerGap: 16
        readonly property int footerTop: 2
        readonly property int footerBottom: 6
        readonly property int ruleInset: 8
        readonly property int ruleGap: 6
        // 2, not the design's 1.5: a half-pixel rule lands on a seam at 1x.
        readonly property int caretWidth: 2
        readonly property int caretHeight: 17
        // Where the panel's top sits in the height the bar leaves free.
        readonly property real topFraction: 132 / 850
    }

    // ---- overlays ---------------------------------------------------------
    //
    // The window picker, the clipboard, capture, sessions and what-changed.
    // Five surfaces rather than five groups, because they share a shape -- a
    // drawer-elevation panel of a fixed width, padded 20, its sections 18
    // apart and its cards 14 -- and only their contents differ.
    //
    // Everything here was measured off the design. Radii and gaps that already
    // had a name (`radius.drawer` 26, `radius.cardXl` 20, `radius.cardLg` 18,
    // `radius.tile` 16, `radius.chip` 12, `space.*`) are NOT repeated; only the
    // values the rest of the shell had no reason to carry are.
    readonly property QtObject overlays: QtObject {

        // ---- shared ---------------------------------------------------------

        // The window picker, sessions and what-changed are the same panel with
        // different contents: a drawer padded 20, its blocks 18 apart, its grid
        // cells 14, and a header whose glyph sits 14 from its title.
        readonly property int blockGap: 18
        readonly property int cardGap: 14
        readonly property int headerGap: 14
        // Both card grids -- the window picker's and the sessions panel's --
        // are three across. One value, because they are the same grid.
        readonly property int columns: 3

        // A selected card is bordered *and* haloed: `0 0 0 6px` of a very dilute
        // primary, which is a ring rather than a glow -- it does not blur, so it
        // is drawn as a second rectangle and not as a shadow.
        readonly property int selectedBorder: 2
        readonly property int halo: 6
        readonly property real haloAlpha: 0.1
        // The sessions panel draws the same ring a shade quieter behind its
        // larger cards.
        readonly property real haloAlphaSoft: 0.09
        // Where a panel's top sits in the design's 850px frame, as a proportion,
        // so the same screen lands in the same place on a display that is not
        // 850 tall. The picker sits highest, the clipboard next, then
        // what-changed and sessions.
        readonly property real topPicker: 92 / 850
        readonly property real topClipboard: 120 / 850
        readonly property real topChanges: 118 / 850
        readonly property real topSessions: 132 / 850
        // A section heading in a card, a hint strip, the small glyph beside a
        // banner's title: sizes the ramp in `size` has no reason to carry.
        readonly property real iconBanner: 20
        readonly property real iconToolbar: 19

        // ---- clipboard ------------------------------------------------------
        readonly property QtObject clipboard: QtObject {
            // 940x600, fixed. The design's panel is a border-box div, so unlike
            // the launcher's these are the outer measurements and the 8px
            // padding falls inside them.
            readonly property int width: 940
            readonly property int height: 600
            readonly property int padding: 8
            // The split: list, a one-pixel rule, and the preview takes the rest.
            readonly property int listWidth: 470

            readonly property int searchHeight: 52
            readonly property int searchPadding: 14
            readonly property int searchGap: 13
            readonly property int dividerInset: 6

            readonly property int listPadV: 8
            readonly property int listPadH: 6
            readonly property int listGap: 2

            // A row is 44, except one carrying a thumbnail and a second line.
            readonly property int rowHeight: 44
            readonly property int rowHeightRich: 52
            readonly property int rowPadding: 11
            readonly property int rowGap: 11
            // The image thumbnail and the colour swatch, both leading slots.
            readonly property int thumbnail: 34
            readonly property int swatch: 18
            readonly property int swatchRadius: 6

            // A section heading pads 10 at the sides, 4 under, and 10 over --
            // except the first, which only needs 6 because the rule above it
            // already spaces it.
            readonly property int sectionPadding: 10
            readonly property int sectionTop: 10
            readonly property int sectionTopFirst: 6
            readonly property int sectionBottom: 4

            readonly property int footerHeight: 42
            readonly property int footerPadding: 14
            readonly property int footerGap: 16
            // Clear all, at the footer's far end, and how long its "Clear 24
            // items?" waits for the second press.
            readonly property int clearHeight: 26
            readonly property int clearConfirm: 3000

            readonly property int previewGap: 14
            readonly property int metaGap: 7
            readonly property int actionHeight: 34
            readonly property int actionGap: 8
            // The two icon-only actions beside Paste.
            readonly property int actionIcon: 44
        }

        // ---- capture --------------------------------------------------------
        readonly property QtObject capture: QtObject {
            // 1.5px, and it stays 1.5: a selection edge is the one rule in the
            // shell drawn over live content rather than over a panel, and at 2px
            // it eats a pixel of what is about to be captured. `real`, because a
            // fractional literal in an `int` property is a hard load error.
            readonly property real border: 1.5
            readonly property int radius: 4
            readonly property int handle: 11
            // A dilute primary bloom outside the selection. This one *is* blurred.
            readonly property int glow: 40
            readonly property real glowAlpha: 0.2
            // Below this the selection is treated as a click, not a drag.
            readonly property int minimum: 8

            readonly property int badgeHeight: 26
            readonly property int badgePadding: 11
            readonly property int badgeGap: 14

            readonly property int toolbarPadding: 8
            readonly property int toolbarGap: 4
            readonly property int toolbarRadius: 22
            // How far the toolbar floats below the selection.
            readonly property int toolbarOffset: 28
            readonly property int buttonHeight: 44
            readonly property int buttonRadius: 15
            readonly property int buttonPadding: 15
            // The one filled verb is a pixel wider on each side than the rest.
            readonly property int buttonPaddingFilled: 16
            readonly property int buttonGap: 8
            readonly property int dividerHeight: 26
            readonly property int dividerMargin: 4

            // The recording chip, top right, error-tinted.
            readonly property int chipHeight: 38
            readonly property int chipPadding: 15
            readonly property int chipGap: 11
            readonly property int chipRadius: 19
            readonly property int chipDot: 8
            readonly property int chipDivider: 16
        }

        // ---- window picker --------------------------------------------------
        readonly property QtObject picker: QtObject {
            readonly property int width: 1080
            // Where it comes forward from as it opens (components/Reveal).
            readonly property real enterScale: 0.96
            // 168, and this one is NOT the content-box trap `navWidth` fell
            // into. Five of the design's six thumbnails declare `height:168px`
            // and then add 10-12px of padding, which renders 188 and is what
            // made this look like the same mistake -- but that padding is
            // inside the fake window contents each one is drawn with. The
            // sixth has no contents, just a gradient, and renders 168 flat.
            // The frame is 168; the padding belongs to what is drawn in it.
            readonly property int thumbnail: 168
            readonly property int footerPadV: 11
            readonly property int footerPadH: 13
            readonly property int footerGap: 10
            readonly property int keycapRadius: 7
            readonly property int keycapPadV: 3
            readonly property int keycapPadH: 7
            // The caret after the filter string, as on the launcher: 2, not the
            // design's 1.5, because a half-pixel rule lands on a seam at 1x.
            readonly property int caretWidth: 2
            readonly property int caretHeight: 17
            // The All / This monitor rail is smaller than any other Segmented in
            // the shell, so it carries its own four numbers.
            readonly property int railRadius: 14
            readonly property int segmentRadius: 12
            readonly property int segmentHeight: 24
            readonly property int segmentPadding: 11
            // The glyph a card falls back to when its window will not capture.
            readonly property real placeholder: 34
            // The recording dot in a card's footer.
            readonly property int dot: 6
            readonly property int hintGap: 18
            // Not in the design, which draws six windows. A real session can
            // hold thirty, and a picker that runs off the bottom of the screen
            // is not a picker; the rest are counted in the footer.
            readonly property int maximum: 12
        }

        // ---- sessions ---------------------------------------------------------
        readonly property QtObject sessions: QtObject {
            readonly property int width: 980
            readonly property int cardPadding: 14
            readonly property int cardGap: 12
            // The mini layout diagram.
            readonly property int diagram: 132
            readonly property int diagramRadius: 13
            readonly property int diagramPadding: 9
            readonly property int diagramGap: 6
            readonly property int tileRadius: 7
            // A session's name, between `size.body` and `size.subheading` and in
            // neither -- the design's one 14px string.
            readonly property real nameSize: 14
            // The name sits 3 above its contents line -- tighter than any gap
            // in `space`, because the two are one block.
            readonly property int metaGap: 3
            readonly property int dot: 5
            readonly property int actionHeight: 30
            readonly property int actionRadius: 15
            readonly property int actionGap: 7
            readonly property int actionMore: 38
            readonly property int chipHeight: 32
            readonly property int chipPadding: 14
            readonly property int chipGap: 9
            readonly property int chipRadius: 16
            // "Save current" pads a pixel wider than the login chip does.
            readonly property int savePadding: 15
            readonly property int toggleWidth: 36
            readonly property int toggleHeight: 20
        }

        // ---- what changed -----------------------------------------------------
        readonly property QtObject changes: QtObject {
            readonly property int width: 880
            readonly property int blockGap: 16
            readonly property int cardGap: 12
            readonly property int bannerPadV: 14
            readonly property int bannerPadH: 16
            readonly property int bannerGap: 13
            readonly property int buttonHeight: 32
            readonly property int buttonPadding: 15
            readonly property int buttonRadius: 16
            readonly property int noteGap: 11
            readonly property int rowGap: 7
            // How much of the routine list is shown before "Show all N", and
            // the ceiling "Show all" itself stops at: the panel sizes to its
            // contents, so an unbounded list would run off the screen.
            readonly property int routineShown: 5
            readonly property int routineMax: 18
        }
    }

    // ---- overview ---------------------------------------------------------
    // The workspace overview, folded in from the module: workspace cards three
    // across, the focused one ringed, the empty ones dashed. As many rows as
    // the workspaces take -- the design's two for the five a session starts
    // with and the card that makes a sixth.
    readonly property QtObject overview: QtObject {
        readonly property int cardWidth: 376
        readonly property int cardHeight: 232
        readonly property int gap: 18
        readonly property int columns: 3
        // The card's own inset, which is also the margin a thumbnail keeps from
        // its edges -- the design's `padding:10` on a position:relative card.
        readonly property int cardPadding: 10
        readonly property int labelLeft: 12
        readonly property int labelTop: 10
        readonly property real labelSize: 11

        // The focused card: a 2px border and a 6px ring at 9% -- a ring, not a
        // glow, so it is a second rectangle rather than a shadow.
        readonly property int focusBorder: 2
        readonly property int halo: 6
        readonly property real haloAlpha: 0.09

        // Three fills off the same panel base. A card is quieter than a panel
        // because the wallpaper, not another surface, is what shows through it.
        readonly property real cardAlpha: 0.6
        readonly property real focusedAlpha: 0.72
        readonly property real emptyAlpha: 0.5
        // The *second* empty card is drawn fainter than the first: the next
        // workspace is one you would plausibly make, the ones past it are not.
        // Opacity rather than a fourth fill, which is how the design does it.
        readonly property real distantOpacity: 0.6

        // The screen behind. Lighter than the power menu's, and unblurred:
        // the overview is about what is on the other workspaces, so the one you
        // are looking at should stay recognisable.
        readonly property real dim: 0.52

        // An empty card's plus and its caption.
        readonly property real emptyIcon: 24
        readonly property int emptyGap: 8
        readonly property real emptyLabelSize: 11.5
        readonly property int dash: 4
        // The dashed outline is a shade brighter than a panel's border: it is
        // the only thing giving an empty card an edge.
        readonly property real emptyBorderAlpha: 0.12

        // The legend, below the grid.
        readonly property int legendGap: 22
        readonly property int legendItemGap: 18
        readonly property real legendSize: 11

        // A window thumbnail keeps the workspace's proportions, so the only
        // metrics it needs of its own are its corner and where the miniature
        // monitor is allowed to sit: clear of the label at the top, and inset
        // from the card's three other edges.
        readonly property int thumbRadius: root.radius.small
        readonly property int thumbTop: 34
        readonly property int thumbInset: 18
        // What shows through until a capture arrives, and behind a window that
        // is itself translucent.
        readonly property real thumbAlpha: 0.9
        // A window in the air, on its way to another workspace.
        readonly property real dragOpacity: 0.85
        // Below this, a thumbnail is a smudge -- draw the app's glyph instead.
        readonly property int thumbMinSide: 28
        // How far the cursor travels before a press on a thumbnail stops being
        // a click and becomes a drag.
        readonly property int dragThreshold: 6
        // A dropped window stays where it was let go until Hyprland says where
        // it went, and then moves there. This long at most, if no answer comes.
        readonly property int dropHold: 1000
        // After a window changes size its frozen frame is the old shape, so
        // the thumbnail runs live again for this long: through Hyprland's own
        // resize animation (a `morph`) and a little past it.
        readonly property int recapture: 800
        // One change to the layout is often several events: they are answered
        // with one query, this long after the last.
        readonly property int settle: 40

        // The design's scale, 0.96 to 1, now on the expressive curve and
        // timing (components/Reveal, which holds it at 1 under reduceMotion).
        readonly property real enterScale: 0.96
    }

    // ---- session ----------------------------------------------------------
    // The power menu. Five square buttons, a greeting and a line of context;
    // nothing else on the screen.
    readonly property QtObject session: QtObject {
        // Deeper than the overview's, and blurred by the compositor: this one
        // is a full stop, so what is behind it stops being legible.
        readonly property real dim: 0.72

        readonly property int button: 150
        readonly property int buttonGap: 16
        // Inside a button: glyph, label, key.
        readonly property int buttonContentGap: 14
        // Greeting to context line, and the three blocks to each other.
        readonly property int titleGap: 6
        readonly property int blockGap: 34
        // Around the three blocks, now that they hang off the bar in a drawer
        // of their own rather than floating in the middle of the dim.
        readonly property int padding: 34

        readonly property real greetingSize: 22
        readonly property real contextSize: 13
        readonly property real labelSize: 13
        readonly property real keySize: 10.5
        readonly property real hintSize: 11.5
        readonly property real iconSize: 36

        // Lock is the one button that carries colour, and its border is its own
        // foreground at a fifth. Shut down is error-tinted at the same weights
        // the design uses for a destructive control everywhere else.
        readonly property real accentBorder: 0.2
        readonly property real dangerFill: 0.09
        readonly property real dangerBorder: 0.18
    }

    // ---- keybinds cheatsheet ------------------------------------------------
    // The cheatsheet, super + <. A 1160px drawer 46px from the top, over the
    // power menu's kind of full stop: a 70% dim the compositor blurs.
    readonly property QtObject keybinds: QtObject {
        readonly property real dim: 0.7
        readonly property int width: 1160
        // 46px down the design's 850px frame, as a proportion, like the other
        // overlays' tops.
        readonly property real top: 46 / 850
        // The filter field's text and every row's action.
        readonly property real textSize: 12
        // Header row: the glyph and title, the filter field, "mod is super".
        readonly property int headerGap: 14
        readonly property int filterHeight: 32
        readonly property int filterWidth: 260
        readonly property int filterPad: 14
        readonly property int filterGap: 10
        readonly property int modGap: 7
        // Three columns of cards, filled top to bottom.
        readonly property int columns: 3
        readonly property int columnGap: 12
        readonly property int cardPadding: 15
        readonly property int cardGap: 9
        readonly property int cardHeaderGap: 9
        // One row per bind: its keys in a 158px block, then the action. A card
        // widens the block to its widest chord, up to keysMax, so its actions
        // stay in line; a chord past that pushes only its own action along.
        readonly property int rowHeight: 28
        readonly property int rowGap: 2
        readonly property int rowSpacing: 10
        readonly property int keysWidth: 158
        readonly property int keysMax: 190
        readonly property int keyGap: 4
        readonly property real plusSize: 10
        // The cheatsheet's own keycap: taller and brighter than the launcher's
        // inline `esc`, because here the keys are the content.
        readonly property int keyHeight: 22
        readonly property int keyPad: 7
        readonly property int keyRadius: Math.round(7 * root.radiusScale)
        readonly property real keyAlpha: 0.06
        // Footer: the live count, "Edit in settings", "dismiss esc".
        readonly property int footerGap: 18
        readonly property int footerPad: 2
        readonly property int linkGap: 8
    }

    // ---- wallpaper switcher -----------------------------------------------
    //
    // Measured off the design; anything that already had a name
    // (`radius.drawer` 26, `radius.cardXl` 20, `radius.cardLg` 18,
    // `radius.chip` 12, `space.*`, the type ramp) is not repeated here.
    readonly property QtObject wallpaper: QtObject {

        // ---- the change itself ----------------------------------------------

        // The soft edge of a grow or a wipe, in px: wide enough that the edge
        // reads as light rather than as a cut, narrow enough to stay a shape.
        readonly property int feather: 32

        // ---- the panel ------------------------------------------------------

        // Border-box in the design, unlike the launcher's content-box panel: 1120
        // is the outer width and the 20px padding falls inside it.
        readonly property int width: 1120
        readonly property real topFraction: 96 / 850
        // Between the four blocks -- header, coverflow, panels, filmstrip.
        readonly property int blockGap: 20
        readonly property int headerGap: 14
        // The filter field's caret. Two pixels rather than the design's 1.5 for
        // the same reason the launcher rounds it up: a half-pixel rule lands on
        // a seam at 1x. Duplicated from `launcher` rather than shared.
        readonly property int caretWidth: 2
        readonly property int caretHeight: 17

        // ---- coverflow ------------------------------------------------------
        //
        // 120 / 200 / 360 / 200 / 120, and the two flanks are dimmed rather
        // than blurred -- depth without a decorative effect.
        readonly property int cardGap: 12
        readonly property int centreWidth: 360
        readonly property int centreHeight: 226
        readonly property int nearWidth: 200
        readonly property int nearHeight: 126
        readonly property int farWidth: 120
        readonly property int farHeight: 75
        readonly property real nearOpacity: 0.6
        readonly property real farOpacity: 0.35
        readonly property int nearRadius: 14
        // The selected card is bordered and ringed, the same idiom the
        // workspace overview, the window picker and sessions use for a
        // selection -- a flat ring, never a blurred glow.
        readonly property int centreBorder: 2
        readonly property int halo: 7
        readonly property real haloAlpha: 0.1
        readonly property int centreShadowY: 22
        readonly property int centreShadowBlur: 60

        // The caption over the bottom of the centre card: a gradient scrim so
        // the filename survives a pale photograph.
        readonly property int scrimHeight: 48
        readonly property real scrimAlpha: 0.88
        readonly property int scrimPadH: 14
        readonly property int scrimPadBottom: 11

        // ---- the two panels below -------------------------------------------
        readonly property int panelGap: 14
        readonly property int paletteGap: 13
        readonly property int swatchGap: 7
        readonly property int swatchHeight: 38
        readonly property int swatchRadius: 10
        readonly property int swatchLabelGap: 5
        // A six-character hex is the smallest literal in the shell and the one
        // place the type ramp does not reach.
        readonly property real hexSize: 9.5
        readonly property int actionGap: 10
        readonly property int actionHeight: 30
        // The light / dark / auto choice in the palette panel's header.
        readonly property int modeHeight: 26

        // ---- the bar miniature ----------------------------------------------
        //
        // A schematic, not a scale model, and deliberately: the bar is 58px on
        // a 1360px screen, which at this size would be under one pixel. The
        // design draws it as blocks at its own proportions. What is live about
        // it is everything that is not a size -- which edge the bar is on
        // (`Config.bar.position`), how many workspace pills there are and which
        // one is active, and the six colours the palette would generate.
        readonly property int previewWidth: 236
        readonly property int previewGap: 12
        readonly property int previewRadius: 14
        readonly property int miniMargin: 8
        readonly property int miniThickness: 26
        readonly property int miniPadding: 6
        readonly property int miniGap: 6
        readonly property int miniTile: 16
        readonly property int miniTileRadius: 6
        readonly property int miniPillCross: 14
        readonly property int miniPill: 10
        readonly property int miniPillActive: 17
        readonly property int miniPillRadius: 4
        readonly property int miniItem: 3
        readonly property int miniItemRadius: 2
        // The gap between the rail and the window mock-up beside it, and the
        // gutter that mock-up keeps from the far edges.
        readonly property int miniLead: 10
        readonly property int miniGutter: 10
        readonly property int miniTitleWidth: 88
        readonly property int miniTitleHeight: 9
        readonly property int miniTitleRadius: 5
        readonly property int miniContentGap: 9
        readonly property int miniContentRadius: 10

        // ---- filmstrip -------------------------------------------------------
        readonly property int stripGap: 8
        readonly property int stripHeight: 62
        readonly property int stripRadius: 11
        readonly property real stripOpacity: 0.85
        // The "+N" tile is fixed where the thumbnails flex.
        readonly property int stripMoreWidth: 78
        readonly property int stripMoreGap: 3
        readonly property real stripMoreSize: 10
        readonly property int stripShown: 8
        readonly property real dashOn: 4
        readonly property real dashOff: 3
    }

    // ---- calendar ---------------------------------------------------------
    //
    // The old floating calendar's pieces that outlived its window: the month
    // grid's defaults (MonthGrid), and the source chips and event spines of
    // Home's month (modules/dashboard/MonthFold.qml, whose own sizes are
    // `dashboard.fold*`).
    readonly property QtObject calendar: QtObject {
        readonly property int chipGap: 7
        readonly property int chipDot: 7

        // ---- month grid ------------------------------------------------------
        readonly property int gridGap: 3
        readonly property int cellHeight: 30
        readonly property int cellRadius: 10
        readonly property real weekdaySize: 10
        // The dot under a day that has something on it, and the gap it keeps
        // from the bottom of its cell.
        readonly property int markDot: 3
        readonly property int markDotGap: 1

        // ---- events ----------------------------------------------------------
        readonly property int spineWidth: 3
        readonly property int spineRadius: 2
    }

    // ---- dock -------------------------------------------------------------
    readonly property QtObject dock: QtObject {
        readonly property int tile: 52
        readonly property int tileHover: 68
        readonly property int tileNear: 60
        readonly property int tileFar: 56
        readonly property int gap: 8
        readonly property int padding: 8
        readonly property int runningDot: 4

        // ---- folded in from the dock module ------------------------------

        // The design pads `8px 10px`: a dock is wider than it is tall, so its end
        // caps are wider than its lid.
        readonly property int padAlong: 10
        // Tile to running dot.
        readonly property int dotGap: 5
        // The dock is an overlay, so it keeps the overlay margin from the edge.
        readonly property int margin: root.space.overlayMargin - 4

        readonly property int dividerLength: 44
        readonly property int dividerGap: 4
        // A rule between two kinds of thing, a shade brighter than a panel's
        // border because it has to read against the dock's own fill.
        readonly property real dividerAlpha: 0.12
        // The divider is a rule between tiles, not between columns: it stops
        // level with the tiles rather than running down past their dots.
        readonly property int dividerLift: 9

        // Magnification is four discrete steps, not a curve -- the hovered item,
        // its neighbours, their neighbours, and everything else. Each step has
        // its own glyph size and corner in the design, so they are listed rather
        // than derived: 52/16/23, 56/17/25, 60/18/26, 68/20/30.
        readonly property real iconTile: 23
        readonly property real iconFar: 25
        readonly property real iconNear: 26
        readonly property real iconHover: 30

        // `distance` is how many items away from the one under the cursor, or
        // -1 for none. Stated as functions because the dock lays the row out
        // from the same numbers the tile draws itself at, and two copies of the
        // table would be two chances to disagree.
        function sideAt(distance: int): int {
            return distance === 0 ? root.dock.tileHover : distance === 1 ? root.dock.tileNear : distance === 2 ? root.dock.tileFar : root.dock.tile;
        }

        function glyphAt(distance: int): real {
            return distance === 0 ? root.dock.iconHover : distance === 1 ? root.dock.iconNear : distance === 2 ? root.dock.iconFar : root.dock.iconTile;
        }

        // 52 -> 16, 56 -> 17, 60 -> 18, 68 -> 20. One line reproduces all four
        // and keeps following the settings screen's corner-radius slider.
        function tileRadius(side: int): int {
            return Math.round((side + 12) / 4 * root.radiusScale);
        }

        // The count badge on a stack.
        readonly property int badge: 18
        readonly property int badgeOffset: 3
        readonly property int badgePadding: 5
        readonly property real badgeSize: 10

        // The hover label above the dock. Its corner is a pixel rounder than
        // `radius.small`, which is the one place the design parts company with
        // the chip radius.
        readonly property int tipRadius: Math.round(10 * root.radiusScale)
        readonly property int tipHeight: 28
        readonly property int tipPadding: 12
        readonly property real tipSize: 11.5
        // The label sits nearly opaque -- it is a word over a window, not a
        // surface. Added to the user's panel opacity the way `Panel` adds its
        // own, so the settings slider still moves it with everything else.
        readonly property real tipBoost: 0.13
        // Tooltip and stack panel both float this far above the dock.
        readonly property int lift: 13

        // The stack panel.
        readonly property int stackWidth: 336
        readonly property int stackPadding: 14
        readonly property int stackGap: 12
        readonly property int stackColumns: 3
        readonly property int stackCellGap: 8
        readonly property int stackCellPadding: 10
        readonly property int stackCellInnerGap: 7
        readonly property real stackCellIcon: 20
        readonly property real stackNameSize: 11
        readonly property real stackTimeSize: 9.5
        readonly property int stackHeaderGap: 10
        readonly property real stackHeaderIcon: 18
        readonly property int stackFooterHeight: 30
        // How long "Empty" waits, after asking, for the second click.
        readonly property int confirmWindow: 3000
        readonly property int stackToggleHeight: 24
        readonly property int stackToggleRail: 14
        // A list row in the stack panel is shorter than the shell's standard 40:
        // the panel is 336 wide and six of them have to fit above a dock.
        readonly property int stackRowHeight: 34

        // Autohide. The design's timing: 200ms slide in, gone 400ms after the
        // cursor leaves. The strip is two pixels rather than one for the reason
        // `bar.revealStrip` gives -- a scaled output rounds one away.
        readonly property int revealStrip: 2
        readonly property int hideDelay: 400
        // How often a stack's folder is re-read while the dock is on screen.
        // A poll rather than a motion duration: `FileView` watches files, not
        // directories, and inotify is not exposed to QML.
        readonly property int refreshInterval: 30000
        readonly property int duration: root.scaled(root.reduceMotion ? 100 : 200)
    }

    // ---- settings ---------------------------------------------------------
    // Everything measured off the design's Appearance and Bar pages. The
    // settings window is an application rather than a shell surface, so it
    // carries its own metrics ramp: a 13px row title and a 12px numeral sit
    // between the shell's body (12.5) and label (11.5) sizes, and neither
    // exists anywhere else.
    readonly property QtObject settings: QtObject {
        // Fixed, on both pages. The 242px nav and the two-column rows beside it
        // are designed against this width; reflowing it is a different screen.
        readonly property int windowWidth: 1020
        readonly property int windowHeight: 706

        // `0 30px 80px rgba(0,0,0,.55)` -- deeper than a panel, shallower than
        // the drawer, because the window floats over the whole desktop.
        readonly property int shadowY: 30
        readonly property int shadowBlur: 80
        readonly property real shadowAlpha: 0.55

        // ---- nav sidebar ---------------------------------------------------
        // 262, not the 242 the design declares: that rule is content-box, so
        // its 10px of horizontal padding sits outside the number and the
        // sidebar renders 263 wide including its 1px edge. Same class of
        // mistake as the workspace pill, the launcher row and the clock --
        // read the rendered box, not the declared width.
        readonly property int navWidth: 262
        readonly property int navPadV: 14
        readonly property int navPadH: 10
        readonly property int navGap: 2
        readonly property int navItemHeight: 38
        readonly property int navItemPad: 14
        // "Shell settings": `padding: 8px 12px 14px`.
        readonly property int navTitlePadH: 12
        readonly property int navTitleTop: 8
        readonly property int navTitleBottom: 14
        // The window's close button, at the end of that line: a round 28,
        // a size under the pane's own actions.
        readonly property int closeSize: 28
        readonly property real closeIcon: 18

        // Settings, Keybinds. A bind's keys are a button that records new
        // ones: keycaps inside an outline, wide enough for "super + ctrl +
        // shift + 1–9" and for the prompt that replaces them while it listens.
        readonly property int bindKeysHeight: 30
        readonly property int bindKeysWidth: 196
        readonly property int bindKeysPad: 6
        readonly property int bindKeyGap: 4
        readonly property int bindKeysRadius: Math.round(9 * root.radiusScale)
        // The round icon buttons after it: back to the default, off, delete.
        readonly property int bindActionSize: 28
        readonly property real bindActionIcon: 17
        readonly property int bindRowGap: 10
        // Your own binds: the name and the command, side by side.
        readonly property int bindNameWidth: 150
        readonly property int bindFilterWidth: 240

        // ---- content pane --------------------------------------------------
        readonly property int panePadV: 26
        readonly property int panePadH: 30
        readonly property int paneGap: 22
        // Section label to the card under it.
        readonly property int sectionGap: 9
        // The Appearance page pads its cards 18 and spaces their rows 16; the
        // Bar page pads 16 (`space.panelPadding`) and spaces 14. Both are here
        // because a card that guessed would be wrong on one of the two pages.
        readonly property int cardPadding: 18
        readonly property int cardGap: 16
        // The Appearance page's second card, which carries three sliders rather
        // than three rows of prose, opens its rows up a further two pixels.
        readonly property int cardGapWide: 18
        readonly property int cardGapTight: 14
        // A row and the control at the end of it.
        readonly property int rowGap: 20
        readonly property int rowGapTight: 14
        // The label column: 180 on the Appearance page's sliders, 170 on the
        // Bar page's.
        readonly property int labelWidth: 180
        // Settings, Appearance, Motion: the speed slider's range and step,
        // as multiples of the designed pace; and a row that cannot be used.
        readonly property real speedMin: 0.5
        readonly property real speedMax: 3
        readonly property real speedStep: 0.25
        readonly property real disabledOpacity: 0.38
        readonly property int labelWidthNarrow: 170
        // Title over subtitle, which are set solid except in the wallpaper
        // block -- the one place the design opens them up.
        readonly property int labelGap: 3
        // The right-aligned numeral: "22 px", "84 %", "120 ms".
        readonly property int valueWidth: 56
        readonly property int valueWidthNarrow: 54

        readonly property real rowTitleSize: 13
        readonly property real valueSize: 12
        readonly property real actionSize: 12
        readonly property int actionHeight: 32
        // Reload / Reset / Apply: `0 15px`, which is Pill's own default at 32.
        readonly property int segmentHeight: 26
        readonly property int segmentPad: 13
        // 16x16, round -- the settings window's slider handle is the largest of
        // the three the design draws.
        readonly property real sliderHandle: 16
        // The dashboard's tab strip (116 x 34, 4 round it) a size down, to sit
        // inside a card: On power / On battery above a laptop's idle timeouts,
        // Floating / Attached under the bar's position.
        readonly property int tabWidth: 112
        readonly property int tabHeight: 28
        readonly property int tabInset: 3
        readonly property int tabRailRadius: 17
        readonly property real tabIcon: 15
        readonly property real tabLabel: 12

        // ---- the wallpaper preview block -----------------------------------
        readonly property int previewWidth: 110
        readonly property int previewHeight: 68
        readonly property int previewGap: 14
        readonly property int swatch: 12
        readonly property int swatchGap: 4
        // A calendar's colour choice on the Calendars page: a dot inside the
        // ring that marks the chosen one.
        readonly property int calendarSwatch: 22
        readonly property int calendarSwatchGap: 6
        readonly property int calendarSwatchRing: 2
        // The star on the calendar new events go to.
        readonly property int calendarStar: 20
        // How long a Remove waits for its second press.
        readonly property int confirmWindow: 4000
        readonly property int swatchInset: 8

        // ---- the four monitor diagrams -------------------------------------
        readonly property int monitorHeight: 74
        readonly property int monitorGap: 12
        readonly property int monitorLabelGap: 8
        // A drawing of a monitor, so its corner is a property of the drawing
        // rather than of the shell's shape language: it does not scale with the
        // radius slider, or choosing a 0px radius would square the diagram that
        // is meant to be showing where the bar goes.
        readonly property int monitorRadius: 11
        readonly property int monitorInset: 7
        readonly property int monitorBar: 9
        readonly property int monitorBarRadius: 5
        readonly property int monitorBorder: 1
        readonly property int monitorBorderSelected: 2

        // ---- the pinned & stacks list --------------------------------------
        readonly property int tile: 38
        readonly property int tileGap: 7
        readonly property real tileIcon: 19
        readonly property real tileIconSmall: 17
        readonly property int tileRadius: Math.round(13 * root.radiusScale)
        // The rule between the apps and the stacks.
        readonly property int listDivider: 26
        readonly property int listDividerGap: 2
        readonly property real hintSize: 11
        // Not in the design, which draws the square that adds a stack but
        // not what it opens. A folder has to be chosen from somewhere, and a
        // list of the ones in $HOME is the smallest honest answer.
        readonly property int pickerWidth: 232
        readonly property int pickerRows: 7
        readonly property int pickerRowHeight: 34

        // ---- ranges --------------------------------------------------------
        // The corner-radius slider is in pixels, not in the multiplier the
        // config stores: the design's Appearance page reads "22 px" with its
        // fill at 55%, and 22/40 is exactly 0.55, so the scale runs 0 to 40
        // and the default sits where the design draws it.
        readonly property int radiusBase: 22
        readonly property int radiusMax: 40
        // Reveal delay, 0 to half a second in 10ms steps. The design draws 120ms
        // at 22% of the track, which no round maximum reproduces exactly; 500
        // is the defensible one and puts it at 24%.
        readonly property int revealMax: 500
        readonly property int revealStep: 10

        // Slider drags write `Config` on every frame so the shell moves under
        // the cursor, but shell.json is watched by the FileView that serves it
        // -- writing on every frame would reload the config twenty times a
        // second. The write is coalesced this far behind the last change.
        readonly property int saveDebounce: 250

        // ---- the pages the design names but does not draw -------------------
        //
        // General, Notifications, Launcher, Lock screen and Modules are built
        // from the Appearance and Bar pages' own parts; these are the few
        // things those two pages never needed.
        //
        // A text field: a path, a city, a URL. The card's own row height, and
        // the chip radius, so it sits in a row beside a segmented rail.
        readonly property int fieldHeight: 32
        readonly property int fieldWidth: 300
        readonly property int fieldPad: 12
        readonly property int fieldRadius: Math.round(10 * root.radiusScale)
        // A pane taller than the window scrolls; this is its thumb.
        readonly property int scrollbar: 4
        // The bar's items as chips, on the Modules page.
        readonly property int chipHeight: 30
        readonly property int chipGap: 6
        readonly property int chipPad: 10
        readonly property int chipButton: 22
        readonly property int modulesLabel: 64

        // Ranges for the new sliders.
        readonly property int timeoutMin: 2000
        readonly property int timeoutMax: 20000
        readonly property int timeoutStep: 1000
        readonly property int maxVisibleMax: 8
        readonly property int maxResultsMin: 3
        readonly property int maxResultsMax: 12
        readonly property int rampMin: 15
        readonly property int rampMax: 180
        readonly property int rampStep: 15
        // Evening warmth's "How warm", as a fraction.
        readonly property real warmthStep: 0.05
        readonly property int kelvinMin: 2700
        readonly property int kelvinMax: 5500
        readonly property int kelvinStep: 100
    }

    // ---- lock -------------------------------------------------------------
    //
    // Everything in the middle is centred, and the four corner pieces are
    // absolute offsets from the edges, so these numbers hold on a screen that
    // is not the design's 1360x850.
    readonly property QtObject lock: QtObject {

        // ---- the ground ---------------------------------------------------
        //
        // The lock draws on a deeper ground than any window does -- #06090B in
        // the design, against the surface's #0E1416 -- so that the three
        // blooms have something to be light against. Held as a darkening of
        // `surface` rather than as a fourth neutral, because matugen
        // regenerates the palette from the wallpaper and would not know about
        // a hand-written colour. Dark scheme only: in light mode the lock
        // keeps `surface`, which is already the right ground for it.
        readonly property real groundDarken: 2.2

        // CSS sizes `radial-gradient(circle, ...)` to its farthest corner, so
        // the design's stop percentages are fractions of the half-diagonal,
        // not of the half-width. Reading them as half-widths pulls every bloom
        // in by a third.
        readonly property real bloomExtent: Math.SQRT1_2

        // The frame every measurement below was taken on. The blooms are laid
        // out against it and then scaled to COVER the real screen, the way a
        // background image would be: they are the wallpaper, and a fixed 1100px
        // circle on a 3840px monitor is a blob in a corner rather than light
        // filling a room. Everything else on this screen -- the rings, the arc,
        // the field, the corner pieces -- stays at its measured size, because
        // those are sized to the type they surround, not to the screen.
        readonly property int frameWidth: 1360
        readonly property int frameHeight: 850

        // Three blooms, each a circle whose box is partly off-screen. The two
        // large ones hang off a corner; the third is placed as a fraction of
        // the frame, which is the only one of the three that has to scale.
        readonly property int bloomOne: 1100
        readonly property int bloomOneX: -180
        readonly property int bloomOneY: -260
        readonly property real bloomOneMid: 0.38
        readonly property real bloomOneEdge: 0.70

        readonly property int bloomTwo: 1000
        readonly property int bloomTwoX: -300   // from the right edge
        readonly property int bloomTwoY: -380   // from the bottom edge
        readonly property real bloomTwoMid: 0.42
        readonly property real bloomTwoEdge: 0.72

        readonly property int bloomThree: 620
        readonly property real bloomThreeX: 0.40  // fraction of the width
        readonly property real bloomThreeY: 0.10  // fraction of the height
        readonly property real bloomThreeEdge: 0.68

        // The design puts a `0 0 90px` glow behind the clock as a text-shadow.
        // Drawn as a fourth bloom instead: a shadow that size is a bloom, and
        // a bloom costs one static gradient where a layered MultiEffect costs a
        // full-size texture of 154px type on every repaint.
        readonly property int clockGlow: 560
        readonly property real clockGlowEdge: 0.62

        // ---- the rings and the arc ------------------------------------------
        readonly property int ringOuter: 760
        readonly property int ringInner: 560

        // The conic arc. Degrees clockwise from twelve o'clock: the design's
        // gradient starts at six and runs 232 degrees round, so it fades in up
        // the left side, is brightest over the top and is gone by two o'clock.
        readonly property int arc: 438
        readonly property int arcThickness: 9
        readonly property int arcStart: 180
        readonly property int arcSweep: 232
        readonly property real arcPrimaryStop: 96 / 232
        readonly property real arcTertiaryStop: 168 / 232
        // Enough segments that a seam is under a pixel at 438px across.
        readonly property int arcSegments: 96
        // Where the arc's opacity sits at silence while it is tracking audio.
        // It never goes above the value the design draws, so a quiet passage
        // dims the arc rather than a loud one over-brightening it.
        readonly property real arcQuiet: 0.72
        // One turn of the arc while something plays, at the speed an average
        // level gives -- slower than the media tab's 14s cover, because this
        // is a large shape at the edge of vision and not the thing you look at.
        // The speed is `arcTurnFloor + arcTurnGain * level` of that, so silence
        // still turns it and a loud passage surges.
        readonly property int arcTurn: 20000
        readonly property real arcTurnFloor: 0.35
        readonly property real arcTurnGain: 1.3

        // ---- the centre stack ------------------------------------------------
        readonly property real stateSize: 14
        readonly property real stateTracking: 0.34   // em
        readonly property real clockTracking: -0.05  // em
        readonly property real dateSize: 17
        readonly property int centreGap: 6

        // ---- the four ambient stats -------------------------------------------
        readonly property int statsOffset: 146   // below the centre line
        readonly property int statWidth: 168
        readonly property int statGap: 7
        readonly property real statValue: 19
        readonly property real statIcon: 24
        readonly property int dividerHeight: 58
        // Below this the bottom stack and the stats row would want the same
        // pixels -- a 1366x768 panel is exactly that case -- so the stats drop
        // out rather than being drawn through the password field.
        readonly property int statsMinHeight: 820

        // ---- identity and the password field -----------------------------------
        readonly property int bottomMargin: 46
        readonly property int bottomGap: 13
        readonly property int avatar: 40
        readonly property int identityGap: 13

        readonly property int fieldHeight: 52
        readonly property int fieldRadius: 26
        readonly property int fieldPadLead: 22
        readonly property int fieldPadTrail: 10
        readonly property int fieldGap: 12
        readonly property real fieldIcon: 20
        readonly property int dotsWidth: 204
        readonly property int dot: 8
        readonly property int dotGap: 8
        // Thirteen dots and a caret fit the 204px run. Capped one short of
        // that: past the cap the field would either grow or overflow, and
        // either one hands the length of the password to anyone watching.
        readonly property int maxDots: 12
        // 2, not the design's 1.5, for the reason launcher.caretWidth gives.
        readonly property int caretWidth: 2
        readonly property int caretHeight: 18
        readonly property int submit: 34
        readonly property real submitIcon: 19
        readonly property int hintGap: 9

        // ---- the three corner pieces ---------------------------------------------
        readonly property int cornerMargin: 34
        readonly property int chipHeight: 40
        readonly property int chipPadding: 18
        readonly property int chipGap: 14
        readonly property int chipItemGap: 7

        // The design draws the two chips at 50% and the password field at 60%
        // where a popout is 92%. Held as a reduction of the user's panel
        // opacity rather than as a fixed alpha, so the settings screen's
        // opacity slider still moves all three with everything else.
        readonly property real chipFade: 0.32
        readonly property real fieldFade: 0.22

        readonly property int mediaHeight: 60
        readonly property int mediaGap: 16
        readonly property int mediaArt: 40
        readonly property int mediaTextWidth: 140
        readonly property int mediaControlGap: 14
        readonly property real mediaPlayIcon: 22

        // The live spectrum, bottom right. Ten bars rather than the 24 the
        // Players service meters, because that is what the design draws and a
        // 24-bar block at this width would be a solid rectangle.
        readonly property int levelsHeight: 38
        readonly property int levelsBars: 10
        readonly property real levelsBarWidth: 3
        readonly property real levelsGap: 3
        readonly property real levelsOpacity: 0.7
        // Bars above this fraction of full scale carry `primary`; the design
        // splits its ten bars between .62 and .54.
        readonly property real levelsHighlight: 0.58
    }

    // ---- type -------------------------------------------------------------
    readonly property QtObject font: QtObject {
        readonly property string ui: "Rubik"

        // Resolved, not asserted. Qt matches a family by its exact name, and
        // a machine may carry JetBrains Mono only under the Nerd Font's family
        // -- the same typeface with extra glyphs. Naming the upstream family
        // alone falls through to Noto Sans, which is not monospace at all, so
        // every percentage, timestamp and keybind in the shell would silently
        // lose its grid. Prefer the upstream name for the day it is packaged
        // into assets/, take the Nerd Font when that is what exists, and fail
        // to the generic rather than to a proportional face.
        readonly property string mono: {
            const want = ["JetBrains Mono", "JetBrainsMono Nerd Font", "JetBrains Mono NL"];
            const have = Qt.fontFamilies();
            for (const family of want)
                if (have.indexOf(family) >= 0)
                    return family;
            return "monospace";
        }

        readonly property string icon: "Material Symbols Rounded"

        // The Material Symbols variable axes the design draws every glyph at:
        // weight 300, unfilled, no optical grade. A number, so it belongs here
        // rather than as a default inside Icon.qml.
        readonly property int iconWeight: 300
        readonly property real iconFill: 0
        readonly property int iconGrade: 0
    }

    // ---- component library ------------------------------------------------
    // `components/` owns no numbers of its own either. These are the sizes the
    // design draws each widget at, gathered here so that the one file which
    // knows how to paint a slider is not also the file that decides how tall
    // one is. Every one of them is still a property on the component, so a
    // caller that needs another size overrides it at the call site.
    readonly property QtObject widget: QtObject {
        // One physical pixel. Every rule, divider and panel border in the shell
        // is this thick; the design never draws a heavier one.
        readonly property int hairline: 1

        // Slider -- a 6px track with a 4x14 handle, as in the output popout.
        readonly property int sliderWidth: 120
        readonly property real sliderTrack: 6
        readonly property real sliderHandleWidth: 4
        readonly property real sliderHandleHeight: 14

        // Toggle -- 44x26, knob in a 3px gutter. As in the control popouts and
        // the Appearance page.
        readonly property int toggleWidth: 44
        readonly property int toggleHeight: 26
        readonly property int toggleInset: 3

        // Segmented rail -- 28px segments in the same 3px gutter, the power
        // popout's power profiles.
        readonly property int segmentHeight: 28
        readonly property int segmentInset: 3

        // Pill and list row at their commonest heights.
        readonly property int pillHeight: 28
        readonly property int rowHeight: 40

        // Ring -- a progress arc's default size. The dashboard sizes its own.
        readonly property real ringDiameter: 56
        readonly property real ringThickness: 6

        // Sparkline, and the waveform built on it. The waveform's bars stand
        // slightly further apart than a throughput trace's: 28 of them have to
        // read as separate at 156px wide.
        readonly property int sparklineWidth: 120
        readonly property int sparklineHeight: 52
        readonly property real barSpacing: 2
        readonly property real barRadius: 2
        readonly property real barMinHeight: 2
        readonly property real waveformBarSpacing: 2.5
        readonly property int waveformHeight: 26
    }

    // `real`, not `int`: the design's type table specifies 12.5px body, 11.5px
    // secondary and 10.5px mono metadata, and the file bundled with it declared
    // these as int -- which fails to load outright with "Invalid property
    // assignment: int expected". Half-point sizes are deliberate here, so widen
    // the type rather than rounding the design.
    readonly property QtObject size: QtObject {
        readonly property real display: 154   // lock clock
        readonly property real headline: 36  // "what changed" hero figure
        readonly property real title: 21    // settings page title
        readonly property real heading: 16    // panel title
        readonly property real body: 12.5
        readonly property real subheading: 15  // track title, greeting
        readonly property real label: 11.5  // secondary
        readonly property real caption: 11    // section labels, uppercase
        readonly property real micro: 10.5  // mono metadata
        // The icon ramp is measured off the design's screens, and the three
        // sizes it shipped with do not cover them: a glyph set beside text is
        // sized to that text, so 11.5px labels carry 14px icons (the dashboard
        // drawer's pills), 12.5px labels carry 16px (its tab strip, the trailing
        // check on a selected row) and a list row's leading glyph is 17px on
        // every screen that has one -- the control popouts, the clipboard, the
        // Appearance page. Named for where they sit, not by scale.
        readonly property real iconXs: 14   // inline with an 11.5px label
        readonly property real iconSm: 15
        readonly property real iconLabel: 16  // inline with a 12.5px label
        readonly property real iconRow: 17    // leading glyph of a list row
        readonly property real iconMd: 18
        readonly property real iconLg: 21
        readonly property real iconXl: 26   // album placeholder
    }

    readonly property real captionTracking: 0.1   // em, uppercase section labels

    // ---- motion -----------------------------------------------------------
    //
    // Two registers, both documented in docs/motion.md. The first is for small
    // state changes -- a hover, a toggle, a colour -- and stays quick and
    // plain. The second is the dashboard's: surfaces grow, content arrives on a
    // curve that overshoots nothing but settles late, and what leaves gets out
    // of the way fast.
    //
    // Under reduceMotion nothing travels and nothing changes size on screen;
    // every distance and morph below is zero, and what is left is a short fade.
    readonly property QtObject anim: QtObject {
        readonly property int fast: root.scaled(root.reduceMotion ? 70 : 140)
        readonly property int normal: root.scaled(root.reduceMotion ? 90 : 180)
        readonly property int slow: root.scaled(root.reduceMotion ? 110 : 220)
        readonly property int enterEasing: Easing.OutCubic
        readonly property int exitEasing: Easing.InCubic
        // Translation distance — zero when motion is reduced.
        readonly property int slide: root.reduceMotion ? 0 : 8

        // ---- expressive ---------------------------------------------------
        //
        // Curves, as Easing.BezierSpline control points. `emphasized` is for a
        // surface changing size or place (the dashboard's open and tab morph),
        // `rise` for content settling into it, `leave` for content going: it
        // starts slowly and is quickest as it disappears.
        readonly property var emphasized: [0.3, 0.9, 0.2, 1, 1, 1]
        readonly property var rise: [0.2, 0.9, 0.2, 1, 1, 1]
        readonly property var leave: [0.3, 0, 0.8, 0.15, 1, 1]

        // A surface growing, shrinking or moving.
        readonly property int morph: root.scaled(root.reduceMotion ? 0 : 500)
        // Content arriving: `arrive` is its fade, `travel` how long it takes
        // to cover its distance -- longer, so it is still settling after it is
        // fully opaque.
        readonly property int arrive: root.reduceMotion ? root.anim.fast : root.scaled(350)
        readonly property int travel: root.scaled(root.reduceMotion ? 0 : 500)
        // Content leaving, which should never hold up what replaces it, and
        // how long its replacement waits before it starts to show -- long
        // enough that two pages of text are never legible at once.
        readonly property int depart: root.reduceMotion ? root.anim.fast : root.scaled(200)
        readonly property int handover: root.scaled(root.reduceMotion ? 0 : 100)

        // How far arriving content travels: up into place, or across when the
        // change has a direction (the next tab, the next month).
        readonly property int riseBy: root.reduceMotion ? 0 : 10
        readonly property int shiftBy: root.reduceMotion ? 0 : 12

        // Lists arrive one item after another, `stagger` apart. Past
        // `staggerMax` items the rest come with the last one, so a long list
        // is never still arriving after a second.
        readonly property int stagger: root.scaled(root.reduceMotion ? 0 : 35)
        readonly property int staggerMax: 8

        // The palette crossing over to a new one: a retint, light to dark,
        // evening warmth. Long and even, because it is the whole screen
        // changing colour; a colour change is not motion, so under
        // reduceMotion it shortens rather than going.
        readonly property int palette: root.reduceMotion ? root.anim.slow : root.scaled(800)
    }

    // ---- elevation --------------------------------------------------------
    readonly property QtObject shadow: QtObject {
        readonly property int panelBlur: 56
        readonly property int drawerBlur: 110
        readonly property int panelY: 22
        readonly property int drawerY: 40
        readonly property real alpha: 0.5

        // How much transparent margin a window must leave around a panel for its
        // shadow to survive. A layer-shell surface scissors at its own edges, and
        // the shadow fades out across the whole `blur` beyond the panel, plus the
        // downward offset (measured; see Panel.shadowGutter). Needed by windows
        // that must size themselves before there is a Panel inside them to read
        // `shadowGutter` from.
        readonly property int gutter: Math.ceil(root.shadow.panelBlur + root.shadow.panelY)
        readonly property int drawerGutter: Math.ceil(root.shadow.drawerBlur + root.shadow.drawerY)
        // A drawer sits further off the surface than a popout, and the design
        // darkens its shadow to match: `0 40px 110px rgba(0,0,0,.7)`.
        readonly property real drawerAlpha: 0.7
    }

    readonly property int backdropBlur: 28
}
