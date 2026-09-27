# Calendar

vela's calendar lives on the dashboard's Home tab: a month that folds out
under the day, fed by as many calendar accounts as you like, where you can
read your days, add, change and delete events, and be reminded of them. This
is the whole guide: using it, connecting your calendars, reminders, how
syncing and offline work, where things are kept, and what to do when
something is off.

- [First-time setup](#first-time-setup)
- [Opening it](#opening-it)
- [Reading the month](#reading-the-month)
- [Keyboard](#keyboard)
- [Connecting calendars](#connecting-calendars)
  - [Google](#google) · [Outlook](#outlook--microsoft-365) · [iCloud](#icloud) · [Nextcloud](#nextcloud) · [Other CalDAV](#other-caldav-servers) · [Links](#calendar-links)
- [Several calendars: colours and switching off](#several-calendars-colours-and-switching-off)
- [Events: adding, changing, deleting](#events-adding-changing-deleting)
- [Reminders](#reminders)
- [Syncing, and working offline](#syncing-and-working-offline)
- [Privacy: where things are kept](#privacy-where-things-are-kept)
- [The command line](#the-command-line)
- [Configuration (shell.json)](#configuration-shelljson)
- [Your own khal or vdirsyncer setup](#your-own-khal-or-vdirsyncer-setup)
- [Troubleshooting](#troubleshooting)
- [How it works](#how-it-works)
- [Limitations](#limitations)

---

## First-time setup

1. Install the tools it uses (bootstrap installs them; on an older install,
   run it again or install them by hand):

   ```sh
   sudo dnf install khal vdirsyncer libsecret python3-icalendar
   ```

   | Package | What it does here |
   |---|---|
   | `khal` | reads the calendars for the month |
   | `vdirsyncer` | fetches your accounts and uploads your changes |
   | `libsecret` | `secret-tool`, which keeps passwords and links in the keyring |
   | `python3-icalendar` | writes the events you add or change |

2. Open **Settings** (super + I), go to **Calendars**, pick your provider and
   add the account ([details per provider below](#connecting-calendars)).
3. Open the month (right-click the bar clock). Your events arrive with the
   first sync, a few seconds after adding the account.

---

## Opening it

The month folds out under the day on Home, and the dashboard grows to take
it. Any of these opens it:

| How | Notes |
|---|---|
| Right-click the bar clock | opens the dashboard with the month out; again closes it |
| super + shift + D | the same |
| The arrow on the day's card | on Home; folds it out and back |
| The date under the big clock | on Home; the same as the arrow |
| `qs -c vela ipc call shell toggle calendar` | also `open` and `close` |

A plain click on the clock and super + D open Home with the month folded
away. Closing the dashboard folds the month and goes back to today, so it
always opens fresh; switching to another tab and back keeps it as it was.

---

## Reading the month

### The grid

- **Today** is the filled day. The **picked day** has an outline; click any
  day to pick it.
- A **dot** under a day means it has something on.
- The arrows beside the month's name step a month (to the same day of the
  month); **Today** appears when you have wandered off and brings you back.
- The grid always draws six weeks, so it never changes size between months.

### The day

Picking a day retargets the rest of Home to it:

- **Top or bottom bar:** the timeline card follows the picked day.
  - **Today** it is a rolling window around now: the last three hours and the
    next eight or nine, so at 23:00 it runs from 20:00 into tomorrow morning,
    with tomorrow's early events on it and midnight marked with the next
    day's name. It moves on the hour, and the now-line moves within it; the
    note above counts down to the next thing ("Dentist in 20m").
  - **Another day** shows that day, 08:00 to 22:00, stretched to take in any
    event earlier or later, and is named ("Tuesday 29 September" instead of
    "Today").
- **Beside the month**, the day's events are listed with their start time and
  length, as many as fit, then "+3 more". A day with nothing on says so, and
  says what comes next ("Next: Dentist · Thu 1 Oct" — click it to jump there).
- **Left or right bar:** the agenda card below shows the day, with a **Now**
  row where the current time falls when the day is today.
- An event with a meeting link (an `http(s)` URL or location) has a
  **Join** button.

### The legend and the status line

- Under the list, the **legend** names the calendars being shown, three of
  them and a count of the rest ("+3"). The count, and the pencil at the end,
  open Settings, Calendars.
- Under the grid, the **status line** says how the last sync went: "Synced
  just now", "Synced 12m ago", "1 waiting · can't reach cloud.home",
  "Syncing…". With no calendar at all it says so, and the legend offers
  **Add a calendar**.

---

## Keyboard

While the month is out on Home:

| Key | Does |
|---|---|
| ← → | the day before / after |
| ↑ ↓ | a week back / on |
| Page Up / Page Down | a month back / on |
| T or Home | back to today |
| C | fold the month away (or out) |
| Esc | close the dashboard |

In the event form:

| Key | Does |
|---|---|
| Enter | save |
| Esc | put the form away (the dashboard stays) |
| Tab | the next field |

While the form is open, Tab, 1–9 and C do nothing else, so a stray key never
switches tab or folds the month away under what you are typing. After you
click a tab in the dashboard's tab strip the arrows move the tabs; click a
day and they move the day again.

---

## Connecting calendars

**Settings → Calendars → Add a calendar.** Pick a provider, fill in what it
asks for and press **Add** (or Enter; Tab and shift + Tab move between the
fields). The account appears at once, syncs straight away, and its calendars
show in the list below and in the month. Add as many as you like, of any
kind.

There are two kinds of account:

| Kind | Providers | What you get |
|---|---|---|
| **A link** | Google, Outlook, Link | one calendar per link, **read-only** |
| **CalDAV** | iCloud, Nextcloud, CalDAV | every calendar on the account, **read and write** |

Only CalDAV calendars take new events from the shell. See
[Limitations](#limitations) for why Google and Outlook are read-only.

### Google

1. Open [Google Calendar](https://calendar.google.com) on the web.
2. **Settings** (the gear) → under *Settings for my calendars*, pick the
   calendar → **Integrate calendar**.
3. Copy **Secret address in iCal format**.
4. In vela: **Google**, give it a name, paste the link, **Add**.

One link is one calendar: add each calendar you want the same way. Treat the
secret address like a password — anyone with it can read the calendar. If it
ever leaks, use *Reset* next to it in Google Calendar and add the new one.
(On a work or school account the secret address can be switched off by the
administrator.)

### Outlook / Microsoft 365

1. Open Outlook on the web → **Settings** → **Calendar** → **Shared
   calendars**.
2. Under *Publish a calendar*, pick the calendar and **Can view all details**,
   then **Publish**.
3. Copy the **ICS** link (not the HTML one).
4. In vela: **Outlook**, a name, the link, **Add**.

Publishing can be switched off by an organisation's administrator.

### iCloud

1. Go to [account.apple.com](https://account.apple.com) → **Sign-In and
   Security** → **App-Specific Passwords** → create one (call it "vela").
2. In vela: **iCloud**, a name, your **Apple ID** email and the
   **app-specific password**, **Add**.

Every iCloud calendar you have comes in, and they take new events. Your
normal Apple ID password will not work here; it has to be an app-specific
one.

### Nextcloud

1. In Nextcloud: **Settings** → **Security** → *Devices & sessions* → create
   an **app password** (call it "vela").
2. In vela: **Nextcloud**, a name, the **server address** (for example
   `https://cloud.example.com` — the `/remote.php/dav/` part is added for
   you), your **username** and the **app password**, **Add**.

**A Nextcloud at home** that is only reachable on your own network works
well: events you add while out are kept on the laptop and uploaded when you
are back (see [working offline](#syncing-and-working-offline)).

- If it is served over plain **http** on your network, type the address with
  `http://` in front; anything without a scheme is taken as `https://`.
- If it uses a **self-signed certificate**, sync fails with a certificate
  error. Add your certificate authority to Fedora's trust store
  (`sudo trust anchor your-ca.crt`) or give the server a certificate from a
  public authority.

Nextcloud's **Contact birthdays** calendar comes along with the others. It
is made from your contacts and is read-only, so it shows in the month (switch
it off in Settings, Calendars if you like) but is never offered for new
events. A calendar you make in Nextcloud later appears by itself at the next
sync.

### Other CalDAV servers

Fastmail, mailbox.org, Posteo, a Radicale or Baïkal of your own — anything
that speaks CalDAV:

1. Find the provider's **CalDAV address**, and create an **app password** if
   it offers them.
2. In vela: **CalDAV**, a name, the **server** address, **username** and
   **password**, **Add**.

| Provider | Server address |
|---|---|
| Fastmail | `https://caldav.fastmail.com/`, with an app password |
| Radicale / Baïkal | your server's address |
| others | the CalDAV address from the provider's help pages |

### Calendar links

Any `.ics` or `webcal://` link: public holidays, a team's fixtures, a school
calendar, Proton Calendar's *Share with anyone* link, a calendar someone
shared. **Link**, a name, the link, **Add**. `webcal://` is fetched as
`https://`. Read-only.

### Removing an account

**Remove** beside the account, then **Remove?** to confirm. Its calendars
leave the month, its downloaded copy is deleted, and its password or link is
deleted from the keyring. Nothing on the server is touched.

---

## Several calendars: colours and switching off

**Settings → Calendars → Calendars** lists every calendar, with the account
it came from (or "From your own khal config").

- **Colour:** each calendar can take one of the palette's three accents or
  grey. The colours follow your wallpaper like the rest of the shell, so a
  calendar stays recognisable without clashing with it. A calendar you have
  not coloured gets the next accent in turn.
- **Switch:** turning a calendar off hides its events from the month, the
  timeline, the agenda and the lock screen, without removing the account.
  Turn it back on and they return at once.

Both are saved in `shell.json` by the calendar's name (see
[Configuration](#configuration-shelljson)).

---

## Events: adding, changing, deleting

### Adding

1. Pick the day in the month.
2. Press **+** in the day's header (on a left or right bar, the **+** in the
   agenda's header).
3. Type a **title**, set **All day** or a start and end time, and pick the
   **calendar**.
4. **Save**, or Enter.

It appears in the month at once, and is uploaded by the sync that follows.

**Which calendars are offered:** those of your CalDAV accounts that take
events and are switched on in Settings. vela asks the server which ones take
events, so a calendar it keeps read-only is never offered: Nextcloud's
*Contact birthdays* (made from your address book), a Deck board's calendar,
or a calendar someone shared with you to read only. A calendar you switched
off is not offered either — an event saved there would vanish as you made
it.

**Where new events go:** the calendar with the **star** in Settings,
Calendars (it also says *new events go here*). Click the star on another
calendar to change it. With none starred, or the starred one switched off,
it is the first calendar that takes events.

Times can be typed the way you would say them:

| You type | It means |
|---|---|
| `9` | 09:00 |
| `930` | 09:30 |
| `9:30` or `9.30` | 09:30 |
| `2115` | 21:15 |

A time it cannot read turns red, and **Save** waits until it can. New events
start at the next full hour when the day is today, 09:00 otherwise, and last
an hour.

To put the event on another day, use the arrows in the form's header — or, on
a top or bottom bar, simply pick another day in the grid while the form is
open.

### Changing

Click the event in the day's list (or in the agenda, on a side bar). The same
form opens with its details; change anything, including its day or its
calendar, and **Save**. Moving an event to another calendar moves it on the
server too, even between accounts.

An event that lasts several days keeps its length when moved. Its notes and
location are kept as they are (they are not edited from the form yet).

### Deleting

Open the event, **Delete**, then **Delete?** to confirm. It is removed from
the server with the next sync.

### What cannot be changed here

| Mark | Meaning |
|---|---|
| a lock | the event is from a read-only calendar: a Google, Outlook or other link, or a CalDAV calendar the server keeps read-only (Nextcloud's *Contact birthdays*, one shared with you to read) |
| two arrows | a repeating event: its one file is the whole series, so change it in your calendar app, where the series can be seen |

These appear only once you have a calendar that does take events, so a
setup with only read-only calendars is not covered in locks.

---

## Reminders

A notification comes before each event, from every calendar that is switched
on:

- **The event's own reminders**, if it has any: the "15 minutes before" (or
  "1 day before", or several) set on your phone or in your calendar app
  travels with the event, and is what vela uses. This covers all-day events
  too, when they have one.
- **Otherwise, 10 minutes before** a timed event. All-day events without a
  reminder of their own stay quiet: a birthday should not ping at midnight.

The notification says what, when and where — *Standup · In 10m · 09:30 –
09:45 · Room 4* — with buttons:

| Button | Does |
|---|---|
| **Join** | opens the meeting link, when the event's location or URL is one (Meet, Zoom, Teams, Jitsi…) |
| **Snooze 5 min** | brings the same reminder back in five minutes, as long as the event has not ended |
| clicking the notification | opens Home with the month unfolded |

Choose in Settings, Calendars, *Reminders*:

- **Before each event**: Off, at start, 5, 10, 15 or 30 minutes — the
  default for events with no reminder of their own.
- **Use each event's own reminders**: switch it off to have every timed event
  remind at the default above, whatever its calendar app says.
- **Try it** sends a made-up reminder, to see what they look like and that
  notifications get through.

Worth knowing:

- **Each reminder comes once.** vela remembers which ones it has sent (in
  `~/.local/state/vela/reminders.json`), so restarting the shell or logging
  in again does not send them twice, and a snooze survives a restart.
- **Missed ones still come, while they are useful.** One that fell due while
  the laptop was asleep comes when it wakes, and one that fell due while the
  shell was not running (up to an hour back) comes when it starts — but only
  if the event has not ended yet.
- **Do not disturb and Focus** hold reminders like any other notification:
  they are not shown as they arrive, and wait in the notification centre (the
  bar's bell).
- **An event added on another device** is known once it has synced here
  (every 15 minutes by default), so a meeting created on your phone five
  minutes before it starts may come without a reminder. **Sync now** in
  Settings brings it in straight away.
- A calendar that is **switched off** in Settings does not remind.
- Reminders are notifications, with no sound of their own.

---

## Syncing, and working offline

### When it syncs

- **Every 15 minutes** by default; choose 5, 15, 30 minutes or an hour in
  Settings, Calendars, *Sync*.
- **Straight after** you add an account, and after every event you save or
  delete.
- **When the network comes back or changes** (a few seconds after, for the
  address to settle) — so a server at home is reached as soon as you are.
- **Sync now** on the Calendars page, any time.

Each sync of a CalDAV account also asks the server which calendars it has
and which of them take events. A calendar made since (on your phone, on the
web) is added by itself; one that is read-only is marked so, and never
offered for new events.

### Offline first

Everything you do is written on the laptop first. When the server cannot be
reached — the Nextcloud is at home and you are not, the Wi-Fi dropped, the
server is down — nothing is lost:

- The event is in the month immediately.
- The status line says **"1 waiting · can't reach cloud.home"**, and the
  account in Settings says **"Can't reach cloud.home — syncs when it can ·
  1 waiting to upload"**. This is shown calmly, not as an error.
- The first sync that gets through uploads everything that was waiting, and
  brings in what changed on the server meanwhile (from your phone, say).

### If the same event changed in two places

If an event is changed on the laptop and on another device before they sync,
the **server's version wins** when they meet. Changes to different events
never conflict.

---

## Privacy: where things are kept

**Passwords and links go into your keyring**, encrypted with your login
password — never into a file, and never into `shell.json` (which may live in
a dotfiles repository). A Google or Outlook secret link counts as a password:
anyone who has it can read the calendar.

- The keyring is gnome-keyring, which vela's `autostart.lua` starts. The
  login screen unlocks it (GDM does this automatically); with another login
  manager it may ask for your password once per session, the first time a
  calendar syncs.
- With **no keyring** running, nothing is written down instead: the
  Calendars page says *The keyring is not available*, with the reason and
  **Check again**, and **Add** waits; each existing account says the same
  thing rather than syncing.
- vdirsyncer asks the keyring for each secret at the moment it syncs.

What is kept where:

| Where | What | Secret? |
|---|---|---|
| keyring (service `vela-calendar`) | each account's password or link | yes, encrypted |
| `~/.local/share/vela/calendar/accounts.json` | provider, name, server, username | no |
| `~/.local/share/vela/calendar/state.json` | each account's calendars and last sync — what the shell reads | no |
| `~/.local/share/vela/calendar/vdirsyncer.conf` | one vdirsyncer pair per account; secrets are fetched, not written | no |
| `~/.local/share/vela/calendar/khal-calendars.conf` | the accounts' calendars, for khal | no |
| `~/.local/share/vela/calendar/data/<id>/` | the downloaded events, one folder per calendar | your events |
| `~/.cache/vela/khal.conf`, `khal.db` | the shell's own copy of the khal config and its index | no |
| `~/.local/state/vela/reminders.json` | which reminders were sent (event UID and time), and snoozes | no |
| `~/.config/vela/shell.json` | calendar colours and switches, sync interval, reminder settings | no |

The folder `~/.local/share/vela/calendar/` can only be opened by you.

To see the keyring entries: `secret-tool search --all service vela-calendar`.

---

## The command line

`vela calendar` does everything the Calendars page does; the page calls it.

```sh
vela calendar                # the same as list
vela calendar list           # accounts, their calendars and how each last synced
vela calendar sync           # sync every account (and your own vdirsyncer, if you have one)
vela calendar sync <id>      # just one account
vela calendar remove <id>    # remove an account (and its keyring entry)
vela calendar keyring        # "ok", or what is wrong with the keyring
```

Adding an account and writing events take their details from the
environment, never the command line (which any process can read):

```sh
# a link
VELA_CAL_PROVIDER=link VELA_CAL_NAME="Holidays" \
VELA_CAL_URL="https://example.com/holidays.ics" vela calendar add

# a CalDAV account (provider: icloud, nextcloud or caldav)
VELA_CAL_PROVIDER=nextcloud VELA_CAL_NAME="Home" VELA_CAL_URL="https://cloud.example.com" \
VELA_CAL_USER=me VELA_CAL_PASS="app-password" vela calendar add
```

Events are written into a calendar by its folder — the `path` of one of the
account's `writable` calendars in `state.json`:

```sh
# timed, local time; prints the new event's UID
VELA_EV_PATH=~/.local/share/vela/calendar/data/<id>/<calendar> \
VELA_EV_TITLE="Dentist" VELA_EV_START=2026-10-02T15:00 VELA_EV_END=2026-10-02T16:00 \
vela calendar event add

# all day (END is the last day, inclusive)
VELA_EV_PATH=... VELA_EV_TITLE="Trip" VELA_EV_START=2026-10-05 VELA_EV_END=2026-10-07 \
vela calendar event add

vela calendar event edit <uid>      # same variables; VELA_EV_PATH moves it
vela calendar event delete <uid>
```

Every command exits non-zero with a one-line reason when it cannot do what
was asked.

---

## Configuration (shell.json)

The calendar's part of `~/.config/vela/shell.json`. The Calendars page writes
all of it; you rarely need to edit it by hand.

```json
"calendar": {
    "backend": "khal",
    "syncCommand": "vela calendar sync",
    "syncMinutes": 15,
    "reminderMinutes": 10,
    "eventAlarms": true,
    "sources": [
        { "name": "Family", "colour": "tertiary", "enabled": true },
        { "name": "Work",   "colour": "primary",  "enabled": true },
        { "name": "Team",   "colour": "outline",  "enabled": false }
    ]
}
```

| Key | Meaning |
|---|---|
| `syncCommand` | what runs on each sync. `vela calendar sync` syncs the accounts and then a vdirsyncer set up by hand. The old default, `vdirsyncer sync`, is treated the same. |
| `syncMinutes` | minutes between syncs (Settings offers 5, 15, 30, 60) |
| `newEvents` | the calendar new events go to, by name (any case) — the star in Settings. `""` is the first calendar that takes events |
| `reminderMinutes` | minutes before a timed event that its reminder comes, for events with no reminder of their own: `0` is as it starts, `-1` is none (Settings offers off, 0, 5, 10, 15, 30; any number works here) |
| `eventAlarms` | `true` uses each event's own reminders where it has them; `false` ignores them and uses `reminderMinutes` for every timed event |
| `sources` | per calendar, by name (any case): `colour` is `primary`, `tertiary`, `secondary` or `outline` (grey; the older `outlineVariant` means the same), and `enabled: false` hides it. A calendar not listed gets the next accent and is shown. |

A name listed here that no calendar has is ignored: the legend never names a
calendar that does not exist.

---

## Your own khal or vdirsyncer setup

A khal or vdirsyncer you configured by hand keeps working alongside the
accounts:

- The shell reads your `~/.config/khal/config` and adds the accounts'
  calendars to its own copy of it (in `~/.cache/vela/`, with its own index),
  so both sets show in the month. Your file is never changed, and `khal` in a
  terminal keeps showing just your own calendars.
- `vela calendar sync` runs `vdirsyncer sync` on your own
  `~/.config/vdirsyncer/config` after the accounts.
- Your own calendars show in Settings as "From your own khal config" and can
  be coloured and switched off like any other. New events can only be added
  to the accounts' CalDAV calendars.

---

## Troubleshooting

| You see | Why | What to do |
|---|---|---|
| "No calendar set up yet" and **Add a calendar** | no account and no khal config | add one in Settings, Calendars |
| "khal is not installed" | khal is missing | `sudo dnf install khal` |
| "vdirsyncer is not installed" (on the Sync row or an account) | nothing can fetch the accounts | `sudo dnf install vdirsyncer`, then **Sync now** |
| "The keyring is not available" | gnome-keyring is not running, or secret-tool is missing | log out and in (autostart starts gnome-keyring); `sudo dnf install libsecret gnome-keyring`; then **Check again** |
| A keyring password prompt at the first sync | the login screen did not unlock the keyring | type your login password; GDM unlocks it on its own |
| "Can't reach *host*" | the server is out of reach from where you are | nothing — it syncs when it can be reached; changes wait on the laptop |
| "Could not sync: … 401 …" or "Unauthorized" | wrong username or password | remove the account and add it again with an **app password** (iCloud, Nextcloud, Fastmail need one) |
| "Could not sync: … certificate …" / SSL | a self-signed or expired certificate | see [Nextcloud](#nextcloud): trust your CA, or use `http://` on your own network |
| "Could not sync: … 404 …" on a link | the link was reset or unpublished | make a new link and add it again (then remove the old account) |
| An account's calendar is missing from the month | it is switched off, or its first sync has not finished | Settings, Calendars: check its switch; **Sync now** |
| Events show at the wrong time | the laptop's time zone is wrong | `timedatectl` and `sudo timedatectl set-timezone Europe/Rome` (for example) |
| Two calendars called "Family" and "Family1" | two accounts both have a calendar named Family | harmless; rename one on the server if it bothers you |
| An event has a lock or arrows and will not open | read-only calendar, or a repeating event | change it where it comes from (see [what cannot be changed](#what-cannot-be-changed-here)) |
| "python3-icalendar is not installed" when saving | the event writer is missing | `sudo dnf install python3-icalendar` |
| "Could not sync: … 403 … Forbidden" | something was written into a calendar the server keeps read-only (an older vela could offer Nextcloud's birthdays for new events) | nothing: the next sync sees the calendar is read-only, moves events made in vela into the account's first calendar that takes events, and puts the read-only one back as the server has it |
| No reminder came | *Before each event* is Off and the event has none of its own; the calendar is switched off; Do not disturb or Focus was on (look in the bell); the event was added elsewhere and had not synced yet | Settings, Calendars, *Reminders*: **Try it** — if that shows nothing, notifications themselves are not getting through |
| A reminder at a time you did not choose | the event has its own reminder (set in its calendar app), which wins | change it on the event, or switch off *Use each event's own reminders* |

For more detail, `vela calendar list` shows each account's last result, and
`vela calendar sync` prints the first error it met.

**Starting over:** remove every account in Settings, Calendars (this also
clears their keyring entries), then, if anything is left,
`rm -rf ~/.local/share/vela/calendar ~/.cache/vela/khal.*` and
`secret-tool clear service vela-calendar`.

---

## How it works

```
Settings, Calendars ──(details via the environment)──▶ vela calendar
                                                          │
                     keyring (passwords, links) ◀─────────┤
                     accounts.json, state.json ◀──────────┤
                     vdirsyncer.conf (one pair per account)
                                                          │
                  vdirsyncer ◀── password.fetch / url.fetch ── keyring
                     │  sync: server ⇄ data/<id>/<calendar>/*.ics
                     ▼
    khal (the shell's copy of your khal config + khal-calendars.conf)
                     │  khal list --json
                     ▼
            services/Calendar.qml ──▶ Home: month, timeline, agenda, lock screen
                     ▲
   EventForm ──▶ vela calendar event add|edit|delete ──▶ data/<id>/<calendar>/
```

- **Accounts** are kept by `vela calendar` (`packages/bin/.local/bin/vela`),
  which writes one vdirsyncer pair per account, syncs each on its own so a
  failure is named against its account, and writes the khal calendar blocks
  for them. Discovery (asking a CalDAV server which calendars it has) runs
  when an account is added, and again whenever the server has a calendar the
  laptop does not. Each sync also asks the server which calendars take events
  (each one's `current-user-privilege-set`); the read-only ones are left out
  of the account's `writable` list in `state.json`, and events made in vela
  that ended up in one are moved to a calendar that takes them.
- **Reading**: the shell runs khal on a copy of your khal config with ISO date
  formats, the accounts' calendars spliced in, and an index of its own
  (`services/Calendar.qml`). Events are re-read after every sync and every
  change; hidden calendars are filtered out in the shell, so a switch shows at
  once.
- **Writing**: `vela calendar event` writes the `.ics` into the calendar's
  local folder with python's icalendar — timed events in UTC (read the same
  everywhere), all-day events as dates, SEQUENCE bumped on each edit — and
  vdirsyncer uploads it on the next sync. Each account counts its changes
  waiting to upload until a sync succeeds.
- **Offline**: a sync that fails because the server cannot be reached is
  recorded as *offline* (not as broken), and the shell syncs again when the
  network changes (`Net.connected`, `Net.ssid`).
- **Reminders**: khal reports each event's own reminders (`alarms-list`); the
  shell checks every twenty seconds for reminders that fell due since its
  last check, sends each once with `notify-send`, and keeps what it has sent
  in `~/.local/state/vela/reminders.json`. A notification that could not be
  shown (the notification service still starting at login) is tried again a
  few seconds later.

The parts of the shell:

| File | Does |
|---|---|
| `modules/dashboard/MonthFold.qml` | the month card: grid, day list, legend, status |
| `modules/dashboard/EventForm.qml` | the new / edit event form |
| `modules/dashboard/HomeTab.qml` | the day's timeline and agenda, following the picked day |
| `modules/dashboard/Dashboard.qml` | the month's state (open, picked day, the form) and keys |
| `modules/settings/CalendarsPane.qml` | Settings, Calendars |
| `services/Calendar.qml` | khal, the accounts' state, saving events, syncing, reminders |
| `components/MonthGrid.qml` | the six-week grid |

---

## Limitations

- **Google and Outlook are read-only.** Their links can only be read. Google's
  two-way sync needs an OAuth app you register in Google Cloud yourself, and
  Outlook has no CalDAV at all (it would need Microsoft's own API), so neither
  is offered. A calendar you need to write to can live in iCloud, Nextcloud or
  any CalDAV service.
- **Repeating events** are shown but not changed from the shell.
- **Locations and notes** are shown (and kept when you edit), but not edited
  in the form yet.
- **Invitations** (attendees, replies) are not shown, and reminders are not
  set from the form — an event's own reminders come from its calendar app.
- **Reminders need the shell running**: nothing reminds while you are logged
  out, and one missed by more than an hour, or whose event has ended, is not
  sent late.
- If an event changes in two places before they sync, the server's version
  wins.
