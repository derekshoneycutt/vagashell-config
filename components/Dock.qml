import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../config/Theme.js" as Theme
import "../config/Apps.js" as Apps

PanelWindow {
    id: root

    required property var shellScreen
    property int hoveredIndex: -1

    screen: shellScreen
    implicitHeight: Theme.dockSurfaceHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-dock"

    anchors {
        left: true
        right: true
        bottom: true
    }

    mask: Region {
        item: dockBackground
    }

    function iconSizeFor(index): real {
        const distance = Math.abs(index - hoveredIndex);
        if (hoveredIndex < 0 || distance > 1)
            return Theme.dockIconSize;
        if (distance === 1)
            return Theme.dockIconSize + (Theme.dockIconHoverSize - Theme.dockIconSize) * 0.42;
        return Theme.dockIconHoverSize;
    }

    component DockLabel: Rectangle {
        required property string label

        width: labelText.implicitWidth + 12
        height: labelText.implicitHeight + 8
        color: Theme.elevated
        radius: 4
        border.width: 1
        border.color: "#55636c70"

        Text {
            id: labelText
            anchors.centerIn: parent
            color: Theme.foreground
            font.family: "Cantarell"
            font.pixelSize: 11
            text: parent.label
        }
    }

    property var unpinnedApps: {
        const active = Hyprland.activeToplevel;
        const monitor = Hyprland.monitorFor(root.shellScreen);
        const grouped = {};

        for (const toplevel of Hyprland.toplevels.values) {
            if (toplevel.monitor !== monitor)
                continue;

            const metadata = toplevel.lastIpcObject || {};
            const windowClass = String(metadata.class || metadata.initialClass || "");
            const normalizedClass = windowClass.toLowerCase();
            const pinned = Apps.pinned.some(app => app.aliases.some(alias => alias.toLowerCase() === normalizedClass));
            if (pinned || normalizedClass.length === 0)
                continue;

            if (!grouped[normalizedClass])
                grouped[normalizedClass] = { windowClass: windowClass, title: toplevel.title, toplevels: [] };
            grouped[normalizedClass].toplevels.push(toplevel);
        }

        return Object.keys(grouped).map(key => grouped[key]);
    }

    Rectangle {
        id: dockBackground
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        width: dockRow.implicitWidth + 16
        height: dockRow.implicitHeight + 8
        color: "transparent"
        radius: Theme.radius
        border.width: 0

        Row {
            id: dockRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            spacing: 4

            Repeater {
                model: Apps.pinned

                Item {
                    id: dockItem

                    required property var modelData
                    required property int index
                    readonly property int dockIndex: index
                    readonly property real iconSize: root.iconSizeFor(dockIndex)
                    property var desktopEntry: {
                        DesktopEntries.applications.values;
                        return modelData.desktopId ? DesktopEntries.byId(modelData.desktopId) : null;
                    }
                    property string displayName: desktopEntry ? desktopEntry.name : modelData.name
                    property string iconName: desktopEntry ? desktopEntry.icon : (modelData.icon || "application-x-executable")
                    property var matchingToplevels: {
                        const active = Hyprland.activeToplevel;
                        const monitor = Hyprland.monitorFor(root.shellScreen);
                        return Hyprland.toplevels.values.filter(toplevel => {
                            const metadata = toplevel.lastIpcObject || {};
                            const windowClass = String(metadata.class || metadata.initialClass || "").toLowerCase();
                            return toplevel.monitor === monitor
                                && modelData.aliases.some(alias => alias.toLowerCase() === windowClass);
                        });
                    }
                    property bool running: matchingToplevels.length > 0
                    property bool focused: matchingToplevels.some(toplevel => toplevel.activated)

                    width: iconSize + 8
                    height: iconSize + 8
                    anchors.bottom: parent.bottom
                    z: dockMouse.containsMouse ? 2 : (iconSize > Theme.dockIconSize ? 1 : 0)

                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Process {
                        id: customLauncher
                        command: dockItem.modelData.command || []
                    }

                    function launch(): void {
                        if (dockItem.desktopEntry)
                            dockItem.desktopEntry.execute();
                        else if (dockItem.modelData.command)
                            customLauncher.startDetached();
                    }

                    function closeAll(): void {
                        for (const toplevel of matchingToplevels)
                            Hyprland.dispatch("closewindow address:" + toplevel.address);
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 7
                        color: dockMouse.containsMouse ? Theme.hover : "transparent"
                    }

                    Image {
                        anchors.centerIn: parent
                        width: dockItem.iconSize
                        height: dockItem.iconSize
                        source: Quickshell.iconPath(dockItem.iconName, "application-x-executable")
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: Theme.dockIconHoverSize
                        sourceSize.height: Theme.dockIconHoverSize

                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: dockItem.focused ? 18 : 6
                        height: 3
                        radius: 2
                        color: dockItem.running ? Theme.accent : "transparent"

                        Behavior on width {
                            NumberAnimation { duration: 140 }
                        }
                    }

                    MouseArea {
                        id: dockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onContainsMouseChanged: {
                            if (containsMouse)
                                root.hoveredIndex = dockItem.dockIndex;
                            else if (root.hoveredIndex === dockItem.dockIndex)
                                root.hoveredIndex = -1;
                        }
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton)
                                dockItem.launch();
                            else if (mouse.button === Qt.RightButton)
                                contextMenu.open();
                            else
                                dockItem.launch();
                        }
                    }

                    Menu {
                        id: contextMenu

                        MenuItem {
                            text: "New window"
                            onTriggered: dockItem.launch()
                        }

                        MenuItem {
                            text: "Close all"
                            enabled: dockItem.running
                            onTriggered: dockItem.closeAll()
                        }
                    }

                    DockLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 6
                        visible: dockMouse.containsMouse
                        label: dockItem.displayName
                        z: 3
                    }
                }
            }

            Rectangle {
                visible: root.unpinnedApps.length > 0
                width: visible ? 1 : 0
                height: 32
                anchors.verticalCenter: parent.verticalCenter
                color: "#55636c70"
            }

            Repeater {
                model: root.unpinnedApps

                Item {
                    id: runningItem

                    required property var modelData
                    required property int index
                    readonly property int dockIndex: Apps.pinned.length + index
                    readonly property real iconSize: root.iconSizeFor(dockIndex)
                    property var desktopEntry: {
                        DesktopEntries.applications.values;
                        return DesktopEntries.heuristicLookup(modelData.windowClass);
                    }

                    width: iconSize + 8
                    height: iconSize + 8
                    anchors.bottom: parent.bottom
                    z: runningMouse.containsMouse ? 2 : (iconSize > Theme.dockIconSize ? 1 : 0)

                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    function launchOrFocus(): void {
                        if (runningItem.desktopEntry) {
                            runningItem.desktopEntry.execute();
                            return;
                        }

                        Hyprland.dispatch("focuswindow address:" + modelData.toplevels[0].address);
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 7
                        color: runningMouse.containsMouse ? Theme.hover : "transparent"
                    }

                    Image {
                        anchors.centerIn: parent
                        width: runningItem.iconSize
                        height: runningItem.iconSize
                        source: Quickshell.iconPath(runningItem.desktopEntry ? runningItem.desktopEntry.icon : modelData.windowClass, "application-x-executable")
                        fillMode: Image.PreserveAspectFit

                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: modelData.toplevels.some(toplevel => toplevel.activated) ? 18 : 6
                        height: 3
                        radius: 2
                        color: Theme.accent
                    }

                    MouseArea {
                        id: runningMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onContainsMouseChanged: {
                            if (containsMouse)
                                root.hoveredIndex = runningItem.dockIndex;
                            else if (root.hoveredIndex === runningItem.dockIndex)
                                root.hoveredIndex = -1;
                        }
                        onClicked: runningItem.launchOrFocus()
                    }

                    DockLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 6
                        visible: runningMouse.containsMouse
                        label: runningItem.desktopEntry ? runningItem.desktopEntry.name : modelData.title
                        z: 3
                    }
                }
            }
        }
    }
}
