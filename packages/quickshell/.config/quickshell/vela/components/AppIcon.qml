import QtQuick
import qs.tokens

// An application's icon: its real one from the icon theme chosen in Settings
// (Appearance, App icons), or, without a theme or when the theme has nothing
// for it, the Material symbol the design draws (`glyph`). `Icon` with one
// more property, so every place that draws an app takes the same two paths:
//
//     AppIcon {
//         source: AppIcons.forClient(client)    // "" without a theme
//         glyph: Hypr.iconOf(client)
//         size: Appearance.size.iconRow         // the glyph's size
//         imageSize: Appearance.size.iconRow + Appearance.size.appIconGrow
//     }
//
// The glyph is drawn monochrome in `color`, as everywhere; an icon is drawn as
// its theme made it. An icon that fails to load is the glyph after all.
Item {
    id: root

    // An image source from `AppIcons`, "" for none.
    property string source: ""
    property string glyph: ""
    property real size: Appearance.size.iconMd
    // How big an icon is drawn. A glyph sits inside its em box with room to
    // spare and an icon fills its square, so an icon the glyph's size reads
    // larger; most places draw it a touch bigger than the glyph regardless.
    property real imageSize: root.size
    // The size an icon is decoded at. Fixed for an icon whose size animates
    // (the dock's magnification): decoding again at every frame of the
    // animation would re-rasterise an SVG sixty times a second.
    property real decodeSize: root.imageSize
    property color color: Colours.on.surfaceVariant

    readonly property bool showsImage: root.source !== "" && picture.status !== Image.Error

    implicitWidth: root.showsImage ? root.imageSize : symbol.implicitWidth
    implicitHeight: root.showsImage ? root.imageSize : symbol.implicitHeight

    Image {
        id: picture

        anchors.centerIn: parent
        width: root.imageSize
        height: root.imageSize
        visible: root.showsImage
        source: root.source
        sourceSize.width: Math.ceil(root.decodeSize)
        sourceSize.height: Math.ceil(root.decodeSize)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
    }

    Icon {
        id: symbol

        anchors.centerIn: parent
        visible: !root.showsImage
        text: root.glyph
        size: root.size
        color: root.color
    }
}
