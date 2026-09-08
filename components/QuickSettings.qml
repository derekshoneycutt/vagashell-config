import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import "../config/Theme.js" as Theme

Item {
    id: root

    property var audioSink
    property var bluetoothAdapter
    property var connectedNetwork
    property var connectivityService
    property string expandedSection: ""
    property string pendingWifiSsid: ""
    property bool confirmPowerOff: false
    property bool confirmReboot: false

    implicitHeight: content.implicitHeight + 32

    function toggleSection(section: string): void {
        root.expandedSection = root.expandedSection === section ? "" : section;
        root.pendingWifiSsid = "";
        if (root.expandedSection && root.connectivityService)
            root.connectivityService.refresh();
    }

    Process { id: commandProcess }

    Timer {
        id: confirmTimer
        interval: 5000
        onTriggered: {
            root.confirmPowerOff = false;
            root.confirmReboot = false;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.elevated
        radius: Theme.radius
        border.width: 1
        border.color: "#33434d50"

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Label {
                text: "CONTROLS"
                color: Theme.accent
                font.family: "Cantarell"
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                color: Theme.background
                radius: 7
                border.width: 1
                border.color: "#33434d50"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    ToolButton {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        icon.source: Quickshell.iconPath(root.audioSink && root.audioSink.audio && root.audioSink.audio.muted
                            ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
                        icon.color: Theme.foreground
                        onClicked: {
                            if (root.audioSink && root.audioSink.audio)
                                root.audioSink.audio.muted = !root.audioSink.audio.muted;
                        }
                    }

                    Slider {
                        Layout.fillWidth: true
                        from: 0
                        to: 1
                        value: root.audioSink && root.audioSink.audio ? root.audioSink.audio.volume : 0
                        enabled: root.audioSink !== null && root.audioSink.audio !== null
                        onMoved: root.audioSink.audio.volume = value
                    }

                    Label {
                        Layout.preferredWidth: 34
                        horizontalAlignment: Text.AlignRight
                        color: Theme.muted
                        font.pixelSize: 10
                        text: root.audioSink && root.audioSink.audio
                            ? Math.round(root.audioSink.audio.volume * 100) + "%" : "--"
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                ItemDelegate {
                    id: wifiHeader
                    Layout.fillWidth: true
                    implicitHeight: 42
                    onClicked: root.toggleSection("wifi")
                    background: Rectangle {
                        color: wifiHeader.hovered ? Theme.hover : Theme.background
                        radius: 7
                        border.width: 1
                        border.color: root.expandedSection === "wifi" ? Theme.accent : "#33434d50"
                    }
                    contentItem: Item {
                        Image {
                            id: wifiIcon
                            width: 17
                            height: 17
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            source: Quickshell.iconPath(root.connectedNetwork
                                ? "network-wireless-signal-excellent-symbolic" : "network-wireless-offline-symbolic")
                        }
                        ColumnLayout {
                            anchors.left: wifiIcon.right
                            anchors.leftMargin: 8
                            anchors.right: wifiSwitch.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            Label {
                                color: Theme.foreground
                                font.family: "Cantarell"
                                font.weight: Font.DemiBold
                                text: "Wi-Fi"
                            }
                            Label {
                                Layout.fillWidth: true
                                color: Theme.muted
                                font.family: "Cantarell"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                text: root.connectedNetwork ? root.connectedNetwork.name : "Not connected"
                            }
                        }
                        Switch {
                            id: wifiSwitch
                            width: 48
                            anchors.right: wifiChevron.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            checked: Networking.wifiEnabled
                            enabled: Networking.wifiHardwareEnabled
                            onToggled: Networking.wifiEnabled = checked
                        }
                        Image {
                            id: wifiChevron
                            width: 12
                            height: 12
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            source: Quickshell.iconPath(root.expandedSection === "wifi"
                                ? "go-up-symbolic" : "go-down-symbolic")
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.expandedSection === "wifi"
                    spacing: 5

                    Label {
                        Layout.fillWidth: true
                        visible: root.connectivityService && root.connectivityService.wifi.error.length > 0
                        color: Theme.urgent
                        font.pixelSize: 10
                        wrapMode: Text.Wrap
                        text: root.connectivityService ? root.connectivityService.wifi.error : ""
                    }

                    Repeater {
                        model: root.connectivityService ? root.connectivityService.wifi.networks : []

                        ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 3

                            ItemDelegate {
                                id: networkRow
                                Layout.fillWidth: true
                                implicitHeight: 38
                                background: Rectangle {
                                    color: networkRow.hovered ? Theme.hover : "transparent"
                                    radius: 6
                                }
                                contentItem: RowLayout {
                                    spacing: 7
                                    Image {
                                        Layout.preferredWidth: 15
                                        Layout.preferredHeight: 15
                                        source: Quickshell.iconPath(modelData.secured
                                            ? "network-wireless-encrypted-symbolic"
                                            : "network-wireless-signal-excellent-symbolic")
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        color: Theme.foreground
                                        font.family: "Cantarell"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        text: modelData.ssid
                                    }
                                    Label {
                                        color: modelData.connected ? Theme.accent : Theme.muted
                                        font.pixelSize: 9
                                        text: modelData.connected ? "Connected"
                                            : modelData.saved ? "Saved" : modelData.signal + "%"
                                    }
                                    ToolButton {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        icon.source: Quickshell.iconPath(modelData.connected
                                            ? "network-disconnect-symbolic" : "network-connect-symbolic",
                                            modelData.connected ? "window-close-symbolic" : "list-add-symbolic")
                                        icon.width: 15
                                        icon.height: 15
                                        icon.color: modelData.connected ? Theme.urgent : Theme.accent
                                        enabled: !root.connectivityService.busyAction
                                        onClicked: {
                                            if (modelData.connected) {
                                                root.connectivityService.disconnectWifi(modelData.ssid);
                                            } else if (modelData.saved || !modelData.secured) {
                                                root.connectivityService.connectWifi(modelData.ssid, "");
                                            } else {
                                                root.pendingWifiSsid = modelData.ssid;
                                            }
                                        }
                                    }
                                    ToolButton {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        visible: modelData.saved && !modelData.connected
                                        icon.source: Quickshell.iconPath("edit-delete-symbolic")
                                        icon.width: 14
                                        icon.height: 14
                                        icon.color: Theme.muted
                                        enabled: !root.connectivityService.busyAction
                                        onClicked: root.connectivityService.forgetWifi(modelData.ssid)
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: root.pendingWifiSsid === modelData.ssid
                                spacing: 5

                                TextField {
                                    id: passwordField
                                    Layout.fillWidth: true
                                    placeholderText: "Wi-Fi password"
                                    echoMode: TextInput.Password
                                    onAccepted: connectButton.clicked()
                                }
                                Button {
                                    id: connectButton
                                    text: "Connect"
                                    enabled: passwordField.text.length > 0
                                    onClicked: {
                                        root.connectivityService.connectWifi(modelData.ssid, passwordField.text);
                                        passwordField.clear();
                                        root.pendingWifiSsid = "";
                                    }
                                }
                                ToolButton {
                                    icon.source: Quickshell.iconPath("window-close-symbolic")
                                    onClicked: {
                                        passwordField.clear();
                                        root.pendingWifiSsid = "";
                                    }
                                }
                            }
                        }
                    }

                    ToolButton {
                        Layout.alignment: Qt.AlignRight
                        icon.source: Quickshell.iconPath("view-refresh-symbolic")
                        icon.color: Theme.foreground
                        enabled: root.connectivityService && !root.connectivityService.busyAction
                        onClicked: root.connectivityService.scanWifi()
                    }
                }

                ItemDelegate {
                    id: bluetoothHeader
                    Layout.fillWidth: true
                    implicitHeight: 42
                    onClicked: root.toggleSection("bluetooth")
                    background: Rectangle {
                        color: bluetoothHeader.hovered ? Theme.hover : Theme.background
                        radius: 7
                        border.width: 1
                        border.color: root.expandedSection === "bluetooth" ? Theme.accent : "#33434d50"
                    }
                    contentItem: Item {
                        Image {
                            id: bluetoothIcon
                            width: 17
                            height: 17
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            source: Quickshell.iconPath(root.bluetoothAdapter && root.bluetoothAdapter.enabled
                                ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic", "bluetooth-symbolic")
                        }
                        ColumnLayout {
                            anchors.left: bluetoothIcon.right
                            anchors.leftMargin: 8
                            anchors.right: bluetoothSwitch.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            Label {
                                color: Theme.foreground
                                font.family: "Cantarell"
                                font.weight: Font.DemiBold
                                text: "Bluetooth"
                            }
                            Label {
                                color: Theme.muted
                                font.family: "Cantarell"
                                font.pixelSize: 10
                                text: root.connectivityService
                                    ? root.connectivityService.bluetooth.devices.filter(device => device.connected).length + " connected"
                                    : "Unavailable"
                            }
                        }
                        Switch {
                            id: bluetoothSwitch
                            width: 48
                            anchors.right: bluetoothChevron.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            checked: root.bluetoothAdapter !== null && root.bluetoothAdapter.enabled
                            enabled: root.bluetoothAdapter !== null
                            onToggled: root.bluetoothAdapter.enabled = checked
                        }
                        Image {
                            id: bluetoothChevron
                            width: 12
                            height: 12
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            source: Quickshell.iconPath(root.expandedSection === "bluetooth"
                                ? "go-up-symbolic" : "go-down-symbolic")
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.expandedSection === "bluetooth"
                    spacing: 5

                    Label {
                        Layout.fillWidth: true
                        visible: root.connectivityService && root.connectivityService.bluetooth.error.length > 0
                        color: Theme.urgent
                        font.pixelSize: 10
                        wrapMode: Text.Wrap
                        text: root.connectivityService ? root.connectivityService.bluetooth.error : ""
                    }

                    Repeater {
                        model: root.connectivityService ? root.connectivityService.bluetooth.devices : []

                        ItemDelegate {
                            id: deviceRow
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 40
                            background: Rectangle {
                                color: deviceRow.hovered ? Theme.hover : "transparent"
                                radius: 6
                            }
                            contentItem: RowLayout {
                                spacing: 7
                                Image {
                                    Layout.preferredWidth: 15
                                    Layout.preferredHeight: 15
                                    source: Quickshell.iconPath("bluetooth-symbolic")
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Label {
                                        Layout.fillWidth: true
                                        color: Theme.foreground
                                        font.family: "Cantarell"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        text: modelData.name
                                    }
                                    Label {
                                        color: modelData.connected ? Theme.accent : Theme.muted
                                        font.pixelSize: 9
                                        text: modelData.connected ? "Connected"
                                            : modelData.paired ? "Paired" : "Available"
                                    }
                                }
                                Label {
                                    visible: modelData.battery !== null
                                    color: Theme.muted
                                    font.pixelSize: 9
                                    text: modelData.battery + "%"
                                }
                                ToolButton {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    icon.source: Quickshell.iconPath(modelData.connected
                                        ? "network-disconnect-symbolic" : "network-connect-symbolic",
                                        modelData.connected ? "window-close-symbolic" : "list-add-symbolic")
                                    icon.width: 15
                                    icon.height: 15
                                    icon.color: modelData.connected ? Theme.urgent : Theme.accent
                                    enabled: !root.connectivityService.busyAction
                                    onClicked: root.connectivityService.bluetoothAction(
                                        modelData.connected ? "bluetoothDisconnect"
                                            : modelData.paired ? "bluetoothConnect" : "bluetoothPair",
                                        modelData.address)
                                }
                                ToolButton {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    visible: modelData.paired && !modelData.connected
                                    icon.source: Quickshell.iconPath("edit-delete-symbolic")
                                    icon.width: 14
                                    icon.height: 14
                                    icon.color: Theme.muted
                                    enabled: !root.connectivityService.busyAction
                                    onClicked: root.connectivityService.bluetoothAction("bluetoothRemove", modelData.address)
                                }
                            }
                        }
                    }

                    Button {
                        Layout.alignment: Qt.AlignRight
                        text: root.connectivityService && root.connectivityService.busyAction === "bluetoothScan"
                            ? "Scanning..." : "Scan"
                        icon.source: Quickshell.iconPath("view-refresh-symbolic")
                        enabled: root.connectivityService && !root.connectivityService.busyAction
                        onClicked: root.connectivityService.scanBluetooth()
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                visible: root.connectivityService && root.connectivityService.error.length > 0
                color: Theme.urgent
                font.pixelSize: 10
                wrapMode: Text.Wrap
                text: root.connectivityService ? root.connectivityService.error : ""
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#33434d50"
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                color: Theme.background
                radius: 7

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    ToolButton {
                        icon.source: Quickshell.iconPath("system-lock-screen-symbolic")
                        icon.color: Theme.foreground
                        onClicked: commandProcess.exec(["loginctl", "lock-session"])
                    }
                    ToolButton {
                        icon.source: Quickshell.iconPath("system-log-out-symbolic")
                        icon.color: Theme.foreground
                        onClicked: Hyprland.dispatch("exit")
                    }
                    ToolButton {
                        icon.source: Quickshell.iconPath("weather-clear-night-symbolic", "system-suspend-symbolic")
                        icon.color: Theme.foreground
                        onClicked: commandProcess.exec(["systemctl", "suspend"])
                    }
                    ToolButton {
                        icon.source: Quickshell.iconPath("system-reboot-symbolic")
                        icon.color: root.confirmReboot ? Theme.urgent : Theme.foreground
                        onClicked: {
                            if (root.confirmReboot)
                                commandProcess.exec(["systemctl", "reboot"]);
                            else {
                                root.confirmReboot = true;
                                root.confirmPowerOff = false;
                                confirmTimer.restart();
                            }
                        }
                    }
                    ToolButton {
                        icon.source: Quickshell.iconPath("system-shutdown-symbolic")
                        icon.color: root.confirmPowerOff ? Theme.urgent : Theme.foreground
                        onClicked: {
                            if (root.confirmPowerOff)
                                commandProcess.exec(["systemctl", "poweroff"]);
                            else {
                                root.confirmPowerOff = true;
                                root.confirmReboot = false;
                                confirmTimer.restart();
                            }
                        }
                    }
                }
            }
        }
    }
}
