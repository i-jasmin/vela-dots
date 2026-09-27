import qs.tokens

// The now-playing waveform on the dashboard: the same bars as a Sparkline,
// split at the playhead. Played is `primary` -- playing media is one of the
// three things the design lets carry colour -- and the tail is `muted`, which
// is the one neutral quiet enough to sit under it without reading as a second
// accent.
//
//     Waveform {
//         values: Mpris.levels        // 0-1 amplitudes, one per bar
//         progress: Mpris.position / Mpris.length
//     }
//
// Amplitudes are already normalised, so the scale is pinned: a quiet passage
// should look quiet, not be rescaled up to fill the box.
Sparkline {
    maxValue: 1
    progress: 0
    barSpacing: Appearance.widget.waveformBarSpacing
    fill: Colours.muted
    // The design softens the played bars to 90%, which keeps a 28-bar block of
    // accent from shouting over the track title beside it.
    highlight: Colours.alpha(Colours.primary, 0.9)
    implicitHeight: Appearance.widget.waveformHeight
}
