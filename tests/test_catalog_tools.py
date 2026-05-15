import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class CatalogToolsTest(unittest.TestCase):
    def run_cli(self, *args):
        return subprocess.run(
            ["./bin/theme-launcher", *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_bulk_metadata_includes_gui_detail_fields(self):
        result = self.run_cli("metadata")
        self.assertEqual(result.returncode, 0, result.stderr)
        metadata = json.loads(result.stdout)
        self.assertGreater(len(metadata), 0)
        first = metadata[0]
        self.assertIn("path", first)
        self.assertIn("targets", first)
        self.assertIn("source", first)


if __name__ == "__main__":
    unittest.main()
