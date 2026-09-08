import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../config/Theme.js" as Theme

PanelWindow {
    id: root

    required property var shellScreen
    required property var systemMonitorState
    required property var appListState
    required property var frameOutlineState

    readonly property real leftEdge: systemMonitorState.visibleWidth
    readonly property real rightEdge: width - appListState.visibleWidth
    readonly property real topEdge: Theme.barHeight
    readonly property real bottomEdge: height - Theme.bottomBarHeight

    function pathData(): string {
        const left = leftEdge;
        const right = rightEdge;
        const top = topEdge;
        const bottom = bottomEdge;
        const radius = Theme.frameRadius;
        let path = `M ${left + radius} ${top}`;

        if (frameOutlineState.calendarVisible) {
            const calendarLeft = frameOutlineState.calendarX;
            const calendarRight = calendarLeft + frameOutlineState.calendarWidth;
            const calendarBottom = top + frameOutlineState.calendarHeight;
            const calendarRadius = 12;
            path += ` L ${calendarLeft - radius} ${top}`;
            path += ` A ${radius} ${radius} 0 0 1 ${calendarLeft} ${top + radius}`;
            path += ` L ${calendarLeft} ${calendarBottom - calendarRadius}`;
            path += ` Q ${calendarLeft} ${calendarBottom} ${calendarLeft + calendarRadius} ${calendarBottom}`;
            path += ` L ${calendarRight - calendarRadius} ${calendarBottom}`;
            path += ` Q ${calendarRight} ${calendarBottom} ${calendarRight} ${calendarBottom - calendarRadius}`;
            path += ` L ${calendarRight} ${top + radius}`;
            path += ` A ${radius} ${radius} 0 0 1 ${calendarRight + radius} ${top}`;
        }

        path += ` L ${right - radius} ${top}`;
        path += ` A ${radius} ${radius} 0 0 1 ${right} ${top + radius}`;
        path += ` L ${right} ${bottom - radius}`;
        path += ` A ${radius} ${radius} 0 0 1 ${right - radius} ${bottom}`;
        path += ` L ${left + radius} ${bottom}`;
        path += ` A ${radius} ${radius} 0 0 1 ${left} ${bottom - radius}`;
        path += ` L ${left} ${top + radius}`;
        path += ` A ${radius} ${radius} 0 0 1 ${left + radius} ${top}`;
        path += " Z";
        return path;
    }

    screen: shellScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-frame-outline"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    mask: Region {
        width: 0
        height: 0
    }

    Rectangle {
        id: outlineGradient
        anchors.fill: parent
        visible: false
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.frameOutlineStart }
            GradientStop { position: 1; color: Theme.frameOutlineEnd }
        }
    }

    Shape {
        id: outlineMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "white"
            strokeWidth: Theme.frameOutlineWidth
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin

            PathSvg { path: root.pathData() }
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: outlineMask
        autoPaddingEnabled: false
        colorization: 1
        colorizationColor: Theme.frameOutlineGlow
        blurEnabled: true
        blurMax: 8
        blur: 0.35
        opacity: Theme.frameOutlineGlowOpacity
    }

    MultiEffect {
        anchors.fill: parent
        source: outlineGradient
        maskEnabled: true
        maskSource: outlineMask
    }
}
