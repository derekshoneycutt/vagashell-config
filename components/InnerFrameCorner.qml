import QtQuick
import "../config/Theme.js" as Theme

Item {
    id: root

    required property bool atTop
    required property bool atLeft

    implicitWidth: Theme.frameRadius
    implicitHeight: Theme.frameRadius

    Canvas {
        anchors.fill: parent

        onPaint: {
            const context = getContext("2d");
            context.clearRect(0, 0, width, height);
            context.globalCompositeOperation = "source-over";
            context.fillStyle = Theme.background;
            context.fillRect(0, 0, width, height);

            context.globalCompositeOperation = "destination-out";
            context.beginPath();
            context.arc(root.atLeft ? width : 0,
                        root.atTop ? height : 0,
                        Theme.frameRadius, 0, Math.PI * 2);
            context.fill();
            context.globalCompositeOperation = "source-over";
        }
    }
}