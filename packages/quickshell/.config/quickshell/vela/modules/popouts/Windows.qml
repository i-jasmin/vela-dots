pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.services
import qs.components

// The workspace window list -- the fifth content, and the one that is not one
// of the bar's four control popouts.
//
// It is the bar's own popout: on a vertical bar there is no room for the
// focused window's title, so clicking the workspace you are already on gives
// you the list instead. The vertical bar's design draws it beside the rail
// and the popouts' design does not mention it, but it hangs off the same
// anchor, opens the same way and dismisses the same way, so it is drawn here
// rather than given its own window.
//
// Its shape is its own: 246px rather than 292, an 18px radius rather than 20,
// and a single pixel between rows because this is one list rather than a stack
// of sections. Those come off the vertical bar's design, not off the popouts'.
PopoutContent {
    id: root

    // The workspace id the bar put in `BarPopouts.payload`. `var` rather than
    // `int`: the four control popouts leave the payload undefined, and a
    // component is built before it is told which popout it is.
    property var workspace: undefined

    readonly property int workspaceId: Number(root.workspace) || Hypr.focusedWorkspaceId

    readonly property var windows: {
        // `Hyprland.toplevels.values` does not notify when a window moves
        // between workspaces -- one toplevel's `workspace` changes and the list
        // is identical -- so a filter over it alone would go stale while the
        // popout was open. `windowCounts` is recomputed on exactly those
        // events; reading it here is what makes this binding follow them. The
        // value is deliberately discarded.
        void Hypr.windowCounts;
        return Hypr.windowsOn(root.workspaceId);
    }

    popoutWidth: Appearance.popout.windowsWidth
    contentPadding: Appearance.space.sm
    contentRadius: Appearance.radius.cardLg
    contentSpacing: Appearance.popout.windowsSpacing

    // A toplevel's `lastIpcObject` -- and therefore its class, and therefore
    // its glyph -- is only filled in by a full toplevel query, which nothing
    // runs on its own after startup: a window opened since then arrives on the
    // event socket with a title and no class, and would draw the fallback
    // glyph. Asking once, as the list opens, is the moment the answer is
    // actually wanted. The rows re-evaluate when it lands.
    Component.onCompleted: Hypr.refresh()

    SectionLabel {
        text: root.windows.length === 1 ? qsTr("Workspace %1 · 1 window").arg(root.workspaceId) : qsTr("Workspace %1 · %2 windows").arg(root.workspaceId).arg(root.windows.length)

        Layout.fillWidth: true
        Layout.leftMargin: Appearance.space.md
        Layout.rightMargin: Appearance.space.md
        Layout.topMargin: Appearance.space.sm
        Layout.bottomMargin: Appearance.space.sm
    }

    Repeater {
        model: root.windows

        Row {
            id: window

            required property var modelData

            // A monochrome glyph, as the design draws `terminal` and `public`
            // here -- or the real application icon, when an icon theme is
            // chosen and the whole shell draws apps that way.
            icon: Hypr.iconOf(window.modelData)
            iconSource: AppIcons.forClient(window.modelData)
            title: window.modelData.title
            selected: window.modelData.address === Hypr.activeAddress
            titleColour: window.selected ? Colours.on.surface : Colours.on.surfaceVariant
            // The design marks the focused window with the fill alone -- there
            // is no check on these rows, because you are not choosing one of a
            // set, you are being shown where you are.
            trailingIcon: ""
            rowHeight: Appearance.popout.windowsRowHeight
            spacing: Appearance.popout.headerGap
            iconSize: Appearance.size.iconLabel
            onClicked: Hypr.focusWindow(window.modelData.address)

            Layout.fillWidth: true
        }
    }

    Empty {
        text: qsTr("No windows here")
        visible: root.windows.length === 0
    }
}
