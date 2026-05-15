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

    def test_preview_texture_has_fixed_layout_size(self):
        script = r'''
          set -euo pipefail
          source ./lib/theme-launcher.sh
          python_cmd="$(theme_launcher_python_gtk_command)"
          "$python_cmd" - <<'PY'
import importlib.machinery
import importlib.util

loader = importlib.machinery.SourceFileLoader("theme_launcher_gui", "bin/theme-launcher-gui")
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)

texture = module.preview_texture_from_file("catalog/themes/gruvbox/preview.png")
assert texture.get_width() == module.PREVIEW_IMAGE_WIDTH
assert texture.get_height() == module.PREVIEW_IMAGE_HEIGHT
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


if __name__ == "__main__":
    unittest.main()
