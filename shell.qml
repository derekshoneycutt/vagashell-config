//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "services"

ShellRoot {
    PersistentProperties {
        id: systemMonitorPreferences
        reloadableId: "systemMonitorState"

        property bool pinned: true
    }

    PersistentProperties {
        id: appListPreferences
        reloadableId: "appListState"

        property bool pinned: false
    }

    IpcHandler {
        target: "sidebars"

        function toggleLeft(): void {
            systemMonitorPreferences.pinned = !systemMonitorPreferences.pinned;
        }

        function toggleRight(): void {
            appListPreferences.pinned = !appListPreferences.pinned;
        }
    }

    NotificationService {
        id: notifications
    }

    SystemDataService {
        id: systemData
    }

    ConnectivityService {
        id: connectivity
    }

    AppPinService {
        id: appPins
    }

    Variants {
        model: Quickshell.screens

        DesktopFrame {
            required property var modelData
            shellScreen: modelData
            systemMonitorPreferences: systemMonitorPreferences
            appListPreferences: appListPreferences
            notificationService: notifications
            systemDataService: systemData
            connectivityService: connectivity
            appPinService: appPins
        }
    }
}
