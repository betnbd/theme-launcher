import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib" / "theme-launcher.sh"


def run_block_writer(initial_contents, block, begin, end, legacy_begin="", legacy_end=""):
    with tempfile.NamedTemporaryFile("w", delete=False) as handle:
        handle.write(initial_contents)
        path = handle.name
    script = textwrap.dedent(
        f"""
        source {LIB!s}
        theme_launcher_write_marked_block "$1" "$2" "$3" "$4" "$5" "$6"
        """
    ).strip()
    subprocess.run(
        ["bash", "-c", script, "_", path, block, begin, end, legacy_begin, legacy_end],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    contents = Path(path).read_text()
    Path(path).unlink(missing_ok=True)
    backup = Path(path + ".theme-launcher.bak")
    backup.unlink(missing_ok=True)
    return contents


class MarkedBlockTest(unittest.TestCase):
    BEGIN = "# theme-launcher begin"
    END = "# theme-launcher end"

    def test_inserts_block_into_empty_file(self):
        result = run_block_writer("", "hello = 1", self.BEGIN, self.END)
        self.assertEqual(
            result,
            f"{self.BEGIN}\nhello = 1\n{self.END}\n",
        )

    def test_replaces_existing_block(self):
        initial = f"top line\n{self.BEGIN}\nold = 0\n{self.END}\n"
        result = run_block_writer(initial, "new = 2", self.BEGIN, self.END)
        self.assertIn("top line", result)
        self.assertIn("new = 2", result)
        self.assertNotIn("old = 0", result)
        self.assertEqual(result.count(self.BEGIN), 1)
        self.assertEqual(result.count(self.END), 1)

    def test_idempotent_on_repeated_writes(self):
        first = run_block_writer("alpha\n", "payload = 1", self.BEGIN, self.END)
        second = run_block_writer(first, "payload = 1", self.BEGIN, self.END)
        self.assertEqual(first, second)

    def test_trims_trailing_blank_lines_before_block(self):
        initial = "alpha\n\n\n\n"
        result = run_block_writer(initial, "x = 1", self.BEGIN, self.END)
        self.assertNotIn("\n\n\n", result)
        self.assertTrue(result.startswith("alpha\n"))
        self.assertIn(f"\n{self.BEGIN}\nx = 1\n{self.END}\n", result)

    def test_upgrades_legacy_markers(self):
        legacy_begin = "# legacy begin"
        legacy_end = "# legacy end"
        initial = f"keep me\n{legacy_begin}\nold body\n{legacy_end}\n"
        result = run_block_writer(
            initial, "new body", self.BEGIN, self.END, legacy_begin, legacy_end
        )
        self.assertIn("keep me", result)
        self.assertNotIn(legacy_begin, result)
        self.assertNotIn("old body", result)
        self.assertIn(f"{self.BEGIN}\nnew body\n{self.END}\n", result)


if __name__ == "__main__":
    unittest.main()
