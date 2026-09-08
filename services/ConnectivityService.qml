import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var wifi: ({
        available: false,
        enabled: false,
        hardwareEnabled: false,
        networks: [],
        error: "Waiting for NetworkManager"
    })
    property var bluetooth: ({
        available: false,
        powered: false,
        discovering: false,
        devices: [],
        error: "Waiting for BlueZ"
    })
    property string busyAction: ""
    property string error: ""
    property bool stopping: false

    function send(request): void {
        if (!backend.running) {
            root.error = "Connectivity backend is not running";
            return;
        }
        backend.write(JSON.stringify(request) + "\n");
    }

    function refresh(): void {
        root.send({ action: "refresh" });
    }

    function connectWifi(ssid: string, password: string): void {
        root.send({ action: "wifiConnect", ssid: ssid, password: password });
    }

    function disconnectWifi(ssid: string): void {
        root.send({ action: "wifiDisconnect", ssid: ssid });
    }

    function forgetWifi(ssid: string): void {
        root.send({ action: "wifiForget", ssid: ssid });
    }

    function scanWifi(): void {
        root.send({ action: "wifiScan" });
    }

    function scanBluetooth(): void {
        root.send({ action: "bluetoothScan" });
    }

    function bluetoothAction(action: string, address: string): void {
        root.send({ action: action, address: address });
    }

    function accept(line): void {
        let data;
        try {
            data = JSON.parse(line);
        } catch (parseError) {
            root.error = "Invalid connectivity data: " + parseError;
            return;
        }

        if (data.version !== 1) {
            root.error = "Unsupported connectivity payload";
            return;
        }

        if (data.type === "snapshot") {
            root.wifi = data.wifi;
            root.bluetooth = data.bluetooth;
            root.busyAction = "";
            root.error = "";
        } else if (data.type === "busy") {
            root.busyAction = data.action || "working";
            root.error = "";
        } else if (data.type === "error") {
            root.busyAction = "";
            root.error = data.message || "Connectivity operation failed";
        }
    }

    Process {
        id: backend
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/connectivity_backend.py"]
        running: false
        stdinEnabled: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.accept(line)
        }

        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => console.warn("Connectivity backend:", line)
        }

        onExited: (exitCode, exitStatus) => {
            if (root.stopping)
                return;
            root.busyAction = "";
            root.error = "Connectivity backend exited (" + exitCode + ")";
            restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: backend.running = true
    }

    Timer {
        id: initialRefreshTimer
        interval: 250
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        backend.running = true;
        initialRefreshTimer.start();
    }

    Component.onDestruction: {
        root.stopping = true;
        backend.running = false;
    }
}
