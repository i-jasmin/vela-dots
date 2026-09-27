import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.tokens

// The focused window, in the two shapes the design gives it.
//
// This is the piece that changes most between the two bars, and the reason is
// stated in the design: "the window title comes back out of the workspace
// popout and sits inline after the divider". A 58px column cannot hold a title,
// so the vertical bar draws the app's glyph alone in a 34px tile and puts the
// title in the workspace popout you get by clicking. A 40px bar has the whole
// width, so the horizontal bar sets the glyph and the title side by side with
// no tile at all.
//
// Same component either way: one `bar.vertical` picks the shape, and both open
// the same window list.
Item {
    id: root

    required property BarState bar

    // Per-monitor, not global. `Hypr.activeToplevel` is the window the session
    // has focus on, so on every other monitor this named a window that is not
    // there -- sitting above that monitor's own active workspace pill, which
    // was correctly showing something else. The design is explicit that each
    // monitor shows its own state.
    //
    // `windowCounts` is read for its notification rather than its value:
    // moving a window between workspaces changes no toplevel in the list, so a
    // binding over `windowsOn` alone never re-runs (the trap `Hypr.recount`
    // documents) and this would keep naming the window that left.
    readonly property var toplevel: {
        const tick = Hypr.windowCounts;
        const ws = Hypr.activeWorkspaceOn(root.bar.screenName);
        const here = Hypr.windowsOn(ws);
        if (here.length === 0)
            return null;
        // The focused window, when it is on this monitor. Checked first
        // because it is the only answer that follows focus between windows on
        // one workspace: the focus-history fallback below is read from a
        // snapshot that only refreshes when a window opens or closes.
        const active = Hypr.activeToplevel;
        if (active && here.includes(active))
            return active;
        // Otherwise the window this workspace last had focused.
        const remembered = here.find(t => t.address === Hypr.lastFocused[ws]);
        if (remembered)
            return remembered;
        // Lowest focus-history id is the most recently focused. Unlike the
        // events it is answered for windows that existed before the shell
        // started.
        let best = null;
        let bestAt = Infinity;
        for (const t of here) {
            const at = t.lastIpcObject?.focusHistoryID ?? Infinity;
            if (at < bestAt) {
                best = t;
                bestAt = at;
            }
        }
        return best ?? here[0];
    }
    readonly property string title: root.toplevel?.title ?? ""

    readonly property bool present: root.toplevel !== null && root.title !== ""
    readonly property string glyph: Hypr.iconOf(root.toplevel)

    implicitWidth: root.bar.vertical ? tile.implicitWidth : inline.implicitWidth + Appearance.space.xs
    implicitHeight: root.bar.vertical ? tile.implicitHeight : inline.implicitHeight

    // The title is the one thing on the bar with no natural length, so it is
    // the one thing that gives when the bar runs short -- a long title used to
    // run straight through the centred clock on a narrow output. Read by
    // `BarGroup`, which puts it on the Loader: the Loader is what the layout
    // measures, and `Layout.minimumWidth` set in here would be read by nothing.
    readonly property bool shrinks: !root.bar.vertical

    BarButton {
        id: tile

        visible: root.bar.vertical
        anchors.centerIn: parent
        icon: root.glyph
        filled: true
        showing: root.bar.showing("workspaces")

        onClicked: root.bar.popout("workspaces", tile, Hypr.activeWorkspaceOn(root.bar.screenName))
    }

    BarFlow {
        id: inline

        visible: !root.bar.vertical
        anchors.left: parent.left
        // Anchored right as well, so the run is exactly as wide as whatever
        // the bar could spare -- otherwise it keeps its full implicit width
        // and overflows the item it is inside.
        anchors.right: parent.right
        // The design pushes the glyph a touch clear of the divider before it.
        anchors.leftMargin: Appearance.space.xs
        anchors.verticalCenter: parent.verticalCenter
        gap: Appearance.bar.titleGap

        Icon {
            Layout.alignment: Qt.AlignVCenter
            text: root.glyph
            size: Appearance.size.iconSm
            color: Colours.outline
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: Appearance.bar.titleMaxWidth
            // The one item in the leading run that yields when the run is
            // capped, so a narrow bar shortens the title rather than running
            // it through the clock. A capped layout shrinks its filling
            // children first; without this the group would simply overflow.
            Layout.fillWidth: true
            // `Layout.minimumWidth` defaults to the item's implicit width, so
            // without this the layout refuses to take the title below its full
            // length and the cap above does nothing at all. Zero, because the
            // elide is what decides how little is worth drawing.
            Layout.minimumWidth: 0
            text: root.title
            elide: Text.ElideRight
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.bar.titleSize
            color: Colours.on.surfaceVariant
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.bar.vertical
        cursorShape: Qt.PointingHandCursor
        onClicked: root.bar.popout("workspaces", root, Hypr.activeWorkspaceOn(root.bar.screenName))
    }
}
