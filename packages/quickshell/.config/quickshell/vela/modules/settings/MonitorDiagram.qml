import QtQuick
import QtQuick.Layouts
import qs.tokens

// One of the Bar page's four position choices: a drawing of a monitor with the
// bar on the edge it would take, its name underneath.
//
// It is a radio button drawn as a picture, so it behaves like one -- left and
// right move the choice as well as the focus, which is the whole reason the
// design shows four pictures instead of a menu.
//
// The bar inside is placed with x/y rather than anchors: three of the four
// edges would need an anchor cleared, and an anchor whose binding resolves to
// `undefined` is not reliably cleared on this Qt.
Item {
    id: root

    // "top" | "left" | "right" | "bottom"
    property string edge
    property string label
    property bool selected: false

    signal chosen
    signal move(int by)

    readonly property bool horizontal: root.edge === "top" || root.edge === "bottom"
    // The focused control is one of the three things allowed to carry colour,
    // and so is the selected one; nothing else in this card does.
    readonly property bool accented: root.selected || root.activeFocus

    implicitHeight: column.implicitHeight

    activeFocusOnTab: true

    Keys.onLeftPressed: root.move(-1)
    Keys.onRightPressed: root.move(1)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.chosen();
            event.accepted = true;
        }
    }

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Appearance.settings.monitorLabelGap

        Rectangle {
            id: screenBox

            implicitHeight: Appearance.settings.monitorHeight
            radius: Appearance.settings.monitorRadius
            color: Colours.surface
            border.width: root.accented ? Appearance.settings.monitorBorderSelected : Appearance.settings.monitorBorder
            border.color: root.accented ? Colours.primary : Colours.panelBorder

            Layout.fillWidth: true

            Behavior on border.color {
                enabled: !Colours.crossing

                ColorAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Appearance.anim.enterEasing
                }
            }

            Rectangle {
                readonly property int inset: Appearance.settings.monitorInset
                readonly property int thickness: Appearance.settings.monitorBar

                x: root.edge === "right" ? screenBox.width - inset - thickness : inset
                y: root.edge === "bottom" ? screenBox.height - inset - thickness : inset
                width: root.horizontal ? screenBox.width - inset * 2 : thickness
                height: root.horizontal ? thickness : screenBox.height - inset * 2
                radius: Appearance.settings.monitorBarRadius
                color: root.selected ? Colours.primary : Colours.outlineVariant

                Behavior on color {
                    enabled: !Colours.crossing

                    ColorAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Appearance.anim.enterEasing
                    }
                }
            }
        }

        Text {
            text: root.label
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.label
            color: root.selected ? Colours.primary : Colours.outline
            horizontalAlignment: Text.AlignHCenter

            Layout.fillWidth: true
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.chosen();
        }
    }
}
