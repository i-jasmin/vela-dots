import QtQuick
import QtQuick.Layouts
import qs.tokens

// The small rounded control: a dashboard tab, a segment, the focus timer's
// Pause and Skip, Reload and Apply in settings, the health chip. Heights are
// the design's four -- 26, 28, 30, 32 -- and the radius follows the height, so
// a pill is always a pill and never a rounded rectangle.
//
// `tone` is the whole of its appearance, and only two of the five carry colour:
//
//   plain   nothing drawn, tertiary text  -- an unselected tab
//   subtle  neutral fill, secondary text  -- Skip, Reload
//   accent  primaryContainer              -- the selected tab, the enabled control
//   filled  primary                       -- the one affirmative action on a screen
//   danger  error-tinted                  -- destructive, reboot required
//
// Anything that is not the selection or the primary action is neutral. A
// reviewer will reject a `filled` pill that is not the screen's single verb.
Rectangle {
    id: root

    property string text
    // Material Symbols ligature, drawn before the label. Empty for none.
    property string icon
    property string tone: "subtle"
    // Convenience for a selectable pill: overrides `tone` while set.
    property bool checked: false
    property bool interactive: true

    property int pillHeight: Appearance.widget.pillHeight
    // The design pads a pill to just under half its height: 15 at 32, 13 at 28.
    property int hPadding: Math.round((root.pillHeight - 2) / 2)
    property real fontSize: Appearance.size.label
    property real iconSize: Appearance.size.iconXs
    // A glyph sits half an em from its label -- 6px beside 11.5px text.
    property int spacing: Math.round(root.fontSize / 2)

    readonly property string activeTone: root.checked ? "accent" : root.tone
    // Writable: a tinted chip (the dashboard's health chip) overrides `color`
    // and this together, and stays one Pill rather than a new component.
    property color foreground: root.activeTone === "accent" ? Colours.on.primaryContainer : root.activeTone === "filled" ? Colours.on.primary : root.activeTone === "danger" ? Colours.error : root.activeTone === "plain" ? Colours.outline : Colours.on.surfaceVariant

    readonly property alias hovered: mouse.containsMouse
    readonly property alias pressed: mouse.pressed

    // Arbitrary content before the icon and label -- the dashboard's health
    // chip is a coloured dot, the clipboard's colour rows are a swatch. Same
    // slot shape as Row, so the two read alike at the call site.
    property Component leading: null

    signal clicked

    implicitWidth: contents.implicitWidth + root.hPadding * 2
    implicitHeight: root.pillHeight
    radius: root.pillHeight / 2
    opacity: root.enabled ? 1 : 0.38

    color: root.activeTone === "accent" ? Colours.primaryContainer : root.activeTone === "filled" ? Colours.primary : root.activeTone === "danger" ? Colours.alpha(Colours.error, 0.12) : root.activeTone === "plain" ? "transparent" : Colours.hover

    // The focused control is one of the three things allowed to carry colour.
    border.width: root.activeFocus ? 1 : 0
    border.color: Colours.primary

    activeFocusOnTab: root.interactive && root.enabled

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
        }
    }

    Behavior on color {
        enabled: !Colours.crossing

        ColorAnimation {
            duration: Appearance.anim.fast
            easing.type: Appearance.anim.enterEasing
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Colours.hover
        opacity: root.interactive && root.enabled && (mouse.containsMouse || root.activeFocus) ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Appearance.anim.enterEasing
            }
        }
    }

    RowLayout {
        id: contents

        anchors.centerIn: parent
        spacing: (root.icon || root.leading) && root.text ? root.spacing : 0

        Loader {
            Layout.alignment: Qt.AlignVCenter
            active: root.leading !== null
            visible: active
            sourceComponent: root.leading
        }

        Icon {
            text: root.icon
            visible: root.icon !== ""
            size: root.iconSize
            color: root.foreground
        }

        Text {
            text: root.text
            visible: root.text !== ""
            font.family: Appearance.font.ui
            font.pixelSize: root.fontSize
            color: root.foreground
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.interactive && root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.clicked();
        }
    }
}
