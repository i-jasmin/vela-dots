pragma Singleton

import QtQuick
import Quickshell
import Qt.labs.folderlistmodel

// The filesystem, for the surfaces that show it.
//
// Two questions, both of which a module would otherwise answer by running a
// process: "open this" and "what is in this folder, newest first". The dock's
// stacks, the clipboard's open action and the calendar's Join button all ask
// one or the other.
Singleton {
    id: root

    function expand(path: string): string {
        const p = path ?? "";
        return p.startsWith("~") ? Quickshell.env("HOME") + p.slice(1) : p;
    }

    // Hands the path to whatever the desktop says owns it. Also the right call
    // for a URL -- xdg-open does not care which it was given.
    function open(target: string): void {
        if (!target)
            return;
        Quickshell.execDetached(["xdg-open", root.expand(target)]);
    }

    function openUrl(url: string): void {
        root.open(url);
    }

    // A listing of `path`, newest first. Returns a FolderListModel rather than
    // an array: it watches the directory, so a stack that is open while a
    // download lands updates itself instead of going stale.
    function watch(path: string, limit: int): var {
        return listing.createObject(root, {
            folder: `file://${root.expand(path)}`,
            limit: limit ?? 0
        });
    }

    Component {
        id: listing

        FolderListModel {
            property int limit: 0

            showDirs: true
            showDotAndDotDot: false
            showHidden: false
            sortField: FolderListModel.Time
            sortReversed: false
        }
    }
}
