import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.config
import qs.services
import qs.components
import qs.modules.attached

// The launcher. 580px, opened on `super + space`, dismissed on esc.
//
// Three sources in one list, in the order `Config.launcher.sources` gives them:
// applications, commands on $PATH, and a web search as the last row. That last
// row is the reason the list is built the way `Search.rank()` builds it -- a
// launcher whose web fallback only appears once nothing else matched has hidden
// it exactly when it stops being a guess and starts being the answer.
//
// ATTACHED TO THE BAR. The launcher hangs off the bar in an `AttachedDrawer`,
// like the dashboard: centred along a horizontal bar, and a little way down a
// vertical one, where it keeps its top edge still and grows downward. Its
// length follows the results, so typing grows and shrinks the drawer instead
// of the list jumping, and the search field never moves while it does: it is
// the row nearest the bar, which on a bottom bar means the bottom row.
//
// IN THE BAR'S OWN WINDOW. Every monitor's shell window (modules/shell/
// Shell.qml) holds one of these beside the bar, full screen, with the drawer
// placed in it, for the two reasons that governed the dashboard: a layer-shell
// surface clips at its own edges, so the shadow needs transparent room to fall
// into, and a 580px window cannot hear a click beside itself. The one on
// `ShellState.drawerScreen` is the one that opens, and the window hands it the
// keyboard -- exclusively, because the launcher is opened from a keybind and
// the first keystroke after it has to land in the field without a click first.
Item {
    id: root

    // The monitor whose shell window this is in, and the BarState of its
    // bar, whose colour the drawer takes.
    required property string screenName
    required property var bar

    readonly property bool shown: ShellState.launcher && ShellState.drawerScreen === root.screenName
    readonly property bool live: drawer.live

    // Measured off the design, and kept in `Appearance.launcher`: the width
    // (580 is the design's content box, not its outer edge), the caret, and
    // how far down the screen the panel sits.

    // The search row goes next to the bar, so it stays put while the results
    // change the drawer's length.
    readonly property bool searchLast: Config.bar.position === "bottom"

    readonly property string countText: {
        const shown = search.results.length;
        const total = search.matchCount;
        // `maxResults` caps what is drawn, so on a broad query the row count
        // and the match count are different numbers and the footer says both.
        // The design only draws the case where they agree.
        const label = total > shown ? qsTr("%1 of %2 results").arg(shown).arg(total) : shown === 1 ? qsTr("1 result") : qsTr("%1 results").arg(shown);
        return `${label} · ${search.elapsed} ms`;
    }

    visible: root.live

    // Emptied once the drawer has gone, not only on the next open: a query
    // left in a prefix mode (";" for the clipboard) kept ranking and
    // rebuilding its hidden rows every time the clipboard changed.
    onLiveChanged: if (!root.live)
        search.reset()

    onShownChanged: {
        if (!root.shown)
            return;
        // A fresh open starts from an empty query. Inheriting the last search
        // would make the first keystroke land somewhere unpredictable.
        search.reset();
        search.prime();
        input.forceActiveFocus();
    }

    Search {
        id: search
    }

    Item {
        anchors.fill: parent
        focus: true

        // Click-away, which the window does. The design dismisses the launcher
        // on esc alone, but the window has to cover the screen for the shadow
        // to exist at all, and a full-screen surface that swallows clicks
        // without answering them is a trap rather than a decision.
        AttachedDrawer {
            id: drawer

            anchors.fill: parent
            key: "launcher"
            screenName: root.screenName
            bar: root.bar
            open: root.shown
            radius: Appearance.radius.launcher
            contentWidth: Appearance.launcher.contentWidth + Appearance.space.sm * 2
            contentHeight: column.implicitHeight + Appearance.space.sm * 2
            // The design puts the panel 132px down an 850px frame; along a
            // vertical bar that is where its top edge stays.
            along: drawer.side ? Math.round(drawer.height * Appearance.launcher.topFraction) : -1
            align: drawer.side ? "start" : "centre"

            GridLayout {
                id: column

                anchors.fill: parent
                anchors.margins: Appearance.space.sm
                columns: 1
                rowSpacing: 0

                // ---- search row -------------------------------------------
                RowLayout {
                    spacing: Appearance.launcher.searchGap

                    Layout.row: root.searchLast ? 2 : 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: Appearance.launcher.searchHeight
                    Layout.leftMargin: Appearance.launcher.searchPadding
                    Layout.rightMargin: Appearance.launcher.searchPadding

                    // One of the three things allowed to carry colour on this
                    // screen: the field the shell is waiting on.
                    Icon {
                        text: "search"
                        size: Appearance.size.iconLg
                        color: Colours.primary

                        Layout.alignment: Qt.AlignVCenter
                    }

                    TextInput {
                        id: input

                        // The design's 15.5px. Qt quantises `font.pixelSize`
                        // to whole pixels and rounds half up, so the token that
                        // renders what the design renders is the 16px one
                        // -- 15.5 would not have been a smaller glyph,
                        // only an illegal literal.
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.heading
                        color: Colours.on.surface
                        selectionColor: Colours.primaryContainer
                        selectedTextColor: Colours.on.primaryContainer
                        selectByMouse: true
                        // Drawn below rather than by Qt: the built-in caret
                        // blinks, and nothing in this shell moves while
                        // nothing is happening (docs/motion.md).
                        cursorDelegate: Item {}

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        onTextChanged: search.query = input.text

                        Keys.onPressed: event => {
                            switch (event.key) {
                            case Qt.Key_Escape:
                                ShellState.close("launcher");
                                break;
                            case Qt.Key_Down:
                                search.move(1);
                                break;
                            case Qt.Key_Up:
                                search.move(-1);
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                search.activate(search.current);
                                break;
                            case Qt.Key_Tab:
                                search.complete();
                                input.cursorPosition = input.text.length;
                                break;
                            default:
                                return;
                            }
                            event.accepted = true;
                        }

                        // `reset()` and Tab-completion write the query from the
                        // model's side; typing writes it from this side. The
                        // guard is what keeps the two from chasing each other.
                        Connections {
                            target: search

                            function onQueryChanged(): void {
                                if (input.text !== search.query)
                                    input.text = search.query;
                            }
                        }

                        Text {
                            // Clear of the caret, which sits at x 0 while the
                            // field is empty.
                            x: Appearance.launcher.caretWidth + Appearance.space.xs
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text.length === 0
                            text: qsTr("Search apps, commands and the web")
                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.size.heading
                            color: Colours.outline
                        }

                        Rectangle {
                            x: input.cursorRectangle.x
                            y: input.cursorRectangle.y + Math.round((input.cursorRectangle.height - height) / 2)
                            implicitWidth: Appearance.launcher.caretWidth
                            implicitHeight: Appearance.launcher.caretHeight
                            color: Colours.primary
                            visible: input.activeFocus
                        }
                    }

                    Keycap {
                        key: qsTr("esc")

                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                Rectangle {
                    implicitHeight: 1
                    color: Colours.panelBorder

                    Layout.row: 1
                    Layout.fillWidth: true
                    Layout.leftMargin: Appearance.launcher.dividerInset
                    Layout.rightMargin: Appearance.launcher.dividerInset
                }

                // ---- results ----------------------------------------------
                ColumnLayout {
                    spacing: Appearance.launcher.rowGap

                    Layout.row: root.searchLast ? 0 : 2
                    Layout.fillWidth: true
                    Layout.topMargin: Appearance.launcher.listTop
                    Layout.bottomMargin: Appearance.launcher.listBottom
                    Layout.leftMargin: Appearance.launcher.listInset
                    Layout.rightMargin: Appearance.launcher.listInset

                    Repeater {
                        model: search.results

                        ResultRow {
                            required property var modelData
                            required property int index

                            result: modelData
                            selected: index === search.selected
                            onClicked: search.activate(modelData)

                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        implicitHeight: 1
                        color: Colours.panelBorder

                        Layout.fillWidth: true
                        Layout.topMargin: Appearance.launcher.ruleGap
                        Layout.bottomMargin: Appearance.launcher.ruleGap
                        Layout.leftMargin: Appearance.launcher.ruleInset
                        Layout.rightMargin: Appearance.launcher.ruleInset
                    }

                    // ---- footer -------------------------------------------
                    //
                    // Keybinds and a count: literals, so the whole strip is
                    // monospace.
                    RowLayout {
                        spacing: Appearance.launcher.footerGap

                        Layout.fillWidth: true
                        Layout.topMargin: Appearance.launcher.footerTop
                        Layout.bottomMargin: Appearance.launcher.footerBottom
                        Layout.leftMargin: Appearance.launcher.footerInset
                        Layout.rightMargin: Appearance.launcher.footerInset

                        Repeater {
                            // Enter's word follows the selected row: launch,
                            // run, copy, insert, paste. Tab is only offered
                            // where it fills something in.
                            model: [qsTr("↑↓ navigate"), qsTr("↵ %1").arg(search.verb), ...(search.completes ? [qsTr("⇥ complete")] : [])]

                            Text {
                                required property string modelData

                                text: modelData
                                font.family: Appearance.font.mono
                                font.pixelSize: Appearance.size.micro
                                color: Colours.outline
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.countText
                            font.family: Appearance.font.mono
                            font.pixelSize: Appearance.size.micro
                            color: Colours.outline
                        }
                    }
                }
            }
        }
    }
}
