import QtQuick
import QtQuick.Layouts
import "../config/Theme.js" as Theme

ColumnLayout {
    id: root

    property string label: ""
    property real used: 0
    property real total: 0
    readonly property real fraction: total > 0 ? Math.max(0, Math.min(1, used / total)) : 0

    spacing: 3

    function formatBytes(value): string {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let amount = Math.max(0, Number(value) || 0);
        let unit = 0;
        while (amount >= 1024 && unit < units.length - 1) {
            amount /= 1024;
            unit++;
        }
        return amount.toFixed(unit < 3 ? 0 : 1) + " " + units[unit];
    }

    RowLayout {
        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            color: Theme.foreground
            font.family: "Cantarell"
            font.pixelSize: 11
            text: root.label
        }

        Text {
            color: Theme.muted
            font.family: "Cantarell"
            font.pixelSize: 10
            text: root.total > 0
                ? root.formatBytes(root.used) + " / " + root.formatBytes(root.total) + "  " + Math.round(root.fraction * 100) + "%"
                : "Unavailable"
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 6
        radius: 3
        color: Theme.hover

        Rectangle {
            width: parent.width * root.fraction
            height: parent.height
            radius: parent.radius
            color: Theme.accent

            Behavior on width {
                NumberAnimation { duration: 180 }
            }
        }
    }
}
