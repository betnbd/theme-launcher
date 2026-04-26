import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class GtkPythonTest(unittest.TestCase):
    def test_launcher_finds_python_with_gtk_bindings(self):
        script = r'''
          set -euo pipefail
          source ./lib/theme-launcher.sh
          python_cmd="$(theme_launcher_python_gtk_command)"
          "$python_cmd" - <<'PY'
import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk  # noqa: F401
PY
        '''

        result = subprocess.run(
            ["bash", "-c", script],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_gui_shebang_uses_gtk_capable_python(self):
        shebang = (ROOT / "bin" / "theme-launcher-gui").read_text().splitlines()[0]
        self.assertEqual(shebang, "#!/usr/bin/python3")


if __name__ == "__main__":
    unittest.main()
