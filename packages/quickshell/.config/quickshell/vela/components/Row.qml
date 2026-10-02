import QtQuick
import QtQuick.Layouts
import qs.tokens

// The list row, which is most of the shell: output devices and networks in the
// bar's popouts, launcher results, clipboard entries, the settings nav. Leading
// glyph, title, optional subtitle, optional trailing content, and a selected
// state in `primaryContainer` with a check.
//
//     Row {
//         icon: "wifi"
//         title: net.ssid
//         subtitle: net.detail
//         selected: net.active
//         onClicked: Net.connect(net)
//     }
//
// NAMING: this file shadows QtQuick's `Row` positioner for every file that
// imports `qs.components` after `QtQuick` -- the later import wins. That is the
// name the build order fixes, so use `RowLayout` for horizontal layout (which
// every component here does anyway), or alias the import: `import QtQuick as Q`
// and then `Q.Row`.
//
// `leading` and `trailing` take a Component when a glyph is not enough: the
// clipboard's 34px thumbnail and its colour swatch go in the first, a timestamp
// or a keycap in the second.
Rectangle {
    id: root

    property string title
    property string subtitle
    // Material Symbols ligature for the leading glyph. Empty for none.
    property string icon
    // An application's own icon, drawn in the glyph's place when there is one
    // (`AppIcons`); the glyph stays the fallback.
    property string iconSource
    property bool selected: false
    property bool interactive: true

    // Slots. Either wins over the corresponding string property.
    property Component leading: null
    property Component trailing: null
    property string trailingIcon: root.selected && !root.trailingText && !root.trailing ? "check" : ""
    property string trailingText

    // A path, a command, a hex, a size: monospace, like every literal.
    property bool titleMono: false
    property bool subtitleMono: false

    property int rowHeight: Appearance.widget.rowHeight
    property int hPadding: Appearance.space.md
    property int spacing: Appearance.space.md
    property real iconSize: Appearance.size.iconRow

    // A device list dims the rows that are not current; a list of equal
    // candidates (launcher, clipboard) leaves every title at full contrast.
    property color titleColour: Colours.on.surface
    property color iconColour: root.selected ? Colours.on.primaryContainer : Colours.outline
    property color subtitleColour: root.selected ? Colours.on.primaryContainer : Colours.outline

    readonly property alias hovered: mouse.containsMouse

    signal clicked

    implicitWidth: contents.implicitWidth + root.hPadding * 2
    implicitHeight: root.rowHeight
    radius: Appearance.radius.chip
    color: root.selected ? Colours.primaryContainer : "transparent"

    activeFocusOnTab: root.interactive

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
        opacity: root.interactive && !root.selected && (mouse.containsMouse || root.activeFocus) ? 1 : 0
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

        anchors.fill: parent
        anchors.leftMargin: root.hPadding
        anchors.rightMargin: root.hPadding
        spacing: root.spacing

        Loader {
            active: root.leading !== null
            visible: active
            sourceComponent: root.leading
            Layout.alignment: Qt.AlignVCenter
        }

        AppIcon {
            source: root.iconSource
            glyph: root.icon
            visible: root.icon !== "" && root.leading === null
            size: root.iconSize
            imageSize: root.iconSize + Appearance.size.appIconGrow
            color: root.iconColour
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            spacing: 0

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: root.title
                visible: root.title !== ""
                font.family: root.titleMono ? Appearance.font.mono : Appearance.font.ui
                font.pixelSize: Appearance.size.body
                color: root.titleColour
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.subtitle
                visible: root.subtitle !== ""
                font.family: root.subtitleMono ? Appearance.font.mono : Appearance.font.ui
                font.pixelSize: Appearance.size.micro
                color: root.subtitleColour
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Loader {
            active: root.trailing !== null
            visible: active
            sourceComponent: root.trailing
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: root.trailingText
            visible: root.trailingText !== "" && root.trailing === null
            font.family: Appearance.font.mono
            font.pixelSize: Appearance.size.micro
            color: root.subtitleColour
            Layout.alignment: Qt.AlignVCenter
        }

        Icon {
            text: root.trailingIcon
            visible: root.trailingIcon !== "" && root.trailing === null && root.trailingText === ""
            size: Appearance.size.iconLabel
            color: root.selected ? Colours.on.primaryContainer : Colours.outline
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.clicked();
        }
    }
}
