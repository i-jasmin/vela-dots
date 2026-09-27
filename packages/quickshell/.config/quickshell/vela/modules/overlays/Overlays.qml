import Quickshell

// The six surfaces that are neither the bar, a popout, nor a drawer -- the
// window picker, the clipboard, capture, sessions, what changed after an
// update, and the keybinds cheatsheet. And the frames a retint
// crossfades the windows through, which are none of those but are
// full-screen layer windows too.
//
// One Scope rather than six instantiations in `shell.qml`, because they share
// a rule: `ShellState` makes them mutually exclusive, each is a full-screen
// layer-shell window with its panel inset into it, and each is driven entirely
// from its own boolean. Nothing here holds state.
Scope {
    ClipboardPanel {}
    CaptureOverlay {}
    WindowPicker {}
    Sessions {}
    WhatChanged {}
    Cheatsheet {}
    Recolour {}
}
