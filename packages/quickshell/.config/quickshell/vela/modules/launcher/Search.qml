import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// The launcher's model: the query, the ranked results, which one is selected,
// and what happens when it is launched. The launcher mixes three sources in one
// list -- applications, commands on $PATH and a web fallback -- so the ranking
// has to produce one flat list from three very different kinds of thing.
//
// Headless on purpose. Nothing here draws, so the measurement the footer
// reports ("4 results · 3 ms") is the cost of the search itself rather than the
// cost of the search plus a relayout, and the ladder below can be reasoned
// about without a delegate in the way.
//
// The $PATH scan and the category-to-ligature table both live in
// `services/Apps.qml`: they shell out and they are asked by more than one
// module, and throughout the shell a surface asks a service rather than running
// a process itself.
//
// SHORTCUTS IN THE FIELD. A sum or a conversion -- `12*7`, `5 km in mi` -- gets
// its answer as the first row, and enter copies it (`services/Calc.qml`). Three
// prefixes turn the list into one thing: `=` is always a sum, `:` searches
// emoji and types the one picked, `;` searches the clipboard history and
// pastes. Each can be switched off in settings, and then its character is
// just a character.
Scope {
    id: root

    // ---- state ------------------------------------------------------------

    property string query: ""
    property int selected: 0

    readonly property string trimmed: root.query.trim()
    readonly property bool searching: root.trimmed.length > 0

    // A result is a plain object, not a typed model: three sources with three
    // different payloads share one list, and the delegate only ever reads
    // `kind`, `title`, `subtitle` and `icon`.
    //
    //   { kind: "app"|"command"|"web"|"answer"|"emoji"|"clip", title,
    //     subtitle, icon, image?: string, mono: bool, glyph: string,
    //     entry: DesktopEntry|clipboard entry|null, payload: string }
    //
    // `glyph` is the emoji a row shows in place of its icon, and `image` an
    // app's own icon, when an icon theme is chosen (`AppIcons`).
    property var results: []
    // What the footer counts: every match found, before `maxResults` cuts the
    // list down to what fits.
    property int matchCount: 0
    property int elapsed: 0

    readonly property var current: root.results[root.selected] ?? null

    // What the query is: an ordinary search, or one of the prefixes. `rest` is
    // the query with its prefix taken off.
    readonly property string mode: {
        const q = root.trimmed;
        if (Config.launcher.emoji && q.startsWith(":"))
            return "emoji";
        if (Config.launcher.clipboard && q.startsWith(";"))
            return "clip";
        if (Config.launcher.calculator && q.startsWith("="))
            return "calc";
        return "search";
    }
    readonly property string rest: root.mode === "search" ? root.trimmed : root.trimmed.slice(1).trim()

    // What enter does to the selected row, for the footer.
    readonly property string verb: ({
            app: qsTr("launch"),
            command: qsTr("run"),
            web: qsTr("search"),
            answer: qsTr("copy"),
            emoji: qsTr("insert"),
            clip: qsTr("paste")
        })[root.current?.kind ?? "app"]
    // Whether Tab has anything to fill in from the selected row.
    readonly property bool completes: ["app", "command", "answer"].includes(root.current?.kind ?? "app")

    // DesktopEntries is empty for the first second or two of a session,
    // so this stays a binding -- a snapshot taken at startup would be empty for
    // the rest of the run. NoDisplay is the desktop-entry spec's own "keep this
    // out of menus".
    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    // Everything executable on $PATH, filled once by the scan below.
    property bool scanned: false

    // Re-rank whenever anything the ranking reads changes. `sources`,
    // `maxResults` and `webSearch` are live-reloaded out of shell.json, so a
    // list that ignored them would be stale the moment the settings screen
    // wrote the file.
    // The emoji table and the clipboard history only while their prefix is
    // typed: a copy made with the launcher shut should not re-rank it.
    readonly property var inputs: [root.trimmed, root.apps, Apps.executables, Config.launcher.maxResults, Config.launcher.sources, Config.launcher.webSearch, Config.launcher.calculator, Config.launcher.emoji, Config.launcher.clipboard, root.mode === "emoji" ? Emoji.entries : null, root.mode === "clip" ? Clipboard.entries : null]

    onInputsChanged: root.rank()
    // A change handler does not run for the initial value, so after a reload
    // -- with the desktop entries already loaded -- the list stayed empty
    // until something else changed.
    Component.onCompleted: root.rank()

    // ---- ranking ----------------------------------------------------------

    function rank(): void {
        const started = Date.now();
        const cap = Math.max(1, Config.launcher.maxResults);

        if (root.mode !== "search") {
            let found = [];
            if (root.mode === "emoji") {
                Emoji.prime();
                found = Emoji.search(root.rest).map(e => root.emojiResult(e));
            } else if (root.mode === "clip") {
                found = root.searchClipboard(root.rest).map(e => root.clipResult(e));
            } else {
                const answer = Calc.answer(root.rest, true);
                found = answer ? [root.answerResult(answer)] : [];
            }
            root.finish(found.slice(0, cap), found.length, started);
            return;
        }

        // A sum or a conversion answers first: somebody who typed `12*7` is
        // not looking for an application called that.
        const answer = Config.launcher.calculator && root.searching ? Calc.answer(root.trimmed, false) : null;
        const answers = answer ? [root.answerResult(answer)] : [];

        const sources = [];
        for (const name of Config.launcher.sources)
            sources.push(name);

        const words = root.trimmed.toLowerCase();
        const apps = sources.includes("apps") ? root.rankApps(words) : [];
        const commands = sources.includes("commands") ? root.rankCommands(root.trimmed) : [];
        const web = sources.includes("web") && root.searching ? [root.webResult(root.trimmed)] : [];

        // Commands are capped well below `maxResults`: a two-letter query
        // prefixes hundreds of binaries, and a launcher that answers "gn" with
        // eight of them has buried the app the user meant.
        const shownCommands = commands.slice(0, root.commandLimit);

        // The later sources are given their rows first and the apps take what
        // is left, so the web fallback is always reachable. Reversing that --
        // filling with apps and truncating -- is what makes a launcher's web
        // fallback appear only when nothing matched, which is exactly when it
        // is least useful.
        const appCap = Math.max(1, cap - answers.length - shownCommands.length - web.length);

        const out = [...answers];
        for (const name of sources) {
            if (name === "apps")
                out.push(...apps.slice(0, appCap));
            else if (name === "commands")
                out.push(...shownCommands);
            else if (name === "web")
                out.push(...web);
        }

        root.finish(out.slice(0, cap), answers.length + apps.length + commands.length + web.length, started);
    }

    function finish(results: var, matches: int, started: real): void {
        root.matchCount = matches;
        root.results = results;
        root.elapsed = Date.now() - started;
        // A new result set invalidates the old cursor; keeping it would launch
        // whichever row happened to slide underneath it.
        root.selected = 0;
    }

    // Newest first, as the history keeps them; the words match the text or the
    // app it was copied from, the same test the clipboard panel's search uses.
    function searchClipboard(text: string): var {
        const needle = text.toLowerCase();
        if (!needle)
            return Clipboard.entries;
        return Clipboard.entries.filter(e => e.text.toLowerCase().includes(needle) || e.app.toLowerCase().includes(needle));
    }

    readonly property int commandLimit: 3

    // With nothing typed the panel still lists apps, alphabetically, rather
    // than an empty box the user has to guess at -- and the arrow keys have
    // something to move over from the first frame.
    function rankApps(words: string): var {
        if (!words)
            return [...root.apps].sort((a, b) => a.name.localeCompare(b.name)).map(e => root.appResult(e));

        const scored = [];
        for (const entry of root.apps) {
            const score = root.scoreEntry(entry, words);
            if (score > 0)
                scored.push({
                    entry,
                    score
                });
        }

        // Ties break on the shorter name: between two equally good matches the
        // less qualified one is nearly always the one meant -- "Files" over
        // "Files Preferences".
        scored.sort((a, b) => b.score - a.score || a.entry.name.length - b.entry.name.length);
        return scored.map(m => root.appResult(m.entry));
    }

    // The design draws a command result as `obs-cli --scene desk`, arguments
    // and all, which is the shape of a query whose first word is a real binary.
    // A bare word instead offers the binaries it prefixes.
    function rankCommands(raw: string): var {
        if (!raw)
            return [];

        const parts = raw.split(/\s+/);
        if (parts.length > 1)
            return Apps.executables.includes(parts[0]) ? [root.commandResult(raw)] : [];

        const head = parts[0].toLowerCase();
        const hits = Apps.executables.filter(c => c.toLowerCase().startsWith(head));
        // Shortest first: someone typing "git" means git, not git-receive-pack.
        hits.sort((a, b) => a.length - b.length || a.localeCompare(b));
        return hits.map(c => root.commandResult(c));
    }

    // How well one entry matches the whole query, 0 for no match.
    //
    // Each word is scored against the entry's four searchable fields and keeps
    // its best hit, weighted by how likely the user was thinking of that field:
    // a keywords or categories hit is a real match but never outranks an
    // equally good name hit. Every word has to land somewhere and the entry
    // scores the average, so a second word narrows rather than widens: "fire br"
    // keeps Firefox, which matches "fire" in its name and "br" in its Web
    // Browser generic name, and drops everything that matched only one.
    function scoreEntry(entry: var, words: string): real {
        const parts = words.split(/\s+/);
        let total = 0;

        for (const word of parts) {
            const best = Math.max(root.scoreText(entry.name, word), root.scoreText(entry.genericName, word) * 0.7, root.scoreList(entry.keywords, word) * 0.6, root.scoreList(entry.categories, word) * 0.4);
            if (best === 0)
                return 0;
            total += best;
        }

        return total / parts.length;
    }

    function scoreList(texts: var, word: string): real {
        return (texts ?? []).reduce((best, text) => Math.max(best, root.scoreText(text, word)), 0);
    }

    // Scores one query word against one piece of text, 0 to 1. Where the match
    // lands matters more than that it happened, because someone typing "fi"
    // means Files far more often than Color Profile Viewer.
    //
    //   1.00   the text is exactly the word
    //   0.90   the text starts with it            fire -> Firefox
    //   0.75   a word of the text starts with it  man  -> File Manager
    //   0.50   it is buried inside a word         man  -> Command Line
    //   <=0.40 its letters appear in order but apart, scaled by how many of
    //          them continued a run or opened a word
    //   0.00   the letters do not appear in order: not a match
    function scoreText(text: string, word: string): real {
        if (!text)
            return 0;

        const haystack = text.toLowerCase();
        if (haystack === word)
            return 1;
        if (haystack.startsWith(word))
            return 0.9;

        // A hit at a word boundary beats one buried mid-word wherever it falls
        // in the text, so look at every occurrence rather than only the first.
        let buried = false;
        for (let at = haystack.indexOf(word); at !== -1; at = haystack.indexOf(word, at + 1)) {
            if (root.opensWord(haystack, at))
                return 0.75;
            buried = true;
        }

        return buried ? 0.5 : root.scatterScore(haystack, word);
    }

    function opensWord(text: string, at: int): bool {
        return at === 0 || !/[a-z0-9]/.test(text[at - 1]);
    }

    // The fuzzy tier. Walks the word through the text taking the earliest match
    // for each letter and counts only the letters that either continued the
    // previous match or opened a word, so an acronym scores full marks here
    // while letters found scattered at random barely register. That is what
    // keeps fuzzy matching from burying the exact matches above it.
    function scatterScore(text: string, word: string): real {
        let from = 0;
        let previous = -2;
        let strong = 0;

        for (let i = 0; i < word.length; i++) {
            const at = text.indexOf(word[i], from);
            if (at === -1)
                return 0;
            if (at === previous + 1 || root.opensWord(text, at))
                strong++;
            previous = at;
            from = at + 1;
        }

        return 0.4 * strong / word.length;
    }

    // ---- result construction ----------------------------------------------

    function appResult(entry: var): var {
        // GenericName first, Comment behind it -- but an entry whose generic
        // name only repeats its name ("Audio Player" / "Audio Player", which is
        // most of GNOME's) gets the comment instead, because a subtitle that
        // says the title again is a row of wasted height.
        const generic = entry.genericName ?? "";
        const subtitle = generic && generic.toLowerCase() !== entry.name.toLowerCase() ? generic : entry.comment || "";

        return {
            kind: "app",
            title: entry.name,
            subtitle,
            icon: Apps.symbolFor(entry),
            // The app's own icon when an icon theme is chosen, "" otherwise;
            // `icon` stays the fallback.
            image: AppIcons.forEntry(entry),
            mono: false,
            glyph: "",
            entry,
            payload: entry.name
        };
    }

    function commandResult(command: string): var {
        return {
            kind: "command",
            title: command,
            subtitle: qsTr("Run command"),
            icon: "terminal",
            // A command is a literal, so it is monospace, as every literal is.
            mono: true,
            glyph: "",
            entry: null,
            payload: command
        };
    }

    function webResult(raw: string): var {
        return {
            kind: "web",
            // The design's copy, typographic quotes and all.
            title: qsTr("Search the web for “%1”").arg(raw),
            subtitle: root.engineName,
            icon: "travel_explore",
            mono: false,
            glyph: "",
            entry: null,
            payload: Config.launcher.webSearch + encodeURIComponent(raw)
        };
    }

    // A number is a literal, so the answer is monospace.
    function answerResult(answer: var): var {
        return {
            kind: "answer",
            title: answer.text,
            subtitle: answer.copy === answer.text ? qsTr("Copy the answer") : qsTr("Copy the number"),
            icon: answer.symbol,
            mono: true,
            glyph: "",
            entry: null,
            payload: answer.copy
        };
    }

    // "Grinning face", over the words that found it.
    function emojiResult(emoji: var): var {
        return {
            kind: "emoji",
            title: emoji.name.charAt(0).toUpperCase() + emoji.name.slice(1),
            subtitle: emoji.words.slice(0, 4).join(", "),
            icon: "",
            mono: false,
            glyph: emoji.glyph,
            entry: null,
            payload: emoji.glyph
        };
    }

    // The first line of what was copied, over where it came from and when --
    // or, for a picture, what the picture is.
    function clipResult(entry: var): var {
        const image = entry.kind === "image";
        const said = [entry.app, Clipboard.ago(entry)].filter(p => p).join(" · ");
        return {
            kind: "clip",
            title: image ? qsTr("Image") : entry.text.trim().split("\n")[0],
            subtitle: image ? Clipboard.detail(entry) : said,
            icon: Clipboard.icon(entry),
            mono: entry.kind === "colour" || entry.kind === "link",
            glyph: "",
            entry,
            payload: entry.text
        };
    }

    // The search engine's own name, not its hostname: the design says
    // "DuckDuckGo", and "Duckduckgo.com" would be a different, worse screen.
    // Anything unrecognised falls back to the host, which is at least true.
    readonly property string engineName: {
        const host = (Config.launcher.webSearch.match(/^[a-z]+:\/\/([^/?#]+)/i)?.[1] ?? "").replace(/^www\./, "").toLowerCase();
        const known = {
            "duckduckgo.com": "DuckDuckGo",
            "google.com": "Google",
            "bing.com": "Bing",
            "kagi.com": "Kagi",
            "startpage.com": "Startpage",
            "ecosia.org": "Ecosia",
            "qwant.com": "Qwant",
            "search.brave.com": "Brave Search",
            "searx.be": "SearXNG"
        };
        return known[host] ?? (host || qsTr("Web"));
    }

    // ---- keyboard ----------------------------------------------------------

    // Wraps, because at the end of a short list Down almost always means "back
    // to the top" rather than "do nothing".
    function move(delta: int): void {
        if (root.results.length === 0)
            return;
        root.selected = (root.selected + delta + root.results.length) % root.results.length;
    }

    // Tab. Fills the query in from the selected row so the next keystroke
    // narrows from a real name rather than from two letters -- or, on an
    // answer, carries the number on so the next sum starts from it.
    function complete(): void {
        const result = root.current;
        if (!result || !root.completes)
            return;
        root.query = result.kind === "answer" && root.mode === "calc" ? `=${result.payload}` : result.payload;
    }

    // Takes the result rather than reading `current`, so a click launches the
    // row that was clicked even though the selection never moved to it.
    function activate(result: var): void {
        if (!result)
            return;

        // Close first: an application can take a second to map its window, and
        // a launcher still sitting over it looks like the click missed.
        ShellState.close("launcher");

        if (result.kind === "app")
            Apps.launch(result.entry);
        else if (result.kind === "command")
            Apps.run(result.payload);
        else if (result.kind === "web")
            Files.open(result.payload);
        else if (result.kind === "answer")
            Clipboard.copyText(result.payload);
        else if (result.kind === "emoji")
            Emoji.insert(result.payload);
        else if (result.kind === "clip")
            Clipboard.paste(result.entry);
    }

    function reset(): void {
        root.query = "";
        root.selected = 0;
    }

    // Called when the launcher opens rather than at startup: 3200 filenames off
    // eight directories costs 30ms, which is worth nothing at boot and is
    // already spent by the time the first keystroke arrives.
    function prime(): void {
        if (root.scanned || !Config.launcher.sources.includes("commands"))
            return;
        root.scanned = true;
        Apps.prime();
    }
}
