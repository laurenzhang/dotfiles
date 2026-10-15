import json
import os
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(__file__), "..", "scripts", "merge-pi-settings.py")


class MergePiSettingsTest(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.TemporaryDirectory()
        self.addCleanup(self.home.cleanup)
        self.path = os.path.join(self.home.name, ".pi", "agent", "settings.json")

    def run_script(self):
        return subprocess.run([sys.executable, SCRIPT], env={**os.environ, "HOME": self.home.name}, capture_output=True, text=True)

    def write(self, text):
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        with open(self.path, "w") as f:
            f.write(text)

    def read(self):
        with open(self.path) as f:
            return json.load(f)

    def test_creates_the_file(self):
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.read(), {"tuiMode": "regular"})

    def test_keeps_existing_settings(self):
        self.write('{"lastChangelogVersion": "1.2.0"}')
        self.run_script()
        self.assertEqual(self.read(), {"lastChangelogVersion": "1.2.0", "tuiMode": "regular"})

    def test_keeps_a_value_set_by_hand(self):
        self.write('{"tuiMode": "fullscreen"}')
        result = self.run_script()
        self.assertEqual(self.read(), {"tuiMode": "fullscreen"})
        self.assertIn("already set", result.stdout)

    def test_is_idempotent(self):
        self.run_script()
        first = self.read()
        self.run_script()
        self.assertEqual(self.read(), first)

    def test_invalid_json_is_left_untouched(self):
        self.write("{bad")
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        with open(self.path) as f:
            self.assertEqual(f.read(), "{bad")


if __name__ == "__main__":
    unittest.main()
