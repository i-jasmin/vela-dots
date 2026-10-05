pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.tokens
import qs.components

// The dock. Apps left of a divider, stacks right of it, floating clear of the
// bottom edge with a 24px corner.
//
// One instance per monitor, like the bar, so the dock is where the cursor is
// rather than on whichever screen happened to be focused when the shell
// started.
//
// THE WINDOW IS THE WHOLE SCREEN and the dock is placed inside it. A dock that
// was only as big as itself could not hear a click beside itself -- which is
// how a stack panel is dismissed -- and would clip its own shadow at its edges.
// Nothing is drawn in the margin, and `mask` keeps the live input
// region down to the dock itself, or to a two-pixel strip at the screen edge
// while it is hidden, so the rest of the window is not in anyone's way.
//
// POSITION. The design draws the dock along the bottom and describes it in the
// settings pages as sitting "on the opposite edge to the bar". `bottom` and
// `top` are both drawn here; `left` and `right` fall back to `bottom`, because
// a vertical dock is a second geometry -- magnification along the other axis,
// stack panels opening sideways -- that the design never draws and that should
// be designed before it is written.
Scope {
    id: root

    // One reader for the whole shell, outside `Variants`: a second monitor is a
    // second dock, not a second Downloads folder.
    //
    // Named `folders` rather than `stacks`, because the Stack panel takes a
    // property of that name and the assignment would resolve to itself.
    Stacks {
        id: folders
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: scope

            required property ShellScreen modelData

            PanelWindow {
                id: win

                // The design is a horizontal strip, and nothing in it
                // draws a vertical dock: there is no rail layout to fall back
                // on, so "left" and "right" are clamped to the bottom rather
                // than half-honoured. Clamped out loud -- a setting that is
                // accepted and then ignored in silence is the state this file
                // was in, and it is worse than either answer.
                readonly property bool atTop: Config.dock.position === "top"
                readonly property bool positionSupported: Config.dock.position === "top" || Config.dock.position === "bottom"

                onPositionSupportedChanged: {
                    if (!win.positionSupported)
                        console.warn(`[vela] dock.position "${Config.dock.position}" is not drawn; the dock is only drawn as a horizontal strip. Using "bottom".`);
                }

                // ---- what is in it ------------------------------------------------

                // Every running application, keyed by the desktop entry it resolves
                // to so a window and its pinned tile are the same thing. Falls back
                // to the raw class for a window with no entry, which is still better
                // than a second tile for the same program.
                readonly property var running: {
                    const map = {};
                    for (const client of Hypr.clients) {
                        const appClass = Hypr.classOf(client);
                        if (!appClass)
                            continue;
                        const entry = Hypr.entryFor(appClass);
                        const key = entry?.id ?? appClass;
                        if (!map[key])
                            map[key] = {
                                entry: entry,
                                appClass: appClass,
                                addresses: []
                            };
                        map[key].addresses.push(client.address);
                    }
                    return map;
                }

                // Pinned first, in the order shell.json lists them, then whatever
                // else is running. Identity only: what is *running* and what a stack
                // *holds* are bound by the delegate, so the model -- and with it
                // every delegate and its hover state -- is not rebuilt every time a
                // window opens.
                readonly property var apps: {
                    const out = [];
                    const seen = [];
                    for (const id of Config.dock.pinned) {
                        const entry = win.entryById(id);
                        const key = entry?.id ?? id;
                        if (seen.includes(key))
                            continue;
                        seen.push(key);
                        out.push({
                            kind: "app",
                            slot: out.length,
                            key: key,
                            entry: entry,
                            icon: win.symbolFor(entry, id),
                            image: AppIcons.forEntry(entry) || AppIcons.forClass(id.replace(/\.desktop$/i, "")),
                            label: entry?.name ?? id
                        });
                    }
                    if (Config.dock.includeRunning)
                        for (const key of Object.keys(win.running)) {
                            if (seen.includes(key))
                                continue;
                            seen.push(key);
                            const found = win.running[key];
                            out.push({
                                kind: "app",
                                slot: out.length,
                                key: key,
                                entry: found.entry,
                                icon: win.symbolFor(found.entry, found.appClass),
                                image: AppIcons.forEntry(found.entry) || AppIcons.forClass(found.appClass),
                                label: found.entry?.name ?? found.appClass
                            });
                        }
                    return out;
                }

                readonly property var stackItems: {
                    const out = [];
                    const configured = Config.dock.stacks ?? [];
                    for (let i = 0; i < configured.length; i++)
                        out.push({
                            kind: "stack",
                            slot: win.apps.length + i,
                            index: i,
                            path: configured[i].path ?? "",
                            icon: configured[i].icon ?? "folder",
                            label: folders.label(configured[i].path ?? "")
                        });
                    return out;
                }

                readonly property bool dividerVisible: win.apps.length > 0 && win.stackItems.length > 0
                // Where the stacks start in the run of cells, once the divider
                // has taken one.
                readonly property int stackOffset: win.apps.length + (win.dividerVisible ? 1 : 0)

                // THE ROW IS PLACED, NOT POSITIONED, and this is why.
                //
                // A `Row` lays its children out left to right, so magnifying an
                // item pushes everything after it along -- including, half the
                // time, the item under the cursor. It slides out from under the
                // pointer, un-hovers, shrinks back, re-hovers: measured, and it
                // oscillates until the cursor moves. Every real dock solves it
                // the same way: the hovered item's centre stays exactly where it
                // was at rest and the row grows outwards from it in both
                // directions. That needs an explicit x per cell, which a
                // positioner cannot give.
                //
                // Returns the base widths, the magnified widths, the left edge
                // of every cell relative to the row's rest origin, and the span
                // that covers them.
                readonly property var geom: {
                    const gap = Appearance.dock.gap;
                    const base = [];
                    const slots = [];
                    for (const app of win.apps) {
                        base.push(Appearance.dock.tile);
                        slots.push(app.slot);
                    }
                    if (win.dividerVisible) {
                        base.push(1 + Appearance.dock.dividerGap * 2);
                        slots.push(-1);
                    }
                    for (const stack of win.stackItems) {
                        base.push(Appearance.dock.tile);
                        slots.push(stack.slot);
                    }

                    const baseLeft = [];
                    let run = 0;
                    for (const width of base) {
                        baseLeft.push(run);
                        run += width + gap;
                    }
                    const baseWidth = Math.max(0, run - gap);

                    const magnify = Config.dock.magnify;
                    const widths = slots.map((slot, i) => slot < 0 ? base[i] : Appearance.dock.sideAt(magnify && win.hoveredSlot >= 0 ? Math.abs(slot - win.hoveredSlot) : -1));

                    const held = slots.indexOf(win.hoveredSlot);
                    const left = new Array(base.length);
                    if (win.hoveredSlot < 0 || held < 0) {
                        for (let i = 0; i < base.length; i++)
                            left[i] = baseLeft[i];
                    } else {
                        // The one fixed point: the hovered cell keeps the centre
                        // it had at rest.
                        left[held] = baseLeft[held] + base[held] / 2 - widths[held] / 2;
                        for (let i = held - 1; i >= 0; i--)
                            left[i] = left[i + 1] - gap - widths[i];
                        for (let i = held + 1; i < base.length; i++)
                            left[i] = left[i - 1] + widths[i - 1] + gap;
                    }

                    const first = left.length > 0 ? left[0] : 0;
                    const last = left.length > 0 ? left[left.length - 1] + widths[widths.length - 1] : 0;
                    return {
                        left: left,
                        min: first,
                        width: last - first,
                        baseWidth: baseWidth
                    };
                }

                // A cell's left edge inside the row.
                function cellX(index: int): real {
                    return (win.geom.left[index] ?? 0) - win.geom.min;
                }

                // A desktop id as shell.json spells it ("kitty.desktop"), matched
                // against what Quickshell calls the same entry. Searched rather than
                // looked up, because `byId` warns on a miss and a pinned app that is
                // not installed is a normal state, not a fault.
                function entryById(id: string): var {
                    const want = id.replace(/\.desktop$/i, "").toLowerCase();
                    return DesktopEntries.applications.values.find(e => (e.id ?? "").replace(/\.desktop$/i, "").toLowerCase() === want) ?? null;
                }

                // Which Material Symbol a tile carries. The design draws monochrome
                // ligatures rather than themed app icons; `Apps` answers it so the
                // bar, the launcher and the dock cannot disagree about what an
                // application looks like. With an icon theme chosen, `image` is the
                // app's own icon and this its fallback.
                function symbolFor(entry: var, fallback: string): string {
                    return entry ? Apps.symbolFor(entry) : Apps.symbolForClass(fallback.replace(/\.desktop$/i, ""));
                }

                // ---- what it does -------------------------------------------------

                function activateApp(item: var): void {
                    const found = win.running[item.key];
                    if (found && found.addresses.length > 0) {
                        Hypr.focusWindow(found.addresses[0]);
                        return;
                    }
                    if (item.entry)
                        Apps.launch(item.entry);
                }

                // Middle click. A dock that can only ever focus the window you
                // already have is half a dock.
                function newInstance(item: var): void {
                    if (item.entry)
                        Apps.launch(item.entry);
                }

                function toggleStack(index: int): void {
                    if (win.openStack === index) {
                        win.openStack = -1;
                        return;
                    }
                    folders.refresh();
                    win.openStack = index;
                }

                // ---- when it is on screen -----------------------------------------

                readonly property string mode: Config.dock.behaviour
                readonly property bool overviewOnly: win.mode === "overview-only"
                property bool revealedByHover: false
                property int openStack: -1
                readonly property bool stackOpen: win.openStack >= 0

                readonly property bool shown: Config.dock.enabled && (win.mode === "always" || (win.overviewOnly ? ShellState.overview : win.revealedByHover || win.stackOpen))

                // The item under the cursor, and its place in the run of tiles.
                // Tracked as the item rather than as an index so the hover label can
                // follow it while the magnification animates it about.
                property Item hoveredTile: null
                readonly property int hoveredSlot: win.hoveredTile?.item?.slot ?? -1
                // The tile the label is about: the hovered one, or the last one
                // while the label fades out, so it goes where it was rather
                // than jumping to the middle with no text in it.
                property Item tipTile: null
                onHoveredTileChanged: if (win.hoveredTile)
                    win.tipTile = win.hoveredTile

                // The stack the panel is showing, kept through its exit for the
                // same reason.
                property int shownStack: -1
                onOpenStackChanged: if (win.openStack >= 0)
                    win.shownStack = win.openStack

                // "Signal · 2 unread". The count is real -- it is what the
                // notification server is currently holding for that application --
                // and simply absent when there is nothing.
                readonly property string tipText: {
                    const item = win.tipTile?.item ?? null;
                    if (!item)
                        return "";
                    const key = Object.keys(Notifs.groups).find(g => g.toLowerCase() === item.label.toLowerCase());
                    const unread = key ? Notifs.groups[key].length : 0;
                    if (unread === 0)
                        return item.label;
                    return `${item.label} · ${unread === 1 ? qsTr("1 unread") : qsTr("%1 unread").arg(unread)}`;
                }

                // The bar's footprint, so the dock centres on the space left over --
                // the design's `calc(50% + 34px)`.
                readonly property int insetLeft: Config.bar.position === "left" ? Config.bar.footprint : 0
                readonly property int insetRight: Config.bar.position === "right" ? Config.bar.footprint : 0

                screen: scope.modelData
                visible: Config.dock.enabled
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                WlrLayershell.layer: WlrLayer.Top
                // The compositor does the backdrop blur -- `layerrule = blur,
                // ^(vela-.*)$` matches this name. Without it the dock degrades to
                // flat, not to unreadable.
                WlrLayershell.namespace: "vela-dock"
                // On demand, never exclusive: a dock must not take the keyboard from
                // the window under it, but an open stack panel has to hear escape.
                WlrLayershell.keyboardFocus: win.stackOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

                mask: Region {
                    // With a stack panel open the whole window is live, because
                    // dismissing it by clicking away is the only way out that does
                    // not involve aiming at the tile again.
                    item: win.stackOpen ? null : hitbox
                    width: win.stackOpen ? win.width : 0
                    height: win.stackOpen ? win.height : 0
                }

                onShownChanged: {
                    if (!win.shown)
                        win.openStack = -1;
                }

                onStackOpenChanged: {
                    if (win.stackOpen)
                        keys.forceActiveFocus();
                }

                // The listings are read when the dock appears rather than on a
                // timer, and kept fresh only while it is there: a `find` over
                // Downloads every minute for a dock nobody is looking at is a cost
                // with no reader.
                Timer {
                    running: win.shown
                    interval: Appearance.dock.refreshInterval
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: folders.refresh()
                }

                Timer {
                    id: hide

                    interval: Appearance.dock.hideDelay
                    onTriggered: win.revealedByHover = false
                }

                // The live region: the dock and the margin below it while it is out,
                // a strip at the very edge while it is away. It snaps rather than
                // following the slide, so a cursor left sitting where the dock used
                // to be does not immediately pull it back.
                Item {
                    id: hitbox

                    x: win.shown ? dock.x : 0
                    y: win.shown ? (win.atTop ? 0 : dock.y) : (win.atTop ? 0 : win.height - Appearance.dock.revealStrip)
                    width: win.shown ? dock.width : win.width
                    height: win.shown ? dock.height + Appearance.dock.margin : Appearance.dock.revealStrip

                    HoverHandler {
                        id: stripHover
                    }
                }

                // Hover is only delivered to the item under the pointer and its
                // ancestors -- never to a sibling behind it. `hitbox` is behind
                // the dock, so on its own it reads "not hovered" the moment the
                // pointer reaches a tile (each has its own HoverHandler), and the
                // dock hid itself 400 ms after you pointed at it. The panel's own
                // handler is an ancestor of every tile, so between the two the
                // pointer is accounted for wherever it is.
                readonly property bool pointerInside: stripHover.hovered || dockHover.hovered

                onPointerInsideChanged: {
                    if (win.pointerInside) {
                        hide.stop();
                        win.revealedByHover = true;
                    } else {
                        hide.restart();
                    }
                }

                Item {
                    id: keys

                    anchors.fill: parent

                    Keys.onEscapePressed: event => {
                        win.openStack = -1;
                        event.accepted = true;
                    }

                    // Click-away, live only while a stack panel is open -- the mask
                    // above is what stops this swallowing anything the rest of the
                    // time.
                    MouseArea {
                        anchors.fill: parent
                        enabled: win.stackOpen
                        onClicked: win.openStack = -1
                    }
                }

                // ---- the dock ------------------------------------------------------
                Panel {
                    id: dock

                    level: "panel"

                    HoverHandler {
                        id: dockHover
                    }
                    radius: Appearance.radius.dock
                    // Placed by `items` below rather than by the panel, because the
                    // design pads a dock 8 across and 10 along.
                    padding: 0

                    implicitWidth: win.geom.width + Appearance.dock.padAlong * 2
                    implicitHeight: Appearance.dock.tileHover + Appearance.dock.dotGap + Appearance.dock.runningDot + Appearance.dock.padding * 2

                    // Centred on the space the bar leaves -- but while something
                    // is magnified, placed so the hovered tile sits exactly
                    // where it did at rest. Both terms animate with the same
                    // curve as the cells inside, so the sum interpolates
                    // cleanly and the tile under the cursor does not move at
                    // all.
                    readonly property real centre: win.insetLeft + (win.width - win.insetLeft - win.insetRight) / 2
                    x: Math.round(dock.centre - win.geom.baseWidth / 2 + win.geom.min - Appearance.dock.padAlong)

                    // Reduced motion means no translation at all, here as
                    // everywhere: the magnifier is the one place in the shell
                    // where sliding under the cursor is most of what the
                    // effect IS, so gating it leaves the size change alone and
                    // takes the movement away. The same widget in the settings
                    // preview has always been gated this way.
                    Behavior on x {
                        enabled: !Appearance.reduceMotion

                        NumberAnimation {
                            duration: Appearance.anim.fast
                            easing.type: Appearance.anim.enterEasing
                        }
                    }

                    Behavior on implicitWidth {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                            easing.type: Appearance.anim.enterEasing
                        }
                    }

                    readonly property int restY: win.atTop ? Appearance.dock.margin : win.height - Appearance.dock.margin - height
                    // Hidden, the dock leaves through the edge it came from --
                    // except under reduced motion, where it does not travel at
                    // all and the fade carries the whole transition. Same rule
                    // the bar follows.
                    readonly property int awayY: Appearance.reduceMotion ? dock.restY : win.atTop ? -height : win.height

                    y: win.shown ? dock.restY : dock.awayY
                    opacity: win.shown ? 1 : 0
                    visible: opacity > 0

                    // Each curve from where its value is heading, which the
                    // Behavior knows before it starts -- not from `shown`,
                    // which these bindings may see after `y` and `opacity`
                    // already have (the bar's slide, in modules/bar/Bar.qml).
                    Behavior on y {
                        id: sliding

                        NumberAnimation {
                            duration: Appearance.dock.duration
                            easing.type: sliding.targetValue === dock.restY ? Appearance.anim.enterEasing : Appearance.anim.exitEasing
                        }
                    }

                    Behavior on opacity {
                        id: fading

                        NumberAnimation {
                            duration: Appearance.dock.duration
                            easing.type: fading.targetValue > 0 ? Appearance.anim.enterEasing : Appearance.anim.exitEasing
                        }
                    }

                    Item {
                        id: items

                        x: Appearance.dock.padAlong
                        y: Appearance.dock.padding
                        width: win.geom.width
                        height: Appearance.dock.tileHover + Appearance.dock.dotGap + Appearance.dock.runningDot

                        Repeater {
                            model: win.apps

                            AppTile {
                                id: appTile

                                required property var modelData
                                required property int index

                                item: appTile.modelData
                                magnify: Config.dock.magnify
                                distance: win.hoveredSlot < 0 ? -1 : Math.abs(appTile.modelData.slot - win.hoveredSlot)
                                running: (win.running[appTile.modelData.key]?.addresses.length ?? 0) > 0

                                x: win.cellX(appTile.index)

                                Behavior on x {
                                    enabled: !Appearance.reduceMotion

                                    NumberAnimation {
                                        duration: Appearance.anim.fast
                                        easing.type: Appearance.anim.enterEasing
                                    }
                                }

                                onHoveredChanged: win.trackHover(appTile, hovered)
                                onActivated: win.activateApp(appTile.modelData)
                                onSecondary: win.newInstance(appTile.modelData)
                            }
                        }

                        // Apps on one side, stacks on the other.
                        Item {
                            visible: win.dividerVisible
                            x: win.cellX(win.apps.length)
                            width: 1 + Appearance.dock.dividerGap * 2
                            height: parent.height

                            Behavior on x {
                                enabled: !Appearance.reduceMotion

                                NumberAnimation {
                                    duration: Appearance.anim.fast
                                    easing.type: Appearance.anim.enterEasing
                                }
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: parent.height - Appearance.dock.dividerLift - height
                                implicitWidth: 1
                                implicitHeight: Appearance.dock.dividerLength
                                color: Colours.alpha(Colours.on.surface, Appearance.dock.dividerAlpha)
                            }
                        }

                        Repeater {
                            id: stackRow

                            model: win.stackItems

                            AppTile {
                                id: stackTile

                                required property var modelData
                                required property int index

                                item: stackTile.modelData
                                magnify: Config.dock.magnify
                                distance: win.hoveredSlot < 0 ? -1 : Math.abs(stackTile.modelData.slot - win.hoveredSlot)
                                badge: folders.count(stackTile.modelData.path)
                                accent: win.openStack === stackTile.modelData.index

                                x: win.cellX(win.stackOffset + stackTile.index)

                                Behavior on x {
                                    enabled: !Appearance.reduceMotion

                                    NumberAnimation {
                                        duration: Appearance.anim.fast
                                        easing.type: Appearance.anim.enterEasing
                                    }
                                }

                                onHoveredChanged: win.trackHover(stackTile, hovered)
                                onActivated: win.toggleStack(stackTile.modelData.index)
                                onSecondary: folders.openFolder(stackTile.modelData.path)
                            }
                        }
                    }
                }

                function trackHover(tile: Item, hovered: bool): void {
                    if (hovered)
                        win.hoveredTile = tile;
                    else if (win.hoveredTile === tile)
                        win.hoveredTile = null;
                }

                // Where a label or a stack panel points: the centre of the hovered
                // tile, in window coordinates. Every term is a live property, so it
                // keeps up while magnification moves the tiles around.
                readonly property real tipCentre: {
                    const tile = win.tipTile;
                    if (!tile)
                        return win.width / 2;
                    return dock.x + items.x + tile.x + tile.width / 2;
                }

                // ---- the hover label -------------------------------------------------
                Rectangle {
                    id: tip

                    readonly property int lift: win.atTop ? dock.y + dock.height + Appearance.dock.lift : dock.y - Appearance.dock.lift - height

                    readonly property bool wanted: win.shown && win.hoveredTile !== null && !win.stackOpen

                    visible: opacity > 0
                    x: Math.round(Math.max(Appearance.dock.margin, Math.min(win.width - width - Appearance.dock.margin, win.tipCentre - width / 2)))
                    y: tip.lift

                    implicitWidth: tipLabel.implicitWidth + Appearance.dock.tipPadding * 2
                    implicitHeight: Appearance.dock.tipHeight
                    radius: Appearance.dock.tipRadius
                    color: Colours.alpha(Colours.panel, Math.min(1, Appearance.panelOpacity + Appearance.dock.tipBoost))
                    border.width: 1
                    border.color: Colours.panelBorder

                    // Faded both ways: it used to fade in and cut out, because
                    // it went invisible before the fade could start.
                    opacity: tip.wanted ? 1 : 0

                    Behavior on opacity {
                        id: tipFading

                        NumberAnimation {
                            duration: Appearance.anim.fast
                            easing.type: tipFading.targetValue > 0 ? Appearance.anim.enterEasing : Appearance.anim.exitEasing
                        }
                    }

                    Text {
                        id: tipLabel

                        anchors.centerIn: parent
                        text: win.tipText
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.dock.tipSize
                        color: Colours.on.surface
                    }
                }

                // ---- the stack panel -------------------------------------------------
                //
                // Rises out of the dock and sinks back into it (`Reveal`), held
                // on the stack it was showing until it has gone.
                Loader {
                    id: panel

                    readonly property real target: win.shownStack >= 0 ? win.stackCentre(win.shownStack) : win.width / 2

                    active: win.stackOpen || stackEntrance.opacity > 0
                    visible: active
                    opacity: stackEntrance.opacity

                    x: Math.round(Math.max(Appearance.dock.margin, Math.min(win.width - width - Appearance.dock.margin, panel.target - width / 2)))
                    y: (win.atTop ? dock.y + dock.height + Appearance.dock.lift : dock.y - Appearance.dock.lift - height) + (win.atTop ? -stackEntrance.offset : stackEntrance.offset)

                    Reveal {
                        id: stackEntrance

                        shown: win.stackOpen
                    }

                    sourceComponent: Stack {
                        stacks: folders
                        stack: Config.dock.stacks[win.shownStack] ?? ({})
                        index: win.shownStack
                    }
                }

                // The open stack's tile centre, found by index rather than by hover:
                // the panel stays put when the cursor moves on.
                function stackCentre(index: int): real {
                    for (let i = 0; i < stackRow.count; i++) {
                        const tile = stackRow.itemAt(i);
                        if (tile?.item?.index === index)
                            return dock.x + items.x + tile.x + tile.width / 2;
                    }
                    return win.width / 2;
                }
            }
        }
    }
}
