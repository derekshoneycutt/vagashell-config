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

    IpcHandler {
        target: "recorder"

        function state(): string {
            return JSON.stringify({
                status: recorder.status,
                geometry: recorder.geometry,
                error: recorder.error,
                outputPath: recorder.outputPath
            });
        }

        function select(): void {
            recorder.selectRegion();
        }

        function start(): void {
            recorder.startRecording();
        }

        function stop(): void {
            recorder.stopRecording();
        }

        function toggle(): void {
            recorder.toggle();
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

    RecorderService {
        id: recorder
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
            recorderService: recorder
            appPinService: appPins
        }
    }
}
