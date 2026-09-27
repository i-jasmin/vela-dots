---
title: Wallpapers and colours
description: How the palette comes from your wallpaper, light and dark, evening warmth, and what follows along.
---

Every colour in vela comes from the wallpaper. Pick one, and
[matugen](https://github.com/InioX/matugen) turns it into a Material 3
palette that the shell and your apps all take.

## Choosing a wallpaper

**super + W** opens the switcher: a strip of the images in
`~/Pictures/Wallpapers`, with the palette each would give on the left and a
small bar wearing it on the right.

- **Arrows** move, **Enter** applies.
- **Tab** chooses **light**, **dark** or **auto**; Enter applies it with the
  wallpaper. Auto goes dark at sunset.
- **super + shift + W** goes back to the previous wallpaper.

From a terminal:

```sh
vela wallpaper ~/Pictures/Wallpapers/lake.jpg   # set it, and retheme
vela theme dark                                  # light, dark or toggle
```

## What follows the palette

| App | When |
| --- | --- |
| the shell | at once -- every colour eases across |
| Hyprland (borders) | at once |
| kitty | at once, in every open window |
| cava | at once |
| GTK and libadwaita apps | light or dark at once; their colours on next start |
| fuzzel, hyprlock | next time they open |

Just before the colours change, the shell holds a still frame over every open
window and fades it away once the apps have repainted underneath, so every
window crosses over to the new colours together.

## Look and feel

**Settings → Appearance** sets the palette's variant (how colourful it is),
light / dark / auto, how round the corners are, how see-through the panels are,
and **motion**: full, reduced or off, and how fast -- Hyprland's own window
animations follow the same setting.

## Evening warmth

After sunset the palette warms gradually, over an hour and a half. With
hyprsunset installed it can warm the screen itself as well, on the same curve
(Settings → General). The location for sunset is found from your connection,
or you can name a city.

## The terminal greeting

A new terminal opens with a short summary of the system in the palette's
colours. Turn it off with `VELA_GREETING=off` in your environment -- in fish,
`set -Ux VELA_GREETING off`.
