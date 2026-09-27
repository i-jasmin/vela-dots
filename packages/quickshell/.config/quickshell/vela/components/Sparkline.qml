import QtQuick
import qs.tokens

// A rolling window of samples as bars: the network throughput graph on the
// dashboard. Bars rather than a line because that is what the design draws --
// and a bar per sample stays honest at fourteen samples, where a smoothed line
// would invent values between them.
//
//     Sparkline {
//         values: Net.rxHistory      // oldest first
//         highlightAbove: 0.5        // bars over half the peak carry `primary`
//     }
//
// `maxValue` of 0 autoscales to the tallest sample, which is what a byte rate
// wants; pin it to 1 for anything already normalised, or the graph rescales
// under its own feet every tick.
//
// Two colouring rules, both off by default, never both on:
//   highlightAbove  a fraction of the peak -- the throughput graph
//   progress        a fraction of the width -- see Waveform
Item {
    id: root

    property var values: []
    property real maxValue: 0

    property real barSpacing: Appearance.widget.barSpacing
    property real barRadius: Appearance.widget.barRadius
    property real minBarHeight: Appearance.widget.barMinHeight

    property color fill: Colours.primaryContainer
    property color highlight: Colours.primary
    property real highlightAbove: -1
    property real progress: -1

    readonly property int count: root.values ? root.values.length : 0
    readonly property real peak: {
        if (root.maxValue > 0)
            return root.maxValue;
        let p = 0;
        for (let i = 0; i < root.count; i++)
            p = Math.max(p, root.values[i]);
        return p > 0 ? p : 1;
    }
    readonly property real barWidth: root.count > 0 ? Math.max(1, (root.width - root.barSpacing * (root.count - 1)) / root.count) : 0

    implicitWidth: Appearance.widget.sparklineWidth
    implicitHeight: Appearance.widget.sparklineHeight

    Repeater {
        model: root.count

        Rectangle {
            id: bar

            required property int index
            readonly property real sample: root.values[bar.index] ?? 0

            x: bar.index * (root.barWidth + root.barSpacing)
            width: root.barWidth
            height: Math.max(root.minBarHeight, Math.min(1, bar.sample / root.peak) * root.height)
            y: root.height - height
            radius: root.barRadius

            color: {
                if (root.progress >= 0)
                    return bar.index < root.progress * root.count ? root.highlight : root.fill;
                if (root.highlightAbove >= 0)
                    return bar.sample / root.peak > root.highlightAbove ? root.highlight : root.fill;
                return root.fill;
            }
        }
    }
}
