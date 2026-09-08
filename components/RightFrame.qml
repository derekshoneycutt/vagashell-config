import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../config/Theme.js" as Theme

PanelWindow {
    id: root

    required property var shellScreen
    required property var uiState
    required property var connectivityService
    readonly property bool expanded: uiState.expanded
    property var audioSink: Pipewire.defaultAudioSink
    property var bluetoothAdapter: Bluetooth.defaultAdapter
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
    readonly property var categorizedApplications: {
        const applications = DesktopEntries.applications.values
            .filter(entry => entry.name && !entry.noDisplay)
            .sort((first, second) => first.name.localeCompare(second.name));
        const groups = [
            { name: "Development", categories: ["Development"] },
            { name: "Games", categories: ["Game"] },
            { name: "Graphics", categories: ["Graphics", "Photography"] },
            { name: "Internet", categories: ["Network", "WebBrowser", "Email"] },
            { name: "Office", categories: ["Office"] },
            { name: "Media", categories: ["AudioVideo", "Audio", "Video"] },
            { name: "System", categories: ["System", "Settings"] },
            { name: "Utilities", categories: ["Utility", "FileManager", "TerminalEmulator"] },
            { name: "Other", categories: [] }
        ];
        const result = [];
        const assigned = {};
        for (const group of groups) {
            const entries = applications.filter(entry => {
                if (assigned[entry.id])
                    return false;
                const categories = entry.categories || [];
                const matches = group.categories.length === 0
                    || group.categories.some(category => categories.includes(category));
                if (matches)
                    assigned[entry.id] = true;
                return matches;
            });
            if (entries.length > 0)
                result.push({ name: group.name, entries: entries });
        }
        return result;
    }

    screen: shellScreen
    implicitWidth: Theme.appListWidth
    color: "transparent"
    exclusiveZone: Math.round(uiState.reservedWidth)

    anchors {
        top: true
        right: true
        bottom: true
    }

    mask: Region {
        x: root.width - root.uiState.visibleWidth
        width: root.uiState.visibleWidth
        height: root.height
    }

    Item {
        id: drawer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.width
        x: root.width - root.uiState.visibleWidth

        Rectangle {
            anchors.fill: parent
            color: Theme.background
        }

        PwObjectTracker {
            objects: root.audioSink ? [root.audioSink] : []
        }

        Timer {
            id: hoverCloseTimer
            interval: 340
            onTriggered: root.uiState.hovered = false
        }

        ScrollView {
            id: appScroll
            anchors.fill: parent
            anchors.topMargin: 8
            anchors.leftMargin: Theme.appListHandleWidth + 8
            anchors.rightMargin: 10
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: appScroll.availableWidth
                spacing: 3

                QuickSettings {
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    audioSink: root.audioSink
                    bluetoothAdapter: root.bluetoothAdapter
                    connectedNetwork: root.connectedNetwork
                    connectivityService: root.connectivityService
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Layout.leftMargin: 5
                    color: Theme.foreground
                    font.family: "Cantarell"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    text: "Applications"
                }

                Repeater {
                    model: root.categorizedApplications

                    ColumnLayout {
                        id: categorySection

                        required property var modelData
                        property bool categoryExpanded: false
                        Layout.fillWidth: true
                        spacing: 2

                        ItemDelegate {
                            id: categoryHeader
                            Layout.fillWidth: true
                            Layout.topMargin: 7
                            implicitHeight: 30
                            leftPadding: 5
                            rightPadding: 5
                            onClicked: categorySection.categoryExpanded = !categorySection.categoryExpanded

                            background: Rectangle {
                                color: categoryHeader.hovered ? Theme.hover : "transparent"
                                radius: 5
                            }

                            contentItem: RowLayout {
                                spacing: 7

                                Image {
                                    Layout.preferredWidth: 12
                                    Layout.preferredHeight: 12
                                    source: Quickshell.iconPath(categorySection.categoryExpanded
                                        ? "go-down-symbolic" : "go-next-symbolic")
                                }

                                Text {
                                    Layout.fillWidth: true
                                    color: Theme.accent
                                    font.family: "Cantarell"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    text: categorySection.modelData.name.toUpperCase()
                                }

                                Text {
                                    color: Theme.muted
                                    font.family: "Cantarell"
                                    font.pixelSize: 10
                                    text: categorySection.modelData.entries.length
                                }
                            }
                        }

                        Repeater {
                            model: categorySection.categoryExpanded ? categorySection.modelData.entries : []

                            ItemDelegate {
                                id: appItem
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 38
                                leftPadding: 7
                                rightPadding: 7
                                onClicked: modelData.execute()

                                background: Rectangle {
                                    color: appItem.hovered ? Theme.hover : "transparent"
                                    radius: 5
                                }

                                contentItem: RowLayout {
                                    spacing: 9

                                    Image {
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        source: Quickshell.iconPath(appItem.modelData.icon, "application-x-executable")
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        Text {
                                            Layout.fillWidth: true
                                            color: Theme.foreground
                                            elide: Text.ElideRight
                                            font.family: "Cantarell"
                                            font.pixelSize: 12
                                            text: appItem.modelData.name
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: text.length > 0
                                            color: Theme.muted
                                            elide: Text.ElideRight
                                            font.family: "Cantarell"
                                            font.pixelSize: 9
                                            text: appItem.modelData.genericName || ""
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item { implicitHeight: 8 }
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Theme.appListHandleWidth
            color: Theme.elevated
            opacity: 1 - root.uiState.expansion

            Rectangle {
                x: parent.width
                width: 1
                height: parent.height
                color: "#33434d50"
            }

            Image {
                anchors.centerIn: parent
                width: 14
                height: 14
                source: Quickshell.iconPath(root.expanded ? "go-next-symbolic" : "go-previous-symbolic")
                opacity: 0.9
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 100
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: {
            hoverCloseTimer.stop();
            root.uiState.hovered = true;
        }
        onExited: hoverCloseTimer.restart()
    }
}