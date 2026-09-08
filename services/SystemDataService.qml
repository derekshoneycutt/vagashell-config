import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var snapshot: null
    property var aggregateHistory: []
    property var pairHistories: []
    property var diskReadHistory: []
    property var diskWriteHistory: []
    property var networkReceiveHistory: []
    property var networkTransmitHistory: []
    property bool stale: true
    property string error: "Waiting for system metrics"
    property bool stopping: false

    readonly property int historyLength: 60

    function appendSample(history, value): var {
        const next = history.slice(Math.max(0, history.length - root.historyLength + 1));
        next.push(Number.isFinite(value) ? value : 0);
        return next;
    }

    function sumRate(items, key): real {
        let total = 0;
        for (const item of items || [])
            total += Number(item[key]) || 0;
        return total;
    }

    function accept(line): void {
        let data;
        try {
            data = JSON.parse(line);
        } catch (parseError) {
            root.error = "Invalid metrics data: " + parseError;
            return;
        }

        if (data.version !== 1 || !data.cpu || !data.memory) {
            root.error = "Unsupported metrics payload";
            return;
        }

        root.aggregateHistory = root.appendSample(root.aggregateHistory, data.cpu.aggregate / 100);

        const nextPairHistories = [];
        for (let index = 0; index < data.cpu.pairs.length; index++) {
            const previous = root.pairHistories[index] || { first: [], second: [] };
            nextPairHistories.push({
                first: root.appendSample(previous.first, data.cpu.pairs[index].first / 100),
                second: root.appendSample(previous.second, data.cpu.pairs[index].second / 100)
            });
        }
        root.pairHistories = nextPairHistories;

        root.diskReadHistory = root.appendSample(root.diskReadHistory, root.sumRate(data.disks, "readBytesPerSecond"));
        root.diskWriteHistory = root.appendSample(root.diskWriteHistory, root.sumRate(data.disks, "writeBytesPerSecond"));
        root.networkReceiveHistory = root.appendSample(root.networkReceiveHistory, data.network.receiveBytesPerSecond);
        root.networkTransmitHistory = root.appendSample(root.networkTransmitHistory, data.network.transmitBytesPerSecond);
        root.snapshot = data;
        root.stale = false;
        root.error = "";
        staleTimer.restart();
    }

    Process {
        id: collector
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/system_metrics.py"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.accept(line)
        }

        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => console.warn("System metrics:", line)
        }

        onExited: (exitCode, exitStatus) => {
            if (root.stopping)
                return;
            root.stale = true;
            root.error = "Metrics collector exited (" + exitCode + ")";
            restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: collector.running = true
    }

    Timer {
        id: staleTimer
        interval: 5000
        onTriggered: {
            root.stale = true;
            root.error = "System metrics are stale";
        }
    }

    Component.onDestruction: {
        root.stopping = true;
        collector.running = false;
    }
}
