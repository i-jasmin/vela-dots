pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
// After QtQuick deliberately: this is what every module doing the same gets,
// and it is the only way `Row` here means the component next door rather than
// QtQuick's positioner. See the note at the top of Row.qml.
import qs.components
import qs.tokens

// Every component in the library, in every state it has, in one window, at the
// sizes the design draws them. This is a development tool: nothing in the
// shell instantiates it, and it is the thing to look at when changing a
// component rather than the running desktop.
//
//     cp -a ~/.config/quickshell/vela /tmp/vela-gallery
//     printf 'import Quickshell\nimport qs.components\nShellRoot { Gallery {} }\n' \
//         > /tmp/vela-gallery/shell.qml
//     qs -p /tmp/vela-gallery
//
// Sample values are the ones in the design, so a screenshot of this window can
// be held against the bar's popouts, the dashboard, the launcher and the
// Appearance page directly.
FloatingWindow {
    id: root

    // The dashboard's network card, oldest sample first.
    readonly property list<real> netSamples: [18, 26, 14, 44, 72, 96, 64, 38, 22, 30, 52, 34, 20, 16]
    // The dashboard's now-playing waveform: 28 bars, 20 of them played.
    readonly property list<real> levels: [0.30, 0.58, 0.82, 0.46, 0.96, 0.64, 0.38, 0.74, 0.52, 0.88, 0.34, 0.62, 0.44, 0.78, 0.28, 0.56, 0.92, 0.48, 0.70, 0.36, 0.60, 0.42, 0.76, 0.32, 0.54, 0.86, 0.40, 0.66]

    property real volume: 0.62
    property bool airplane: false
    property bool wallpaperScheme: true
    property int profile: 1
    property int variant: 0

    // The motion section's state.
    property bool expanded: false
    property bool listShown: true
    property int pane: 0

    title: "vela components"
    color: Colours.surface
    implicitWidth: 1240
    implicitHeight: 1000

    component Section: ColumnLayout {
        id: section

        property string label

        spacing: Appearance.space.md
        Layout.fillWidth: true

        Text {
            text: section.label.toUpperCase()
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.caption
            font.letterSpacing: Appearance.size.caption * Appearance.captionTracking
            color: Colours.outline
        }
    }

    component Note: Text {
        font.family: Appearance.font.mono
        font.pixelSize: Appearance.size.micro
        color: Colours.outline
    }

    Flickable {
        id: page

        anchors.fill: parent
        contentHeight: column.implicitHeight + Appearance.space.overlayMargin * 2
        contentWidth: width
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: column

            x: Appearance.space.overlayMargin
            y: Appearance.space.overlayMargin
            width: page.width - Appearance.space.overlayMargin * 2
            spacing: Appearance.space.xl + Appearance.space.sm

            // ---- Panel ----------------------------------------------------
            Section {
                label: "Panel · 4 levels, shadow gutter reserved by the layout"

                RowLayout {
                    spacing: Appearance.space.xl

                    Panel {
                        id: barPanel

                        level: "bar"
                        radius: Appearance.radius.barV
                        implicitWidth: Appearance.bar.thicknessVertical
                        implicitHeight: 120

                        Layout.margins: barPanel.shadowGutter

                        Text {
                            anchors.centerIn: parent
                            text: "bar"
                            font.family: Appearance.font.ui
                            font.pixelSize: Appearance.size.label
                            color: Colours.on.surfaceVariant
                        }
                    }

                    Panel {
                        id: popoutPanel

                        level: "popout"
                        padding: Appearance.space.md + 2
                        implicitWidth: 292
                        implicitHeight: 120

                        Layout.margins: popoutPanel.shadowGutter

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Appearance.space.sm

                            RowLayout {
                                spacing: Appearance.space.sm + 2

                                Icon {
                                    text: "volume_up"
                                    color: Colours.primary
                                    size: Appearance.size.iconMd
                                }

                                Text {
                                    text: "Output"
                                    font.family: Appearance.font.ui
                                    font.pixelSize: Appearance.size.body
                                    color: Colours.on.surface
                                }
                            }

                            Note {
                                text: "popout · 292 × r20 · .92"
                            }

                            Item {
                                Layout.fillHeight: true
                            }
                        }
                    }

                    Panel {
                        id: drawerPanel

                        level: "drawer"
                        implicitWidth: 260
                        implicitHeight: 120

                        Layout.margins: drawerPanel.shadowGutter

                        Note {
                            anchors.centerIn: parent
                            text: "drawer · r26 · gutter " + drawerPanel.shadowGutter
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            // ---- Card -----------------------------------------------------
            Section {
                label: "Card · r15 / r18 / r20"

                RowLayout {
                    spacing: Appearance.space.md

                    Card {
                        implicitWidth: 200
                        implicitHeight: 88

                        Note {
                            anchors.centerIn: parent
                            text: "card · 15"
                        }
                    }

                    Card {
                        radius: Appearance.radius.cardLg
                        padding: Appearance.space.lg + 2
                        implicitWidth: 200
                        implicitHeight: 88

                        Note {
                            anchors.centerIn: parent
                            text: "cardLg · 18"
                        }
                    }

                    Card {
                        radius: Appearance.radius.cardXl
                        implicitWidth: 200
                        implicitHeight: 88

                        Note {
                            anchors.centerIn: parent
                            text: "cardXl · 20"
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            // ---- Pill -----------------------------------------------------
            Section {
                label: "Pill · tones, then the four heights"

                RowLayout {
                    spacing: Appearance.space.sm

                    Pill {
                        text: "plain"
                        tone: "plain"
                    }

                    Pill {
                        text: "subtle"
                    }

                    Pill {
                        text: "Pause"
                        icon: "pause"
                        tone: "accent"
                    }

                    Pill {
                        text: "Apply"
                        tone: "filled"
                        pillHeight: 32
                        fontSize: Appearance.size.label + 0.5
                    }

                    Pill {
                        text: "Shut down"
                        icon: "power_settings_new"
                        tone: "danger"
                    }

                    Pill {
                        text: "disabled"
                        enabled: false
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    spacing: Appearance.space.sm

                    Pill {
                        text: "26"
                        pillHeight: 26
                    }

                    Pill {
                        text: "28"
                        pillHeight: 28
                    }

                    Pill {
                        text: "30"
                        pillHeight: 30
                        fontSize: Appearance.size.body
                    }

                    Pill {
                        text: "32"
                        pillHeight: 32
                        fontSize: Appearance.size.body
                    }

                    // The dashboard's health chip: a Pill with its container
                    // colour overridden, which is how any tinted chip is made.
                    Pill {
                        text: "All systems nominal"
                        tone: "plain"
                        pillHeight: 30
                        color: Colours.alpha(Colours.tertiary, 0.1)
                        foreground: Colours.tertiary
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            // ---- Segmented ------------------------------------------------
            Section {
                label: "Segmented · power profiles (28, equal), scheme variant (26), tabs (30)"

                RowLayout {
                    spacing: Appearance.space.xl

                    Segmented {
                        model: ["Saver", "Balanced", "Performance"]
                        currentIndex: root.profile
                        equalWidths: true
                        segmentRadius: Appearance.radius.chip
                        implicitWidth: 264
                        onSelected: i => root.profile = i
                    }

                    Segmented {
                        model: ["Tonal spot", "Neutral", "Expressive"]
                        currentIndex: root.variant
                        segmentHeight: 26
                        onSelected: i => root.variant = i
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Segmented {
                    model: [
                        {
                            "label": "Dashboard",
                            "icon": "dashboard"
                        },
                        {
                            "label": "Media",
                            "icon": "graphic_eq"
                        },
                        {
                            "label": "Performance",
                            "icon": "speed"
                        },
                        {
                            "label": "Weather",
                            "icon": "partly_cloudy_day"
                        }
                    ]
                    segmentHeight: 30
                    inset: Appearance.space.xs
                    fontSize: Appearance.size.body
                    iconSize: Appearance.size.iconLabel
                }
            }

            // ---- Slider ---------------------------------------------------
            Section {
                label: "Slider · master (6 + bar handle), settings (round handle), per-app (5, no handle)"

                RowLayout {
                    spacing: Appearance.space.md - 1

                    Icon {
                        text: "volume_up"
                        size: Appearance.size.iconRow
                    }

                    Slider {
                        value: root.volume
                        onMoved: v => root.volume = v

                        Layout.fillWidth: true
                        Layout.maximumWidth: 320
                    }

                    Note {
                        text: Math.round(root.volume * 100)
                        horizontalAlignment: Text.AlignRight

                        Layout.preferredWidth: 24
                    }

                    Slider {
                        value: 0.55
                        handleWidth: 16
                        handleHeight: 16

                        Layout.fillWidth: true
                        Layout.maximumWidth: 320
                    }

                    Note {
                        text: "22 px"
                        color: Colours.on.surfaceVariant
                        horizontalAlignment: Text.AlignRight

                        Layout.preferredWidth: 56
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    spacing: Appearance.space.md - 1

                    Icon {
                        text: "graphic_eq"
                        size: Appearance.size.iconSm
                        color: Colours.outline
                    }

                    Slider {
                        value: 0.8
                        trackHeight: 5
                        handleWidth: 0
                        fill: Colours.secondary

                        Layout.fillWidth: true
                        Layout.maximumWidth: 220
                    }

                    Text {
                        text: "Spotify"
                        font.family: Appearance.font.ui
                        font.pixelSize: Appearance.size.micro
                        color: Colours.outline
                    }

                    Slider {
                        value: 0
                        trackHeight: 5
                        handleWidth: 0
                        fill: Colours.secondary

                        Layout.fillWidth: true
                        Layout.maximumWidth: 120
                    }

                    Slider {
                        value: 1
                        trackHeight: 5
                        handleWidth: 0
                        fill: Colours.secondary

                        Layout.fillWidth: true
                        Layout.maximumWidth: 120
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            // ---- Toggle ---------------------------------------------------
            Section {
                label: "Toggle · 44 × 26 and 40 × 22, off and on"

                RowLayout {
                    spacing: Appearance.space.lg

                    Toggle {
                        checked: root.airplane
                        trackWidth: 40
                        trackHeight: 22
                        onToggled: on => root.airplane = on
                    }

                    Toggle {
                        checked: true
                        trackWidth: 40
                        trackHeight: 22
                    }

                    Toggle {
                        checked: false
                    }

                    Toggle {
                        checked: root.wallpaperScheme
                        onToggled: on => root.wallpaperScheme = on
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            // ---- Row ------------------------------------------------------
            Section {
                label: "Row · 40 popout, 48 launcher, 44 clipboard"

                RowLayout {
                    spacing: Appearance.space.xl

                    Panel {
                        id: rowPanel

                        level: "popout"
                        padding: Appearance.space.md + 2
                        implicitWidth: 292
                        implicitHeight: rowList.implicitHeight + padding * 2

                        Layout.margins: rowPanel.shadowGutter

                        ColumnLayout {
                            id: rowList

                            anchors.fill: parent
                            spacing: 0

                            Row {
                                icon: "headphones"
                                title: "WH-1000XM4"
                                subtitle: "AAC · 84% battery"
                                selected: true

                                Layout.fillWidth: true
                            }

                            Row {
                                icon: "speaker"
                                title: "Built-in Analog Stereo"
                                titleColour: Colours.on.surfaceVariant

                                Layout.fillWidth: true
                            }

                            Row {
                                icon: "cast"
                                title: "HDMI / DisplayPort"
                                titleColour: Colours.on.surfaceVariant

                                Layout.fillWidth: true
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 2

                        Layout.fillWidth: true
                        Layout.maximumWidth: 380

                        Row {
                            title: "OBS Studio"
                            subtitle: "Screen recording & streaming"
                            selected: true
                            rowHeight: 48
                            spacing: Appearance.space.md

                            leading: Rectangle {
                                implicitWidth: 30
                                implicitHeight: 30
                                radius: Appearance.radius.small
                                color: Colours.alpha(Colours.on.primaryContainer, 0.12)

                                Icon {
                                    anchors.centerIn: parent
                                    text: "videocam"
                                    size: Appearance.size.iconMd
                                    color: Colours.on.primaryContainer
                                }
                            }

                            trailing: Keycap {
                                key: "↵"
                                onAccent: true
                            }

                            Layout.fillWidth: true
                        }

                        Row {
                            title: "obs-cli --scene desk"
                            subtitle: "Run command"
                            titleMono: true
                            rowHeight: 48
                            spacing: Appearance.space.md

                            leading: Rectangle {
                                implicitWidth: 30
                                implicitHeight: 30
                                radius: Appearance.radius.small
                                color: Colours.hover

                                Icon {
                                    anchors.centerIn: parent
                                    text: "terminal"
                                    size: Appearance.size.iconMd
                                    color: Colours.outline
                                }
                            }

                            Layout.fillWidth: true
                        }

                        Row {
                            // Sample data, derived so the swatch and the hex agree.
                            title: Colours.primary.toString().toUpperCase()
                            titleMono: true
                            trailingText: "14m"
                            rowHeight: 44

                            leading: Rectangle {
                                implicitWidth: 18
                                implicitHeight: 18
                                radius: Appearance.radius.xs
                                color: Colours.primary
                            }

                            Layout.fillWidth: true
                        }

                        Row {
                            icon: "link"
                            title: "wiki.hyprland.org/Configuring/Variables"
                            titleColour: Colours.on.surfaceVariant
                            trailingText: "31m"
                            rowHeight: 44

                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // ---- Keycap ---------------------------------------------------
            Section {
                label: "Keycap · mono, on surface and on an accent row"

                RowLayout {
                    spacing: Appearance.space.md

                    Keycap {
                        key: "esc"
                    }

                    Keycap {
                        key: "↵"
                    }

                    Keycap {
                        key: "⇥"
                    }

                    Keycap {
                        key: "super"
                    }

                    Rectangle {
                        implicitWidth: accentCap.implicitWidth + Appearance.space.md * 2
                        implicitHeight: 40
                        radius: Appearance.radius.chip
                        color: Colours.primaryContainer

                        Keycap {
                            id: accentCap

                            anchors.centerIn: parent
                            key: "↵"
                            onAccent: true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            // ---- Ring -----------------------------------------------------
            Section {
                label: "Ring · focus timer 80/8, resources 56/6"

                RowLayout {
                    spacing: Appearance.space.lg

                    Ring {
                        value: 0.64
                        diameter: 80
                        thickness: 8

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0

                            Text {
                                text: "09:04"
                                font.family: Appearance.font.mono
                                font.pixelSize: Appearance.size.heading
                                color: Colours.on.surface

                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: "left"
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.size.micro
                                color: Colours.outline

                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    Repeater {
                        model: [
                            {
                                "label": "CPU",
                                "value": 0.12,
                                "colour": Colours.primary
                            },
                            {
                                "label": "RAM",
                                "value": 0.38,
                                "colour": Colours.secondary
                            },
                            {
                                "label": "GPU",
                                "value": 0.07,
                                "colour": Colours.tertiary
                            },
                            {
                                "label": "Disk",
                                "value": 0.61,
                                "colour": Colours.muted
                            }
                        ]

                        ColumnLayout {
                            id: meter

                            required property var modelData

                            spacing: Appearance.space.xs + 2

                            Ring {
                                value: meter.modelData.value
                                fill: meter.modelData.colour

                                Layout.alignment: Qt.AlignHCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: Math.round(meter.modelData.value * 100)
                                    font.family: Appearance.font.mono
                                    font.pixelSize: Appearance.size.label
                                    color: Colours.on.surface
                                }
                            }

                            Text {
                                text: meter.modelData.label
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.size.micro
                                color: Colours.outline

                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            // ---- Sparkline and Waveform -----------------------------------
            Section {
                label: "Sparkline · autoscaled, highlight over half the peak — Waveform · played / muted tail"

                RowLayout {
                    spacing: Appearance.space.xl

                    Card {
                        radius: Appearance.radius.cardXl
                        implicitWidth: 250
                        implicitHeight: sparkColumn.implicitHeight + padding * 2

                        ColumnLayout {
                            id: sparkColumn

                            anchors.fill: parent
                            spacing: Appearance.space.sm + 2

                            Text {
                                text: "NETWORK"
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.size.caption
                                font.letterSpacing: Appearance.size.caption * Appearance.captionTracking
                                color: Colours.outline
                            }

                            Sparkline {
                                values: root.netSamples
                                highlightAbove: 0.5

                                Layout.fillWidth: true
                            }

                            RowLayout {
                                Note {
                                    text: "↓ 4.2 MB/s"
                                    color: Colours.primary
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Note {
                                    text: "↑ 0.3 MB/s"
                                }
                            }
                        }
                    }

                    Card {
                        radius: Appearance.radius.cardXl
                        implicitWidth: 300
                        implicitHeight: waveColumn.implicitHeight + padding * 2

                        ColumnLayout {
                            id: waveColumn

                            anchors.fill: parent
                            spacing: Appearance.space.sm

                            Text {
                                text: "Says"
                                font.family: Appearance.font.ui
                                font.pixelSize: Appearance.size.heading
                                color: Colours.on.surface
                            }

                            Waveform {
                                values: root.levels
                                progress: 20 / 28

                                Layout.fillWidth: true
                            }

                            RowLayout {
                                Note {
                                    text: "3:41"
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Note {
                                    text: "9:32"
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            // ---- Icon -----------------------------------------------------
            Section {
                label: "Icon · 14 / 15 / 16 / 17 / 18 / 21, weight 300, unfilled"

                RowLayout {
                    spacing: Appearance.space.lg

                    Repeater {
                        model: [Appearance.size.iconXs, Appearance.size.iconSm, Appearance.size.iconLabel, Appearance.size.iconRow, Appearance.size.iconMd, Appearance.size.iconLg]

                        Icon {
                            required property var modelData

                            text: "expand_circle_down"
                            size: modelData
                        }
                    }

                    Icon {
                        text: "wifi"
                        color: Colours.primary
                        size: Appearance.size.iconLg
                    }

                    Icon {
                        text: "bluetooth"
                        color: Colours.on.surface
                        size: Appearance.size.iconLg
                    }

                    Icon {
                        text: "power_settings_new"
                        color: Colours.error
                        size: Appearance.size.iconLg
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            // ---- Motion ---------------------------------------------------
            //
            // The expressive register's three pieces, each with the control
            // that sets it off. Run with reduceMotion on as well: nothing
            // should travel or change size, only fade.
            Section {
                label: "Motion · MorphBox / Stagger / Crossfade"

                RowLayout {
                    spacing: Appearance.space.xl
                    Layout.alignment: Qt.AlignTop

                    ColumnLayout {
                        spacing: Appearance.space.sm
                        Layout.alignment: Qt.AlignTop

                        Pill {
                            text: root.expanded ? "Fewer" : "More"
                            icon: root.expanded ? "unfold_less" : "unfold_more"
                            onClicked: root.expanded = !root.expanded
                        }

                        Card {
                            radius: Appearance.radius.cardXl
                            implicitWidth: 300
                            implicitHeight: grow.implicitHeight + padding * 2

                            MorphBox {
                                id: grow

                                anchors.left: parent.left
                                anchors.right: parent.right
                                morphWidth: false

                                ColumnLayout {
                                    width: parent.width
                                    spacing: Appearance.space.sm

                                    Repeater {
                                        model: root.expanded ? 5 : 2

                                        Row {
                                            required property int index

                                            icon: "notifications"
                                            title: "Row " + (index + 1)
                                            subtitle: "The card grows to fit"
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: Appearance.space.sm
                        Layout.alignment: Qt.AlignTop

                        Pill {
                            text: "Replay"
                            icon: "replay"
                            onClicked: {
                                root.listShown = false;
                                root.listShown = true;
                            }
                        }

                        Card {
                            radius: Appearance.radius.cardXl
                            implicitWidth: 300
                            implicitHeight: list.implicitHeight + padding * 2

                            ColumnLayout {
                                id: list

                                anchors.fill: parent
                                spacing: Appearance.space.sm

                                Repeater {
                                    model: 6

                                    Row {
                                        id: item

                                        required property int index

                                        icon: "apps"
                                        title: "Item " + (item.index + 1)
                                        subtitle: "Arrives " + arrival.delay + " ms in"
                                        opacity: arrival.opacity
                                        transform: Translate {
                                            y: arrival.offset
                                        }
                                        Layout.fillWidth: true

                                        Stagger {
                                            id: arrival

                                            index: item.index
                                            active: root.listShown
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: Appearance.space.sm
                        Layout.alignment: Qt.AlignTop

                        RowLayout {
                            spacing: Appearance.space.sm

                            Pill {
                                icon: "chevron_left"
                                text: "Back"
                                onClicked: {
                                    swap.direction = -1;
                                    root.pane = (root.pane + 2) % 3;
                                }
                            }

                            Pill {
                                icon: "chevron_right"
                                text: "Next"
                                onClicked: {
                                    swap.direction = 1;
                                    root.pane = (root.pane + 1) % 3;
                                }
                            }
                        }

                        Card {
                            radius: Appearance.radius.cardXl
                            implicitWidth: 300
                            implicitHeight: 140
                            clip: true

                            Crossfade {
                                id: swap

                                anchors.fill: parent
                                vertical: false
                                component: root.pane === 0 ? paneOne : root.pane === 1 ? paneTwo : paneThree
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    component Pane: ColumnLayout {
        id: pane

        property string heading
        property string glyph

        spacing: Appearance.space.sm

        Icon {
            text: pane.glyph
            size: Appearance.size.iconLg
            color: Colours.primary
        }

        Text {
            text: pane.heading
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.heading
            color: Colours.on.surface
        }

        Note {
            text: "Crossfade, across"
        }
    }

    Component {
        id: paneOne

        Pane {
            heading: "One"
            glyph: "looks_one"
        }
    }

    Component {
        id: paneTwo

        Pane {
            heading: "Two"
            glyph: "looks_two"
        }
    }

    Component {
        id: paneThree

        Pane {
            heading: "Three"
            glyph: "looks_3"
        }
    }
}
