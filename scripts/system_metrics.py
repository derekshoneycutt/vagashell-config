#!/usr/bin/env python3

import argparse
import json
import os
import platform
import re
import signal
import time
from pathlib import Path

SAMPLE_INTERVAL = 1.0
SECTOR_SIZE = 512
FILESYSTEMS = [
    ("Root", Path("/")),
    ("Audiobooks", Path("/home/derek/Audiobooks")),
    ("Pictures", Path("/home/derek/Pictures")),
]
VIRTUAL_INTERFACE_PREFIXES = (
    "br-",
    "docker",
    "dummy",
    "ifb",
    "lo",
    "tun",
    "tap",
    "veth",
    "virbr",
    "wg",
)


def read_text(path):
    try:
        return Path(path).read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError):
        return None


def clamp(value, minimum=0.0, maximum=100.0):
    return max(minimum, min(maximum, value))


def byte_rate(delta, elapsed):
    if elapsed <= 0 or delta < 0:
        return 0.0
    return delta / elapsed


class MetricsCollector:
    def __init__(self):
        self.previous_cpu = {}
        self.previous_disks = {}
        self.previous_network = {}
        self.previous_time = None
        self.sensor_scan_time = 0.0
        self.sensor_paths = []

    def sample(self):
        now = time.monotonic()
        elapsed = now - self.previous_time if self.previous_time is not None else 0.0
        self.previous_time = now

        cpu = self.sample_cpu()
        disks = self.sample_disks(elapsed)
        network = self.sample_network(elapsed)

        return {
            "version": 1,
            "timestamp": time.time(),
            "host": self.sample_host(),
            "cpu": cpu,
            "temperatures": self.sample_temperatures(now),
            "memory": self.sample_memory(),
            "filesystems": self.sample_filesystems(),
            "disks": disks,
            "network": network,
        }

    def sample_host(self):
        uptime_text = read_text("/proc/uptime") or "0"
        try:
            uptime_seconds = float(uptime_text.split()[0])
        except (ValueError, IndexError):
            uptime_seconds = 0.0

        return {
            "hostname": read_text("/etc/hostname") or platform.node(),
            "kernel": platform.release(),
            "uptimeSeconds": uptime_seconds,
        }

    def sample_cpu(self):
        stat_text = read_text("/proc/stat") or ""
        current = {}
        for line in stat_text.splitlines():
            fields = line.split()
            if not fields or not re.fullmatch(r"cpu\d*", fields[0]):
                continue
            try:
                values = [int(value) for value in fields[1:]]
            except ValueError:
                continue

            idle = sum(values[index] for index in (3, 4) if index < len(values))
            total = sum(values[:8])
            current[fields[0]] = (idle, total)

        usage = {}
        for name, (idle, total) in current.items():
            previous = self.previous_cpu.get(name)
            if previous is None:
                usage[name] = 0.0
                continue

            idle_delta = idle - previous[0]
            total_delta = total - previous[1]
            usage[name] = clamp(100.0 * (1.0 - idle_delta / total_delta)) if total_delta > 0 else 0.0

        self.previous_cpu = current
        threads = [usage[name] for name in sorted(usage, key=self.cpu_sort_key) if name != "cpu"]
        pair_offset = len(threads) // 2
        pairs = [
            {
                "label": f"{index}/{index + pair_offset}",
                "first": threads[index],
                "second": threads[index + pair_offset],
            }
            for index in range(pair_offset)
        ]
        return {"aggregate": usage.get("cpu", 0.0), "threads": threads, "pairs": pairs}

    @staticmethod
    def cpu_sort_key(name):
        return -1 if name == "cpu" else int(name[3:])

    def discover_sensors(self):
        sensors = []
        for hwmon in sorted(Path("/sys/class/hwmon").glob("hwmon*")):
            device_name = read_text(hwmon / "name") or hwmon.name
            for input_path in sorted(hwmon.glob("temp*_input")):
                match = re.fullmatch(r"temp(\d+)_input", input_path.name)
                if not match:
                    continue
                label = read_text(hwmon / f"temp{match.group(1)}_label")
                display_name = label or device_name
                sensors.append((self.temperature_sort_key(device_name, display_name), display_name, input_path))
        sensors.sort(key=lambda item: item[0])
        self.sensor_paths = [(name, path) for _, name, path in sensors]

    @staticmethod
    def temperature_sort_key(device_name, label):
        device = device_name.lower()
        label_lower = label.lower()
        if device == "k10temp" or label_lower == "tctl":
            return (0, label_lower)
        if device == "amdgpu" or label_lower == "edge":
            return (1, label_lower)
        if device == "nvme" or label_lower == "composite":
            return (2, label_lower)
        return (3, device, label_lower)

    def sample_temperatures(self, now):
        if not self.sensor_paths or now - self.sensor_scan_time >= 60:
            self.discover_sensors()
            self.sensor_scan_time = now

        temperatures = []
        for name, path in self.sensor_paths:
            raw_value = read_text(path)
            try:
                value = float(raw_value) / 1000.0
            except (TypeError, ValueError):
                continue
            if -50 <= value <= 200:
                temperatures.append({"name": name, "celsius": value})
        return temperatures

    @staticmethod
    def sample_memory():
        values = {}
        for line in (read_text("/proc/meminfo") or "").splitlines():
            fields = line.replace(":", "").split()
            if len(fields) >= 2:
                try:
                    values[fields[0]] = int(fields[1]) * 1024
                except ValueError:
                    pass

        memory_total = values.get("MemTotal", 0)
        memory_used = max(0, memory_total - values.get("MemAvailable", 0))
        swap_total = values.get("SwapTotal", 0)
        swap_used = max(0, swap_total - values.get("SwapFree", 0))
        return {
            "used": memory_used,
            "total": memory_total,
            "percent": 100.0 * memory_used / memory_total if memory_total else 0.0,
            "swapUsed": swap_used,
            "swapTotal": swap_total,
            "swapPercent": 100.0 * swap_used / swap_total if swap_total else 0.0,
        }

    @staticmethod
    def sample_filesystems():
        filesystems = []
        for name, path in FILESYSTEMS:
            try:
                stats = os.statvfs(path)
            except OSError:
                continue
            total = stats.f_blocks * stats.f_frsize
            available = stats.f_bavail * stats.f_frsize
            used = max(0, total - available)
            filesystems.append({
                "name": name,
                "path": str(path),
                "used": used,
                "total": total,
                "percent": 100.0 * used / total if total else 0.0,
            })
        return filesystems

    def sample_disks(self, elapsed):
        disks = []
        current = {}
        for device_path in sorted(Path("/sys/block").iterdir()):
            device = device_path.name
            if device.startswith(("loop", "ram", "zram", "dm-", "sr")):
                continue
            fields = (read_text(device_path / "stat") or "").split()
            if len(fields) < 7:
                continue
            try:
                counters = (int(fields[2]) * SECTOR_SIZE, int(fields[6]) * SECTOR_SIZE)
            except ValueError:
                continue
            current[device] = counters
            previous = self.previous_disks.get(device)
            read_rate = byte_rate(counters[0] - previous[0], elapsed) if previous else 0.0
            write_rate = byte_rate(counters[1] - previous[1], elapsed) if previous else 0.0
            disks.append({"name": device, "readBytesPerSecond": read_rate, "writeBytesPerSecond": write_rate})
        self.previous_disks = current
        return disks

    def sample_network(self, elapsed):
        candidates = []
        for interface_path in sorted(Path("/sys/class/net").iterdir()):
            name = interface_path.name
            if name.startswith(VIRTUAL_INTERFACE_PREFIXES):
                continue
            operstate = read_text(interface_path / "operstate") or "unknown"
            try:
                rx_bytes = int(read_text(interface_path / "statistics/rx_bytes") or 0)
                tx_bytes = int(read_text(interface_path / "statistics/tx_bytes") or 0)
            except ValueError:
                continue
            candidates.append((operstate != "up", name, rx_bytes, tx_bytes))

        if not candidates:
            self.previous_network = {}
            return {"interface": "", "state": "unavailable", "receiveBytesPerSecond": 0.0, "transmitBytesPerSecond": 0.0}

        _, name, rx_bytes, tx_bytes = min(candidates)
        current = {name: (rx_bytes, tx_bytes)}
        previous = self.previous_network.get(name)
        self.previous_network = current
        return {
            "interface": name,
            "state": read_text(Path("/sys/class/net") / name / "operstate") or "unknown",
            "receiveBytesPerSecond": byte_rate(rx_bytes - previous[0], elapsed) if previous else 0.0,
            "transmitBytesPerSecond": byte_rate(tx_bytes - previous[1], elapsed) if previous else 0.0,
        }


def main():
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)

    parser = argparse.ArgumentParser(description="Stream system metrics as JSON lines.")
    parser.add_argument("--once", action="store_true", help="Emit one initialized sample and exit.")
    parser.add_argument("--interval", type=float, default=SAMPLE_INTERVAL, help="Seconds between samples.")
    arguments = parser.parse_args()

    collector = MetricsCollector()
    if arguments.once:
        collector.sample()
        time.sleep(max(0.05, arguments.interval))
        print(json.dumps(collector.sample(), separators=(",", ":")), flush=True)
        return

    while True:
        started = time.monotonic()
        print(json.dumps(collector.sample(), separators=(",", ":")), flush=True)
        remaining = arguments.interval - (time.monotonic() - started)
        if remaining > 0:
            time.sleep(remaining)


if __name__ == "__main__":
    main()
