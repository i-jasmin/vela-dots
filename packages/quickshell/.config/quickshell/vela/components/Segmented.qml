import QtQuick
import QtQuick.Layouts
import qs.tokens

// One choice out of three or four, shown in full: the power profiles in the
// Power popout, scheme variant and mode on the Appearance page, the dashboard's
// tab strip. A rail in the neutral hover fill, with the selected segment -- and
// only it -- in `primaryContainer`.
//
//     Segmented {
//         model: ["Saver", "Balanced", "Performance"]
//         currentIndex: Power.profileIndex
//         equalWidths: true
//         onSelected: i => Power.setProfile(i)
//     }
//
// Entries are plain strings, or `{ label, icon }` when the segment carries a
// glyph. `equalWidths` is the popout's flex:1 row; leave it off and each
// segment is as wide as its own label, which is what the settings pane does.
//
// Left and right arrows move the selection when the rail has focus: the whole
// point of a segmented control over a menu is that every option is one key
// away.
Rectangle {
    id: root

    property var model: []
    property int currentIndex: 0
    property bool equalWidths: false

    // -1 leaves each segment deriving padding from its own height. The
    // dashboard's tab strip overrides it to 16.
    property int hPadding: -1

    property int segmentHeight: Appearance.widget.segmentHeight
    // -1 leaves each segment a full pill, which is what the dashboard and the
    // Appearance page draw. The popout's 28px segments are squarer -- they pass
    // `chip`.
    property int segmentRadius: -1
    // The design's tab strip rounds its rail a step past `card`.
    property int railRadius: Appearance.radius.cardXl - 3
    property real fontSize: Appearance.size.label
    property real iconSize: Appearance.size.iconXs
    // The rail's gutter around its segments -- 3 in the popout and the settings
    // pane, 4 on the dashboard's wider tab strip.
    property int inset: Appearance.widget.segmentInset
    // One pill that slides to the chosen segment instead of each segment
    // lighting up in place -- the dashboard's tab strip and length chips.
    // `segmentWidth` fixes every segment's width, which the slide needs to
    // read as one motion; -1 leaves segments at their natural width.
    property bool sliding: false
    property int segmentWidth: -1
    property int slideDuration: Appearance.anim.normal
    property var slideCurve: []

    signal selected(int index)

    implicitWidth: row.implicitWidth + root.inset * 2
    implicitHeight: root.segmentHeight + root.inset * 2
    radius: root.railRadius
    color: Colours.hover

    activeFocusOnTab: true

    Keys.onLeftPressed: root.step(-1)
    Keys.onRightPressed: root.step(1)

    function step(by: int): void {
        const n = root.model ? root.model.length : 0;
        if (n === 0)
            return;
        const next = Math.max(0, Math.min(n - 1, root.currentIndex + by));
        if (next !== root.currentIndex) {
            root.currentIndex = next;
            root.selected(next);
        }
    }

    readonly property Item currentSegment: segments.count > 0 ? segments.itemAt(root.currentIndex) : null

    Rectangle {
        visible: root.sliding && root.currentSegment !== null
        x: row.x + (root.currentSegment?.x ?? 0)
        y: row.y + (root.currentSegment?.y ?? 0)
        width: root.currentSegment?.width ?? 0
        height: root.currentSegment?.height ?? 0
        radius: root.segmentRadius >= 0 ? root.segmentRadius : height / 2
        color: Colours.primaryContainer

        Behavior on x {
            NumberAnimation {
                duration: root.slideDuration
                easing.type: root.slideCurve.length > 0 ? Easing.BezierSpline : Appearance.anim.enterEasing
                easing.bezierCurve: root.slideCurve
            }
        }
    }

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.margins: root.inset
        spacing: Appearance.space.xs

        Repeater {
            id: segments

            model: root.model

            Pill {
                id: segment

                required property int index
                required property var modelData

                text: segment.modelData.label ?? segment.modelData
                icon: segment.modelData.icon ?? ""
                tone: "plain"
                checked: !root.sliding && segment.index === root.currentIndex
                foreground: segment.index === root.currentIndex ? Colours.on.primaryContainer : Colours.outline
                pillHeight: root.segmentHeight
                radius: root.segmentRadius >= 0 ? root.segmentRadius : segment.pillHeight / 2
                fontSize: root.fontSize
                iconSize: root.iconSize
                hPadding: root.hPadding >= 0 ? root.hPadding : Math.round((segment.pillHeight - 2) / 2)
                // A three-way rail is one control, not three tab stops: the
                // arrows move the selection, which is what the rail is for.
                // Left as stops, Tab walked through it four times and the
                // focused rail drew nothing at all.
                activeFocusOnTab: false

                Layout.fillWidth: root.equalWidths
                Layout.preferredWidth: root.segmentWidth > 0 ? root.segmentWidth : root.equalWidths ? 1 : segment.implicitWidth
                Layout.fillHeight: true

                onClicked: {
                    // The rail takes the focus, not the segment: a clicked
                    // segment kept it, and with it the focus ring, which
                    // then sat on that segment whatever was selected after
                    // -- on the dashboard's Home pill, every time it
                    // reopened. On the rail, the arrows still move it.
                    root.forceActiveFocus();
                    root.currentIndex = segment.index;
                    root.selected(segment.index);
                }
            }
        }
    }
}
