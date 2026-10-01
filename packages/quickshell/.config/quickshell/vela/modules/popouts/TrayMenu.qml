pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.tokens
import qs.services
import qs.components
import qs.modules.bar

// A tray app's own menu, off its icon in the tray -- drawn by the shell, in
// its colours and type, where the app's would be Qt's or GTK's plain light
// menu. The app still says what is in it, over D-Bus: the labels, which of
// them are greyed out, the separators, a checkbox or a choice of one, an
// icon, a submenu. The shell draws them as one list, the shape of the workspace
// window list, at a control popout's width.
//
// A submenu opens in place: its entries take the list's, under a row that
// goes back to the menu it came from (or the left arrow does). Choosing an
// entry puts the popout away, as a menu does.
PopoutContent {
    id: root

    // The tray item whose menu this is (BarPopouts.payload).
    property var item: null

    // The app has quit, or taken its icon out of the tray, with its menu open.
    readonly property bool gone: typeof root.item === "object" && root.item !== null && !SysTray.items.includes(root.item)

    // The submenus opened on the way here, innermost last.
    property var trail: []

    readonly property var menu: root.trail.length > 0 ? root.trail[root.trail.length - 1] : (root.item?.menu ?? null)

    // Room for an icon on every row once any of them has one, so the labels
    // still line up.
    readonly property bool icons: opener.children.values.some(e => !e.isSeparator && SysTray.usable(e.icon))

    popoutWidth: Appearance.popout.width
    contentPadding: Appearance.space.sm
    contentRadius: Appearance.radius.cardLg
    contentSpacing: Appearance.popout.windowsSpacing

    onItemChanged: root.trail = []

    // Only while it is this menu that is open: one still leaving as another
    // popout comes in is not the one to put away.
    onGoneChanged: {
        if (root.gone && BarPopouts.current === "tray" && BarPopouts.payload === root.item)
            BarPopouts.close();
    }

    function into(entry: var): void {
        root.trail = [...root.trail, entry];
        // The row that was asked has gone with the list it was in; from here
        // the arrow keys start again at the top.
        root.forceActiveFocus();
    }

    function back(): void {
        root.trail = root.trail.slice(0, -1);
        root.forceActiveFocus();
    }

    function choose(entry: var): void {
        if (entry.hasChildren) {
            root.into(entry);
            return;
        }
        entry.triggered();
        BarPopouts.close();
    }

    Keys.onLeftPressed: event => {
        event.accepted = root.trail.length > 0;
        if (event.accepted)
            root.back();
    }

    // Asks the app for the entries and keeps them current; opening and closing
    // it is what tells the app its menu (or a submenu) is showing, for apps
    // that fill one in only then.
    QsMenuOpener {
        id: opener

        menu: root.menu
    }

    // The app's menu stays loaded while it is open -- let go of, Quickshell
    // drops it and every entry in it, a submenu just opened included -- and
    // each menu on the way to a submenu stays open, as with any menu.
    QsMenuOpener {
        menu: root.item?.menu ?? null
    }

    // Kept by the menu they stand for (ScriptModel), so going deeper or back
    // leaves the rest of the way open rather than closing and reopening it.
    Instantiator {
        model: ScriptModel {
            values: root.trail
        }

        delegate: QsMenuOpener {
            required property var modelData

            menu: modelData
        }
    }

    Row {
        visible: root.trail.length > 0
        icon: "arrow_back"
        title: root.trail.length > 0 ? SysTray.label(root.trail[root.trail.length - 1].text) : ""
        titleColour: Colours.on.surfaceVariant
        trailingIcon: ""
        rowHeight: Appearance.popout.windowsRowHeight
        spacing: Appearance.popout.headerGap
        iconSize: Appearance.size.iconLabel
        onClicked: root.back()

        Layout.fillWidth: true
    }

    Divider {
        visible: root.trail.length > 0

        Layout.topMargin: Appearance.space.xs
        Layout.bottomMargin: Appearance.space.xs
    }

    Flickable {
        id: scroll

        contentWidth: width
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: scroll.contentHeight > scroll.height
        clip: scroll.interactive

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(column.implicitHeight, Appearance.popout.menuMax)

        ColumnLayout {
            id: column

            width: scroll.width
            spacing: Appearance.popout.windowsSpacing

            Repeater {
                model: opener.children

                Item {
                    id: entry

                    required property var modelData

                    readonly property bool separator: entry.modelData.isSeparator
                    readonly property bool checkable: entry.modelData.buttonType !== QsMenuButtonType.None

                    implicitHeight: entry.separator ? Appearance.widget.hairline + Appearance.space.xs * 2 : row.implicitHeight

                    Layout.fillWidth: true

                    Divider {
                        visible: entry.separator
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Row {
                        id: row

                        visible: !entry.separator
                        anchors.left: parent.left
                        anchors.right: parent.right
                        title: SysTray.label(entry.modelData.text)
                        interactive: entry.modelData.enabled
                        titleColour: entry.modelData.enabled ? Colours.on.surface : Colours.outline
                        leading: root.icons ? glyph : null
                        trailing: entry.checkable ? check : null
                        trailingIcon: entry.modelData.hasChildren ? "chevron_right" : ""
                        rowHeight: Appearance.popout.windowsRowHeight
                        spacing: Appearance.popout.headerGap
                        onClicked: root.choose(entry.modelData)

                        Keys.onRightPressed: event => {
                            event.accepted = entry.modelData.hasChildren;
                            if (event.accepted)
                                root.into(entry.modelData);
                        }
                    }

                    // The app's own icon for the entry, or the same room left
                    // empty when it has none.
                    Component {
                        id: glyph

                        Item {
                            implicitWidth: Appearance.size.iconLabel
                            implicitHeight: Appearance.size.iconLabel

                            IconImage {
                                anchors.fill: parent
                                source: SysTray.usable(entry.modelData.icon) ? entry.modelData.icon : ""
                                asynchronous: true
                                visible: source !== ""
                            }
                        }
                    }

                    // A checkbox, or one of a choice: the accent when on.
                    Component {
                        id: check

                        Icon {
                            readonly property bool radio: entry.modelData.buttonType === QsMenuButtonType.RadioButton
                            readonly property int mark: entry.modelData.checkState

                            text: radio ? (mark === Qt.Checked ? "radio_button_checked" : "radio_button_unchecked") : mark === Qt.Checked ? "check_box" : mark === Qt.PartiallyChecked ? "indeterminate_check_box" : "check_box_outline_blank"
                            size: Appearance.size.iconLabel
                            color: mark === Qt.Unchecked ? Colours.outline : Colours.primary
                        }
                    }
                }
            }
        }
    }
}
