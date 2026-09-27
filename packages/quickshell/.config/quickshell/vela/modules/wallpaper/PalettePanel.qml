pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.services
import qs.components

// The wallpaper switcher's left panel: the palette this image *would* generate,
// six swatches with their hex, and the two ways to commit it.
//
// The swatches are not a guess and not the running theme -- they are what
// `matugen --dry-run --json hex` answers for the selected image, which is the
// same extraction the apply would do. That is the whole point of the panel:
// you are looking at the result before you take it.
//
// Above them, light, dark or auto: the swatches are the palette in the mode
// picked, and Apply sets the mode with the wallpaper.
//
// Apply is explicit, and there are two of them, because they are different
// things. "Apply" sets the wallpaper everywhere and re-themes from it; "Set
// for this monitor" changes one screen's image and leaves the palette alone --
// there is one palette and it follows the wallpaper the user chose for the
// shell, not the last screen they happened to be pointing at.
Card {
    id: root

    property string path
    property string monitor
    property string mode

    readonly property var modes: ["light", "dark", "auto"]

    signal modePicked(string mode)

    readonly property var swatches: {
        const p = Wallpaper.previewPalette;
        return [p.primary, p.primaryContainer, p.secondary, p.tertiary, p.surface, p.surfaceContainer];
    }

    readonly property string note: {
        if (!Wallpaper.themerAvailable)
            return qsTr("matugen is not installed · the image changes, the palette does not");
        if (Wallpaper.applying)
            return qsTr("re-theming…");
        if (Wallpaper.lastRebuildMs > 0)
            return qsTr("bar, panels and lock re-theme in ~%1 ms").arg(Wallpaper.lastRebuildMs);
        return qsTr("bar, panels and lock re-theme from the wallpaper");
    }

    signal applied
    signal appliedToMonitor

    radius: Appearance.radius.cardXl
    implicitHeight: column.implicitHeight + root.padding * 2

    ColumnLayout {
        id: column

        anchors.fill: parent
        spacing: Appearance.wallpaper.paletteGap

        RowLayout {
            spacing: Appearance.space.sm

            Layout.fillWidth: true

            SectionLabel {
                text: qsTr("Palette this generates")

                Layout.fillWidth: true
            }

            Text {
                // "scheme-tonal-spot · dark" -- the variant and the mode the
                // apply would run with; under auto, which one the sun says.
                text: Wallpaper.schemeLabel
                font.family: Appearance.font.mono
                font.pixelSize: Appearance.size.micro
                color: Colours.outline

                Layout.alignment: Qt.AlignVCenter
            }

            Segmented {
                readonly property int wanted: Math.max(0, root.modes.indexOf(root.mode))

                model: [qsTr("Light"), qsTr("Dark"), qsTr("Auto")]
                currentIndex: wanted
                segmentHeight: Appearance.wallpaper.modeHeight
                fontSize: Appearance.size.caption
                railRadius: Appearance.radius.card
                onWantedChanged: currentIndex = wanted
                onSelected: i => root.modePicked(root.modes[i])

                Layout.alignment: Qt.AlignVCenter
            }
        }

        RowLayout {
            spacing: Appearance.wallpaper.swatchGap

            Layout.fillWidth: true

            Repeater {
                model: root.swatches

                ColumnLayout {
                    id: swatch

                    required property string modelData

                    spacing: Appearance.wallpaper.swatchLabelGap

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1

                    Rectangle {
                        implicitHeight: Appearance.wallpaper.swatchHeight
                        radius: Appearance.wallpaper.swatchRadius
                        // Empty while matugen has not answered yet: the track
                        // fill, so the panel keeps its shape rather than
                        // collapsing and springing back.
                        color: swatch.modelData === "" ? Colours.track : swatch.modelData

                        Layout.fillWidth: true

                        Behavior on color {
                            enabled: !Colours.crossing

                            ColorAnimation {
                                duration: Appearance.anim.normal
                                easing.type: Appearance.anim.enterEasing
                            }
                        }
                    }

                    Text {
                        // A hex is a literal, and upper case because that is
                        // how the design and matugen both write one.
                        text: swatch.modelData.toUpperCase()
                        font.family: Appearance.font.mono
                        font.pixelSize: Appearance.wallpaper.hexSize
                        color: Colours.outline
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                    }
                }
            }
        }

        RowLayout {
            spacing: Appearance.wallpaper.actionGap

            Layout.fillWidth: true
            Layout.topMargin: 2

            Pill {
                id: apply

                text: qsTr("Apply")
                // The screen's single affirmative verb.
                tone: "filled"
                pillHeight: Appearance.wallpaper.actionHeight
                enabled: root.path !== ""
                onClicked: root.applied()

                // The key that does it, in mono, because a keybind is a
                // literal -- the design writes "↵ Apply" as one label.
                leading: Text {
                    text: "↵"
                    font.family: Appearance.font.mono
                    font.pixelSize: apply.fontSize
                    color: apply.foreground
                }
            }

            Pill {
                text: qsTr("Set for this monitor")
                tone: "subtle"
                pillHeight: Appearance.wallpaper.actionHeight
                enabled: root.path !== "" && root.monitor !== ""
                onClicked: root.appliedToMonitor()
            }

            // Takes the slack itself rather than sitting behind a spacer: a
            // RowLayout lays a fixed item out at its implicit width and lets it
            // overflow, so the note has to be the thing that gives when the
            // panel is narrower than the design's 1120.
            Text {
                text: root.note
                font.family: Appearance.font.mono
                font.pixelSize: Appearance.size.micro
                color: Colours.outline
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight

                Layout.fillWidth: true
            }
        }
    }
}
