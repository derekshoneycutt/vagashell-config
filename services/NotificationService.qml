import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Scope {
    id: root

    readonly property bool enabled: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== null
    readonly property var server: serverLoader.item
    property var latestNotification: null
    property bool toastVisible: false

    function dismissToast(): void {
        toastVisible = false;
    }

    LazyLoader {
        id: serverLoader
        active: root.enabled

        NotificationServer {
            keepOnReload: true
            persistenceSupported: true
            bodySupported: true
            actionsSupported: true
            imageSupported: true

            onNotification: notification => {
                notification.tracked = true;
                root.latestNotification = notification;
                root.toastVisible = true;
                toastTimer.restart();

                const items = trackedNotifications.values;
                if (items.length > 50)
                    items[0].dismiss();
            }
        }
    }

    Timer {
        id: toastTimer
        interval: 6000
        onTriggered: root.toastVisible = false
    }
}
