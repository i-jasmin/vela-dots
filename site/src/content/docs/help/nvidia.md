---
title: NVIDIA
description: Running vela on a machine with an NVIDIA graphics card.
---

Hyprland runs on NVIDIA cards with NVIDIA's own driver, which Fedora does not
ship; it comes from [RPM Fusion](https://rpmfusion.org). The installer and
`vela doctor` tell you when a card has no driver.

## Installing the driver

```sh
sudo dnf install \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo dnf install akmod-nvidia
```

Wait a few minutes for the module to build (`modinfo -F version nvidia` prints a
version when it is ready), then reboot.

:::caution[Secure Boot]
With Secure Boot on, the module has to be signed with a key you enrol, or it
will not load. Follow [RPM Fusion's Secure Boot guide](https://rpmfusion.org/Howto/Secure%20Boot)
before rebooting.
:::

## Laptops with Intel and NVIDIA

On many laptops the built-in screen is wired to the Intel graphics and the
HDMI port to the NVIDIA card. Both have to stay enabled; Hyprland uses the
Intel card to draw and the NVIDIA one for the HDMI port. vela's config sets
nothing card-specific, which is what that needs. `~/.config/hypr/conf/env.lua`
has notes on the variables to try if an external monitor is laggy or blank.
