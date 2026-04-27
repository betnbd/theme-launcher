import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "bin" / "theme-launcher"


class FilterParsingTest(unittest.TestCase):
    def run_cli(self, *args):
        return subprocess.run(
            [str(CLI), *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_only_and_skip_are_mutually_exclusive(self):
        result = self.run_cli("apply", "nonexistent-theme-xyz", "--only", "gnome", "--skip", "ghostty")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cannot combine --only and --skip", result.stderr)

    def test_wallpaper_and_random_are_mutually_exclusive(self):
        result = self.run_cli("apply", "nonexistent-theme-xyz", "--random-wallpaper", "--wallpaper", "foo.png")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cannot combine --wallpaper and --random-wallpaper", result.stderr)

    def test_wallpaper_requires_argument(self):
        result = self.run_cli("apply", "nonexistent-theme-xyz", "--wallpaper")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing wallpaper name after --wallpaper", result.stderr)

    def test_only_requires_argument(self):
        result = self.run_cli("apply", "nonexistent-theme-xyz", "--only")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing target list after --only", result.stderr)

    def test_unknown_option_is_rejected(self):
        result = self.run_cli("apply", "nonexistent-theme-xyz", "--no-such-flag")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown option", result.stderr)


if __name__ == "__main__":
    unittest.main()
