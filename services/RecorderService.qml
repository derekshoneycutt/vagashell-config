import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string status: "idle"
    property string geometry: ""
    property int regionWidth: 0
    property int regionHeight: 0
    property string outputPath: ""
    property string error: ""
    property real startedAt: 0
    property int elapsedSeconds: 0
    property bool stopping: false

    readonly property bool uiHidden: status === "selecting" || status === "starting"

    function send(action: string): void {
        if (!backend.running) {
            root.status = "error";
            root.error = "Recorder backend is not running";
            return;
        }
        backend.write(JSON.stringify({ action: action }) + "\n");
    }

    function selectRegion(): void { root.send("select"); }
    function startRecording(): void { root.send("start"); }
    function stopRecording(): void { root.send("stop"); }
    function toggle(): void { root.send("toggle"); }

    function accept(line): void {
        let data;
        try {
            data = JSON.parse(line);
        } catch (parseError) {
            root.status = "error";
            root.error = "Invalid recorder data: " + parseError;
            return;
        }

        if (data.version !== 1 || data.type !== "state") {
            root.status = "error";
            root.error = "Unsupported recorder payload";
            return;
        }

        root.status = data.status;
        root.geometry = data.geometry || "";
        root.regionWidth = data.width || 0;
        root.regionHeight = data.height || 0;
        root.outputPath = data.outputPath || "";
        root.error = data.error || "";
        root.startedAt = data.startedAt || 0;
        root.elapsedSeconds = root.startedAt > 0
            ? Math.max(0, Math.floor(Date.now() / 1000 - root.startedAt)) : 0;
    }

    Process {
        id: backend
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/recorder_backend.py"]
        running: false
        stdinEnabled: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.accept(line)
        }

        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => console.warn("Recorder backend:", line)
        }

        onExited: (exitCode, exitStatus) => {
            if (root.stopping)
                return;
            root.status = "error";
            root.error = "Recorder backend exited (" + exitCode + ")";
            restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: backend.running = true
    }

    Timer {
        interval: 1000
        running: root.status === "recording"
        repeat: true
        triggeredOnStart: true
        onTriggered: root.elapsedSeconds = root.startedAt > 0
            ? Math.max(0, Math.floor(Date.now() / 1000 - root.startedAt)) : 0
    }

    Component.onCompleted: backend.running = true

    Component.onDestruction: {
        root.stopping = true;
        backend.running = false;
    }
}