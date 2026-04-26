import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "bin" / "theme-launcher"


class MetadataTest(unittest.TestCase):
    def run_cli_json(self, *args):
        result = subprocess.run(
            [str(CLI), *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
        return json.loads(result.stdout)

    def test_current_wallpaper_is_only_reported_for_current_theme(self):
        current_theme = subprocess.run(
            [str(CLI), "current"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()

        metadata = self.run_cli_json("metadata")
        for item in metadata:
            current_wallpaper = item.get("current_wallpaper")
            if item["slug"] == current_theme:
                continue
            self.assertIsNone(
                current_wallpaper,
                f"{item['slug']} leaked current_wallpaper={current_wallpaper!r}",
            )


if __name__ == "__main__":
    unittest.main()
