import QtQuick
import QtQuick.Shapes
import qs.tokens

// The lock screen wallpaper is not a picture. It is three large radial blooms,
// two faint concentric rings and a partial conic arc around the clock -- colour
// as light rather than as an image, which is what lets the lock re-theme with
// the palette instead of fighting whatever photograph is behind it.
//
// Every shape here is static and drawn once. The one thing that moves is the
// arc, and only while something is playing: it turns, faster as the music
// gets louder, and brightens with it. Like the media tab's spinning cover, it
// is a readout -- something is playing -- and not decoration.
Item {
    id: root

    // 0..1 while the arc is tracking live audio, negative when it is not. A
    // level of 0 is silence, which is a real reading -- hence the sentinel
    // rather than a `hasLevel` companion, which would fire its change handler
    // one tick before or after this one.
    property real level: -1

    // Turning with the music. The lock surface decides: only while something
    // plays, the setting is on, and reduceMotion is off.
    property bool turning: false

    // Background-size: cover, for the blooms only. The design's bloom
    // geometry is in pixels on a 1360x850 frame; this is what turns those into
    // the same picture on a screen that is not that size.
    readonly property real cover: Math.max(root.width / Appearance.lock.frameWidth, root.height / Appearance.lock.frameHeight)

    clip: true

    // One bloom: a circle of colour over a square of gradient. Declared once and
    // instantiated four times below, because the only thing that differs between
    // them is where they sit and how far the colour carries.
    component Bloom: Shape {
        id: bloom

        property real diameter: 0
        property color tint: Colours.primary
        property real innerAlpha: 0
        property real midAlpha: 0
        property real midStop: 0.5
        property real edgeStop: 0.7

        preferredRendererType: Shape.CurveRenderer
        asynchronous: false
        width: bloom.diameter
        height: bloom.diameter

        ShapePath {
            // No outline: a bloom is fill only, and a hairline stroke around a
            // 1100px circle would draw a visible ring at its edge.
            strokeWidth: -1
            startX: 0
            startY: 0

            // The path is the whole square, not the circle. The gradient's own
            // stops decide where the light ends; a circular path would cut it
            // at the inscribed radius and leave four hard corners.
            PathLine {
                x: bloom.diameter
                y: 0
            }

            PathLine {
                x: bloom.diameter
                y: bloom.diameter
            }

            PathLine {
                x: 0
                y: bloom.diameter
            }

            PathLine {
                x: 0
                y: 0
            }

            fillGradient: RadialGradient {
                centerX: bloom.diameter / 2
                centerY: bloom.diameter / 2
                focalX: bloom.diameter / 2
                focalY: bloom.diameter / 2
                centerRadius: bloom.diameter * Appearance.lock.bloomExtent

                GradientStop {
                    position: 0
                    color: Colours.alpha(bloom.tint, bloom.innerAlpha)
                }

                GradientStop {
                    position: bloom.midStop
                    color: Colours.alpha(bloom.tint, bloom.midAlpha)
                }

                GradientStop {
                    position: bloom.edgeStop
                    color: Colours.alpha(bloom.tint, 0)
                }

                GradientStop {
                    position: 1
                    color: Colours.alpha(bloom.tint, 0)
                }
            }
        }
    }

    // Top left, the warm end of the palette. The design's rgba(0,110,128,.5)
    // and rgba(0,79,91,.24) are `primaryContainer` at two alphas once they are
    // composited over the lock's ground, so they are written that way: the
    // bloom follows the wallpaper's palette instead of being pinned to a teal
    // that a new wallpaper would clash with.
    Bloom {
        x: Appearance.lock.bloomOneX * root.cover
        y: Appearance.lock.bloomOneY * root.cover
        diameter: Appearance.lock.bloomOne * root.cover
        tint: Colours.primaryContainer
        innerAlpha: 0.76
        midAlpha: 0.25
        midStop: Appearance.lock.bloomOneMid
        edgeStop: Appearance.lock.bloomOneEdge
    }

    // Bottom right, the cool end -- the design's violet is `tertiary`.
    Bloom {
        x: root.width - (Appearance.lock.bloomTwo + Appearance.lock.bloomTwoX) * root.cover
        y: root.height - (Appearance.lock.bloomTwo + Appearance.lock.bloomTwoY) * root.cover
        diameter: Appearance.lock.bloomTwo * root.cover
        tint: Colours.tertiary
        innerAlpha: 0.15
        midAlpha: 0.06
        midStop: Appearance.lock.bloomTwoMid
        edgeStop: Appearance.lock.bloomTwoEdge
    }

    // The neutral wash over the upper middle. Placed as a fraction of the
    // frame, because unlike the other two it is not hung off a corner.
    Bloom {
        x: root.width * Appearance.lock.bloomThreeX
        y: root.height * Appearance.lock.bloomThreeY
        diameter: Appearance.lock.bloomThree * root.cover
        tint: Colours.secondary
        innerAlpha: 0.14
        midAlpha: 0.05
        midStop: 0.3
        edgeStop: Appearance.lock.bloomThreeEdge
    }

    // The glow the design puts behind the 154px clock as a text-shadow.
    Bloom {
        anchors.centerIn: parent
        diameter: Appearance.lock.clockGlow
        tint: Colours.primary
        innerAlpha: 0.13
        midAlpha: 0.05
        midStop: 0.34
        edgeStop: Appearance.lock.clockGlowEdge
    }

    Rectangle {
        anchors.centerIn: parent
        width: Appearance.lock.ringOuter
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Colours.alpha(Colours.primary, 0.07)
    }

    Rectangle {
        anchors.centerIn: parent
        width: Appearance.lock.ringInner
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Colours.alpha(Colours.primary, 0.09)
    }

    // The arc. An annulus -- two circles under an odd-even fill rule, which is
    // what leaves the middle genuinely transparent -- filled with a conical
    // gradient. Qt's shape gradients fill, they do not stroke, so the ring has
    // to be a shape rather than a stroked path.
    //
    // Qt measures a conical gradient's angle anticlockwise from three o'clock
    // where CSS measures clockwise from twelve, so every stop below is the
    // design's position read backwards: `1 - t * sweep / 360`. `arcStart` is
    // folded into the gradient's own angle.
    Shape {
        id: arc

        readonly property real sweepFraction: Appearance.lock.arcSweep / 360

        anchors.centerIn: parent
        width: Appearance.lock.arc
        height: width
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false

        // Silence dims the arc; it never brightens past what the design draws.
        opacity: root.level < 0 ? 1 : Appearance.lock.arcQuiet + (1 - Appearance.lock.arcQuiet) * root.level

        // Advanced frame by frame rather than animated round from 0, so a
        // pause leaves it where it stopped and play carries on from there.
        // The level sets the speed, not the angle: the angle is the sum of the
        // speeds, so a meter that jumps every frame still turns it smoothly.
        FrameAnimation {
            running: root.turning
            onTriggered: arc.rotation = (arc.rotation + frameTime * 360000 / Appearance.lock.arcTurn * (Appearance.lock.arcTurnFloor + Appearance.lock.arcTurnGain * Math.max(0, root.level))) % 360
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Appearance.anim.enterEasing
            }
        }

        ShapePath {
            strokeWidth: -1
            fillRule: ShapePath.OddEvenFill

            PathAngleArc {
                centerX: Appearance.lock.arc / 2
                centerY: Appearance.lock.arc / 2
                radiusX: Appearance.lock.arc / 2
                radiusY: Appearance.lock.arc / 2
                startAngle: 0
                sweepAngle: 360
                moveToStart: true
            }

            PathAngleArc {
                centerX: Appearance.lock.arc / 2
                centerY: Appearance.lock.arc / 2
                radiusX: Appearance.lock.arc / 2 - Appearance.lock.arcThickness
                radiusY: Appearance.lock.arc / 2 - Appearance.lock.arcThickness
                startAngle: 0
                sweepAngle: 360
                moveToStart: true
            }

            fillGradient: ConicalGradient {
                centerX: Appearance.lock.arc / 2
                centerY: Appearance.lock.arc / 2
                angle: 90 - Appearance.lock.arcStart

                GradientStop {
                    position: 0
                    color: Colours.alpha(Colours.tertiary, 0)
                }

                GradientStop {
                    position: 1 - arc.sweepFraction
                    color: Colours.alpha(Colours.tertiary, 0)
                }

                GradientStop {
                    position: 1 - arc.sweepFraction * Appearance.lock.arcTertiaryStop
                    color: Colours.alpha(Colours.tertiary, 0.5)
                }

                GradientStop {
                    position: 1 - arc.sweepFraction * Appearance.lock.arcPrimaryStop
                    color: Colours.alpha(Colours.primary, 0.55)
                }

                GradientStop {
                    position: 1
                    color: Colours.alpha(Colours.primary, 0)
                }
            }
        }
    }
}
