import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../config/Theme.js" as Theme

PanelWindow {
    id: root

    required property var shellScreen
    required property var systemDataService
    required property var uiState
    readonly property var metrics: systemDataService.snapshot
    readonly property bool expanded: uiState.expanded

    screen: shellScreen
    implicitWidth: Theme.sidebarWidth
    color: "transparent"
    exclusiveZone: Math.round(uiState.reservedWidth)

    anchors {
        top: true
        left: true
        bottom: true
    }

    mask: Region {
        width: root.uiState.visibleWidth
        height: root.height
    }

    function formatBytes(value): string {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let amount = Math.max(0, Number(value) || 0);
        let unit = 0;
        while (amount >= 1024 && unit < units.length - 1) {
            amount /= 1024;
            unit++;
        }
        return amount.toFixed(unit === 0 ? 0 : 1) + " " + units[unit];
    }

    function formatRate(value): string {
        return formatBytes(value) + "/s";
    }

    function formatUptime(seconds): string {
        let remaining = Math.max(0, Math.floor(seconds || 0));
        const days = Math.floor(remaining / 86400);
        remaining %= 86400;
        const hours = Math.floor(remaining / 3600);
        remaining %= 3600;
        const minutes = Math.floor(remaining / 60);
        return days + "d " + hours + "h " + minutes + "m";
    }

    function historyMaximum(first, second): real {
        let maximum = 1;
        for (const value of first || [])
            maximum = Math.max(maximum, Number(value) || 0);
        for (const value of second || [])
            maximum = Math.max(maximum, Number(value) || 0);
        return maximum * 1.1;
    }

    component SectionTitle: Text {
        Layout.fillWidth: true
        Layout.topMargin: 6
        color: Theme.accent
        font.family: "Cantarell"
        font.pixelSize: 11
        font.weight: Font.DemiBold
        text: ""
    }

    component Divider: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: "#33434d50"
    }

    Item {
        id: drawer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.width
        x: root.uiState.visibleWidth - root.width

        Rectangle {
            anchors.fill: parent
            color: Theme.background
        }

        HoverHandler {
            id: monitorHover
            onHoveredChanged: root.uiState.hovered = hovered
        }

        ScrollView {
            id: monitorScroll
            anchors.fill: parent
            anchors.rightMargin: Theme.sidebarHandleWidth
            contentWidth: availableWidth
            visible: root.expanded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: Math.max(0, monitorScroll.availableWidth - 24)
                x: 12
                spacing: 8

                Item { implicitHeight: 4 }

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            color: Theme.foreground
                            elide: Text.ElideRight
                            font.family: "Cantarell"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            text: root.metrics ? root.metrics.host.hostname : "System monitor"
                        }

                        Text {
                            Layout.fillWidth: true
                            color: Theme.muted
                            elide: Text.ElideRight
                            font.family: "Cantarell"
                            font.pixelSize: 10
                            text: root.metrics ? "Linux " + root.metrics.host.kernel : "Waiting for metrics"
                        }
                    }

                    Text {
                        color: root.systemDataService.stale ? Theme.urgent : Theme.accent
                        font.pixelSize: 14
                        text: root.systemDataService.stale ? "!" : "●"
                    }

                    ToolButton {
                        implicitWidth: 28
                        implicitHeight: 28
                        opacity: root.uiState.pinned ? 1 : 0.55
                        rotation: root.uiState.pinned ? 0 : 45
                        icon.source: Quickshell.iconPath("view-pin-symbolic")
                        icon.width: 16
                        icon.height: 16
                        icon.color: Theme.foreground
                        onClicked: root.uiState.togglePinned()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    color: Theme.muted
                    font.family: "Cantarell"
                    font.pixelSize: 10
                    text: root.metrics ? "Uptime  " + root.formatUptime(root.metrics.host.uptimeSeconds) : root.systemDataService.error
                }

                Divider {}
                SectionTitle { text: "PROCESSOR" }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        color: Theme.foreground
                        font.family: "Cantarell"
                        font.pixelSize: 11
                        text: "Ryzen 7 5700G"
                    }

                    Text {
                        color: Theme.foreground
                        font.family: "Cantarell"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        text: root.metrics ? Math.round(root.metrics.cpu.aggregate) + "%" : "--"
                    }
                }

                HistoryGraph {
                    Layout.fillWidth: true
                    implicitHeight: 42
                    firstSeries: root.systemDataService.aggregateHistory
                    maxValue: 1
                }

                Repeater {
                    model: root.metrics ? root.metrics.cpu.pairs : []

                    ColumnLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                color: Theme.muted
                                font.family: "Cantarell"
                                font.pixelSize: 10
                                text: "CPU " + parent.parent.modelData.label
                            }

                            Text {
                                color: Theme.foreground
                                font.family: "Cantarell"
                                font.pixelSize: 10
                                text: Math.round(parent.parent.modelData.first) + "%  " + Math.round(parent.parent.modelData.second) + "%"
                            }
                        }

                        HistoryGraph {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            firstSeries: root.systemDataService.pairHistories[parent.index]
                                ? root.systemDataService.pairHistories[parent.index].first : []
                            secondSeries: root.systemDataService.pairHistories[parent.index]
                                ? root.systemDataService.pairHistories[parent.index].second : []
                            secondColor: Theme.cpuSecondary
                            maxValue: 1
                        }
                    }
                }

                Divider {}
                SectionTitle { text: "TEMPERATURES" }

                Repeater {
                    model: root.metrics ? root.metrics.temperatures : []

                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            color: Theme.muted
                            font.family: "Cantarell"
                            font.pixelSize: 11
                            text: parent.modelData.name
                        }

                        Text {
                            color: Theme.foreground
                            font.family: "Cantarell"
                            font.pixelSize: 11
                            text: parent.modelData.celsius.toFixed(1) + " °C"
                        }
                    }
                }

                Divider {}
                SectionTitle { text: "MEMORY" }

                MetricBar {
                    Layout.fillWidth: true
                    label: "Memory"
                    used: root.metrics ? root.metrics.memory.used : 0
                    total: root.metrics ? root.metrics.memory.total : 0
                }

                MetricBar {
                    Layout.fillWidth: true
                    label: "Swap"
                    used: root.metrics ? root.metrics.memory.swapUsed : 0
                    total: root.metrics ? root.metrics.memory.swapTotal : 0
                }

                Divider {}
                SectionTitle { text: "FILESYSTEMS" }

                Repeater {
                    model: root.metrics ? root.metrics.filesystems : []

                    MetricBar {
                        required property var modelData
                        Layout.fillWidth: true
                        label: modelData.name
                        used: modelData.used
                        total: modelData.total
                    }
                }

                Divider {}
                SectionTitle { text: "DISK ACTIVITY" }

                Repeater {
                    model: root.metrics ? root.metrics.disks : []

                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            color: Theme.foreground
                            font.family: "Cantarell"
                            font.pixelSize: 11
                            text: parent.modelData.name
                        }

                        Text {
                            color: Theme.muted
                            font.family: "Cantarell"
                            font.pixelSize: 10
                            text: "R " + root.formatRate(parent.modelData.readBytesPerSecond)
                                + "  W " + root.formatRate(parent.modelData.writeBytesPerSecond)
                        }
                    }
                }

                HistoryGraph {
                    Layout.fillWidth: true
                    firstSeries: root.systemDataService.diskReadHistory
                    secondSeries: root.systemDataService.diskWriteHistory
                    secondColor: Theme.urgent
                    maxValue: root.historyMaximum(firstSeries, secondSeries)
                }

                Divider {}
                SectionTitle { text: "NETWORK" }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        color: Theme.foreground
                        font.family: "Cantarell"
                        font.pixelSize: 11
                        text: root.metrics && root.metrics.network.interface ? root.metrics.network.interface : "Unavailable"
                    }

                    Text {
                        color: Theme.muted
                        font.family: "Cantarell"
                        font.pixelSize: 10
                        text: root.metrics
                            ? "↓ " + root.formatRate(root.metrics.network.receiveBytesPerSecond)
                                + "  ↑ " + root.formatRate(root.metrics.network.transmitBytesPerSecond)
                            : "--"
                    }
                }

                HistoryGraph {
                    Layout.fillWidth: true
                    firstSeries: root.systemDataService.networkReceiveHistory
                    secondSeries: root.systemDataService.networkTransmitHistory
                    secondColor: Theme.urgent
                    maxValue: root.historyMaximum(firstSeries, secondSeries)
                }

                Item { implicitHeight: 8 }
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: Theme.sidebarHandleWidth
            color: root.expanded ? "transparent" : Theme.elevated

            Rectangle {
                anchors.left: parent.left
                width: 1
                height: parent.height
                color: "#33434d50"
            }

            Image {
                anchors.centerIn: parent
                width: 14
                height: 14
                source: Quickshell.iconPath(root.expanded ? "go-previous-symbolic" : "go-next-symbolic")
                opacity: root.expanded ? 0.45 : 0.9
            }
        }
    }
}
