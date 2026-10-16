---
title: Your phone
description: The phone's notifications with Reply, its battery on the bar, files and the clipboard both ways, through KDE Connect.
---

vela talks to your phone through [KDE Connect](https://kdeconnect.kde.org/):
its notifications come up here as cards you can reply from, its battery sits
on the bar, and files and the clipboard go both ways. It works over your
Wi-Fi; nothing goes through anyone's server.

KDE Connect is not installed with vela. A machine with no phone to talk to
does not carry it.

## Setting it up

1. **Settings → Phone → Set up.** A terminal opens and asks for your
   password: it installs KDE Connect's background service, `sshfs` (for the
   phone's files) and the Python bindings vela talks to it with, opens KDE
   Connect's ports (1714 to 1764) in the firewall, and starts it.
2. **On the phone,** install KDE Connect from Google Play or F-Droid, and
   open it on the same Wi-Fi. Your PC is listed by the name Settings → Phone
   shows. Pick it.
3. **Back in Settings → Phone,** the request shows up with a key. Check that
   the phone shows the same key, then press **Pair**.

You can also pair from this side: a device on the network shows under
**Nearby** with **Pair**, and the phone asks you to accept, with the same key.

## On the bar

Set up puts the phone on the bar (**Settings → Modules** moves it). While the
phone is in reach it shows its glyph and its charge. Click it for the phone's
popout:

- **Ring** -- it rings, even on silent, until you find it.
- **Send files** -- pick files here, and they land in the phone's downloads.
- **Clipboard** -- sends what you copied here to the phone now.
- **Its files** -- opens the phone's storage in your file manager. The phone
  asks for permission the first time.

Under those, the files the phone sent last, newest first, and **Open folder**.
At the bottom, **Send copies to the phone**: on, whatever you copy here can be
pasted on the phone straight away.

The other way, Android lets apps read the clipboard only when you ask, so the
phone sends its clipboard when you tap **Send clipboard** in KDE Connect's
notification on the phone.

To send a file from the phone, share it to KDE Connect and pick your PC. It is
saved in `~/Downloads`.

## Notifications

The phone's notifications come up as ordinary cards, headed with the app and
the phone: **WhatsApp · Pixel 8**, with the sender and the message under it.

- **Reply.** When the app on the phone takes replies -- most messaging apps --
  the card has a field to type in. Enter sends it, and the phone sends it from
  the app. In the history there is a **Reply** button.
- **Copy code.** A text with a one-time code (*Your code is 482913*) shows the
  code large, with **Copy code**. The code is copied without landing in the
  [clipboard history](../capture/), so it is not still there tomorrow.

Both can be switched off in **Settings → Phone**, as can the phone's
notifications altogether. The phone's music shows in the dashboard's media
player with nothing to set up.

## From a terminal

```sh
vela phone setup                      # install KDE Connect and open its ports
vela phone status                     # the devices KDE Connect knows (JSON)
vela phone ring <device>              # ring it
vela phone send <device> <file>...    # send it files
vela phone clipboard <device>         # send it the clipboard
vela phone browse <device>            # open its files
vela phone pair|refuse|unpair <device>
vela phone autoshare <device> on|off  # send what you copy here to it
```

`<device>` is the `id` that `vela phone status` prints.

## When it does not find the phone

- **Same network?** The phone and the PC have to be on the same Wi-Fi, and
  some guest and office networks keep devices apart.
- **The firewall.** `vela doctor` says if it is keeping the phone out;
  `vela phone setup` opens the ports again.
- **Is it running?** `vela doctor` has a line for KDE Connect, and the top of
  Settings → Phone says what it is doing.
