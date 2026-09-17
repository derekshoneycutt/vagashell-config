import importlib.util
import pathlib
import subprocess
import unittest
from unittest import mock

MODULE_PATH = pathlib.Path(__file__).parents[1] / "recorder_backend.py"
SPEC = importlib.util.spec_from_file_location("recorder_backend", MODULE_PATH)
BACKEND = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BACKEND)


class GeometryTests(unittest.TestCase):
    def test_parses_region(self):
        self.assertEqual(BACKEND.parse_geometry("120,45 800x600\n"), ("120,45 800x600", 800, 600))

    def test_parses_region_on_negative_coordinate_monitor(self):
        self.assertEqual(BACKEND.parse_geometry("-1920,0 1920x1080"), ("-1920,0 1920x1080", 1920, 1080))

    def test_rejects_invalid_region(self):
        with self.assertRaises(ValueError):
            BACKEND.parse_geometry("800x600+120+45")

    def test_selector_does_not_inherit_backend_stdin(self):
        backend = BACKEND.RecorderBackend()
        result = subprocess.CompletedProcess([], 0, stdout="10,20 300x200\n", stderr="")
        with mock.patch.object(BACKEND.time, "sleep"), mock.patch.object(
            BACKEND.subprocess, "run", return_value=result
        ) as run, mock.patch.object(backend, "emit"):
            backend.select()

        self.assertIs(run.call_args.kwargs["stdin"], subprocess.DEVNULL)
        self.assertEqual(backend.status, "ready")
        self.assertEqual(backend.geometry, "10,20 300x200")


class CommandTests(unittest.TestCase):
    def test_capture_command_uses_selected_geometry(self):
        command = BACKEND.capture_command("120,45 800x600", pathlib.Path("capture.mp4"))
        self.assertEqual(command[command.index("--geometry") + 1], "120,45 800x600")
        self.assertIn("libx264", command)

    def test_gif_command_generates_and_uses_palette(self):
        command = BACKEND.gif_command(pathlib.Path("capture.mp4"), pathlib.Path("capture.gif"))
        filters = command[command.index("-filter_complex") + 1]
        self.assertIn("fps=15", filters)
        self.assertIn("min(1280\\,iw)", filters)
        self.assertIn("palettegen", filters)
        self.assertIn("paletteuse", filters)


if __name__ == "__main__":
    unittest.main()