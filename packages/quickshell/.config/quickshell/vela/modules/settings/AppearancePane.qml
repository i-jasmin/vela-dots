pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.tokens
import qs.components

// Settings, Appearance. Where the palette comes from, how far it drifts from
// its source, whether it is light or dark, the two knobs that change the shape
// and weight of every surface in the shell, and how it all moves.
//
// NOTHING HERE IS HELD. Every control reads `Config` and writes `Config`, and
// `shell.qml` binds `Config.appearance.radiusScale`, `.panelOpacity`,
// `.reduceMotion`, `.animations`, `.animationSpeed` and `.mode` straight onto
// the token singletons -- so a slider dragged on this screen moves the bar
// behind it on the same frame. `Persist` then coalesces the write back to
// shell.json.
//
// RE-ASSERTING A CONTROL. `Segmented`, `Slider` and `Toggle` all assign their
// own value on interaction, which destroys any binding the call site had put on
// it. That is fine for a control that owns its value and wrong for one that is
// a view of a config file, because the file can also change underneath -- by
// hand, or from the other end of `matugen`. So each control below binds its
// value once, for the first frame, and re-asserts it from a `wanted` property
// whenever the config moves. It is two lines per control and it is what makes
// `shell.json` and this window the same thing rather than two copies of it.
//
// In a PaneScroll, like the other long pages: with the motion settings it is
// taller than the window.
PaneScroll {
    id: root

    readonly property var schemes: ["scheme-tonal-spot", "scheme-neutral", "scheme-expressive"]
    readonly property var modes: ["light", "dark", "auto"]

    // The wallpaper this palette came from, with $HOME written the way a user
    // would write it. Monospace, because it is a path.
    readonly property string sourcePath: {
        const p = Wallpaper.current;
        if (!p)
            return "";
        const home = Quickshell.env("HOME");
        return home && p.startsWith(home) ? "~" + p.slice(home.length) : p;
    }

    // The note under the path is a statement about the user's machine, so it
    // says what is actually true of it rather than repeating the design.
    readonly property string sourceNote: {
        if (!Wallpaper.themerAvailable)
            return qsTr("matugen is not installed — the palette stays as generated");
        if (!Config.appearance.generateFromWallpaper)
            return qsTr("Off — the palette stays as it was last generated");
        if (Wallpaper.lastRebuildMs > 0)
            return qsTr("matugen rebuilds the palette on every wallpaper change · last took %1 ms").arg(Wallpaper.lastRebuildMs);
        return qsTr("matugen rebuilds the palette on every wallpaper change");
    }

    readonly property bool canRetheme: Wallpaper.themerAvailable && Wallpaper.current !== ""

    // Re-run matugen against the current wallpaper with whatever scheme and
    // mode are now set. This is the screen's one affirmative action: the other
    // controls here change a colour the shell already has, and this is the one
    // that goes and gets new ones.
    function retheme(): void {
        Persist.now();
        if (root.canRetheme && Config.appearance.generateFromWallpaper)
            Wallpaper.retint(Wallpaper.current);
    }

    PaneHeader {
        title: qsTr("Appearance")

        Pill {
            text: qsTr("Reload")
            tone: "subtle"
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize
            // Re-reads shell.json, the generated scheme.json and the QML
            // itself from disk. The shell already follows the first two, so
            // this is for the case a file changed behind the window's back.
            //
            // IT CLOSES THIS WINDOW, because a reload does not keep
            // `ShellState`. The
            // obvious fix -- a `PersistentProperties` carrying the open flag
            // across -- crashes Quickshell 0.3.1 outright on the reload it is
            // meant to survive (measured: `QObject::connect(QObject,
            // EngineGeneration): invalid nullptr parameter`, then SIGSEGV), so
            // it is not taken here.
            onClicked: Quickshell.reload(false)
        }

        Pill {
            text: qsTr("Apply")
            tone: "filled"
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize
            enabled: root.canRetheme
            onClicked: root.retheme()
        }
    }

    Section {
        title: qsTr("Colour scheme")

        SettingRow {
            leading: preview
            title: qsTr("Generate from wallpaper")
            detail: root.sourcePath || qsTr("no wallpaper set")
            subtitle: root.sourceNote
            labelGap: Appearance.settings.labelGap
            gap: Appearance.settings.previewGap

            Toggle {
                readonly property bool wanted: Config.appearance.generateFromWallpaper

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.appearance.generateFromWallpaper = on;
                    Persist.commit();
                    if (on)
                        root.retheme();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        Divider {}

        SettingRow {
            title: qsTr("Scheme variant")
            subtitle: qsTr("How far the palette drifts from the source colour")
            gap: Appearance.settings.rowGapTight

            Segmented {
                readonly property int wanted: Math.max(0, root.schemes.indexOf(Config.appearance.scheme))

                model: [qsTr("Tonal spot"), qsTr("Neutral"), qsTr("Expressive")]
                currentIndex: wanted
                segmentHeight: Appearance.settings.segmentHeight
                hPadding: Appearance.settings.segmentPad
                railRadius: Appearance.radius.card
                onWantedChanged: currentIndex = wanted
                onSelected: i => {
                    Config.appearance.scheme = root.schemes[i];
                    // A variant is not a colour the shell already has, so the
                    // only way this control can move the running shell is to
                    // go and generate the palette again.
                    root.retheme();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        Divider {}

        SettingRow {
            title: qsTr("Mode")
            subtitle: qsTr("Follows sunset when set to auto")
            gap: Appearance.settings.rowGapTight

            Segmented {
                readonly property int wanted: Math.max(0, root.modes.indexOf(Config.appearance.mode))

                model: [qsTr("Light"), qsTr("Dark"), qsTr("Auto")]
                currentIndex: wanted
                segmentHeight: Appearance.settings.segmentHeight
                hPadding: Appearance.settings.segmentPad
                railRadius: Appearance.radius.card
                onWantedChanged: currentIndex = wanted
                onSelected: i => {
                    Config.appearance.mode = root.modes[i];
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    Section {
        title: qsTr("Shape & density")
        gap: Appearance.settings.cardGapWide

        SettingRow {
            title: qsTr("Corner radius")
            subtitle: qsTr("Panels and cards")
            labelWidth: Appearance.settings.labelWidth

            SettingSlider {
                // `radius.panel` is the slider's own unit: it is 22 at the
                // default scale and it is what every other radius in the shell
                // is derived from, so the readout and the thing being read out
                // cannot drift apart.
                readonly property real wanted: Appearance.radius.panel / Appearance.settings.radiusMax

                value: wanted
                stepSize: 1 / Appearance.settings.radiusMax
                onWantedChanged: value = wanted
                onMoved: v => {
                    Config.appearance.radiusScale = v * Appearance.settings.radiusMax / Appearance.settings.radiusBase;
                    Persist.commit();
                }
            }

            SettingValue {
                text: qsTr("%1 px").arg(Appearance.radius.panel)
            }
        }

        SettingRow {
            title: qsTr("Panel opacity")
            subtitle: qsTr("Behind the blur")
            labelWidth: Appearance.settings.labelWidth

            SettingSlider {
                readonly property real wanted: Config.appearance.panelOpacity

                value: wanted
                stepSize: 0.01
                onWantedChanged: value = wanted
                onMoved: v => {
                    Config.appearance.panelOpacity = v;
                    Persist.commit();
                }
            }

            SettingValue {
                text: qsTr("%1 %").arg(Math.round(Appearance.panelOpacity * 100))
            }
        }
    }

    // ---- motion -------------------------------------------------------------
    //
    // How the shell moves, and how quickly. Three ways of moving -- as
    // designed, fades without the travel, not at all -- and a speed that
    // divides every duration there is (`Appearance.scaled`): the shell's, and
    // Hyprland's window and workspace animations with it, which read the same
    // shell.json (hypr/conf/general.lua; Hypr reloads it on a change).
    Section {
        title: qsTr("Motion")
        gap: Appearance.settings.cardGapWide

        SettingRow {
            title: qsTr("Motion")
            subtitle: !Config.appearance.animations ? qsTr("Nothing animates: every change is instant") : Config.appearance.reduceMotion ? qsTr("Fades only: nothing slides, grows or zooms") : qsTr("As designed: panels grow, content slides into place")
            gap: Appearance.settings.rowGapTight

            Segmented {
                readonly property int wanted: !Config.appearance.animations ? 2 : Config.appearance.reduceMotion ? 1 : 0

                model: [qsTr("Full"), qsTr("Reduced"), qsTr("Off")]
                currentIndex: wanted
                segmentHeight: Appearance.settings.segmentHeight
                hPadding: Appearance.settings.segmentPad
                railRadius: Appearance.radius.card
                onWantedChanged: currentIndex = wanted
                onSelected: i => {
                    Config.appearance.animations = i !== 2;
                    Config.appearance.reduceMotion = i === 1;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        Divider {}

        SettingRow {
            title: qsTr("Speed")
            subtitle: qsTr("How quickly everything moves, your windows included")
            labelWidth: Appearance.settings.labelWidth
            enabled: Config.appearance.animations
            opacity: enabled ? 1 : Appearance.settings.disabledOpacity

            SettingSlider {
                readonly property real wanted: (Config.appearance.animationSpeed - Appearance.settings.speedMin) / (Appearance.settings.speedMax - Appearance.settings.speedMin)

                value: wanted
                stepSize: Appearance.settings.speedStep / (Appearance.settings.speedMax - Appearance.settings.speedMin)
                onWantedChanged: value = wanted
                onMoved: v => {
                    const speed = Appearance.settings.speedMin + v * (Appearance.settings.speedMax - Appearance.settings.speedMin);
                    Config.appearance.animationSpeed = Math.round(speed / Appearance.settings.speedStep) * Appearance.settings.speedStep;
                    Persist.commit();
                }
            }

            SettingValue {
                text: qsTr("%1×").arg(Number(Config.appearance.animationSpeed.toFixed(2)))
            }
        }
    }

    // The wallpaper the palette came from, with the three accent roles it
    // produced drawn over it -- so "generate from wallpaper" shows its own
    // working rather than asserting it.
    Component {
        id: preview

        ClippingRectangle {
            implicitWidth: Appearance.settings.previewWidth
            implicitHeight: Appearance.settings.previewHeight
            radius: Appearance.radius.chip
            color: Colours.surfaceContainerHigh
            border.width: 1
            border.color: Colours.panelBorder

            Image {
                anchors.fill: parent
                // The cached 480px thumbnail when the folder scan has
                // produced one, the image itself when it has not -- a preview
                // that decodes slowly is better than an empty square.
                source: Wallpaper.entryFor(Wallpaper.current)?.thumbnail ?? Wallpaper.current
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: Appearance.settings.previewWidth * 2
            }

            RowLayout {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Appearance.settings.swatchInset
                spacing: Appearance.settings.swatchGap

                Repeater {
                    model: [Colours.primary, Colours.secondary, Colours.tertiary]

                    Rectangle {
                        required property color modelData

                        implicitWidth: Appearance.settings.swatch
                        implicitHeight: Appearance.settings.swatch
                        radius: height / 2
                        color: modelData
                    }
                }
            }
        }
    }
}
