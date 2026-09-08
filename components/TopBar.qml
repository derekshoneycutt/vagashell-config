import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import "../config/Theme.js" as Theme

PanelWindow {
    id: root

    required property var shellScreen
    required property var notificationService
    required property var systemMonitorState
    required property var appListState
    required property var frameOutlineState
    property var audioSink: Pipewire.defaultAudioSink
    property var connectedNetwork: {
        const devices = Networking.devices.values;
        for (let index = 0; index < devices.length; index++) {
            const networks = devices[index].networks.values;
            for (let networkIndex = 0; networkIndex < networks.length; networkIndex++) {
                if (networks[networkIndex].connected)
                    return networks[networkIndex];
            }
        }
        return null;
    }
    property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property int notificationCount: notificationService.server
        ? notificationService.server.trackedNotifications.values.length
        : 0

    screen: shellScreen
    implicitHeight: Theme.barHeight + calendarPopup.height
    color: "transparent"
    exclusiveZone: Theme.barHeight

    anchors {
        top: true
        left: true
        right: true
    }

    mask: Region {
        item: barBackground

        Region {
            item: centerSurface
        }
    }

    Rectangle {
        id: barBackground
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.barHeight
        color: Theme.background
    }

    InnerFrameCorner {
        x: root.systemMonitorState.visibleWidth
        y: Theme.barHeight
        width: Theme.frameRadius
        height: Theme.frameRadius
        atTop: true
        atLeft: true
    }

    InnerFrameCorner {
        x: root.width - root.appListState.visibleWidth - width
        y: Theme.barHeight
        width: Theme.frameRadius
        height: Theme.frameRadius
        atTop: true
        atLeft: false
    }

    Item {
        id: centerSurface
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: calendarPopup.expanded ? calendarPopup.width : clockButton.width + 28
        height: calendarPopup.expanded ? Theme.barHeight + calendarPopup.height : Theme.barHeight
        clip: true

        Behavior on width {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Behavior on height {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Binding {
            target: root.frameOutlineState
            property: "calendarVisible"
            value: calendarPopup.visible
        }

        Binding {
            target: root.frameOutlineState
            property: "calendarX"
            value: centerSurface.x
        }

        Binding {
            target: root.frameOutlineState
            property: "calendarWidth"
            value: centerSurface.width
        }

        Binding {
            target: root.frameOutlineState
            property: "calendarHeight"
            value: centerSurface.height - Theme.barHeight
        }

        Canvas {
            id: calendarSurfaceBackground
            anchors.top: parent.top
            anchors.topMargin: Theme.barHeight
            width: parent.width
            height: calendarPopup.height
            visible: calendarPopup.visible

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const context = getContext("2d");
                const corner = 12;
                context.clearRect(0, 0, width, height);
                context.fillStyle = Theme.background;
                context.beginPath();
                context.moveTo(0, 0);
                context.lineTo(width, 0);
                context.lineTo(width, height - corner);
                context.quadraticCurveTo(width, height, width - corner, height);
                context.lineTo(corner, height);
                context.quadraticCurveTo(0, height, 0, height - corner);
                context.closePath();
                context.fill();
            }
        }

        CalendarPopup {
            id: calendarPopup
            anchors.top: parent.top
            anchors.topMargin: Theme.barHeight
            anchors.horizontalCenter: parent.horizontalCenter
            availableWidth: root.width - 24
            notificationServer: root.notificationService.server
        }
    }

    Canvas {
        anchors.top: barBackground.bottom
        anchors.right: centerSurface.left
        width: Theme.frameRadius
        height: Theme.frameRadius
        visible: calendarPopup.expanded

        onPaint: {
            const context = getContext("2d");
            context.clearRect(0, 0, width, height);
            context.fillStyle = Theme.background;
            context.fillRect(0, 0, width, height);
            context.globalCompositeOperation = "destination-out";
            context.beginPath();
            context.arc(0, height, width, 0, Math.PI * 2);
            context.fill();
            context.globalCompositeOperation = "source-over";
        }
    }

    Canvas {
        anchors.top: barBackground.bottom
        anchors.left: centerSurface.right
        width: Theme.frameRadius
        height: Theme.frameRadius
        visible: calendarPopup.expanded

        onPaint: {
            const context = getContext("2d");
            context.clearRect(0, 0, width, height);
            context.fillStyle = Theme.background;
            context.fillRect(0, 0, width, height);
            context.globalCompositeOperation = "destination-out";
            context.beginPath();
            context.arc(width, height, width, 0, Math.PI * 2);
            context.fill();
            context.globalCompositeOperation = "source-over";
        }
    }

    Process {
        id: launcherProcess
    }

    PwObjectTracker {
        objects: root.audioSink ? [root.audioSink] : []
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.barHeight
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        ToolButton {
            id: launcherButton
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            icon.source: Quickshell.iconPath("view-app-grid-symbolic", "system-run-symbolic")
            icon.width: 18
            icon.height: 18
            icon.color: Theme.foreground

            MouseArea {
                id: launcherMouse
                anchors.fill: parent
                z: 1
                hoverEnabled: true
                onClicked: launcherProcess.exec(["hyprlauncher"])
            }

        }

        Row {
            spacing: 4

            Repeater {
                model: Hyprland.workspaces

                Rectangle {
                    required property var modelData
                    property var monitor: Hyprland.monitorFor(root.shellScreen)
                    property bool onScreen: monitor !== null && modelData.monitor === monitor && modelData.id > 0

                    visible: onScreen
                    width: visible ? 26 : 0
                    height: 26
                    radius: 6
                    color: modelData.active ? Theme.accent : "transparent"

                    Text {
                        anchors.centerIn: parent
                        color: modelData.active ? "#102019" : Theme.muted
                        font.family: "Cantarell"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        text: parent.modelData.id
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: parent.modelData.activate()
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Row {
            spacing: 4

            Repeater {
                model: SystemTray.items

                Item {
                    id: trayItem

                    required property var modelData
                    width: 28
                    height: 28

                    function displayMenu(x: real, y: real): void {
                        const position = trayMouse.mapToItem(null, x, y);
                        modelData.display(root, Math.round(position.x), Math.round(position.y));
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: parent.modelData.icon
                        fillMode: Image.PreserveAspectFit
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            colorization: 1
                            colorizationColor: Theme.foreground
                        }
                    }

                    MouseArea {
                        id: trayMouse

                        anchors.fill: parent
                        z: 1
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        hoverEnabled: true
                        onClicked: mouse => {
                            if ((mouse.button === Qt.RightButton || trayItem.modelData.onlyMenu) && trayItem.modelData.hasMenu)
                                trayItem.displayMenu(mouse.x, mouse.y);
                            else if (mouse.button === Qt.MiddleButton)
                                trayItem.modelData.secondaryActivate();
                            else
                                trayItem.modelData.activate();
                        }
                    }

                }
            }
        }

        ToolButton {
            id: statusButton
            width: 82
            height: 30

            background: Rectangle {
                color: statusMouse.containsMouse || root.appListState.pinned ? Theme.hover : "transparent"
                radius: 6
                border.width: root.appListState.pinned ? 1 : 0
                border.color: Theme.accent
            }

            contentItem: Row {
                anchors.centerIn: parent
                spacing: 8

                ToolButton {
                    width: 16
                    height: 16
                    padding: 0
                    background: null
                    icon.source: Quickshell.iconPath(root.connectedNetwork
                        ? "network-wireless-signal-excellent-symbolic"
                        : "network-wireless-offline-symbolic")
                    icon.width: 16
                    icon.height: 16
                    icon.color: Theme.foreground
                }

                ToolButton {
                    width: 16
                    height: 16
                    padding: 0
                    background: null
                    icon.source: Quickshell.iconPath(root.bluetoothAdapter && root.bluetoothAdapter.enabled
                        ? "bluetooth-active-symbolic"
                        : "bluetooth-disabled-symbolic", "bluetooth-symbolic")
                    icon.width: 16
                    icon.height: 16
                    icon.color: Theme.foreground
                }

                ToolButton {
                    width: 16
                    height: 16
                    padding: 0
                    background: null
                    icon.source: Quickshell.iconPath(root.audioSink && root.audioSink.audio && root.audioSink.audio.muted
                        ? "audio-volume-muted-symbolic"
                        : "audio-volume-high-symbolic")
                    icon.width: 16
                    icon.height: 16
                    icon.color: Theme.foreground
                }
            }

            MouseArea {
                id: statusMouse
                anchors.fill: parent
                z: 1
                hoverEnabled: true
                onClicked: {
                    calendarPopup.close();
                    root.appListState.togglePinned();
                }
            }

        }

        Row {
            visible: UPower.displayDevice.ready && UPower.displayDevice.isPresent
            spacing: 4

            Image {
                width: 17
                height: 17
                source: Quickshell.iconPath(UPower.displayDevice.iconName, "battery-symbolic")
                layer.enabled: true
                layer.effect: MultiEffect {
                    colorization: 1
                    colorizationColor: Theme.foreground
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.muted
                font.family: "Cantarell"
                font.pixelSize: 12
                text: Math.round(UPower.displayDevice.percentage * 100) + "%"
            }
        }
    }

    ToolButton {
        id: clockButton
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round((Theme.barHeight - height) / 2)
        z: 2
        text: Qt.formatDateTime(clock.date, "ddd, MMM d  HH:mm")
        font.family: "Cantarell"
        font.pixelSize: 14
        font.weight: Font.DemiBold

        MouseArea {
            anchors.fill: parent
            z: 1
            onClicked: {
                calendarPopup.toggle();
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -3
            anchors.rightMargin: -8
            visible: root.notificationCount > 0
            width: Math.max(16, notificationBadgeText.implicitWidth + 8)
            height: 16
            radius: 8
            color: Theme.urgent

            Text {
                id: notificationBadgeText
                anchors.centerIn: parent
                text: root.notificationCount > 99 ? "99+" : root.notificationCount
                color: Theme.foreground
                font.family: "Cantarell"
                font.pixelSize: 9
                font.weight: Font.Bold
            }
        }
    }

    NotificationToast {
        anchorWindow: root
        anchorItem: clockButton
        notification: root.notificationService.latestNotification
        visible: root.notificationService.toastVisible
            && Hyprland.monitorFor(root.shellScreen) === Hyprland.focusedMonitor
        onDismissed: root.notificationService.dismissToast()
    }
}
