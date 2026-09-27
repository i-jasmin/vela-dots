import QtQuick
import qs.tokens
import qs.services
import qs.components

// One entry in the clipboard history list. `components/Row` does the row --
// the fill, the hover, the selected `primaryContainer`, the eliding title --
// and this decides only what a *clipboard* entry puts in it.
//
// Four shapes, and they are the reason the screen exists:
//
//   image   34px thumbnail, "Image" over "PNG · 1204 × 760 · 412 KB", 52 tall
//   colour  18px swatch of the colour itself, the hex as the title
//   link    a link glyph, the URL in Rubik because a URL is read, not typed
//   text    a ligature, monospace when the text is a literal rather than prose
//
// A pinned entry trades its timestamp for a pin: the point of pinning is
// that the entry does not age out, so how old it is stops being the
// interesting number.
Row {
    id: root

    required property var entry
    // Whether the title is a literal (path, command, hex) or prose. Decided by
    // the panel, so one rule governs the row and the preview together.
    property bool literal: false

    readonly property string kind: root.entry?.kind ?? "text"

    rowHeight: root.kind === "image" ? Appearance.overlays.clipboard.rowHeightRich : Appearance.overlays.clipboard.rowHeight
    hPadding: Appearance.overlays.clipboard.rowPadding
    spacing: Appearance.overlays.clipboard.rowGap

    // The leading slot wins over `icon`, so a thumbnail or a swatch suppresses
    // the glyph rather than sitting beside it.
    icon: root.kind === "image" || root.kind === "colour" ? "" : Clipboard.icon(root.entry)

    // An ssh-key row's glyph is tinted `tertiary`, as designed, although that
    // is a fourth use of colour beyond the three the shell otherwise keeps it
    // for.
    iconColour: root.selected ? Colours.on.primaryContainer : Clipboard.icon(root.entry) === "key" ? Colours.tertiary : Colours.outline

    title: root.kind === "image" ? qsTr("Image") : root.kind === "colour" ? root.entry.colour : root.entry?.text ?? ""

    // The design does not give every row the same weight: a row whose title is
    // the entry itself -- a hex, a key, an image's name -- sits at `on.surface`,
    // and a row whose title is a *preview* of a longer thing sits a step back at
    // `on.surfaceVariant`. Both clear the 4.5:1 floor.
    titleColour: root.selected || root.kind === "image" || root.kind === "colour" || Clipboard.icon(root.entry) === "key" ? Colours.on.surface : Colours.on.surfaceVariant
    titleMono: root.literal
    subtitle: root.kind === "image" ? Clipboard.detail(root.entry) : ""
    subtitleMono: true

    // cliphist records no timestamps, so an entry vela never watched arrive has
    // no age to print. `ago()` answers "" for those, and an empty trailing slot
    // is the honest rendering -- not "just now".
    trailingText: root.entry?.pinned ? "" : Clipboard.ago(root.entry)

    // `Row` puts a check on a selected row that has nothing else trailing,
    // which is right for a settings list and wrong here: the clipboard's
    // selection is a cursor, not a choice that has been made, and an unstamped
    // entry has no age to print in that slot. Left empty on purpose.
    trailingIcon: ""

    trailing: root.entry?.pinned ? pin : null

    Component {
        id: pin

        Icon {
            text: "push_pin"
            size: Appearance.size.iconSm
            color: root.selected ? Colours.on.primaryContainer : Colours.primary
        }
    }

    leading: root.kind === "image" ? thumbnail : root.kind === "colour" ? swatch : null

    Component {
        id: thumbnail

        // `previewPath` is written by the service's batched `cliphist decode`,
        // so it appears a moment after the row does. An Image whose source is
        // not there yet draws nothing rather than a broken icon, which is the
        // behaviour wanted.
        Rectangle {
            implicitWidth: Appearance.overlays.clipboard.thumbnail
            implicitHeight: Appearance.overlays.clipboard.thumbnail
            radius: Appearance.radius.small
            color: Colours.surfaceContainerHigh
            clip: true

            Image {
                anchors.fill: parent
                source: root.entry.previewPath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize.width: Appearance.overlays.clipboard.thumbnail * 2
                sourceSize.height: Appearance.overlays.clipboard.thumbnail * 2
            }
        }
    }

    Component {
        id: swatch

        // The one place in the shell that paints a colour it was handed rather
        // than one from the palette: the swatch *is* the content.
        Rectangle {
            implicitWidth: Appearance.overlays.clipboard.swatch
            implicitHeight: Appearance.overlays.clipboard.swatch
            radius: Appearance.overlays.clipboard.swatchRadius
            color: root.entry.colour
        }
    }
}
