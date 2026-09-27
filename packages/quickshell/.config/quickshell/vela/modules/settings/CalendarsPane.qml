pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.tokens
import qs.components

// Calendars -- where Home's month gets its events. Accounts are added here
// from a choice of providers, as many as you like, and every calendar they
// bring can be given a colour or switched off.
//
// Two kinds of account, and the page says which each provider is:
//
//   a link   Google's secret address, Outlook's published calendar, any .ics
//            or webcal:// -- one calendar each, read-only, nothing to sign in
//            to. Add one per calendar.
//   CalDAV   iCloud, Nextcloud, or any server that speaks it -- every calendar
//            the account has, from a username and an app password.
//
// The accounts live with `vela calendar`, outside the dotfiles, and their
// secrets -- passwords, and links, a secret address being as good as a
// password -- in the keyring, encrypted with the login password. This page
// hands the details to that command and reads back what it reports
// (services/Calendar.qml). With no keyring nothing can be added, and the page
// says so rather than writing a password down. Colours and switches are not
// secret, and go in shell.json with the rest.
PaneScroll {
    id: root

    readonly property var providers: [
        {
            key: "google",
            label: qsTr("Google"),
            icon: "calendar_month",
            kind: "link",
            how: qsTr("In Google Calendar on the web: Settings, pick the calendar, Integrate calendar, then copy “Secret address in iCal format”. One link per calendar, so add each one you want. Read-only."),
            name: qsTr("e.g. Work"),
            link: "https://calendar.google.com/calendar/ical/…/basic.ics"
        },
        {
            key: "outlook",
            label: qsTr("Outlook"),
            icon: "mail",
            kind: "link",
            how: qsTr("In Outlook on the web: Settings, Calendar, Shared calendars, Publish a calendar. Pick it, choose “Can view all details”, Publish, then copy the ICS link. Read-only."),
            name: qsTr("e.g. Work"),
            link: "https://outlook.office365.com/owa/calendar/…/calendar.ics"
        },
        {
            key: "icloud",
            label: qsTr("iCloud"),
            icon: "cloud",
            kind: "caldav",
            how: qsTr("Your Apple ID and an app-specific password, made at account.apple.com under Sign-In and Security, App-Specific Passwords. Brings every iCloud calendar you have."),
            name: qsTr("e.g. iCloud"),
            user: qsTr("Apple ID"),
            userHint: "you@icloud.com",
            pass: qsTr("App-specific password")
        },
        {
            key: "nextcloud",
            label: qsTr("Nextcloud"),
            icon: "cloud_circle",
            kind: "caldav",
            how: qsTr("Your Nextcloud's address, your username, and an app password from Settings, Security, Devices & sessions. Brings every calendar you have there."),
            name: qsTr("e.g. Nextcloud"),
            server: "https://cloud.example.com",
            user: qsTr("Username"),
            userHint: "",
            pass: qsTr("App password")
        },
        {
            key: "caldav",
            label: qsTr("CalDAV"),
            icon: "dns",
            kind: "caldav",
            how: qsTr("Any other CalDAV server — Fastmail, mailbox.org, Posteo, Radicale, Baïkal: the address it gives you, your username and your password (an app password where it has them). Brings every calendar on the account."),
            name: qsTr("e.g. Fastmail"),
            server: "https://caldav.example.com/",
            user: qsTr("Username"),
            userHint: "",
            pass: qsTr("Password")
        },
        {
            key: "link",
            label: qsTr("Link"),
            icon: "link",
            kind: "link",
            how: qsTr("Any calendar link, .ics or webcal:// — public holidays, a team's fixtures, a school, Proton Calendar's share link, a calendar someone shared. Read-only."),
            name: qsTr("e.g. Holidays"),
            link: "https:// or webcal://…"
        }
    ]

    property string provider: "google"
    readonly property var def: root.providers.find(p => p.key === root.provider) ?? root.providers[0]
    readonly property bool isLink: root.def.kind === "link"
    readonly property bool needsServer: root.def.key === "nextcloud" || root.def.key === "caldav"

    readonly property bool ready: {
        if (Calendar.adding || Calendar.keyringProblem !== "")
            return false;
        if (root.isLink)
            return urlField.text.trim() !== "";
        return (!root.needsServer || urlField.text.trim() !== "") && userField.text.trim() !== "" && passField.text !== "";
    }

    // The account whose Remove was pressed once, waiting for the second.
    property string confirming: ""
    // Said under the form after an account has been added.
    property string added: ""

    function add(): void {
        if (!root.ready)
            return;
        root.added = "";
        Calendar.addAccount(root.provider, nameField.text.trim(), root.isLink || root.needsServer ? urlField.text.trim() : "", root.isLink ? "" : userField.text.trim(), root.isLink ? "" : passField.text);
    }

    function iconOf(provider: string): string {
        return (root.providers.find(p => p.key === provider) ?? root.providers[5]).icon;
    }

    function statusOf(a: var): string {
        const waiting = (a.pending ?? 0) > 0 ? qsTr("%n waiting to upload", "", a.pending) : "";
        // Out of reach is not broken: a server at home, a laptop out.
        if (a.offline)
            return [qsTr("Can't reach %1 — syncs when it can").arg(a.host), waiting].filter(t => t).join(" · ");
        if (a.ok === true && waiting)
            return `${Calendar.syncedAgo(a.synced * 1000)} · ${waiting}`;
        if (a.ok === true) {
            const when = Calendar.syncedAgo(a.synced * 1000);
            return a.calendars.length > 0 ? `${when} · ${a.calendars.join(", ")}` : `${when} · ${qsTr("no calendars in it yet")}`;
        }
        if (a.ok === false)
            return qsTr("Could not sync: %1").arg(a.error);
        return Calendar.syncing ? qsTr("Syncing…") : qsTr("Not synced yet");
    }

    // Which account a calendar came from, for the line under its name.
    function ownerOf(name: string): string {
        const a = Calendar.accounts.find(x => (x.calendars ?? []).some(c => c.toLowerCase() === name.toLowerCase()));
        return a ? a.name : qsTr("From your own khal config");
    }

    Connections {
        target: Calendar

        function onAccountAdded(id: string): void {
            root.added = qsTr("Added. Its events arrive with the first sync, which has started.");
            nameField.clear();
            urlField.clear();
            userField.clear();
            passField.clear();
        }
    }

    // Is vdirsyncer there? Accounts sync through it, and a missing one is
    // the likeliest reason nothing arrives.
    property bool vdirsyncer: true

    // Asked each time the window opens, not only when the page is made:
    // the page outlives a closed window, and a keyring may have started (or
    // stopped) in between.
    Component.onCompleted: Calendar.checkKeyring()

    Connections {
        target: ShellState

        function onSettingsChanged(): void {
            if (!ShellState.settings)
                return;
            Calendar.checkKeyring();
            root.added = "";
        }
    }

    Process {
        running: true
        command: ["sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; command -v vdirsyncer']
        onExited: code => root.vdirsyncer = code === 0
    }

    Timer {
        interval: Appearance.settings.confirmWindow
        running: root.confirming !== ""
        onTriggered: root.confirming = ""
    }

    PaneHeader {
        title: qsTr("Calendars")

        Pill {
            text: Calendar.syncing ? qsTr("Syncing…") : qsTr("Sync now")
            icon: "sync"
            tone: "subtle"
            interactive: Calendar.present && !Calendar.syncing
            pillHeight: Appearance.settings.actionHeight
            fontSize: Appearance.settings.actionSize
            onClicked: Calendar.sync()
        }
    }

    // ---- accounts --------------------------------------------------------
    Section {
        title: qsTr("Accounts")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            visible: Calendar.accounts.length === 0
            title: qsTr("No accounts yet")
            subtitle: Calendar.sources.length > 0 ? qsTr("Add one below. The calendars your own khal config names still show.") : qsTr("Add one below, and Home's month fills in with its events.")
        }

        Repeater {
            model: Calendar.accounts

            SettingRow {
                id: account

                required property var modelData
                required property int index

                title: account.modelData.name
                detail: account.modelData.username ? `${account.modelData.username} · ${account.modelData.host}` : account.modelData.host
                subtitle: root.statusOf(account.modelData)
                labelGap: Appearance.settings.labelGap
                leading: Icon {
                    text: root.iconOf(account.modelData.provider)
                    size: Appearance.settings.tileIcon
                    color: account.modelData.ok === false && !account.modelData.offline ? Colours.error : Colours.on.surfaceVariant
                }

                Pill {
                    readonly property bool asking: root.confirming === account.modelData.id

                    text: Calendar.removing === account.modelData.id ? qsTr("Removing…") : asking ? qsTr("Remove?") : qsTr("Remove")
                    tone: asking ? "danger" : "subtle"
                    interactive: Calendar.removing === ""
                    pillHeight: Appearance.settings.segmentHeight
                    fontSize: Appearance.settings.actionSize
                    onClicked: {
                        if (asking) {
                            root.confirming = "";
                            Calendar.removeAccount(account.modelData.id);
                        } else {
                            root.confirming = account.modelData.id;
                        }
                    }

                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    // ---- add -------------------------------------------------------------
    Section {
        title: qsTr("Add a calendar")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        // Wraps rather than squeezing: six choices do not fit one row of a
        // narrow window.
        Flow {
            spacing: Appearance.space.sm
            Layout.fillWidth: true

            Repeater {
                model: root.providers

                Pill {
                    required property var modelData

                    text: modelData.label
                    icon: modelData.icon
                    tone: "subtle"
                    checked: root.provider === modelData.key
                    pillHeight: Appearance.settings.actionHeight
                    fontSize: Appearance.settings.actionSize
                    iconSize: Appearance.size.iconSm
                    onClicked: {
                        root.provider = modelData.key;
                        root.added = "";
                    }
                }
            }
        }

        // Without a keyring there is nowhere safe to keep what the form asks
        // for, so the form waits for one.
        SettingRow {
            visible: Calendar.keyringProblem !== ""
            title: qsTr("The keyring is not available")
            subtitle: qsTr("Passwords and links are kept encrypted in it, so none can be added until it answers. vela's autostart starts gnome-keyring and your login screen unlocks it. (%1)").arg(Calendar.keyringProblem)
            leading: Icon {
                text: "key_off"
                size: Appearance.settings.tileIcon
                color: Colours.error
            }

            Pill {
                text: qsTr("Check again")
                tone: "subtle"
                pillHeight: Appearance.settings.segmentHeight
                fontSize: Appearance.settings.actionSize
                onClicked: Calendar.checkKeyring()

                Layout.alignment: Qt.AlignVCenter
            }
        }

        Text {
            text: root.def.how
            font.family: Appearance.font.ui
            font.pixelSize: Appearance.size.label
            color: Colours.outline
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        SettingRow {
            title: qsTr("Name")
            subtitle: root.isLink ? qsTr("What the calendar is called here") : qsTr("What the account is called here; its calendars keep their own names")
            SettingField {
                id: nameField

                placeholder: root.def.name
                next: root.isLink || root.needsServer ? urlField : userField
                previous: root.isLink ? urlField : passField
                onSubmitted: root.add()
                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            visible: root.isLink || root.needsServer
            title: root.isLink ? qsTr("Link") : qsTr("Server")
            subtitle: root.isLink ? qsTr("Kept encrypted in your keyring: a secret link is as good as a password") : ""
            SettingField {
                id: urlField

                mono: true
                next: root.isLink ? nameField : userField
                previous: nameField
                onSubmitted: root.add()
                placeholder: root.isLink ? root.def.link : root.def.server ?? ""
                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            visible: !root.isLink
            title: root.def.user ?? ""
            SettingField {
                id: userField

                placeholder: root.def.userHint ?? ""
                next: passField
                previous: root.needsServer ? urlField : nameField
                onSubmitted: root.add()
                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            visible: !root.isLink
            title: root.def.pass ?? ""
            subtitle: qsTr("Kept encrypted in your keyring, never in a file")
            SettingField {
                id: passField

                secret: true
                next: nameField
                previous: userField
                onSubmitted: root.add()
                Layout.alignment: Qt.AlignVCenter
            }
        }

        RowLayout {
            spacing: Appearance.settings.rowGapTight
            Layout.fillWidth: true

            Text {
                text: Calendar.adding ? qsTr("Adding…") : Calendar.addError !== "" ? Calendar.addError : root.added
                visible: text !== ""
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.label
                color: Calendar.addError !== "" && !Calendar.adding ? Colours.error : Colours.on.surfaceVariant
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Item {
                visible: !Calendar.adding && Calendar.addError === "" && root.added === ""
                Layout.fillWidth: true
            }

            Pill {
                text: qsTr("Add")
                icon: "add"
                tone: "filled"
                interactive: root.ready
                opacity: root.ready ? 1 : Appearance.dashboard.disabledOpacity
                pillHeight: Appearance.settings.actionHeight
                fontSize: Appearance.settings.actionSize
                onClicked: root.add()

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // ---- calendars ------------------------------------------------------
    Section {
        visible: Calendar.sources.length > 0
        title: qsTr("Calendars")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        Repeater {
            model: Calendar.sources

            SettingRow {
                id: cal

                required property var modelData

                // Whether new events can go here, and whether they do.
                readonly property var takes: Calendar.writableFor(cal.modelData.name)
                readonly property bool isDefault: cal.takes !== null && Calendar.defaultWritable?.path === cal.takes.path

                title: cal.modelData.name
                subtitle: [root.ownerOf(cal.modelData.name), cal.isDefault ? qsTr("new events go here") : ""].filter(t => t).join(" · ")

                // The star: where new events go. Only on a calendar that
                // takes them and is switched on.
                Icon {
                    visible: cal.takes !== null
                    text: "star"
                    fill: cal.isDefault ? 1 : 0
                    size: Appearance.settings.calendarStar
                    color: cal.isDefault ? Colours.primary : starMouse.containsMouse ? Colours.on.surface : Colours.outline

                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        id: starMouse

                        anchors.fill: parent
                        anchors.margins: -Appearance.space.xs
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Config.calendar.newEvents = cal.modelData.name;
                            Persist.commit();
                        }
                    }
                }

                // Its colour: the scheme's three accents, and grey.
                RowLayout {
                    spacing: Appearance.settings.calendarSwatchGap
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: Calendar.roles

                        Rectangle {
                            id: swatch

                            required property string modelData

                            readonly property bool chosen: cal.modelData.role === swatch.modelData

                            implicitWidth: Appearance.settings.calendarSwatch
                            implicitHeight: Appearance.settings.calendarSwatch
                            radius: width / 2
                            color: "transparent"
                            border.width: swatch.chosen ? Appearance.settings.calendarSwatchRing : 0
                            border.color: Colours.on.surface

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - Appearance.settings.calendarSwatchRing * 3
                                height: width
                                radius: width / 2
                                color: Calendar.colourOf(swatch.modelData)
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Calendar.setSource(cal.modelData.name, swatch.modelData, cal.modelData.enabled);
                                    Persist.commit();
                                }
                            }
                        }
                    }
                }

                Toggle {
                    readonly property bool wanted: cal.modelData.enabled

                    checked: wanted
                    onWantedChanged: checked = wanted
                    onToggled: on => {
                        Calendar.setSource(cal.modelData.name, cal.modelData.role, on);
                        Persist.commit();
                    }

                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    // ---- reminders ------------------------------------------------------
    Section {
        title: qsTr("Reminders")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("Before each event")
            subtitle: qsTr("For events with no reminder of their own. All-day events only remind when they have one.")

            Segmented {
                readonly property var minutes: [-1, 0, 5, 10, 15, 30]
                readonly property int wanted: Math.max(0, minutes.indexOf(Config.calendar.reminderMinutes))

                model: [qsTr("Off"), qsTr("At start"), qsTr("5 min"), qsTr("10 min"), qsTr("15 min"), qsTr("30 min")]
                currentIndex: wanted
                segmentHeight: Appearance.settings.segmentHeight
                hPadding: Appearance.settings.segmentPad
                railRadius: Appearance.radius.card
                onWantedChanged: currentIndex = wanted
                onSelected: i => {
                    Config.calendar.reminderMinutes = minutes[i];
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("Use each event's own reminders")
            subtitle: qsTr("The ones set in its calendar app, like “15 minutes before” on your phone, in place of the default")

            Toggle {
                readonly property bool wanted: Config.calendar.eventAlarms

                checked: wanted
                onWantedChanged: checked = wanted
                onToggled: on => {
                    Config.calendar.eventAlarms = on;
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: qsTr("How they look")
            subtitle: qsTr("A notification with Join for a meeting link and Snooze 5 min; clicking it opens the month. Do not disturb keeps them in the history instead.")

            Pill {
                text: qsTr("Try it")
                icon: "notifications"
                tone: "subtle"
                pillHeight: Appearance.settings.segmentHeight
                fontSize: Appearance.settings.actionSize
                onClicked: Calendar.testReminder()

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // ---- sync -----------------------------------------------------------
    Section {
        title: qsTr("Sync")
        padding: Appearance.space.panelPadding
        gap: Appearance.settings.cardGapTight

        SettingRow {
            title: qsTr("Every")
            subtitle: qsTr("How often the accounts are asked for changes")

            Segmented {
                readonly property var minutes: [5, 15, 30, 60]
                readonly property int wanted: Math.max(0, minutes.indexOf(Config.calendar.syncMinutes))

                model: [qsTr("5 min"), qsTr("15 min"), qsTr("30 min"), qsTr("1 hour")]
                currentIndex: wanted
                segmentHeight: Appearance.settings.segmentHeight
                hPadding: Appearance.settings.segmentPad
                railRadius: Appearance.radius.card
                onWantedChanged: currentIndex = wanted
                onSelected: i => {
                    Config.calendar.syncMinutes = minutes[i];
                    Persist.commit();
                }

                Layout.alignment: Qt.AlignVCenter
            }
        }

        SettingRow {
            title: !Calendar.present ? qsTr("khal is not installed") : !root.vdirsyncer ? qsTr("vdirsyncer is not installed") : Calendar.unreachable.length > 0 ? qsTr("Can't reach %1").arg(Calendar.unreachable.join(", ")) : Calendar.syncError !== "" ? qsTr("The last sync failed") : Calendar.lastSync > 0 ? Calendar.syncedAgo(Calendar.lastSync) : qsTr("Not synced yet")
            detail: Calendar.syncCommand
            subtitle: !Calendar.present ? qsTr("It reads the calendars: sudo dnf install khal, or run bootstrap again") : !root.vdirsyncer ? qsTr("It fetches the accounts: sudo dnf install vdirsyncer, or run bootstrap again") : Calendar.unreachable.length > 0 ? qsTr("Events written meanwhile are kept here and uploaded when it can be reached; a sync runs whenever the network changes") : Calendar.syncError
            labelGap: Appearance.settings.labelGap
        }
    }
}
