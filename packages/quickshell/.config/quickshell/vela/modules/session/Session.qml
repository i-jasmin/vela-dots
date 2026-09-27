pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.services
import qs.tokens
// Qualified: `qs.components` has a `Row` of its own, which would take the
// place of the positioner the buttons are laid out in.
import qs.components as C
import qs.modules.attached

// The power menu, on super + escape.
//
// A full-screen dim, a greeting, a line of context, and five 150px buttons each
// showing the one key that runs it. Nothing else: this is the screen where the
// session ends, and anything else on it is something to fumble past.
//
// ATTACHED TO THE BAR. The three blocks hang off the bar in an `AttachedDrawer`
// at the end the power button is on -- the trailing end, right of a
// horizontal bar and foot of a vertical one -- and the buttons arrive one
// after another as it opens. The dim covers everything but the bar, which
// stays lit and solid so the drawer still reads as part of it. Like the other
// drawers it is drawn in each monitor's shell window, with the bar, and the
// one on `ShellState.drawerScreen` is the one that opens.
//
// THE CONTEXT LINE IS MEASURED, NOT WRITTEN. The design reads "4 hours 12
// minutes of uptime · 2 unsaved buffers in nvim". Uptime is real
// (`SysInfo.uptime`). Unsaved buffers are not knowable in general -- nothing
// reports another process's dirty state -- so they are detected only where they
// are genuinely visible: nvim's default titlestring carries a `+` between the
// file name and its directory when the buffer is modified, and ends "- NVIM". A
// terminal without `set title` says nothing, and then neither does this line:
// it falls back to what *is* true, which is how much is open. Inventing a
// number here would be inventing a reason not to shut down.
Item {
    id: root

    // The monitor whose shell window this is in, and the BarState of its
    // bar, whose colour the drawer takes.
    required property string screenName
    required property var bar

    readonly property bool shown: ShellState.power && ShellState.drawerScreen === root.screenName
    readonly property bool live: drawer.live

    readonly property string user: Quickshell.env("USER") || Quickshell.env("LOGNAME")
    readonly property string greeting: root.user ? qsTr("%1, %2").arg(Time.greeting).arg(root.user) : Time.greeting

    // Windows whose title says nvim is holding an unsaved buffer. Read off the
    // title because that is the only place the information exists; a terminal
    // that does not set its title simply never matches.
    readonly property int unsavedBuffers: Hypr.clients.filter(c => {
        const title = c.title ?? "";
        return / - NVIM$/.test(title) && / \+ /.test(title);
    }).length

    readonly property int openWindows: Hypr.clients.length

    readonly property string context: {
        const bits = [];
        if (SysInfo.uptime > 0)
            bits.push(qsTr("%1 of uptime").arg(root.spell(SysInfo.uptime)));
        if (root.unsavedBuffers > 0)
            bits.push(root.unsavedBuffers === 1 ? qsTr("1 unsaved buffer in nvim") : qsTr("%1 unsaved buffers in nvim").arg(root.unsavedBuffers));
        else if (root.openWindows > 0)
            bits.push(root.openWindows === 1 ? qsTr("1 window open") : qsTr("%1 windows open").arg(root.openWindows));
        return bits.join(" · ");
    }

    // "4 hours 12 minutes", spelled out. `SysInfo.formatUptime` gives "4h 12m",
    // which is right for a 196px card on the dashboard and wrong for a sentence.
    function spell(seconds: int): string {
        const d = Math.floor(seconds / 86400);
        const h = Math.floor(seconds % 86400 / 3600);
        const m = Math.floor(seconds % 3600 / 60);
        // Spelled out per unit rather than with `%n`: Qt only resolves a plural
        // form through a translation catalogue, and with none loaded `%n
        // minute(s)` renders exactly that, brackets and all. Measured on screen.
        const bits = [];
        if (d > 0)
            bits.push(d === 1 ? qsTr("1 day") : qsTr("%1 days").arg(d));
        if (h > 0)
            bits.push(h === 1 ? qsTr("1 hour") : qsTr("%1 hours").arg(h));
        if (m > 0 || bits.length === 0)
            bits.push(m === 1 ? qsTr("1 minute") : qsTr("%1 minutes").arg(m));
        return bits.join(" ");
    }

    // Which button the keyboard is on. Lock, because it is the one you press
    // most and the one that cannot lose anything.
    property int selected: 0

    SessionActions {
        id: actions
    }

    visible: root.live

    onShownChanged: {
        if (!root.shown)
            return;
        root.selected = 0;
        keys.forceActiveFocus();
    }

    // Everything but the bar itself: a dimmed bar under an undimmed drawer
    // would break the join. The bar is cut out to its own rounded shape, so
    // the wallpaper round a floating bar dims with everything else. The
    // blur behind it is the compositor's, on the whole shell window.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: root.shown ? 1 : 0

        // Which curve from where the dim is heading, which the Behavior
        // knows before it starts; `shown` may not have reached this binding
        // yet when the opacity it drives already has.
        Behavior on opacity {
            id: dimming

            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: dimming.targetValue > 0 ? Appearance.anim.enterEasing : Appearance.anim.exitEasing
            }
        }

        ShapePath {
            fillColor: Colours.alpha(Colours.scrim, Appearance.session.dim)
            fillRule: ShapePath.OddEvenFill
            strokeWidth: -1

            PathRectangle {
                width: root.width
                height: root.height
            }

            PathRectangle {
                x: drawer.barRect.x
                y: drawer.barRect.y
                width: drawer.barRect.width
                height: drawer.barRect.height
                radius: drawer.barRadius
            }
        }
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            // The single-key shortcuts first: they are the point of the screen,
            // and every one of them is also a letter nothing else here wants.
            const byKey = actions.indexOfKey(event.text);
            if (event.text && byKey >= 0) {
                actions.run(actions.items[byKey].id);
                event.accepted = true;
                return;
            }
            switch (event.key) {
            case Qt.Key_Escape:
                ShellState.close("power");
                break;
            case Qt.Key_Left:
                root.selected = Math.max(0, root.selected - 1);
                break;
            case Qt.Key_Right:
                root.selected = Math.min(actions.items.length - 1, root.selected + 1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                actions.run(actions.items[root.selected].id);
                break;
            default:
                return;
            }
            event.accepted = true;
        }

        // Click-away, which the window does. The dim covers the screen, so a
        // click that lands on nothing has to mean something -- and on this
        // screen the safe meaning is "no".
        AttachedDrawer {
            id: drawer

            anchors.fill: parent
            key: "power"
            screenName: root.screenName
            bar: root.bar
            open: root.shown
            contentWidth: content.implicitWidth + Appearance.session.padding * 2
            contentHeight: content.implicitHeight + Appearance.session.padding * 2
            // As far along the bar as it will go: the power button's end.
            along: drawer.extent

            Column {
                id: content

                anchors.centerIn: parent
                spacing: Appearance.session.blockGap

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Appearance.session.titleGap

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.greeting
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.session.greetingSize
                        font.weight: Font.Light
                        color: Colours.on.surface
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.context
                        visible: text !== ""
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.session.contextSize
                        color: Colours.outline
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Appearance.session.buttonGap

                    Repeater {
                        model: actions.items

                        SessionButton {
                            id: button

                            required property var modelData
                            required property int index

                            action: modelData
                            selected: index === root.selected
                            opacity: arrival.opacity
                            transform: Translate {
                                y: arrival.offset
                            }

                            onActivated: actions.run(modelData.id)

                            C.Stagger {
                                id: arrival

                                index: button.index
                                active: root.shown
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("esc to dismiss")
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.session.hintSize
                    color: Colours.outline
                }
            }
        }
    }
}
