---
title: NVIDIA
description: Running vela on a PC or laptop with an NVIDIA graphics card.
---

Hyprland runs on NVIDIA cards with NVIDIA's own driver, which Fedora does not
ship; it comes from [RPM Fusion](https://rpmfusion.org). The installer and
`vela doctor` tell you when a card has no driver.

## The driver

vela does not install the driver, and these docs give no steps for it: the
right ones depend on the card, the Fedora release and Secure Boot, and they
change. Follow the guides from the people who package it and from Hyprland:

- [RPM Fusion: NVIDIA](https://rpmfusion.org/Howto/NVIDIA), the driver on
  Fedora.
- [RPM Fusion: Configuration](https://rpmfusion.org/Configuration), the
  repositories it comes from.
- [RPM Fusion: Secure Boot](https://rpmfusion.org/Howto/Secure%20Boot), if
  Secure Boot is on.
- [Hyprland wiki: Nvidia](https://wiki.hypr.land/Nvidia/), Hyprland on NVIDIA
  cards.

## Hyprland's settings

vela sets nothing for any graphics card, and leaves Hyprland to choose the card
it draws on. What to change, if anything, depends on where your monitors are
plugged in. The lines are in `~/.config/hypr/conf/env.lua`, commented out, with
notes.

**Only NVIDIA.** Every monitor is plugged into the NVIDIA card, as on most PCs
with one. The Hyprland wiki's NVIDIA page gives two settings for this; they are
in `env.lua` under *NVIDIA only*. Read the wiki's notes on them, then remove the
`--` in front of each.

**Built-in graphics and NVIDIA.** The processor has graphics of its own, Intel
or AMD, and there is an NVIDIA card as well: most laptops with NVIDIA, and PCs
with monitors on both the motherboard and the card. Leave those two lines
commented; they send work to the NVIDIA card that belongs on the built-in
graphics, and one of them breaks screen sharing. Both have to stay enabled,
since some outputs are wired to one and some to the other. If a monitor is
laggy or blank, or the wrong card draws, see the
[Hyprland wiki's Multi-GPU page](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Multi-GPU/).
To run a single app on the NVIDIA card, put `nv` in front of it in the
terminal: `nv blender`.
