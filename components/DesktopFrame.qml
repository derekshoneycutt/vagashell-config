import QtQuick
import Quickshell
import "../config/Theme.js" as Theme

Scope {
    id: root

    required property var shellScreen
    required property var systemMonitorPreferences
    required property var appListPreferences
    required property var notificationService
    required property var systemDataService
    required property var connectivityService

    QtObject {
        id: systemMonitorState

        readonly property bool pinned: root.systemMonitorPreferences.pinned
        property bool hovered: false
        readonly property bool expanded: pinned || hovered
        property real expansion: expanded ? 1 : 0
        readonly property real visibleWidth: Theme.sidebarHandleWidth
            + (Theme.sidebarWidth - Theme.sidebarHandleWidth) * expansion
        readonly property real reservedWidth: pinned ? Theme.sidebarWidth : Theme.sidebarHandleWidth

        function togglePinned(): void {
            root.systemMonitorPreferences.pinned = !root.systemMonitorPreferences.pinned;
        }

        Behavior on expansion {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
    }

    QtObject {
        id: appListState

        readonly property bool pinned: root.appListPreferences.pinned
        property bool hovered: false
        readonly property bool expanded: pinned || hovered
        property real expansion: expanded ? 1 : 0
        readonly property real visibleWidth: Theme.appListHandleWidth
            + (Theme.appListWidth - Theme.appListHandleWidth) * expansion
        readonly property real reservedWidth: pinned ? Theme.appListWidth : Theme.appListHandleWidth

        function togglePinned(): void {
            root.appListPreferences.pinned = !root.appListPreferences.pinned;
        }

        Behavior on expansion {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
    }

    QtObject {
        id: frameOutlineState

        property bool calendarVisible: false
        property real calendarX: 0
        property real calendarWidth: 0
        property real calendarHeight: 0
    }

    TopBar {
        shellScreen: root.shellScreen
        notificationService: root.notificationService
        systemMonitorState: systemMonitorState
        appListState: appListState
        frameOutlineState: frameOutlineState
    }

    BottomFrame {
        shellScreen: root.shellScreen
        systemMonitorState: systemMonitorState
        appListState: appListState
    }

    SystemMonitor {
        shellScreen: root.shellScreen
        systemDataService: root.systemDataService
        uiState: systemMonitorState
    }

    RightFrame {
        shellScreen: root.shellScreen
        uiState: appListState
        connectivityService: root.connectivityService
    }

    FrameOutline {
        shellScreen: root.shellScreen
        systemMonitorState: systemMonitorState
        appListState: appListState
        frameOutlineState: frameOutlineState
    }

    Dock {
        shellScreen: root.shellScreen
    }
}
