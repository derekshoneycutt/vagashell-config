import QtQuick
import "../config/Theme.js" as Theme

Canvas {
    id: root

    property var firstSeries: []
    property var secondSeries: []
    property real maxValue: 1
    property color firstColor: Theme.accent
    property color secondColor: Theme.foreground

    implicitWidth: 220
    implicitHeight: 34

    onFirstSeriesChanged: requestPaint()
    onSecondSeriesChanged: requestPaint()
    onMaxValueChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function drawSeries(context, values, color): void {
        if (!values || values.length === 0)
            return;

        context.beginPath();
        context.strokeStyle = color;
        context.lineWidth = 1.5;
        const denominator = Math.max(1, values.length - 1);
        for (let index = 0; index < values.length; index++) {
            const x = index * (width - 1) / denominator;
            const normalized = Math.max(0, Math.min(1, values[index] / Math.max(0.0001, maxValue)));
            const y = height - 1 - normalized * (height - 2);
            if (index === 0)
                context.moveTo(x, y);
            else
                context.lineTo(x, y);
        }
        context.stroke();
    }

    onPaint: {
        const context = getContext("2d");
        context.reset();
        context.fillStyle = Theme.hover;
        context.fillRect(0, 0, width, height);
        context.strokeStyle = "#335f6b70";
        context.lineWidth = 1;
        for (let row = 1; row < 4; row++) {
            const y = Math.round(row * height / 4) + 0.5;
            context.beginPath();
            context.moveTo(0, y);
            context.lineTo(width, y);
            context.stroke();
        }
        drawSeries(context, firstSeries, firstColor);
        drawSeries(context, secondSeries, secondColor);
    }
}
