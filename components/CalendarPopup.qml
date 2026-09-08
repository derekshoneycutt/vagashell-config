import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../config/Theme.js" as Theme

Item {
    id: root

    property date shownMonth: new Date()
    property bool expanded: false
    property var notificationServer
    property real availableWidth: 880

    width: Math.min(880, availableWidth)
    height: 340
    visible: false
    clip: true

    function open(): void {
        closeTimer.stop();
        root.visible = true;
        Qt.callLater(() => root.expanded = true);
    }

    function close(): void {
        root.expanded = false;
        closeTimer.restart();
    }

    function toggle(): void {
        if (root.expanded)
            root.close();
        else
            root.open();
    }

    Timer {
        id: closeTimer
        interval: 220
        onTriggered: root.visible = false
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Connections {
        target: clock
        function onDateChanged(): void {
            analogClock.requestPaint();
        }
    }

    Rectangle {
        id: drawer
        width: parent.width
        height: parent.height
        opacity: root.expanded ? 1 : 0
        color: "transparent"

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Rectangle {
                Layout.preferredWidth: Math.min(350, drawer.width * 0.42)
                Layout.fillHeight: true
                color: Theme.background
                radius: 8
                border.width: 1
                border.color: "#55434d50"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        ToolButton {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            icon.source: Quickshell.iconPath("go-previous-symbolic", "pan-start-symbolic")
                            icon.width: 16
                            icon.height: 16
                            icon.color: Theme.foreground
                            onClicked: root.shownMonth = new Date(root.shownMonth.getFullYear(), root.shownMonth.getMonth() - 1, 1)
                        }

                        Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.foreground
                            font.family: "Cantarell"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            text: Qt.formatDate(root.shownMonth, "MMMM yyyy")
                        }

                        ToolButton {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            icon.source: Quickshell.iconPath("go-next-symbolic", "pan-end-symbolic")
                            icon.width: 16
                            icon.height: 16
                            icon.color: Theme.foreground
                            onClicked: root.shownMonth = new Date(root.shownMonth.getFullYear(), root.shownMonth.getMonth() + 1, 1)
                        }
                    }

                    DayOfWeekRow {
                        Layout.fillWidth: true
                        locale: Qt.locale()

                        delegate: Label {
                            required property var model
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.muted
                            font.family: "Cantarell"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            text: model.shortName
                        }
                    }

                    MonthGrid {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        month: root.shownMonth.getMonth()
                        year: root.shownMonth.getFullYear()
                        locale: Qt.locale()

                        delegate: Rectangle {
                            required property var model
                            color: model.today ? Theme.accent : "transparent"
                            radius: 6
                            opacity: model.month === root.shownMonth.getMonth() ? 1 : 0.32

                            Label {
                                anchors.centerIn: parent
                                color: parent.model.today ? "#102019" : Theme.foreground
                                font.family: "Cantarell"
                                font.pixelSize: 12
                                font.weight: parent.model.today ? Font.DemiBold : Font.Normal
                                text: parent.model.day
                            }
                        }
                    }

                    Button {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: 30
                        text: "Today"
                        onClicked: root.shownMonth = new Date()
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 190
                Layout.fillHeight: true
                color: Theme.background
                radius: 8
                border.width: 1
                border.color: "#55434d50"

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Canvas {
                        id: analogClock
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 150
                        height: 150

                        onPaint: {
                            const context = getContext("2d");
                            const centerX = width / 2;
                            const centerY = height / 2;
                            const radius = Math.min(width, height) / 2 - 5;
                            const now = clock.date;
                            context.clearRect(0, 0, width, height);
                            context.save();
                            context.translate(centerX, centerY);

                            context.strokeStyle = Theme.muted;
                            context.lineCap = "round";
                            for (let tick = 0; tick < 60; tick++) {
                                const angle = tick * Math.PI / 30;
                                const major = tick % 5 === 0;
                                const outer = radius - 2;
                                const inner = outer - (major ? 8 : 3);
                                context.globalAlpha = major ? 0.9 : 0.35;
                                context.lineWidth = major ? 2 : 1;
                                context.beginPath();
                                context.moveTo(Math.sin(angle) * inner, -Math.cos(angle) * inner);
                                context.lineTo(Math.sin(angle) * outer, -Math.cos(angle) * outer);
                                context.stroke();
                            }

                            function drawHand(angle, length, lineWidth, color) {
                                context.globalAlpha = 1;
                                context.strokeStyle = color;
                                context.lineWidth = lineWidth;
                                context.beginPath();
                                context.moveTo(0, 0);
                                context.lineTo(Math.sin(angle) * length, -Math.cos(angle) * length);
                                context.stroke();
                            }

                            const seconds = now.getSeconds();
                            const minutes = now.getMinutes() + seconds / 60;
                            const hours = now.getHours() % 12 + minutes / 60;
                            drawHand(hours * Math.PI / 6, radius * 0.5, 5, Theme.foreground);
                            drawHand(minutes * Math.PI / 30, radius * 0.72, 3, Theme.foreground);
                            drawHand(seconds * Math.PI / 30, radius * 0.78, 1.5, Theme.accent);

                            context.fillStyle = Theme.accent;
                            context.beginPath();
                            context.arc(0, 0, 3.5, 0, Math.PI * 2);
                            context.fill();
                            context.restore();
                        }
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.foreground
                        font.family: "Cantarell"
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0
                        text: Qt.formatTime(clock.date, "HH:mm:ss")
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.muted
                        font.family: "Cantarell"
                        font.pixelSize: 12
                        font.letterSpacing: 0
                        text: Qt.formatDate(clock.date, "dddd, MMMM d")
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.background
                radius: 8
                border.width: 1
                border.color: "#55434d50"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        Label {
                            Layout.fillWidth: true
                            text: "Notifications"
                            color: Theme.foreground
                            font.family: "Cantarell"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }

                        ToolButton {
                            visible: root.notificationServer
                                && root.notificationServer.trackedNotifications.values.length > 0
                            icon.source: Quickshell.iconPath("edit-clear-all-symbolic", "edit-clear-symbolic")
                            icon.width: 16
                            icon.height: 16
                            icon.color: Theme.muted
                            ToolTip.visible: hovered
                            ToolTip.text: "Clear notifications"
                            onClicked: {
                                const notifications = root.notificationServer.trackedNotifications.values.slice();
                                for (let index = 0; index < notifications.length; index++)
                                    notifications[index].dismiss();
                            }
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignCenter
                        Layout.fillHeight: true
                        visible: !root.notificationServer
                            || root.notificationServer.trackedNotifications.values.length === 0
                        text: "No notifications"
                        color: Theme.muted
                        font.family: "Cantarell"
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.notificationServer
                            && root.notificationServer.trackedNotifications.values.length > 0
                        clip: true

                        ListView {
                            spacing: 7
                            model: root.notificationServer ? root.notificationServer.trackedNotifications : null

                            delegate: Rectangle {
                                required property var modelData
                                width: ListView.view.width
                                implicitHeight: notificationContent.implicitHeight + 16
                                color: Theme.hover
                                radius: 7

                                ColumnLayout {
                                    id: notificationContent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    spacing: 3

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Label {
                                            Layout.fillWidth: true
                                            text: modelData.appName || "Notification"
                                            color: Theme.muted
                                            font.family: "Cantarell"
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }

                                        ToolButton {
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 24
                                            icon.source: Quickshell.iconPath("window-close-symbolic", "edit-delete-symbolic")
                                            icon.width: 13
                                            icon.height: 13
                                            icon.color: Theme.muted
                                            ToolTip.visible: hovered
                                            ToolTip.text: "Dismiss"
                                            onClicked: modelData.dismiss()
                                        }
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.summary
                                        color: Theme.foreground
                                        font.family: "Cantarell"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        wrapMode: Text.Wrap
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        visible: text.length > 0
                                        text: modelData.body
                                        textFormat: Text.PlainText
                                        color: Theme.muted
                                        font.family: "Cantarell"
                                        font.pixelSize: 11
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                    }

                                    Row {
                                        spacing: 5

                                        Repeater {
                                            model: modelData.actions

                                            Button {
                                                required property var modelData
                                                text: modelData.text
                                                onClicked: modelData.invoke()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
