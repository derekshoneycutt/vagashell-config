import importlib.util
import pathlib
import unittest

MODULE_PATH = pathlib.Path(__file__).parents[1] / "connectivity_backend.py"
SPEC = importlib.util.spec_from_file_location("connectivity_backend", MODULE_PATH)
BACKEND = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BACKEND)


class SplitEscapedTests(unittest.TestCase):
    def test_unescapes_colons_and_backslashes(self):
        self.assertEqual(
            BACKEND.split_escaped(r"*:Cafe\: Upstairs:AA\:BB\:CC:81:WPA2"),
            ["*", "Cafe: Upstairs", "AA:BB:CC", "81", "WPA2"],
        )

    def test_preserves_spaces_and_empty_fields(self):
        self.assertEqual(
            BACKEND.split_escaped(" :Studio Guest::97:"),
            [" ", "Studio Guest", "", "97", ""],
        )


class BluetoothInfoTests(unittest.TestCase):
    def test_parses_state_and_battery(self):
        output = """
Device CC:D6:81:D3:FB:39 (public)
        Name: MX Keys
        Alias: Desk Keyboard
        Paired: yes
        Trusted: yes
        Blocked: no
        Connected: yes
        Battery Percentage: 0x32 (50)
"""
        self.assertEqual(
            BACKEND.parse_bluetooth_info(output, "CC:D6:81:D3:FB:39", "Fallback"),
            {
                "address": "CC:D6:81:D3:FB:39",
                "name": "MX Keys",
                "alias": "Desk Keyboard",
                "connected": True,
                "paired": True,
                "trusted": True,
                "blocked": False,
                "battery": 50,
            },
        )

    def test_falls_back_for_incomplete_device(self):
        device = BACKEND.parse_bluetooth_info("", "00:11:22:33:44:55", "Speaker")
        self.assertEqual(device["name"], "Speaker")
        self.assertIsNone(device["battery"])
        self.assertFalse(device["connected"])


if __name__ == "__main__":
    unittest.main()
