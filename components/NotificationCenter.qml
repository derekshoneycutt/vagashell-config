import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../config/Theme.js" as Theme

PopupWindow {
    id: root

    required property var anchorWindow
    required property var anchorItem
    property var notificationServer

    anchor.window: anchorWindow
    anchor.item: anchorItem
    anchor.rect.y: anchorItem.height + 8
    anchor.rect.x: anchorItem.width - implicitWidth
    implicitWidth: 360
    implicitHeight: 460
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Theme.elevated
        radius: Theme.radius
        border.width: 1
        border.color: "#33434d50"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Label {
                    Layout.fillWidth: true
                    text: "Notifications"
                    color: Theme.foreground
                    font.family: "Cantarell"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }

                Button {
                    text: "Clear"
                    enabled: root.notificationServer && root.notificationServer.trackedNotifications.values.length > 0
                    onClicked: {
                        const notifications = root.notificationServer.trackedNotifications.values.slice();
                        for (let index = 0; index < notifications.length; index++)
                            notifications[index].dismiss();
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignCenter
                visible: !root.notificationServer || root.notificationServer.trackedNotifications.values.length === 0
                text: "No notifications"
                color: Theme.muted
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    spacing: 8
                    model: root.notificationServer ? root.notificationServer.trackedNotifications : null

                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        implicitHeight: notificationContent.implicitHeight + 20
                        color: Theme.hover
                        radius: 7

                        ColumnLayout {
                            id: notificationContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true

                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.appName || "Notification"
                                    color: Theme.muted
                                    font.family: "Cantarell"
                                    font.pixelSize: 11
                                }

                                ToolButton {
                                    text: "x"
                                    onClicked: modelData.dismiss()
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                text: modelData.summary
                                color: Theme.foreground
                                font.family: "Cantarell"
                                font.weight: Font.DemiBold
                                wrapMode: Text.Wrap
                            }

                            Label {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: modelData.body
                                textFormat: Text.PlainText
                                color: Theme.muted
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: 6

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
