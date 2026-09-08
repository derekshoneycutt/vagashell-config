import QtQuick
import Quickshell
import Quickshell.Io
import "../config/Apps.js" as Apps

Scope {
    id: root

    readonly property var pinned: pinConfig.pinned

    function isPinned(desktopId: string): bool {
        return pinned.some(app => app.desktopId === desktopId);
    }

    function pin(desktopEntry: var): void {
        if (isPinned(desktopEntry.id))
            return;

        const next = pinned.slice();
        next.push({
            name: desktopEntry.name,
            desktopId: desktopEntry.id,
            aliases: [desktopEntry.id]
        });
        pinConfig.pinned = next;
    }

    function unpin(desktopId: string): void {
        pinConfig.pinned = pinned.filter(app => app.desktopId !== desktopId);
    }

    function move(index: int, offset: int): void {
        const destination = index + offset;
        if (index < 0 || index >= pinned.length || destination < 0 || destination >= pinned.length)
            return;

        const next = pinned.slice();
        const moved = next.splice(index, 1)[0];
        next.splice(destination, 0, moved);
        pinConfig.pinned = next;
    }

    FileView {
        id: pinFile
        path: Qt.resolvedUrl("../config/pinned-apps.json")
        blockLoading: true
        atomicWrites: true
        printErrors: false
        onLoadFailed: writeAdapter()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: pinConfig
            property var pinned: Apps.pinned
        }
    }
}