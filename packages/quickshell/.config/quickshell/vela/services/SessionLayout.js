.pragma library

// How to rebuild a saved tiled layout in Hyprland's dwindle, window by window.
//
// Dwindle places a new tiled window by splitting another: the focused one, if
// it is on the same workspace, and otherwise the one nearest the pointer --
// and which half the new window takes follows the pointer too, unless a
// direction was preselected. Opening a session's windows one after another
// onto a workspace nobody is looking at therefore left the layout to wherever
// the pointer happened to be. This works out, from the rectangles a session
// saved, the one sequence that builds the same tree: which window to split
// for each new one, which way, and at what ratio.
//
// The rectangles are enough. Dwindle's tree is a nest of full-length cuts
// through the workspace, so the saved windows can always be separated by a
// straight line into two groups, and each group again, down to single
// windows. Hyprland insets each window by `gaps_in` on every side that does
// not touch the work area and not at all on those that do, so the windows of
// a workspace cover exactly its work area, and the middle of the gap between
// two groups is exactly where the cut was. The ratio follows without a pixel
// of error: dwindle gives the first half `size / 2 * ratio`.
//
// Pure functions, so they can be tested against a model of dwindle without a
// compositor (see `plan`).

// How far two edges may disagree and still be one edge: saved geometry is
// rounded to whole pixels.
var slack = 2;

function right(r) {
    return r.x + r.w;
}

function bottom(r) {
    return r.y + r.h;
}

// Dwindle keeps a split's ratio between these (`splitratio` clamps to them).
var minRatio = 0.1;
var maxRatio = 1.9;

// Every straight cut along `axis` ("x" for side by side, "y" for one above
// the other) that separates `items` into two non-empty groups.
function cutsAlong(items, axis) {
    const start = axis === "x" ? (r => r.x) : (r => r.y);
    const end = axis === "x" ? right : bottom;
    const sorted = items.slice().sort((a, b) => start(a) - start(b));
    const cuts = [];
    let reach = -Infinity;
    for (let i = 0; i < sorted.length - 1; i++) {
        reach = Math.max(reach, end(sorted[i]));
        const next = start(sorted[i + 1]);
        if (next >= reach - slack)
            cuts.push({
                axis: axis,
                at: (reach + next) / 2,
                first: sorted.slice(0, i + 1),
                second: sorted.slice(i + 1)
            });
    }
    return cuts;
}

// The tree of cuts over `items` inside `box`, or null when the rectangles do
// not tile (a window saved mid-animation, or geometry that went stale).
//   leaf:  { leaf: item }
//   split: { dir: "r" | "d", ratio, first, second }
// "r" is a cut between left and right, "d" between top and bottom -- the
// directions dwindle's `preselect` takes to put the new window second.
//
// Three columns can be cut left first or right first, and both are the same
// picture -- but not always the same tree dwindle can hold: a thin column
// cut off a wide workspace needs a ratio below the 0.1 dwindle allows. So the
// most even cut is tried first, and the next if anything below it would need
// a ratio dwindle cannot give.
function decompose(items, box) {
    if (items.length === 1)
        return {
            leaf: items[0]
        };
    if (items.length === 0)
        return null;
    const cuts = [...cutsAlong(items, "x"), ...cutsAlong(items, "y")].map(cut => {
        const along = cut.axis === "x";
        const firstBox = along ? {
            x: box.x,
            y: box.y,
            w: cut.at - box.x,
            h: box.h
        } : {
            x: box.x,
            y: box.y,
            w: box.w,
            h: cut.at - box.y
        };
        const secondBox = along ? {
            x: cut.at,
            y: box.y,
            w: right(box) - cut.at,
            h: box.h
        } : {
            x: box.x,
            y: cut.at,
            w: box.w,
            h: bottom(box) - cut.at
        };
        return {
            cut: cut,
            firstBox: firstBox,
            secondBox: secondBox,
            ratio: along ? 2 * firstBox.w / box.w : 2 * firstBox.h / box.h
        };
    }).filter(c => c.ratio >= minRatio && c.ratio <= maxRatio).sort((a, b) => Math.abs(a.ratio - 1) - Math.abs(b.ratio - 1));
    for (const c of cuts) {
        const first = decompose(c.cut.first, c.firstBox);
        const second = first ? decompose(c.cut.second, c.secondBox) : null;
        if (first && second)
            return {
                dir: c.cut.axis === "x" ? "r" : "d",
                ratio: c.ratio,
                first: first,
                second: second
            };
    }
    return null;
}

function bounds(items) {
    const x = Math.min(...items.map(r => r.x));
    const y = Math.min(...items.map(r => r.y));
    return {
        x: x,
        y: y,
        w: Math.max(...items.map(right)) - x,
        h: Math.max(...items.map(bottom)) - y
    };
}

// The window standing for a subtree before it is split any further: the one
// that ends up top left of it.
function representative(node) {
    return node.leaf ? node.leaf : representative(node.first);
}

// The order to open a tree's windows in. Each step is
//   { item, split, dir, ratio }
// -- open `item` by splitting the already-open window `split` (null for the
// first) in direction `dir`, and give the new pair `ratio`. A subtree's
// representative is opened first and fills the subtree's box; splitting it
// makes the second half's representative; then each half is built inside
// the window now holding it.
function order(tree) {
    const steps = [];
    function place(node, occupant) {
        if (!occupant) {
            occupant = representative(node);
            steps.push({
                item: occupant,
                split: null,
                dir: "",
                ratio: 0
            });
        }
        if (node.leaf)
            return;
        const second = representative(node.second);
        steps.push({
            item: second,
            split: occupant,
            dir: node.dir,
            ratio: node.ratio
        });
        place(node.first, occupant);
        place(node.second, second);
    }
    if (tree)
        place(tree, null);
    return steps;
}

// Everything a session restore needs to know, in the order to do it.
//
//   windows: the saved windows, each { workspace, workspaceName, monitor,
//            x, y, w, h, floating, fullscreen, ... }
//
// Returns one entry per workspace, regular workspaces by id and special
// ones last:
//   { workspace, name, special, monitor, steps, loose }
// `steps` rebuild the tiled layout (see `order`); `loose` are the windows
// that are not part of it -- floating, fullscreen, on a special workspace,
// or on a workspace whose saved rectangles did not tile -- opened after, in
// saved order.
function plan(windows) {
    const groups = {};
    for (const w of windows) {
        const name = w.workspaceName || String(w.workspace);
        if (!groups[name])
            groups[name] = {
                workspace: w.workspace,
                name: name,
                special: name.startsWith("special:") || w.workspace < 0,
                monitor: w.monitor || "",
                windows: []
            };
        groups[name].windows.push(w);
    }
    const out = [];
    for (const g of Object.values(groups)) {
        const tiled = g.special ? [] : g.windows.filter(w => !w.floating && !w.fullscreen && w.w > 0 && w.h > 0);
        let steps = [];
        let untiled = [];
        if (tiled.length > 0) {
            const tree = decompose(tiled, bounds(tiled));
            if (tree)
                steps = order(tree);
            else
                untiled = tiled.slice().sort((a, b) => a.x - b.x || a.y - b.y);
        }
        const inTree = new Set(steps.map(s => s.item));
        const loose = [...untiled, ...g.windows.filter(w => !inTree.has(w) && !untiled.includes(w))];
        out.push({
            workspace: g.workspace,
            name: g.name,
            special: g.special,
            monitor: g.monitor,
            steps: steps,
            loose: loose
        });
    }
    return out.sort((a, b) => (a.special - b.special) || (a.workspace - b.workspace));
}
