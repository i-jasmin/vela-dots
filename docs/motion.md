# Motion

How things move in vela, and the tokens and components that do it. Every
duration, curve and distance lives in `Appearance.anim`
(`tokens/Appearance.qml`); a literal duration anywhere else is a bug.

## The rule

**Motion answers a change.** A surface opening, content being replaced, a list
arriving: those move. Nothing moves while nothing is happening -- no blinking
caret, no idle pulse, no looping shimmer. The media tab's spinning cover and the
lock screen's arc are the only things in motion at rest, and they only turn
while something is playing: they are a readout, not decoration. Both are
advanced frame by frame, so a pause leaves them where they stopped; the arc
turns faster as the music gets louder. Neither turns under reduce motion.

## Two registers

**Small state changes** -- a hover, a toggle, a colour, a pill lighting up --
stay quick and plain:

| Token | Value | For |
|---|---|---|
| `anim.fast` / `normal` / `slow` | 140 / 180 / 220 ms | hovers, toggles, colour |
| `anim.enterEasing` / `exitEasing` | OutCubic / InCubic | the same |
| `anim.slide` | 8 px | the small rise of a plain panel |

**Expressive** -- the dashboard's language, for surfaces and their content:

| Token | Value | For |
|---|---|---|
| `anim.emphasized` | `cubic-bezier(.3, .9, .2, 1)` | a surface changing size or place |
| `anim.rise` | `cubic-bezier(.2, .9, .2, 1)` | content settling into it |
| `anim.leave` | `cubic-bezier(.3, 0, .8, .15)` | content moving away: slow to start, quickest as it goes |
| `anim.morph` | 500 ms | a surface growing, shrinking or moving |
| `anim.arrive` | 350 ms | content fading up |
| `anim.travel` | 500 ms | content covering its distance, so it is still settling once opaque |
| `anim.depart` | 200 ms | content fading out; never holds up what replaces it |
| `anim.handover` | 100 ms | how long the replacement waits, so two pages of text are never legible at once |
| `anim.riseBy` | 10 px | content arriving upward |
| `anim.shiftBy` | 12 px | content arriving across, when the change has a direction |
| `anim.stagger` | 35 ms | the gap between list items arriving |
| `anim.staggerMax` | 8 | items past this arrive with the eighth |

## Choreography

- **Surface first, content after.** The surface grows on `emphasized` over
  `morph`; its content fades up over `arrive` while travelling `riseBy` over
  `travel` on `rise`. The content is laid out at its final size from the start
  and uncovered as the surface grows, so nothing inside reflows mid-motion.
- **What leaves gets out of the way.** Outgoing content fades over `depart`,
  moving off on `leave`. Its replacement starts `handover` later.
- **Direction means something.** Content moves the way the change runs: the
  next tab or month arrives from the right and the previous from the left;
  content in a surface that is opening travels the way the surface grows.
  Where a change has no direction, content rises.
- **Lists arrive in order**, `stagger` apart, capped at `staggerMax` so a long
  list is never still arriving after a second.

A Behavior that moves one way on the way in and another on the way out reads
which way it is going from its own `targetValue`, never from the flag that
drives the value. The value's binding and the animation's `duration` and
`easing` all follow that flag, in no fixed order, so `shown ? arrive : leave`
often picked the arrival for an exit:

```qml
Behavior on reveal {
    id: revealing
    NumberAnimation {
        duration: revealing.targetValue > 0 ? Appearance.anim.morph : Appearance.anim.depart
    }
}
```

## Components

All in `components/`, imported with `qs.components`.

**`Morph`** -- the animation for a surface changing size or place, to put in a
Behavior instead of repeating the curve and duration:

```qml
Behavior on height {
    Morph {}
}
```

**`MorphBox`** -- a box that follows its first child's implicit size through
`Morph`: a popout swapping pages, a list gaining results. It clips only while
moving, and a box that was empty takes its first size at once. Turn
`morphWidth` off when a layout sizes it across.

```qml
MorphBox {
    ColumnLayout { ... }
}
```

**`Stagger`** -- one list item's share of a staggered entrance. Not a visual
item, so it goes inside any delegate without joining its layout; the delegate
binds its `opacity` and `offset`. It plays on creation when `active` is true,
and again each time `active` turns true.

```qml
RowLayout {
    id: row
    required property int index
    opacity: arrival.opacity
    transform: Translate { y: arrival.offset }

    Stagger {
        id: arrival
        index: row.index
        active: panel.shown
    }
}
```

**`Reveal`** -- a floating surface's open and close: fades up over `arrive`
while rising `riseBy` over `travel`, and on the way out fades over `depart` as
it sinks back. `scaleFrom` below 1 has it come forward as well (the overview and
the window picker). `entering` is true while the open runs, for the rows'
`Stagger`, so a list arrives in order as the surface opens and rows created
later -- a search, a scroll -- simply appear.

```qml
Panel {
    y: panel.restY + entrance.offset
    opacity: entrance.opacity

    Reveal {
        id: entrance
        shown: root.shown
    }
}
```

**`Crossfade`** -- swaps one component for another: the old page freezes its
size, stops taking input and leaves; the new one arrives after `handover`.
`direction` is 1 (new from below or the right), -1 (the reverse) or 0 (fade
only); `vertical` picks the axis. `enter()` plays the arrival alone, for a
surface that is opening. The old page is destroyed once it has gone. A change
of `key` swaps to a fresh instance of the same component (Home's next
month), and `alignment` says where a leaving page sits if the box has changed
size under it.

A name inside `Stagger` or `Reveal` shadows an id of the same name outside it
-- `Stagger` has `index`, `active`, `distance`, `opacity`, `offset`, `delay`
and `sequence` -- so give the surface's `Reveal` an id none of those use
(`entrance` is the convention).

```qml
Crossfade {
    anchors.fill: parent
    vertical: false
    component: pane === "look" ? lookPane : otherPane
}
```

The Gallery (`components/Gallery.qml`, how to run it is at the top of the
file) has a Motion section with all three and the control that sets each off.

## The palette

A new wallpaper's palette, the switch between light and dark, and each step of
evening warmth cross over rather than cutting: every role in `Colours` eases
towards its new value over `anim.palette` (800 ms), and the accessors read the
eased values. The palette read at startup is not eased, or every start would
open on a sweep from the built-in defaults. A target is always computed from
the target palette, never from another eased role, so no role chases another;
the panel-opacity alpha is applied after the easing, so the settings slider
still moves the panels at once.

While it crosses over, `Colours.crossing` is true, and every colour Behavior
in the shell carries `enabled: !Colours.crossing`. Without that, each would
restart its own short fade on every frame of the long one and trail visibly
behind the rest -- the bar clock's pill by a third of a second. A new colour
Behavior should carry the same line.

## Motion settings

Settings, Appearance, *Motion* -- three keys in `shell.json`:

| Motion | Keys | What moves |
|---|---|---|
| Full | `animations: true`, `reduceMotion: false` | everything, as this document describes |
| Reduced | `reduceMotion: true` | fades only: every distance and every morph is zero, so nothing travels and nothing changes size on screen; fades remain, at `anim.fast` (70 ms) |
| Off | `animations: false` | nothing: every duration is zero, every change instant |

and *Speed*, `animationSpeed` (the slider offers 0.5x to 3x; the file takes
0.25 to 4), which divides every duration: 2 is twice as quick, 0.5 half as.
Every duration in `Appearance` goes through `Appearance.scaled()`, which
applies both, and nothing in the shell writes a duration of its own -- so a
new animation that takes its duration from a token follows the setting with
no further work, and one with a number in it does not.

Hyprland follows the same keys: `hypr/conf/general.lua` reads them from
`shell.json` when its config loads -- window and workspace speeds divided by
the speed, workspaces and other programs' layers fading instead of sliding
under Reduced, animations off under Off -- and `Hypr` reloads Hyprland a
moment after one changes, once `shell.json` has been written.

A new surface or component is not done until it has been run under Reduced
and nothing moved.

## Checking motion by eye

A screenshot tool is too slow to catch a 200 ms fade. To look at frames, slow
everything down: `"animationSpeed": 0.25` in `shell.json` makes every
duration four times as long, the shell's and Hyprland's alike.

## Attached surfaces

`modules/attached/AttachedDrawer.qml` is the dashboard's drawer as a piece of
its own, for everything that hangs off the bar: the dashboard, the popouts, the
launcher and the power menu. It grows out of the bar's inner face on `morph`,
joined to it by two fillets, and tells the bar (through `ShellState.attached`)
to go solid and stay out while it has any extent.

- A change of content size morphs the drawer's length and breadth.
- A change of `along` -- a popout moving to another bar item -- slides it
  along the bar. Size and place only animate while the drawer is out, so one
  that opens somewhere new starts there.
- It is kept off the bar's rounded ends, fillet included, so the join always
  lands on the flat of the bar.
- `align: "start"` keeps the drawer's top (or left) edge still while it
  changes size: the launcher on a vertical bar, whose search field would
  otherwise move as the results change.
- Opening one drawer while another is out on the same monitor -- the
  dashboard over a popout, the launcher over the dashboard -- is a handoff,
  not a close and an open. The new drawer takes the old one's length, breadth
  and place, the old one vanishes in the same frame, and the new one morphs
  on from there. The drawers find each other through `ShellState`. Before,
  the old one retracted into the bar while the new one grew out of it, and
  everything went down before anything came back up.

The bar and every drawer are drawn in one window per monitor
(`modules/shell/Shell.qml`), not a window each. Two windows are two frames that
the compositor shows whenever each is ready, and for a frame or so of every
opening the bar and the drawer were in different states: the join between them
showed as a line. In one window, every frame has both. The window's input region
is just the bar while nothing hangs off it, and a separate empty 1x1 window
reserves the bar's space.

## Where it is used

- **Dashboard**: open and close, the morph between tabs, the crossfade between
  tab contents. Home's month folding out: the drawer grows on `morph` and the
  month fades up as it is uncovered (a `Reveal`'s values); folding away, it
  fades before the drawer has closed over it. The rest of Home stays where it
  was throughout, and a change of month slides the grid across.
- **Popouts**: open and close from their bar item; between items, the drawer
  slides and resizes and the contents cross over, the new one arriving from
  the side the drawer is heading for.
- **Launcher**: open and close; its length follows the results.
- **Power menu**: open and close at the bar's end, the five buttons staggered.
- **Floating panels** (clipboard, cheatsheet, sessions, what changed,
  settings, wallpaper): `Reveal`, with their rows, cards or notes staggered
  in. Settings crosses between panes, in the direction the change runs.
- **Overview and window picker**: come forward from 0.96 rather than rising;
  the overview's cards stagger in, and both move their selection ring with a
  fade rather than a jump. A window dropped in the overview stays where it was
  let go until Hyprland has placed it, then morphs to its new place and size,
  across cards if it changed workspace; the windows it made room for, or
  that closed up behind it, morph with it. A workspace made while it is up
  -- a window dropped on New workspace -- adds its card at once, and a row
  that comes or goes slides the grid to its new centre.
- **Notifications**: a toast arrives on the emphasized curve with the stack
  opening round it, leaves on `depart` with the stack closing behind it, and
  grows or shrinks when its app says something longer or shorter. The
  digest's list folds rather than cutting. Opening one out (a toast, or a
  row in the centre) grows the card on `morph`, its chevron turning on
  `anim.normal`. A swipe (`components/SwipeArea.qml`) is direct
  manipulation: the card follows the pointer or the fingers even under
  reduce motion, springs back on `fast` or flies out on `normal`, and a row
  in the centre then folds away on `depart`, the list closing up behind it.
  Under reduce motion the flight is dropped: the card is put back and fades.
- **Bar**: a module that comes or goes -- the status run folding behind its
  arrow, the media chip as a player appears, the bell while folded -- opens
  and closes on `morph`: its length along the bar, the gap before it and its
  opacity follow one eased value (`BarGroup`'s `reveal`), so the run closes up
  rather than jumping. The arrow turns on `anim.normal`.
- **Palette**: every colour, as above. The other apps' windows cross over
  with it: before a retint each window on screen is captured as one frozen
  frame (`modules/overlays/Recolour.qml`), held over the window while the
  apps repaint underneath, then faded out over `anim.palette` on the same
  InOutQuad as the palette. Under reduce motion that fade is `anim.palette`'s
  short version, like the palette itself.
- **OSD, dock**: the OSD rises and sinks with `Reveal`; the dock's hover label
  fades out where it was, and its stack panel rises from the dock and sinks
  back.

- **Hyprland**: windows, workspaces and other programs' layers use the same
  curves and timings (`packages/hypr/.config/hypr/conf/general.lua`): a window
  pops in over `morph` on `emphasised` and out over `depart` on `leave`, a
  workspace slides over `morph`. The shell's own layers are `no_anim` there,
  because it animates them itself.

What stays on the first register is the small stuff: hovers, toggles, the
colour of a selected row.
