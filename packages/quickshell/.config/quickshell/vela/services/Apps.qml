pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// What is installed, and what each thing looks like.
//
// The launcher had both of these inline, which broke the standing rule that a
// module never shells out -- it asks a service. Both answers are also wanted in
// more than one place: the bar already asks "which app is this" of a window
// class, and the launcher asks it of a desktop entry.
Singleton {
    id: root

    // Executable names on $PATH, for the launcher's command source.
    property var executables: []

    property bool scanned: false

    // Primed when something first needs it rather than at startup: 3200
    // filenames off eight directories costs about 30ms, which is worth nothing
    // at boot and is already spent by the time a first keystroke arrives.
    function prime(): void {
        if (root.scanned)
            return;
        root.scanned = true;
        scan.running = true;
    }

    // Which Material Symbol an application carries. The design draws monochrome
    // ligatures rather than themed app icons -- `videocam` for a recorder,
    // `edit_note` for a notes app -- so an entry's glyph is deduced, not read
    // off the icon theme. With an icon theme chosen in Settings the app's own
    // icon is drawn instead (`AppIcons`), and this is what it falls back to.
    //
    // Categories first, because they are the entry's own statement of what it
    // is; a name heuristic only answers when Categories is absent or too
    // generic, which on one machine was about half of /usr/share/applications.
    //
    // WHOLE categories, never a substring of the joined list. The obvious
    // `/ide|development/.test(joined)` version gave an audio player a `code`
    // glyph, because "AudioVideo" contains "ide" -- measured on screen, three
    // rows wrong out of eight.
    //
    // First match wins, so the order runs specific before general: a player
    // that declares Music, Audio *and* AudioVideo is described by the first two.
    readonly property var categorySymbols: [["recorder", "screencast"], "videocam", ["webbrowser"], "public", ["terminalemulator"], "terminal", ["filemanager"], "folder", ["ide", "development", "building", "debugger", "revisioncontrol"], "code", ["email", "contactmanagement"], "mail", ["instantmessaging", "irc", "ircclient", "chat", "telephony", "videoconference"], "forum", ["music", "audio", "midi", "mixer", "sequencer", "tuner"], "music_note", ["video", "tv", "dvd", "player", "audiovideo"], "movie", ["photography", "graphics", "2dgraphics", "3dgraphics", "rastergraphics", "vectorgraphics", "imageprocessing"], "palette", ["game"], "sports_esports", ["calculator"], "calculate", ["clock"], "schedule", ["texteditor", "wordprocessor", "office", "spreadsheet", "presentation", "documentation", "dictionary"], "edit_note", ["monitor", "security", "filesystem", "filetools", "archiving"], "monitoring", ["settings", "hardwaresettings", "desktopsettings"], "settings", ["network", "p2p", "webdevelopment", "remoteaccess", "dialup"], "language"]

    // The whole question, in the order that answers it best: what the entry
    // says it is, then what its id looks like, then its name. It existed
    // identically in the launcher and in the dock -- two copies of one thing --
    // before it moved here.
    function symbolFor(entry: var): string {
        const byCategory = root.symbolForCategories(entry?.categories);
        if (byCategory)
            return byCategory;
        // `Hypr.symbolFor` asks the same thing of a window class. The desktop
        // id is the closer match to a class ("org.kde.dolphin",
        // "google-chrome"); the name catches the rest.
        const byId = Hypr.symbolFor(entry?.id ?? "");
        return byId === "web_asset" ? Hypr.symbolFor(entry?.name ?? "") : byId;
    }

    // The terminal that `Terminal=true` entries run in -- the same one the
    // super + return bind starts.
    readonly property string terminal: "kitty"

    // Launch a desktop entry. `DesktopEntry.execute()` ignores Terminal=true
    // (Quickshell says so in its own docs), so htop, btop, nvim and friends
    // started with no window at all; those go through the terminal instead.
    function launch(entry: DesktopEntry): void {
        if (!entry)
            return;
        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: [root.terminal, "-e", ...entry.command],
                workingDirectory: entry.workingDirectory
            });
        else
            entry.execute();
    }

    // Run a shell command detached. The launcher's `>` mode is the only caller;
    // it lives here because a module does not start processes.
    function run(command: string): void {
        if (!command)
            return;
        Quickshell.execDetached(["sh", "-c", command]);
    }

    function symbolForCategories(categories: var): string {
        const lower = (categories ?? []).map(c => c.toLowerCase());
        for (let i = 0; i < root.categorySymbols.length; i += 2)
            if (root.categorySymbols[i].some(c => lower.includes(c)))
                return root.categorySymbols[i + 1];
        return "";
    }

    // `running` is never declared inline: Quickshell starts a Process the
    // instant that property is set and QML assigns in declaration order, so
    // `stdout` would be attached to a process that had already run and would
    // collect nothing. `prime()` sets it once the object exists.
    Process {
        id: scan

        command: ["sh", "-c", 'IFS=:; for d in $PATH; do [ -d "$d" ] && find "$d" -maxdepth 1 \( -type f -o -type l \) -executable -printf "%f\n" 2>/dev/null; done | sort -u']

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim();
                root.executables = text ? text.split("\n") : [];
            }
        }
    }
}
