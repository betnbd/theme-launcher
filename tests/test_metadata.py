import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "bin" / "theme-launcher"


class MetadataTest(unittest.TestCase):
    def run_cli_json(self, *args, env=None):
        process_env = os.environ.copy()
        if env:
            process_env.update(env)
        result = subprocess.run(
            [str(CLI), *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
            env=process_env,
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

    def test_single_theme_source_matches_bulk_metadata(self):
        bulk_metadata = {
            item["slug"]: item
            for item in self.run_cli_json("metadata")
        }
        single_metadata = self.run_cli_json("metadata", "gruvbox")
        self.assertEqual(
            single_metadata["source"],
            bulk_metadata["gruvbox"]["source"],
        )

    def test_bootstrap_loads_bundled_catalog_without_local_state(self):
        with tempfile.TemporaryDirectory() as launcher_home:
            bootstrap = self.run_cli_json(
                "bootstrap",
                env={
                    "THEME_LAUNCHER_HOME": launcher_home,
                    "THEME_LAUNCHER_BUNDLED_THEMES_DIR": str(ROOT / "catalog/themes"),
                },
            )

        self.assertEqual(25, len(bootstrap["metadata"]))
        self.assertEqual(
            {"bundled"},
            {item["source"] for item in bootstrap["metadata"]},
        )


if __name__ == "__main__":
    unittest.main()
