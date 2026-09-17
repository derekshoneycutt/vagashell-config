#!/usr/bin/env python3

import json
import re
import shutil
import signal
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

SELECTION_DELAY_SECONDS = 0.35
RECORDING_FRAMERATE = 30
GIF_FRAMERATE = 15
GIF_MAX_WIDTH = 1280
GEOMETRY_PATTERN = re.compile(r"^(-?\d+),(-?\d+) (\d+)x(\d+)$")


def parse_geometry(value):
    match = GEOMETRY_PATTERN.fullmatch(value.strip())
    if not match:
        raise ValueError("Region selector returned invalid geometry")

    x, y, width, height = (int(part) for part in match.groups())
    if width <= 0 or height <= 0:
        raise ValueError("Selected region must have a positive size")
    return f"{x},{y} {width}x{height}", width, height


def capture_command(geometry, output_path):
    return [
        "wf-recorder",
        "--geometry",
        geometry,
        "--framerate",
        str(RECORDING_FRAMERATE),
        "--codec",
        "libx264",
        "--codec-param",
        "preset=ultrafast",
        "--codec-param",
        "crf=18",
        "--file",
        str(output_path),
        "--overwrite",
    ]


def gif_command(input_path, output_path):
    filters = (
        f"fps={GIF_FRAMERATE},"
        f"scale=w='min({GIF_MAX_WIDTH}\\,iw)':h=-1:flags=lanczos,"
        "split[gif_source][palette_source];"
        "[palette_source]palettegen=stats_mode=diff[palette];"
        "[gif_source][palette]paletteuse=dither=sierra2_4a:diff_mode=rectangle"
    )
    return [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(input_path),
        "-filter_complex",
        filters,
        str(output_path),
    ]


class RecorderBackend:
    def __init__(self):
        self.status = "idle"
        self.geometry = ""
        self.width = 0
        self.height = 0
        self.output_path = ""
        self.error = ""
        self.started_at = 0.0
        self.recorder = None
        self.temporary_path = None
        self.log_path = None
        self.log_file = None

        missing = [tool for tool in ("slurp", "wf-recorder", "ffmpeg") if shutil.which(tool) is None]
        if missing:
            self.status = "unavailable"
            self.error = "Missing required tools: " + ", ".join(missing)

    def snapshot(self):
        return {
            "version": 1,
            "type": "state",
            "status": self.status,
            "geometry": self.geometry,
            "width": self.width,
            "height": self.height,
            "outputPath": self.output_path,
            "error": self.error,
            "startedAt": self.started_at,
        }

    def emit(self):
        print(json.dumps(self.snapshot(), separators=(",", ":")), flush=True)

    def set_error(self, message):
        self.status = "error"
        self.error = message.strip() or "Screen recording failed"
        self.started_at = 0.0
        self.emit()

    def select(self):
        if self.status in ("selecting", "starting", "recording", "converting", "unavailable"):
            return

        previous_status = "ready" if self.geometry else "idle"
        self.status = "selecting"
        self.error = ""
        self.emit()
        time.sleep(SELECTION_DELAY_SECONDS)

        result = subprocess.run(
            ["slurp", "-d", "-f", "%x,%y %wx%h"],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            self.status = previous_status
            self.emit()
            return

        try:
            self.geometry, self.width, self.height = parse_geometry(result.stdout)
        except ValueError as error:
            self.set_error(str(error))
            return

        self.status = "ready"
        self.output_path = ""
        self.error = ""
        self.emit()

    def start(self):
        if self.status != "ready" or not self.geometry:
            return

        self.status = "starting"
        self.error = ""
        self.output_path = ""
        self.emit()
        time.sleep(SELECTION_DELAY_SECONDS)

        output_directory = Path.home() / "Videos" / "Recordings"
        output_directory.mkdir(parents=True, exist_ok=True)
        basename = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        self.temporary_path = output_directory / f".{basename}.mp4"
        self.log_path = output_directory / f".{basename}.log"
        self.log_file = self.log_path.open("w+", encoding="utf-8")

        try:
            self.recorder = subprocess.Popen(
                capture_command(self.geometry, self.temporary_path),
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=self.log_file,
            )
        except OSError as error:
            self.close_log()
            self.set_error(str(error))
            return

        time.sleep(0.2)
        if self.recorder.poll() is not None:
            message = self.read_log() or "wf-recorder exited before capture began"
            self.recorder = None
            self.cleanup_temporary_files()
            self.set_error(message)
            return

        self.started_at = time.time()
        self.status = "recording"
        self.emit()

    def stop(self):
        if self.status != "recording" or self.recorder is None:
            return

        recorder = self.recorder
        recorder.send_signal(signal.SIGINT)
        try:
            return_code = recorder.wait(timeout=10)
        except subprocess.TimeoutExpired:
            recorder.terminate()
            try:
                return_code = recorder.wait(timeout=3)
            except subprocess.TimeoutExpired:
                recorder.kill()
                return_code = recorder.wait()

        self.recorder = None
        message = self.read_log()
        if return_code not in (0, 130) or not self.temporary_path or not self.temporary_path.exists():
            self.cleanup_temporary_files()
            self.set_error(message or f"wf-recorder exited with status {return_code}")
            return

        self.status = "converting"
        self.started_at = 0.0
        self.emit()
        output_path = self.temporary_path.with_name(self.temporary_path.stem.lstrip(".") + ".gif")
        result = subprocess.run(gif_command(self.temporary_path, output_path), capture_output=True, text=True, check=False)
        if result.returncode != 0:
            self.cleanup_temporary_files()
            self.set_error(result.stderr or "ffmpeg could not create the GIF")
            return

        self.output_path = str(output_path)
        self.status = "ready"
        self.error = ""
        self.cleanup_temporary_files()
        self.emit()

    def toggle(self):
        if self.status in ("idle", "error"):
            self.select()
        elif self.status == "ready":
            self.start()
        elif self.status == "recording":
            self.stop()

    def close_log(self):
        if self.log_file is not None:
            self.log_file.close()
            self.log_file = None

    def read_log(self):
        if self.log_file is None:
            return ""
        self.log_file.flush()
        self.log_file.seek(0)
        message = self.log_file.read().strip()
        self.close_log()
        return message

    def cleanup_temporary_files(self):
        self.close_log()
        for path in (self.temporary_path, self.log_path):
            if path is not None:
                try:
                    path.unlink(missing_ok=True)
                except OSError:
                    pass
        self.temporary_path = None
        self.log_path = None

    def shutdown(self):
        if self.recorder is not None and self.recorder.poll() is None:
            self.recorder.send_signal(signal.SIGINT)
            try:
                self.recorder.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.recorder.kill()
                self.recorder.wait()
        self.recorder = None
        self.cleanup_temporary_files()

    def handle(self, request):
        action = request.get("action")
        if action == "select":
            self.select()
        elif action == "start":
            self.start()
        elif action == "stop":
            self.stop()
        elif action == "toggle":
            self.toggle()
        elif action == "refresh":
            self.emit()


def main():
    backend = RecorderBackend()

    def exit_on_signal(_signum, _frame):
        raise SystemExit

    signal.signal(signal.SIGTERM, exit_on_signal)
    signal.signal(signal.SIGINT, exit_on_signal)
    backend.emit()
    try:
        for line in sys.stdin:
            try:
                request = json.loads(line)
            except json.JSONDecodeError:
                backend.set_error("Invalid recorder request")
                continue
            backend.handle(request)
    finally:
        backend.shutdown()


if __name__ == "__main__":
    main()