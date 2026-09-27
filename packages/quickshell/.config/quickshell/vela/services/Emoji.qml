pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The emoji the launcher's `:` search offers, and putting one where you were.
//
// The table is `assets/emoji.tsv`: every emoji in Unicode's order with its name
// and a handful of words people search for it by ("smile, happy, joy"). It is
// read the first time somebody types `:`, not at startup -- 130 KB that most
// sessions never ask for.
Singleton {
    id: root

    // { glyph, name, words } in Unicode's order, which puts the faces people
    // reach for first.
    property var entries: []
    property bool wanted: false

    function prime(): void {
        root.wanted = true;
    }

    // Best first. Each word of the query has to land in the name or the search
    // words, and scores by where: the start of the name beats the start of a
    // word in it, which beats a search word, which beats a letter run buried
    // somewhere. Ties keep Unicode's order.
    function search(text: string): var {
        const parts = text.toLowerCase().split(/\s+/).filter(p => p);
        if (parts.length === 0)
            return root.entries;

        const scored = [];
        root.entries.forEach((entry, index) => {
            let total = 0;
            for (const part of parts) {
                const best = root.score(entry, part);
                if (best === 0)
                    return;
                total += best;
            }
            scored.push({
                entry,
                index,
                score: total / parts.length
            });
        });
        scored.sort((a, b) => b.score - a.score || a.index - b.index);
        return scored.map(s => s.entry);
    }

    function score(entry: var, part: string): real {
        if (entry.name === part)
            return 1;
        if (entry.name.startsWith(part))
            return 0.9;
        if (entry.name.includes(` ${part}`))
            return 0.8;
        if (entry.words.includes(part))
            return 0.7;
        if (entry.words.some(w => w.startsWith(part)))
            return 0.6;
        if (entry.name.includes(part))
            return 0.4;
        return 0;
    }

    // Onto the clipboard, and typed into the focused window once the launcher
    // has let go of the keyboard. wtype types the glyph itself rather than a
    // paste shortcut, so a terminal and a browser take it the same way, and
    // what was on the clipboard before is still one paste away in its history.
    // Without wtype it is a copy.
    function insert(glyph: string): void {
        typer.exec(["sh", "-c", "wl-copy -- \"$1\"; command -v wtype >/dev/null && sleep 0.2 && wtype -- \"$1\"", "vela-emoji", glyph]);
    }

    // In order, one at a time: a second glyph picked while the first is
    // still being typed waits for it rather than replacing it (Clipboard's
    // actions, the same).
    Process {
        id: typer

        property var queue: []

        function exec(cmd: var): void {
            if (running) {
                queue = [...queue, cmd];
                return;
            }
            command = cmd;
            running = true;
        }

        onExited: {
            if (queue.length > 0) {
                const next = queue[0];
                queue = queue.slice(1);
                command = next;
                running = true;
            }
        }
    }

    FileView {
        id: table

        path: root.wanted ? Quickshell.shellPath("assets/emoji.tsv") : ""
        watchChanges: false

        onLoaded: {
            const out = [];
            for (const line of table.text().split("\n")) {
                if (!line || line.startsWith("#"))
                    continue;
                const [glyph, name, words] = line.split("\t");
                out.push({
                    glyph,
                    name,
                    words: words ? words.split(", ") : []
                });
            }
            root.entries = out;
        }
    }
}
