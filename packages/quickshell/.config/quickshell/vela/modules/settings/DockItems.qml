pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import qs.config
import qs.services
import qs.tokens
import qs.components

// The Bar page's "Pinned & stacks": one strip of icons, the applications first,
// then a rule, then the folder stacks and the trash, then the square that adds
// another.
//
// ONE LIST, TWO ARRAYS. `Config.dock.pinned` and `Config.dock.stacks` are
// separate keys because they are separate things -- an application and a folder
// do not sort together -- and the rule between them is the design saying so.
// Reordering therefore happens within a group; dragging an application past the
// rule does nothing, which is the honest behaviour rather than a silent one.
//
// The tiles are placed by hand rather than by a RowLayout, because a dragged
// tile has to leave its slot and a layout will not let it.
Item {
    id: root

    readonly property int step: Appearance.settings.tile + Appearance.settings.tileGap

    // `list<string>` and `list<var>` off the JSON adapter are not JS arrays, so
    // they are copied before anything array-shaped is done to them.
    readonly property var apps: {
        const out = [];
        for (const a of Config.dock.pinned)
            out.push(String(a));
        return out;
    }
    readonly property var stacks: {
        const out = [];
        for (const s of Config.dock.stacks)
            out.push(s);
        return out;
    }

    readonly property int ruleX: root.apps.length * root.step + Appearance.settings.listDividerGap
    readonly property int stackBase: root.apps.length === 0 ? 0 : root.ruleX + 1 + Appearance.settings.listDividerGap + Appearance.settings.tileGap
    readonly property int addX: root.stackBase + root.stacks.length * root.step

    property bool adding: false

    implicitWidth: root.addX + Appearance.settings.tile
    implicitHeight: Appearance.settings.tile

    // --- the model, written straight back to the config -------------------

    function writeApps(next: var): void {
        Config.dock.pinned = next;
        Persist.commit();
    }

    function writeStacks(next: var): void {
        Config.dock.stacks = next;
        Persist.commit();
    }

    function shift(list: var, from: int, to: int): var {
        const next = list.slice();
        const at = Math.max(0, Math.min(next.length - 1, to));
        next.splice(at, 0, next.splice(from, 1)[0]);
        return next;
    }

    // Where an x the user let go of belongs, in slots.
    function slotAt(x: real, base: int, count: int): int {
        return Math.max(0, Math.min(count - 1, Math.round((x - base) / root.step)));
    }

    // Focus walks the whole strip -- applications, then stacks, then the add
    // square -- because it is one list to the user however many arrays it is
    // underneath.
    function focusAt(i: int): void {
        const n = root.apps.length;
        const m = root.stacks.length;
        const k = Math.max(0, Math.min(n + m, i));
        const item = k < n ? appTiles.itemAt(k) : k < n + m ? stackTiles.itemAt(k - n) : add;
        if (item)
            item.forceActiveFocus();
    }

    // A stack's glyph is stored with it, because the design draws a different
    // one for Downloads and for the trash; a folder that has not said carries
    // the generic one.
    function stackIcon(entry: var): string {
        return String(entry?.icon ?? "folder");
    }

    function stackName(entry: var): string {
        const p = String(entry?.path ?? "");
        if (p === "trash")
            return qsTr("Trash");
        return p.slice(p.lastIndexOf("/") + 1);
    }

    Repeater {
        id: appTiles

        model: root.apps

        DockTile {
            id: appTile

            required property int index
            required property string modelData

            // The design draws monochrome ligatures rather than themed app
            // icons, and `Hypr` already answers "which app is this" for the
            // bar's focused-window chip. Same question, same answer -- and
            // the app's own icon, as the dock draws it, with an icon theme.
            icon: Hypr.symbolFor(appTile.modelData.replace(/\.desktop$/, ""))
            source: AppIcons.forClass(appTile.modelData.replace(/\.desktop$/, ""))
            draggable: root.apps.length > 1
            x: appTile.dragging ? appTile.dragX : appTile.index * root.step
            z: appTile.dragging ? 1 : 0

            onDropped: at => root.writeApps(root.shift(root.apps, appTile.index, root.slotAt(at, 0, root.apps.length)))
            onMove: by => root.focusAt(appTile.index + by)
            onReorder: by => {
                root.writeApps(root.shift(root.apps, appTile.index, appTile.index + by));
                Qt.callLater(root.focusAt, appTile.index + by);
            }
            onRemoved: {
                const next = root.apps.slice();
                next.splice(appTile.index, 1);
                root.writeApps(next);
                Qt.callLater(root.focusAt, Math.max(0, appTile.index - 1));
            }

            Behavior on x {
                enabled: !appTile.dragging && !Appearance.reduceMotion

                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Appearance.anim.enterEasing
                }
            }
        }
    }

    Rectangle {
        x: root.ruleX
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 1
        implicitHeight: Appearance.settings.listDivider
        // Brighter than `panelBorder`: this rule separates two groups inside a
        // card rather than edging a panel, and the design draws it at .12
        // where a panel edge is .07.
        color: Colours.alpha(Colours.on.surface, 0.12)
        visible: root.apps.length > 0 && root.stacks.length > 0
    }

    Repeater {
        id: stackTiles

        model: root.stacks

        DockTile {
            id: stackTile

            required property int index
            required property var modelData

            icon: root.stackIcon(stackTile.modelData)
            draggable: root.stacks.length > 1
            x: stackTile.dragging ? stackTile.dragX : root.stackBase + stackTile.index * root.step
            z: stackTile.dragging ? 1 : 0

            onDropped: at => root.writeStacks(root.shift(root.stacks, stackTile.index, root.slotAt(at, root.stackBase, root.stacks.length)))
            onMove: by => root.focusAt(root.apps.length + stackTile.index + by)
            onReorder: by => {
                root.writeStacks(root.shift(root.stacks, stackTile.index, stackTile.index + by));
                Qt.callLater(root.focusAt, root.apps.length + stackTile.index + by);
            }
            onRemoved: {
                const next = root.stacks.slice();
                next.splice(stackTile.index, 1);
                root.writeStacks(next);
                Qt.callLater(root.focusAt, Math.max(0, root.apps.length + stackTile.index - 1));
            }

            Behavior on x {
                enabled: !stackTile.dragging && !Appearance.reduceMotion

                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Appearance.anim.enterEasing
                }
            }
        }
    }

    DockTile {
        id: add

        icon: "add"
        outlined: true
        x: root.addX
        enabled: picker.candidates.length > 0
        opacity: add.enabled ? 1 : 0.38

        onActivated: {
            root.adding = !root.adding;
            if (root.adding)
                Qt.callLater(picker.focusFirst);
        }
        onMove: by => {
            if (by < 0)
                root.focusAt(root.apps.length + root.stacks.length - 1);
        }
    }

    // --- the folder picker -------------------------------------------------
    //
    // Not in the design, which draws the square and not what it opens. "Any
    // folder can be a stack" is only true if a folder can be chosen, so this
    // lists the ones in $HOME. It reads the directory with a Qt model rather
    // than by shelling out, which the architecture forbids the UI from doing.
    FolderListModel {
        id: home

        folder: `file://${Quickshell.env("HOME")}`
        showFiles: false
        showDirs: true
        showHidden: false
        sortField: FolderListModel.Name
    }

    Panel {
        id: picker

        readonly property var candidates: {
            const used = {};
            for (const s of root.stacks)
                used[String(s?.path ?? "")] = true;
            const out = [];
            if (!used["trash"])
                out.push({
                    path: "trash",
                    name: qsTr("Trash"),
                    icon: "delete"
                });
            for (let i = 0; i < home.count; i++) {
                const name = String(home.get(i, "fileName"));
                const path = `~/${name}`;
                if (used[path])
                    continue;
                out.push({
                    path: path,
                    name: name,
                    icon: name === "Downloads" ? "download" : "folder"
                });
            }
            return out;
        }

        readonly property var shown: picker.candidates.slice(0, Appearance.settings.pickerRows)

        function focusFirst(): void {
            const item = rows.itemAt(0);
            if (item)
                item.forceActiveFocus();
        }

        function choose(entry: var): void {
            const next = root.stacks.slice();
            next.push({
                path: entry.path,
                icon: entry.icon,
                view: "grid",
                recent: 6
            });
            root.writeStacks(next);
            root.adding = false;
            Qt.callLater(root.focusAt, root.apps.length + next.length - 1);
        }

        level: "popout"
        padding: Appearance.space.sm
        width: Appearance.settings.pickerWidth
        implicitHeight: list.implicitHeight + picker.padding * 2
        // Opens upward: the dock card is the last thing on the Bar page and
        // there is nothing below it to open into.
        x: root.addX + Appearance.settings.tile - picker.width
        y: -picker.height - Appearance.space.sm
        z: 2
        opacity: root.adding && picker.shown.length > 0 ? 1 : 0
        visible: picker.opacity > 0

        Behavior on opacity {
            id: fading

            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: fading.targetValue > 0 ? Appearance.anim.enterEasing : Appearance.anim.exitEasing
            }
        }

        Keys.onEscapePressed: event => {
            root.adding = false;
            add.forceActiveFocus();
            event.accepted = true;
        }

        ColumnLayout {
            id: list

            anchors.fill: parent
            spacing: 0

            Repeater {
                id: rows

                model: picker.shown

                Row {
                    required property var modelData

                    icon: modelData.icon
                    title: modelData.name
                    rowHeight: Appearance.settings.pickerRowHeight
                    trailingIcon: ""

                    Layout.fillWidth: true

                    onClicked: picker.choose(modelData)
                }
            }

            Text {
                readonly property int extra: picker.candidates.length - picker.shown.length

                text: qsTr("%1 more in ~ — add them in shell.json").arg(extra)
                visible: extra > 0
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.settings.hintSize
                color: Colours.outline
                elide: Text.ElideRight

                Layout.fillWidth: true
                Layout.leftMargin: Appearance.space.md
                Layout.topMargin: Appearance.space.xs
                Layout.bottomMargin: Appearance.space.xs
            }
        }
    }
}
