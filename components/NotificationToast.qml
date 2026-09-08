import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../config/Theme.js" as Theme

PopupWindow {
    id: root

    required property var anchorWindow
    required property var anchorItem
    property var notification
    signal dismissed

    anchor.window: anchorWindow
    anchor.item: anchorItem
    anchor.rect.y: anchorItem.height + 8
    anchor.rect.x: anchorItem.width - implicitWidth
    implicitWidth: 360
    implicitHeight: notificationContent.implicitHeight + 24
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Theme.elevated
        radius: Theme.radius
        border.width: 1
        border.color: Theme.accent

        ColumnLayout {
            id: notificationContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 5

            RowLayout {
                Layout.fillWidth: true

                Label {
                    Layout.fillWidth: true
                    text: root.notification ? root.notification.appName : ""
                    color: Theme.muted
                    font.family: "Cantarell"
                    font.pixelSize: 11
                }

                ToolButton {
                    text: "x"
                    onClicked: root.dismissed()
                }
            }

            Label {
                Layout.fillWidth: true
                text: root.notification ? root.notification.summary : ""
                color: Theme.foreground
                font.family: "Cantarell"
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }

            Label {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.notification ? root.notification.body : ""
                textFormat: Text.PlainText
                color: Theme.muted
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }
        }
    }
}
