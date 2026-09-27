pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// What is in each of the dock's stacks -- the design's Downloads and Trash.
//
// Headless, and the only thing in this module that runs a process. It belongs
// in `services/Files.qml`, beside every other thing that asks the system a
// question: a stack is any folder, and the clipboard, the capture overlay and
// the wallpaper switcher all have their own reasons to want "what is in this
// directory, newest first". It has not been moved there yet -- said out loud
// rather than left as a surprise.
//
// One reader per configured stack, re-run when the dock is revealed and while
// it is on screen, never on a timer that ticks into an empty session. A `find`
// over one directory is a few milliseconds; a watch on the directory would be
// better still, but `FileView` watches files, not directories, and inotify is
// not exposed to QML.
Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")

    // { "<configured path>": { count: int, files: [ { name, type, time, path } ] } }
    property var listings: ({})

    // The XDG trash spec puts the files themselves one level down from the
    // trash directory; the metadata beside them is not something to list.
    readonly property string trashPath: `${root.home}/.local/share/Trash/files`

    function resolve(path: string): string {
        if (path === "trash")
            return root.trashPath;
        if (path.startsWith("~"))
            return root.home + path.slice(1);
        return path;
    }

    function label(path: string): string {
        if (path === "trash")
            return qsTr("Trash");
        const full = root.resolve(path).replace(/\/+$/, "");
        return full.slice(full.lastIndexOf("/") + 1) || full;
    }

    function count(path: string): int {
        return root.listings[path]?.count ?? 0;
    }

    function files(path: string): var {
        return root.listings[path]?.files ?? [];
    }

    // Distinguishes "nothing in it" from "not looked yet", so an empty panel can
    // say which it means.
    function known(path: string): bool {
        return root.listings[path] !== undefined;
    }

    function openFolder(path: string): void {
        Files.open(root.resolve(path));
    }

    // `gio trash --empty` also clears the trash on every mounted drive, but
    // without gvfs running it answers success having touched nothing --
    // measured: exit 0, both files still there. So the home trash is then
    // cleared by hand whatever gio said: what is in the folders, not the
    // folders, so anything watching them stays attached, and dotfiles
    // included, which a glob would miss.
    function emptyTrash(): void {
        emptier.running = true;
    }

    Process {
        id: emptier

        command: ["sh", "-c", 'gio trash --empty 2>/dev/null; t="$1"; find "$t/files" "$t/info" "$t/expunged" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null; rm -f -- "$t/directorysizes"', "vela-trash", `${root.home}/.local/share/Trash`]
        onExited: root.refresh()
    }

    function openFile(file: var): void {
        Files.open(file.path);
    }

    function refresh(): void {
        for (let i = 0; i < readers.count; i++)
            readers.objectAt(i).reload();
    }

    // A var object mutated in place does not notify, so every listing has to
    // produce a new one.
    function record(path: string, files: var): void {
        const next = Object.assign({}, root.listings);
        next[path] = {
            count: files.length,
            files: files
        };
        root.listings = next;
    }

    // Which Material Symbol a file carries. The design's own six, extended to
    // the kinds a real Downloads folder actually holds.
    function iconFor(file: var): string {
        if (file.type === "d")
            return "folder";
        const name = file.name.toLowerCase();
        const ext = name.includes(".") ? name.slice(name.lastIndexOf(".") + 1) : "";
        if (ext === "pdf")
            return "picture_as_pdf";
        if (/^(zip|tar|gz|tgz|xz|bz2|zst|7z|rar|iso)$/.test(ext))
            return "folder_zip";
        if (/^(png|jpg|jpeg|gif|webp|avif|svg|bmp|tiff|heic)$/.test(ext))
            return "image";
        if (/^(mp4|mkv|webm|mov|avi|m4v|wmv)$/.test(ext))
            return "movie";
        if (/^(mp3|flac|ogg|opus|wav|m4a|aac)$/.test(ext))
            return "music_note";
        if (/^(sh|bash|fish|zsh|py|rb|pl|lua|appimage|run)$/.test(ext))
            return "terminal";
        if (/^(md|txt|org|rst|doc|docx|odt|rtf|tex|csv)$/.test(ext))
            return "description";
        if (/^(qml|js|ts|json|yaml|yml|toml|c|h|cpp|rs|go|java|css|html|xml)$/.test(ext))
            return "code";
        if (/^(rpm|deb|pkg|flatpakref)$/.test(ext))
            return "inventory_2";
        return "draft";
    }

    // "2 min", "1 h", "yesterday" -- the design's own vocabulary. A duration is
    // a literal, so whatever draws this sets it in mono.
    function ago(time: real): string {
        const secs = Math.max(0, Date.now() / 1000 - time);
        if (secs < 60)
            return qsTr("now");
        const mins = Math.floor(secs / 60);
        if (mins < 60)
            return qsTr("%1 min").arg(mins);
        const hours = Math.floor(mins / 60);
        if (hours < 24)
            return qsTr("%1 h").arg(hours);
        if (hours < 48)
            return qsTr("yesterday");
        return qsTr("%1 d").arg(Math.floor(hours / 24));
    }

    Instantiator {
        id: readers

        model: Config.dock.stacks

        delegate: QtObject {
            id: reader

            required property var modelData

            readonly property string path: reader.modelData.path ?? ""
            readonly property string dir: root.resolve(reader.path)

            function reload(): void {
                if (reader.path)
                    scan.running = true;
            }

            // `running` is never set in the declaration: Quickshell starts a
            // Process the instant that property is assigned and QML assigns in
            // declaration order, so `stdout` would be attached to a process
            // that had already finished.
            property Process scan: Process {
                // The trailing slash is load-bearing. `test -d` follows a
                // symlink and `find` does not, so a `~/Downloads` that is a
                // link to another disk -- an ordinary way to set one up --
                // passed the guard and then listed nothing, leaving the stack
                // empty and its count badge off with no error anywhere.
                // `find "$d/"` descends into the target.
                //
                // The folder is an argument, never part of the script: pasted
                // in as a JSON string it was in double quotes, where the shell
                // still expands a `$` or a backtick in the path.
                command: ["sh", "-c", `d=$1; [ -d "$d" ] || exit 0; find "$d/" -mindepth 1 -maxdepth 1 -printf '%T@\\t%y\\t%f\\n' 2>/dev/null | sort -rn`, "vela-stack", reader.dir]

                stdout: StdioCollector {
                    onStreamFinished: {
                        const text = this.text.trim();
                        const lines = text ? text.split("\n") : [];
                        const files = [];
                        for (const line of lines) {
                            const parts = line.split("\t");
                            if (parts.length < 3)
                                continue;
                            // A name may contain a tab; the first two fields
                            // never can.
                            const name = parts.slice(2).join("\t");
                            // A dot file in Downloads is a part-download or an
                            // editor's swap file, not something to offer.
                            if (!name || name.startsWith("."))
                                continue;
                            files.push({
                                name: name,
                                type: parts[1],
                                time: parseFloat(parts[0]),
                                path: `${reader.dir}/${name}`
                            });
                        }
                        root.record(reader.path, files);
                    }
                }
            }
        }
    }
}
