pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.tokens

// The settings window's write path, and the only one it has.
//
// The settings pages hold no state of their own: every control reads `Config`
// and writes `Config`, so the running shell moves the instant a control does
// and there is no second, pending copy of a setting to drift out of step with
// the first. What is left over is persistence -- `Config` owns the only
// FileView over shell.json, and `Config.save()` is the only way back to disk.
//
// The write is coalesced rather than immediate because that same FileView
// *watches* the file it would be writing: a slider dragged across its track
// would write and re-read shell.json on every frame. `commit()` after a change
// the user made, `now()` when the user asked for it in as many words.
//
// A singleton rather than a property on the window, because the panes are
// loaded into it from their own files and cannot see its id -- the same reason
// `modules/bar/BarPopouts.qml` is one.
Singleton {
    id: root

    function commit(): void {
        flush.restart();
    }

    function now(): void {
        flush.stop();
        Config.save();
    }

    Timer {
        id: flush

        interval: Appearance.settings.saveDebounce
        onTriggered: Config.save()
    }
}
