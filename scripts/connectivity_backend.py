#!/usr/bin/env python3

import argparse
import concurrent.futures
import json
import os
import re
import shutil
import subprocess
import sys

COMMAND_TIMEOUT = 20
DEVICE_PATTERN = re.compile(r"^Device ([0-9A-Fa-f:]{17}) (.+)$")


def emit(payload):
    print(json.dumps({"version": 1, **payload}, separators=(",", ":")), flush=True)


def split_escaped(line, separator=":"):
    fields = []
    current = []
    escaped = False
    for character in line.rstrip("\n"):
        if escaped:
            current.append(character)
            escaped = False
        elif character == "\\":
            escaped = True
        elif character == separator:
            fields.append("".join(current))
            current = []
        else:
            current.append(character)
    if escaped:
        current.append("\\")
    fields.append("".join(current))
    return fields


def run(command, timeout=COMMAND_TIMEOUT, input_text=None):
    environment = os.environ.copy()
    environment["LC_ALL"] = "C"
    result = subprocess.run(
        command,
        input=input_text,
        text=True,
        capture_output=True,
        timeout=timeout,
        env=environment,
        check=False,
    )
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or f"Command exited {result.returncode}"
        raise RuntimeError(message)
    return result.stdout


def nmcli(*arguments, input_text=None, timeout=COMMAND_TIMEOUT):
    return run(["nmcli", *arguments], timeout=timeout, input_text=input_text)


def bluetoothctl(*arguments, timeout=COMMAND_TIMEOUT):
    return run(["bluetoothctl", "--timeout", str(timeout), *arguments], timeout=timeout + 2)


def saved_wifi_profiles():
    profiles = set()
    output = nmcli("-t", "--escape", "yes", "-f", "NAME,TYPE", "connection", "show")
    for line in output.splitlines():
        fields = split_escaped(line)
        if len(fields) >= 2 and fields[-1] in {"802-11-wireless", "wifi"}:
            profiles.add(":".join(fields[:-1]))
    return profiles


def wifi_snapshot():
    if shutil.which("nmcli") is None:
        return {"available": False, "enabled": False, "hardwareEnabled": False, "networks": [], "error": "nmcli is not installed"}

    try:
        radio = nmcli("-t", "-f", "WIFI,WIFI-HW", "radio").strip().split(":")
        enabled = bool(radio) and radio[0] == "enabled"
        hardware_enabled = len(radio) > 1 and radio[1] == "enabled"
        saved = saved_wifi_profiles()
        output = nmcli("-t", "--escape", "yes", "-f", "IN-USE,SSID,BSSID,SIGNAL,SECURITY", "device", "wifi", "list")
        networks = {}
        for line in output.splitlines():
            fields = split_escaped(line)
            if len(fields) != 5:
                continue
            in_use, ssid, bssid, signal_text, security = fields
            if not ssid:
                continue
            try:
                signal = max(0, min(100, int(signal_text)))
            except ValueError:
                signal = 0
            key = (ssid, security)
            candidate = {
                "ssid": ssid,
                "bssid": bssid,
                "signal": signal,
                "security": security,
                "secured": bool(security and security != "--"),
                "connected": in_use == "*",
                "saved": ssid in saved,
            }
            previous = networks.get(key)
            if previous is None or candidate["connected"] or candidate["signal"] > previous["signal"]:
                networks[key] = candidate

        ordered = sorted(
            networks.values(),
            key=lambda network: (
                not network["connected"],
                not network["saved"],
                -network["signal"],
                network["ssid"].lower(),
            ),
        )
        return {"available": True, "enabled": enabled, "hardwareEnabled": hardware_enabled, "networks": ordered, "error": ""}
    except (OSError, subprocess.TimeoutExpired, RuntimeError) as error:
        return {"available": True, "enabled": False, "hardwareEnabled": False, "networks": [], "error": str(error)}


def parse_bluetooth_info(output, address, fallback_name):
    values = {}
    for line in output.splitlines():
        stripped = line.strip()
        if ": " in stripped:
            key, value = stripped.split(": ", 1)
            values[key] = value
    battery_text = values.get("Battery Percentage", "")
    battery_match = re.search(r"\((\d+)\)", battery_text)
    return {
        "address": address,
        "name": values.get("Name") or values.get("Alias") or fallback_name,
        "alias": values.get("Alias") or fallback_name,
        "connected": values.get("Connected") == "yes",
        "paired": values.get("Paired") == "yes",
        "trusted": values.get("Trusted") == "yes",
        "blocked": values.get("Blocked") == "yes",
        "battery": int(battery_match.group(1)) if battery_match else None,
    }


def bluetooth_snapshot():
    if shutil.which("bluetoothctl") is None:
        return {"available": False, "powered": False, "discovering": False, "devices": [], "error": "bluetoothctl is not installed"}

    try:
        controller_output = bluetoothctl("show")
        powered = "Powered: yes" in controller_output
        discovering = "Discovering: yes" in controller_output
        discovered_devices = []
        for line in bluetoothctl("devices").splitlines():
            match = DEVICE_PATTERN.match(line.strip())
            if match:
                discovered_devices.append(match.groups())

        def device_snapshot(device):
            address, name = device
            try:
                info = bluetoothctl("info", address, timeout=5)
                return parse_bluetooth_info(info, address, name)
            except (subprocess.TimeoutExpired, RuntimeError):
                return parse_bluetooth_info("", address, name)

        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            devices = list(executor.map(device_snapshot, discovered_devices))
        devices.sort(key=lambda device: (not device["connected"], not device["paired"], device["name"].lower()))
        return {"available": True, "powered": powered, "discovering": discovering, "devices": devices, "error": ""}
    except (OSError, subprocess.TimeoutExpired, RuntimeError) as error:
        return {"available": True, "powered": False, "discovering": False, "devices": [], "error": str(error)}


def snapshot():
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        wifi_future = executor.submit(wifi_snapshot)
        bluetooth_future = executor.submit(bluetooth_snapshot)
        return {"type": "snapshot", "wifi": wifi_future.result(), "bluetooth": bluetooth_future.result()}


def perform(request):
    action = request.get("action")
    if action == "refresh":
        return snapshot()
    if action == "wifiScan":
        nmcli("device", "wifi", "rescan")
    elif action == "wifiDisconnect":
        nmcli("connection", "down", request["ssid"])
    elif action == "wifiForget":
        nmcli("connection", "delete", request["ssid"])
    elif action == "wifiConnect":
        command = ["--ask", "--wait", "30", "device", "wifi", "connect", request["ssid"]]
        password = request.get("password", "")
        nmcli(*command, input_text=(password + "\n") if password else None, timeout=35)
    elif action == "bluetoothScan":
        bluetoothctl("scan", "on", timeout=8)
    elif action == "bluetoothPair":
        address = request["address"]
        bluetoothctl("pair", address, timeout=30)
        bluetoothctl("trust", address)
        bluetoothctl("connect", address, timeout=30)
    elif action in {"bluetoothConnect", "bluetoothDisconnect", "bluetoothRemove", "bluetoothTrust"}:
        operation = action.removeprefix("bluetooth").lower()
        bluetoothctl(operation, request["address"], timeout=30)
    else:
        raise ValueError(f"Unsupported action: {action}")
    return snapshot()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true")
    arguments = parser.parse_args()

    if arguments.once:
        emit(snapshot())
        return

    emit(snapshot())
    for line in sys.stdin:
        try:
            request = json.loads(line)
            emit({"type": "busy", "action": request.get("action", "")})
            emit(perform(request))
        except (KeyError, ValueError, RuntimeError, OSError, subprocess.TimeoutExpired, json.JSONDecodeError) as error:
            emit(snapshot())
            emit({"type": "error", "message": str(error)})


if __name__ == "__main__":
    main()
