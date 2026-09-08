import QtQuick
import Quickshell
import "../config/Theme.js" as Theme

PanelWindow {
    id: root

    required property var shellScreen
    required property var systemMonitorState
    required property var appListState

    screen: shellScreen
    implicitHeight: Theme.bottomBarHeight + Theme.frameRadius
    color: "transparent"
    exclusiveZone: Theme.bottomBarHeight

    anchors {
        left: true
        right: true
        bottom: true
    }

    mask: Region {
        width: 0
        height: 0
    }

    Rectangle {
        id: bottomBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.bottomBarHeight
        color: Theme.background
    }

    InnerFrameCorner {
        x: root.systemMonitorState.visibleWidth
        anchors.bottom: bottomBar.top
        width: Theme.frameRadius
        height: Theme.frameRadius
        atTop: false
        atLeft: true
    }

    InnerFrameCorner {
        x: root.width - root.appListState.visibleWidth - width
        anchors.bottom: bottomBar.top
        width: Theme.frameRadius
        height: Theme.frameRadius
        atTop: false
        atLeft: false
    }
}
