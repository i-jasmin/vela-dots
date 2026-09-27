import QtQuick
import qs.services
import qs.tokens

// The notification centre's bell: everything the history holds, dotted while
// something arrived since it was last opened. Right-click is do not disturb,
// the same way right-clicking the speaker mutes it.
//
// Its own module rather than the tray's last glyph, because it folds by a
// different rule: while the status run is folded behind its arrow
// (BarExpander) the bell stays as long as anything is unread. As a module of
// its own it opens and closes with the rest of the run (BarGroup's `reveal`)
// instead of vanishing from inside the tray.
BarButton {
    id: root

    required property BarState bar

    // The tray's rhythm, not the run's: it sat 13px (11 on a horizontal bar)
    // from the network glyph when it was part of the tray, and still does.
    readonly property int leadMargin: root.bar.vertical ? Appearance.bar.trayGapV - Appearance.bar.gapV : Appearance.bar.trayGapH - Appearance.bar.gapTrailH
    readonly property bool present: !root.bar.collapsed || Notifs.unread > 0

    icon: Notifs.doNotDisturb ? "notifications_off" : "notifications"
    tile: false
    size: root.bar.vertical ? Appearance.size.iconRow : Appearance.size.iconLabel
    iconSize: root.size
    dot: Notifs.unread > 0 && !Notifs.doNotDisturb
    showing: root.bar.showing("notifications")

    onClicked: root.bar.popout("notifications", root, undefined)
    onSecondaryClicked: Notifs.doNotDisturb = !Notifs.doNotDisturb

    // The keybind lands on the same anchor a click would.
    Connections {
        target: BarPopouts

        function onRequested(name: string): void {
            if (name === "notifications" && root.bar.forKeys)
                root.bar.popout(name, root, undefined);
        }
    }
}
