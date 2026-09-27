import QtQuick
import qs.tokens

// A key as the user would press it: `esc` on the launcher, `↵` on the selected
// result, `super` in the overview legend. Mono, because a keybind is a literal.
//
// Two tones only. On a neutral surface it is a quiet grey chip; on a selected
// row it inherits that row's foreground, so the ↵ in the launcher reads as part
// of the selection rather than as a second accent.
Rectangle {
    id: root

    // The label. A glyph ("↵", "⇥") or a word ("esc", "super").
    property string key
    // Set on a row that is already `primaryContainer`.
    property bool onAccent: false
    // The keybinds cheatsheet's key: a fixed-height chip, a step brighter, for
    // when the keys are the content rather than a hint beside it.
    property bool large: false

    implicitWidth: root.large ? Math.max(Appearance.keybinds.keyHeight, label.implicitWidth + Appearance.keybinds.keyPad * 2) : label.implicitWidth + Appearance.space.sm * 2
    implicitHeight: root.large ? Appearance.keybinds.keyHeight : label.implicitHeight + Appearance.space.xs * 2
    radius: root.large ? Appearance.keybinds.keyRadius : Appearance.radius.small
    color: root.onAccent ? Colours.alpha(Colours.on.primaryContainer, 0.12) : root.large ? Colours.alpha(Colours.on.surface, Appearance.keybinds.keyAlpha) : Colours.hover

    Text {
        id: label

        anchors.centerIn: parent
        text: root.key
        // A key name is never markup: `<` is a key.
        textFormat: Text.PlainText
        font.family: Appearance.font.mono
        font.pixelSize: Appearance.size.micro
        color: root.onAccent ? Colours.on.primaryContainer : root.large ? Colours.on.surfaceVariant : Colours.outline
    }
}
